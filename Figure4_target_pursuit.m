clearvars;
clc;

addpath('./helperFuns/');

%% Construct the approximate map
Figure4_polytope_defs

%% Construct the target, forward reach sets, and distribution
Figure4_target_defs

%% Test: Compute probability
% query_point = [19.5;10.5];
% my_eps = 2e0;
% time_step = 25;
% unit_box = my_eps * Polyhedron('lb',-[1;1],'ub',[1;1]);
% query_box = query_point + unit_box;
% plot(query_box, 'color','b', 'alpha',0.3);
% prob = Figure4_occupy_fun_Levi(query_box, time_step, target_sys, [1,3], ...
%         target_init_state, optimal_input_vec(1:2*time_step), dist_delta, ...
%         dist_peak);
% % Monte-Carlo-simulation based validation    
% relv_sims = concat_state_realization(4*time_step + relv_states,:);    
% prob_mcarlo = sum(query_box.contains(relv_sims))/n_monte_carlo;
% fprintf('Probability : %1.4f | MonteCarlo probability : %1.4f\n', ...
%     prob, prob_mcarlo);    

%% Construct the pursuer forward reach sets
Figure4_pursuer_defs

%% Target system support computation
% Generate Monte Carlo simulation                    
target_concat_state_realization = generateMonteCarloSims(n_monte_carlo, ...
    target_sys, target_init_state, time_horizon, target_affine_vec);
Figure4_target_support
for t_indx_plus1 = 2:plot_t_skip:time_horizon+1
    % Time goes from 0 to time_horizon for both
    %   target_support_position and target_concat_state_realization
    fprintf('Plotting time: %d\n', t_indx_plus1-1);
    plot(target_support_position(t_indx_plus1), 'alpha', 0.2, 'color', 'y');
    relv_indx = 4*(t_indx_plus1-1) + relv_states;
    scatter(target_concat_state_realization(relv_indx(1),1:skip_mc:end), ...
            target_concat_state_realization(relv_indx(2),1:skip_mc:end), ...
            'ro', 'filled');
    drawnow
end
% Plot mean trajectory
mean_trajectory = mean(target_concat_state_realization,2);
plot(mean_trajectory(relv_states(1):4:end), mean_trajectory(relv_states(2):4:end), 'r--', 'linewidth', 2);
                            
%% Find non-empty feasible intersect locations
feasible_intercept_locations = [ones(2,0) * Polyhedron()];
count_infeas = 0;
count_feas = 0;
feas_list = [];       % pursuer_indx, t_indx_plus1, pursuer_cvx_indx
for t_indx_plus1 = 2:time_horizon+1
    % Time goes from 0 to time_horizon for both
    %   pursuer_position_set_zero_input and 
    %   pursuer_position_sets_zero_state_unit_input
    target_support_poly = target_support_position(t_indx_plus1);
    for pursuer_indx = 1:3
        for pursuer_cvx_indx = 1:3
            temp_poly = pursuer_interceptable_position_set(pursuer_indx, ...
                t_indx_plus1, pursuer_cvx_indx);
            temp_poly = temp_poly.intersect(target_support_poly);
            if temp_poly.isEmptySet()
                count_infeas = count_infeas + 1;
            else
                count_feas = count_feas + 1;
                plot(temp_poly, 'color','k','alpha',0.8);
                feas_list = [feas_list;pursuer_indx, t_indx_plus1, pursuer_cvx_indx];
            end                
        end
    end
end
fprintf('Need to solve the catch problem with %d polytopes (%1.3f %%)\n', ...
    count_feas, count_feas/(3*3*time_horizon)*100);

%% Define catch probability
catch_box_half_length = 2e0;
zero_catch_prob = 1e-4;
catch_box = catch_box_half_length * Polyhedron('lb',-[1;1],'ub',[1;1]);

%% Use fmincon for constrained optimization for permitted intercept zones
Figure4_optimize_via_fmincon

%% Final touches to the plot
figure(1);
axis equal;
xlim([-2,37]);
ylim([-2,15]);

function [neg_log_prob, grad_after_log] = obj_with_grad(x, catch_box, t_indx,...
            target_sys, relv_states, target_init_state, ...
            target_affine_vec_slice, dist_delta, dist_peak)
    [prob, grad] = Figure4_occupy_fun_Levi(x + catch_box, t_indx, target_sys,...
                    relv_states, target_init_state, target_affine_vec_slice, ...
                    dist_delta, dist_peak, true);
    neg_log_prob = -log(prob);
    if prob >= 1e-6
        grad_after_log = -grad/prob;
    end
end