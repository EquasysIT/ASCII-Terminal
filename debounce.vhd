--------------------------------------------------------------
-- Engineer: A Burgess                                      --
--                                                          --
-- Design Name: Basic Computer System - Debounce button     --
--                                                          --
--------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity debounce is
    port (
        clk     : in  std_logic;
        btn_in  : in  std_logic;
        btn_out : out std_logic := '1'
        );
end;

architecture rtl of debounce is
-- Set to 250000 for 25Mhz input clock (10ms). Adjust as required if changing clock frequency
constant db_wait   : integer := 250000;

signal btn_state   :  std_logic;
signal btn_counter :  integer range 0 to db_wait := 0;    -- Set to a 10th of the clk frequency for 10ms. Adjust if changing clk frequency

begin
    process (clk)
    begin
        if rising_edge(clk) then
            btn_state <= btn_in;
            if btn_state = btn_in then              -- Increment counter while button state is not changing
                if btn_counter < 250000 then       
                    btn_counter <= btn_counter + 1;
                end if;
            else                                    -- Else reset counter if button state has changed within the 10ms time
                btn_counter <= 0;
            end if;

            if btn_counter = 250000 then            -- Button has not changed for 10ms so output button state
                btn_out <= btn_in;
                btn_counter <= 0;
            end if;
        end if;
    end process;
end rtl;