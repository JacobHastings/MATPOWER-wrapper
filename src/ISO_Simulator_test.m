clc
clear all
clear classes

Dsp_M_Prc = true;
Dsp_MW = true;
Dsp_pct = true;
runs = 4; %2 minimum

%%%%%%%%%%%%%%%%%%%%%%%%% Start loop %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for run = 1:runs
    
    %% Check if MATLAB or OCTAVE
    isOctave = exist('OCTAVE_VERSION', 'builtin') ~= 0;
    %% Load Model
    wrapper_startup;
    Wrapper = MATPOWERWrapper('wrapper_config.json', isOctave);
    
    %% Read profile and save it within a strcuture called load
    Wrapper = Wrapper.read_profiles('load_profile_info', 'load_profile');
    Wrapper = Wrapper.read_profiles('wind_profile_info', 'wind_profile');
    Wrapper = Wrapper.prepare_helics_config('helics_config.json');   
        
    tnext_physics_powerflow = Wrapper.config_data.physics_powerflow.interval;
    tnext_real_time_market = Wrapper.config_data.real_time_market.interval;
    tnext_day_ahead_market = Wrapper.config_data.day_ahead_market.interval;
    time_granted = 0;
    next_helics_time =  min([tnext_physics_powerflow, tnext_real_time_market, tnext_day_ahead_market]);
        
    mpoptOPF = mpoption('verbose', 0, 'out.all', 0, 'model', 'DC');
    mpoptPF = mpoption('verbose', 0, 'out.all', 0, 'pf.nr.max_it', 20, 'pf.enforce_q_lims', 0, 'model', 'DC');
        
        %% Increasing the branch 
        
    % while time_granted <= Wrapper.config_data.Duration
    price_range = [18, 22];
    flexiblity = 0.3 * ((run-1)/(runs-1));

    %Dispatch_use = zeros((tnext_day_ahead_market/300),1+(runs*size(Wrapper.config_data.cosimulation_bus,1)));
    
    while time_granted <= Wrapper.duration
        next_helics_time =  min([tnext_physics_powerflow, tnext_real_time_market, tnext_day_ahead_market]);
        time_granted = next_helics_time;
    %     mpc.bus(:,12) = 1.3* ones(length(mpc.bus(:,12)),1);
    %     mpc.bus(:,13) = 0.7* ones(length(mpc.bus(:,13)),1);
    %     mpc.gen(:,4) = mpc.gen(:,7);
    %     mpc.gen(:,5) = -1*mpc.gen(:,7);
        
        
        if time_granted >= tnext_real_time_market  
                time_granted
                Wrapper = Wrapper.update_loads_from_profiles(time_granted, 'load_profile_info', 'load_profile');
                Wrapper = Wrapper.update_VRE_from_profiles(time_granted, 'wind_profile_info', 'wind_profile');
              %Wrapper = Wrapper.update_dispatchable_loads(bids)*************
              %Uses Wrapper, P_Q
                if flexiblity ~= 0
                    [P_Q]  = Wrapper.get_bids_from_cosimulation(time_granted, flexiblity, price_range);
                    for i = 1 : length(Wrapper.config_data.cosimulation_bus)
                        Bus_number = Wrapper.config_data.cosimulation_bus(i,1);
                        Generator_index = size(Wrapper.mpc.gen,1) + 1;
                        Wrapper.mpc.genfuel(Generator_index,:) = Wrapper.mpc.genfuel(1,:);  %copy random genfuel entry
                        Wrapper.mpc.gen(Generator_index,:) = 0;                             %new entry of 0's
                        Wrapper.mpc.gen(Generator_index,1) = Bus_number;                    %set bus #
                        Wrapper.mpc.gen(Generator_index,8) = 1;                             %gen status on
                        Wrapper.mpc.gen(Generator_index,9) = P_Q(Bus_number).range(2);      %Set max reduction
                        Wrapper.mpc.gencost(Generator_index,:) = 0;                         %new entry of 0's
                        Wrapper.mpc.gencost(Generator_index,1) = P_Q(Bus_number).model;     %Polynomial model
                        if P_Q(Bus_number).model == 2                                   %Polynomial
                            Wrapper.mpc.gencost(Generator_index,4) = 3;                     %Degree 3 polynomial
                            Wrapper.mpc.gencost(Generator_index,5:4+Wrapper.mpc.gencost(Generator_index,4)) = P_Q(Bus_number).bid;     %Polynomial coefficients
                        elseif P_Q(Bus_number).model == 1                               %Piecewise linear
                            Wrapper.mpc.gencost(Generator_index,4) = 3;                     %3 piecewise linear steps
                            Wrapper.mpc.gencost(Generator_index,5:4+(2*(Wrapper.mpc.gencost(Generator_index,4)))) = P_Q(Bus_number).bid;
                        end
                    end
                end
                %*************************************************************
                Wrapper = Wrapper.run_RT_market(time_granted, mpoptOPF);
                %Update Bid loads*********************************************
                %Uses Wrapper
                Dispatch_use((time_granted/300),1) = time_granted;
                Dispatch_use_P((time_granted/300),1) = time_granted;
                if flexiblity ~= 0
                    for i = 1 : length(Wrapper.config_data.cosimulation_bus)
                        Bus_number = Wrapper.config_data.cosimulation_bus(length(Wrapper.config_data.cosimulation_bus)-i+1,1);
                        Generator_index = size(Wrapper.mpc.gen,1);
                        Wrapper.mpc.bus(Bus_number,3) = Wrapper.mpc.bus(Bus_number,3) - Wrapper.mpc.gen(Generator_index,2);
                        Dispatch_use((time_granted/300),i+1+(length(Wrapper.config_data.cosimulation_bus)*(run-1))) = Wrapper.mpc.gen(Generator_index,2);
                        Dispatch_use_P((time_granted/300),i+1+(length(Wrapper.config_data.cosimulation_bus)*(run-1))) = 100 *( Wrapper.mpc.gen(Generator_index,2) /(Wrapper.mpc.gen(Generator_index,2) + Wrapper.mpc.bus(Wrapper.mpc.gen(Generator_index,1),3)));
                        Wrapper.mpc.genfuel(Generator_index,:) = [];
                        Wrapper.mpc.gen(Generator_index,:) = [];
                        Wrapper.mpc.gencost(Generator_index,:) = [];
                    end
                end
                %*************************************************************
                tnext_real_time_market = tnext_real_time_market + Wrapper.config_data.real_time_market.interval;
        end
        
        if time_granted >= tnext_physics_powerflow        
                Wrapper = Wrapper.update_loads_from_profiles(time_granted, 'load_profile_info', 'load_profile');
                Wrapper = Wrapper.update_VRE_from_profiles(time_granted, 'wind_profile_info', 'wind_profile');
                % Collect measurements from distribution networks
                Wrapper = Wrapper.run_power_flow(time_granted, mpoptPF);    
                tnext_physics_powerflow = tnext_physics_powerflow + Wrapper.config_data.physics_powerflow.interval;
        end
        
        if time_granted == Wrapper.duration     %end infinite loop
            time_granted = Wrapper.duration+1;
        end
    
    end
    if run == 1
        Compare_prices = Wrapper.results.RTM.LMP;
        Compare_generation = Wrapper.results.RTM.PD;
    else
        Compare_prices = [Compare_prices Wrapper.results.RTM.LMP(:,2:9)];
        Compare_generation = [Compare_generation Wrapper.results.RTM.PD(:,2:9)];
    end
end
% for a=1:8
% subplot(2,4,a);
% plot (Compare_prices(:,1) , Compare_prices(:,1+a))
% hold on
% plot (Compare_prices(:,1) , Compare_prices(:,9+a))
% hold off
% end
Labels = "";
for a=1:runs
    Labels(a) = append(num2str(flexiblity*100*(a-1)/(runs-1)), "%");
end
if Dsp_M_Prc
    for a=1:runs
        plot (Compare_prices(:,1) , Compare_prices(:,(3+(8*(a-1)))))
        if a==1
            hold on
        end
    end
    title(['Marginal price 0% -> ' num2str(flexiblity*100) '% flexible load'])
    legend(Labels);
    ylabel('Price ($/MW)')
    xlabel('Time (s)')
    hold off
end
if Dsp_MW %Dispatch use in MW
    for b=1:((size(Dispatch_use,2)-1)/runs)
        figure();
        for a=1:runs
            plot (Dispatch_use(:,1) , Dispatch_use(:,(1+b+(((size(Dispatch_use,2)-1)/runs)*(a-1)))))
            if a==1
                hold on
            end
        end
        title(['Bus ' num2str(Wrapper.config_data.cosimulation_bus(b)) ' Load Reduction 0% -> ' num2str(flexiblity*100) '% flexible load'])
        legend(Labels);
        ylabel('Load Reduction (MW)')
        xlabel('Time (s)')
        hold off
    end
end
if Dsp_pct  %Dispatch use as a % of total bus
    for b=1:((size(Dispatch_use_P,2)-1)/runs)
        figure();
        for a=1:runs
            plot (Dispatch_use_P(:,1) , Dispatch_use_P(:,(1+b+(((size(Dispatch_use_P,2)-1)/runs)*(a-1)))))
            if a==1
                hold on
            end
        end
        title(['Bus ' num2str(Wrapper.config_data.cosimulation_bus(b)) ' %Load Reduction 0% -> ' num2str(flexiblity*100) '% flexible load'])
        legend(Labels);
        ylabel('Load Reduction (% of load)')
        xlabel('Time (s)')
        hold off
    end
end
% plot (Compare_prices(:,1) , Compare_prices(:,(2+(8*(runs-1)))) - Compare_prices(:,2))
% hold on
% title(['Marginal price without - with ' num2str(flexiblity*100) '% flexible load'])
% ylabel('Price reduction ($/MW)')
% xlabel('Time (s)')
% hold off