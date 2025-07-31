//--------------------------------------------------------------
//-- Engineer: A Burgess                                      --
//--                                                          --
//-- Design Name: Basic Computer System - Timing Constraints  --
//--                                                          --
//--------------------------------------------------------------

create_clock -name clk27 -period 37.037 -waveform {0 18.518} [get_ports {clk27}] -add
create_generated_clock -name clk25 -source [get_ports {clk27}] -master_clock clk27 -divide_by 27 -multiply_by 25 [get_nets {clk25}]

// Add constraints for the 65C02 which is clock enabled every 16 cycles of the master clock (clk25)
set_multicycle_path -from [get_pins {cpu/*/*}] -to [get_pins {cpu/*/*}] -setup -end 16
set_multicycle_path -from [get_pins {cpu/*/*}] -to [get_pins {cpu/*/*}] -hold -end 15
set_multicycle_path -from [get_pins {cpu/*/*}] -to [get_pins {terminal/*/*}] -setup -end 16
set_multicycle_path -from [get_pins {cpu/*/*}] -to [get_pins {terminal/*/*}] -hold -end 15

set_operating_conditions -grade c -model slow -speed 8 -setup
