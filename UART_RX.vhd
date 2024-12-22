--------------------------------------------------------------
-- Engineer: A Burgess                                      --
--                                                          --
-- Design Name: UART Receiver                               --
--                                                          --
-- October 2024                                             --
--------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity uart_rx is
  port (
    clk         : in  std_logic;
    rx_bit      : in  std_logic;
    rx_valid    : out std_logic;
    rx_byte     : out std_logic_vector(7 downto 0)
    );
end uart_rx;

architecture rtl of uart_rx is

-------------
-- Signals --
-------------

  signal rx_bit_r    : std_logic;
  signal rx_valid_r  : std_logic;
  signal rx_byte_r   : std_logic_vector(7 downto 0);
  signal clk_pos     : std_logic_vector(7 downto 0);
  signal bit_count   : std_logic_vector(2 downto 0);
   

  type uart_machine is (idle, start, data, stop);
  signal uart_state : uart_machine := idle;
   
begin

process(clk)
begin
    if rising_edge(clk) then
            rx_bit_r <= rx_bit; -- Register incoming bit
            case uart_state is
                -- Idle
                when idle =>
                    rx_valid_r <= '0';
                    clk_pos <= x"00";
                    bit_count <= "000";
                    rx_byte_r <= x"00";
                    if rx_bit_r = '0' then     -- Start bit received
                        uart_state <= start;
                    else
                        uart_state <= idle;
                    end if;

                when start =>
                    if clk_pos = 121 then       -- We are in the middle of the start bit
                        if rx_bit_r = '0' then  -- Is it still 0 ?
                            clk_pos <= x"00";
                            uart_state <= data;
                        else
                            uart_state <= idle;
                        end if;
                    else
                        clk_pos <= clk_pos + 1;
                        uart_state <= start;
                    end if;

                when data =>
                    if clk_pos < 242 then
                        clk_pos <= clk_pos + 1;
                        uart_state <= data;
                    else
                        clk_pos <= x"00";       -- We are in the middle of the data bit
                        rx_byte_r <= rx_bit_r & rx_byte_r(7 downto 1);
                        -- All bits received ?
                        if bit_count < 7 then
                            bit_count <= bit_count + 1;
                            uart_state <= data;
                        else
                            bit_count <= "000";
                            uart_state <= stop;
                        end if;
                    end if;

                when stop =>
                    if clk_pos < 242 then
                        clk_pos <= clk_pos + 1;
                        uart_state <= stop;
                    else
                        rx_valid_r <= '1';
                        rx_byte <= rx_byte_r;
                        clk_pos <= x"00";
                        uart_state <= idle;
                    end if;

                when others =>
                    uart_state <= idle;
            end case;
    end if;
end process;

rx_valid <= rx_valid_r;
   
end rtl;