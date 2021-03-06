function [traj_hto, cost_opt_set] = SMTOend(traj_q, T, funcJacob, dim, ... 
                        iteNum, obstacles, radii, eps, bodySizes, collision_threshold, cost_weights, angleRange1, angleRange2,... 
                        freeAxis, jointLimit_low, jointLimit_high, seedNum)

%function for stochastic multimodal trajectory optimization (SMTO)
% this function optimize the goal orientation of the end-effector

    compJacob = funcJacob;
    linkNum = size(traj_q,2);
    traj_task = zeros(T, linkNum, dim);

    for t=1:T
       [x, ~] = compJacob( traj_q(t, :), linkNum );
       traj_task(t, :, :) = x;
    end
    goal_task = zeros(dim, 1);
    goal_task(:) = traj_task(T,linkNum, :);
    start_task = zeros(dim, 1);
    start_task(:) = traj_task(T,linkNum, :);
        
    K = zeros(T, T);

    for t=2:T-1
        K(t, t) = 1.0; 
        K(t+1, t) = - 1.0;
    end
    K(T, T)=1;
       
    A = K' * K;
    A(T,T)=2;
    
    K_st = zeros(T, T);
    for t=1:(T-1)
        K_st(t, t) = 1.0; 
        K_st(t+1, t) = - 1.0;
    end
    A_st = K_st' * K_st;
    M_st = pinv(A_st);
    
    M_end = pinv(A);

    B = A;
    B( T, : ) = [ ];
    B( : , T ) = [ ];
    B(:, 1) = [ ];
    R = inv(B' * B);

    maxR = max(max(R));
    M =2.0* R / (maxR *T);

    zero_mean = zeros( T-2, 1 );

    N = 400;
    modeNum = 1;
    bestBatchNum = 100;
    collisionCost =100;
    collisionCost_pre = 100;
    cnt  = 0;
    traj_hto = [];
    
    noise_set =  zeros(T-2, linkNum, N);
    cost_set = zeros(N, 1);
    p_set = zeros(N, 1);
    traj_sample_set = zeros(T, linkNum, N);
    best_traj_sample_set = zeros(T, linkNum, bestBatchNum);
    best_traj_costs = 100*ones(bestBatchNum, 1);
    p_ini = 1;
    
    Nend = floor(seedNum * angleRange1/ (angleRange1+ angleRange2)) ;
    goal_config_given = traj_q(T, :);
    goal_config = goal_config_given;
    
    % Prepare a set of goal configurations
    config_set = zeros(seedNum+1, linkNum);
    config_set(1, :) =  goal_config_given;
    for k = 1:seedNum+1
        if k < Nend + 1
            noise_ang = angleRange1/Nend;
        else
            noise_ang = angleRange2/ (seedNum - Nend);
        end
            
        noise_endRot = noise_ang * freeAxis;
        noise_endRot = [ zeros(1, 3), noise_endRot ];
                        
        [~, J] = funcJacob(goal_config, linkNum);
        dq = pinv(J) * noise_endRot';
        
        if k ==1 
            
        elseif k < Nend +1
            goal_config = goal_config - dq';
        else
            goal_config = goal_config + dq';
        end
            
        if any(goal_config < jointLimit_low) || any(goal_config > jointLimit_high)
           break; 
        end

        for ite=1:20

            [x, J] = compJacob( goal_config, linkNum );          
            goal_now = zeros(dim, 1);
            goal_now(:) = x(linkNum, :);

            goal_error = goal_task - goal_now;
            if dim == 2
                goal_error = [goal_error; zeros(4,1)];
            else
                goal_error = [goal_error; zeros(3,1)];
            end
            goal_config = goal_config + transpose(0.2 * pinv(J) *goal_error);
            if norm(goal_error) < 0.01
                break; 
            end

        end
        
        config_set(k, :) =  goal_config;

        if k == Nend 
            goal_config = goal_config_given;
        end
    end
    
    config_set( ~any(config_set,2), : ) = []; 
    
    for iteration = 1:iteNum
        %evaluate the current trajectory
        [cost_total,collisionCost, smoothnessCost] = stomp_costfunc(traj_q, dim, funcJacob,obstacles, radii, eps, bodySizes, cost_weights);
               
        for k = 1:N
            
            %sample goal configurations
            end_max = size(config_set, 1);
            d_theta_ind = unidrnd(end_max);
            noise_end_traj = zeros(linkNum, T);
            noise_end_traj(:, T) = config_set(d_theta_ind, :) - goal_config_given;
            traj_end_prop = M_end * noise_end_traj';
            
            %generate the noise with fixed end points
            noise = mvnrnd( zero_mean', M, linkNum);
            p = mvnpdf(noise,zero_mean',M); 
            if iteration == 1 && k==1
                p_ini = p(1);
            end
            p_set(k, 1) = prod(p/p_ini);
            
            zero_ini = zeros(1, linkNum);
            traj_noise = [zero_ini; noise'; zero_ini];
            
            if iteration == 1
                traj_q_noise= traj_q + traj_noise + traj_end_prop;
            else
                m = mod(k, modeNum)+1;
                traj_q_noise = traj_hto(:,:,m) + traj_noise;
            end
                                
            [cost_total,~, ~] = stomp_costfunc(traj_q_noise, dim, funcJacob,obstacles, radii, eps, bodySizes, cost_weights);
            noise_set(:,:, k) = noise';
            cost_set(k, 1) = cost_total;
            traj_sample_set(:,:,k) = traj_q_noise;
        end
        
        D =[];
        for k=1:N
           D = [D; reshape( traj_sample_set(:,:,k), [ 1, T*linkNum ]) ]; 
        end
            
        exp_cost_set = exp( - 40 *(cost_set - min(cost_set))/ (max(cost_set)- min(cost_set)));
        exp_cost_set = exp_cost_set / mean(exp_cost_set);
        
        m = 10;
        z_ini = mod( randperm(N), m ) + 1;
        D_laplace = LaplacianEigenMapping(D, 30, 9)';
        
        z = IWVBEMGMM( D_laplace, m, z_ini, exp_cost_set', 1000  );
        
        modeNum = max(z);
        traj_hto = zeros(T, linkNum, modeNum);
        for m=1:modeNum
           traj_mode_m = zeros(T, linkNum);
           ind = (z==m);
           num = sum(ind);
           traj_sample_set_m = traj_sample_set(:,:,ind);
           traj_sample_set_m_2d = reshape( traj_sample_set_m, [T*linkNum, num] );
           exp_cost_set_m  = exp_cost_set(ind, :);
           exp_cost_set_m_2d = repmat(exp_cost_set_m', [T*linkNum, 1]); 
           mean_traj_m = sum( exp_cost_set_m_2d .*  traj_sample_set_m_2d, 2) / sum( exp_cost_set_m );
           traj_m = reshape( mean_traj_m, [T, linkNum] );
           
           %============ shit trajectory to the initial goal=======================
            for l=1:5
                [x, J] = compJacob( traj_m(T, :), linkNum );
                error = zeros(dim, 1);
                error(:, 1) =  reshape(goal_task, [dim, 1]) -  reshape(x(linkNum, :), [dim, 1]);
                shift = zeros(6, 1);
                shift(1:dim, 1) = error(:);
                shift_end_q = pinv(J) * shift;
                shift_end_traj = zeros(linkNum, T);
                shift_end_traj(:, T) = shift_end_q;
                shift_end_prop = M_end * shift_end_traj';
                traj_m = traj_m + 0.5 * shift_end_prop;
            end
           
           
           traj_m  = CHOMPend( traj_m, T, funcJacob,...
                            dim, 3, obstacles, radii, eps, bodySizes, 0.15, 0.005, cost_weights, freeAxis, freeAxis );
            
           traj_hto(:, :, m) =  traj_m;
        end
                 
    end
    
    cost_opt_set = zeros(modeNum, 1);
    for m = 1:modeNum
       [cost_total_m,~, ~] = stomp_costfunc(traj_hto(:,:,m), dim, funcJacob,obstacles, radii, eps, bodySizes, cost_weights); 
       cost_opt_set(m, 1) = cost_total_m;
       
        smoothnessCost = trace( (traj_hto(:,:,m)' * K') * (K * traj_hto(:,:,m)));
        fprintf('cost_total:%f, smoothnessCost;%f\n',cost_total_m, smoothnessCost);
    end
    
    ind = (cost_opt_set < collision_threshold + 100 );
    traj_hto = traj_hto(:,:,ind);
    
    
    
end

