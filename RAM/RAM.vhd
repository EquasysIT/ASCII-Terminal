--------------------------------------------------------------
-- Engineer: A Burgess                                      --
--                                                          --
-- Design Name: Computer System RAM                         --
--                                                          --
-- October 2024                                             --
--------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity ram is
    port (
        clk     : in  std_logic;
        we      : in  std_logic;
        addr    : in  std_logic_vector(13 downto 0);
        datain  : in std_logic_vector(7 downto 0);
        dataout : out std_logic_vector(7 downto 0)
        );
end;

architecture rtl of ram is
    
    type ramdata is array (0 to 16383) of std_logic_vector (7 downto 0);
    shared variable ram : ramdata;

begin
    process (clk)
    begin
        if rising_edge(clk) then
            if (we = '1') then
                ram(conv_integer(addr)) := datain;
            end if;
            dataout <= ram(conv_integer(addr));
        end if;
    end process;
end rtl;