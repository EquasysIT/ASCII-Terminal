create_clock -name clk27 -period 37.037 -waveform {0 18.518} [get_ports {clk27}] -add
create_generated_clock -name clk25 -source [get_ports {clk27}] -master_clock clk27 -divide_by 27 -multiply_by 25 [get_nets {clk25}]

set_operating_conditions -grade c -model slow -speed 6 -setup
