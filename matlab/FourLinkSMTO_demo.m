clear variables;
close all;

addpath('MotionOpt');
addpath('FourLink');

T = 40; %number of step
D = 2;   %dimension of the state

linkNum = 4;
L = [1.0, 1.0, 1.0, 1.0]; % length of the link
basePos = [ 0, 0 ]; % position of the base
q_ini = [ - 0.05*pi, 0.55*pi, 0.45*pi, -0.45*pi];
x_ini = ForwardKinematicsFourLink(q_ini,basePos, L );

q_end = [-pi*0.   pi*0.1   pi*0.3  pi*0.1];
x_end = ForwardKinematicsFourLink(q_end,basePos, L );

traj_c = zeros(T, linkNum);
for i = 1:40
    traj_c(i,:) = q_ini + (q_end - q_ini) * (1 - cos( (i-1) / (T-1) *pi ) )/2; 
end

% Shift the trajectory so that the mean trajectory starts from q_ini
% shift = x_ini - traj_task(1, :);
% Ti = size(traj_task, 1);
% traj_task = traj_task + repmat(shift, Ti, 1);
    
%traj_c = InverseKinematicsFourLink(traj_task, q_ini);

%======== Obstacle settings =======
obsNum = 2;
obstacles = [ 0.8, 2.5; 1.6, 2.1 ];
radii = [  0.5; 0.1  ];
% obsNum = 1;
% obstacles = [ 1, 2 ];
% radii = [  0.1 ];
eps = 0.15;
bodySizes = [0.01, 0.01, 0.1,  0.15];

traj_q = traj_c;

task_ini = zeros(T, D);
task_chomp = zeros(T, D);



stomp_cost_weights = [1.0, 0.1];
iteNum = 2;
seedNum = 400;
freeAxis = [0,0,1];
angle_pos =  pi/4;
angle_neg = pi/6;
angle_pos_st =  pi/8;
angle_neg_st = pi/10;
jointLimit_low = [-pi, -pi, -pi, -pi];
jointLimit_high = [ pi, pi, pi, pi];
%----- main function of CHOMP -----
tic

% traj_CHOMPend  = CHOMPend( traj_q, T, @ComputeJacobianFourLinkRot,...
%                             D, 10, obstacles, radii, eps, bodySizes, 0.15, 0.005, chomp_cost_weights, freeAxis, freeAxis );

[traj_SMTO, costSet]  = SMTO( traj_q, T, @ComputeJacobianFourLinkRot,...
                            D, iteNum, obstacles, radii, eps, bodySizes, 0.15, stomp_cost_weights);
                        
                     
                        
toc

modeNum = size(traj_SMTO, 3);

f1 = figure;
for i =1:obsNum
    drawCircle(obstacles(i, 1), obstacles(i, 2),radii(i) );
end
for t =[1, T]
    grayScale = (1 - t/T);
    DrawFourLink( basePos, L, traj_c(t, :), f1, grayScale ); 
end

axis([-1 3 -1 3])
set(gca,'xtick',[]);
set(gca,'ytick',[]);
axis equal;
%     for t =[1,T]
%         grayScale = (1 - t/T*0.5);
%         DrawFourLinkColor( basePos, L, traj_q(t, :), f4, grayScale, [0, 1, 0] );
%     end

for m=1:modeNum
    
    f4 = figure;
    for i =1:obsNum
    drawCircle(obstacles(i, 1), obstacles(i, 2),radii(i) );
    end
    for t =1:T
         grayScale = (1 - t/T);
        [ xc, J  ] = DrawFourLink( basePos, L, traj_SMTO(t, :, m), f4, grayScale ); 
        task_ini(t, :) =  xc(3, :);
    end
    for t =[1,T]
        grayScale = (1 - t/T*0.5);
        DrawFourLinkColor( basePos, L, traj_q(t, :), f4, grayScale, [0, 1, 0] );
    end
    
    axis([-1 3 -1 3])
    set(gca,'xtick',[]);
    set(gca,'ytick',[]);
    axis equal;
end


rmpath('MotionOpt');
rmpath('FourLink');