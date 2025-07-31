--------------------------------------------------------------
-- Engineer: A Burgess                                      --
--                                                          --
-- Design Name: Basic Computer System - UART Transmitter    --
--                                                          --
--------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity uart_tx is
  port (
    clk         : in  std_logic;
    tx_valid_i  : in  std_logic;
    tx_byte_i   : in  std_logic_vector(7 downto 0);
    tx_bit_o    : out std_logic;
    tx_valid_o  : out std_logic;
    tx_busy_o   : out std_logic
    );
end uart_tx;

architecture rtl of uart_tx is

-------------
-- Signals --
-------------

  signal tx_valid_in : std_logic;
  signal tx_byte     : std_logic_vector(7 downto 0);
  signal tx_bit      : std_logic;
  signal tx_valid_out: std_logic;
  signal tx_busy     : std_logic;
  signal clk_pos     : std_logic_vector(7 downto 0);
  signal bit_count   : integer range 0 to 7 := 0;
   
  type uart_machine is (idle, start, data, stop);
  signal uart_state : uart_machine := idle;
   
begin

process(clk)
begin
    if rising_edge(clk) then
            tx_valid_in <= tx_valid_i;
            case uart_state is
                when idle =>
                    tx_busy <= '1';
                    tx_bit <= '1'; -- Idle state
                    tx_valid_out <= '0';
                    clk_pos <= x"00";
                    bit_count <= 0;
                    if tx_valid_in = '1' then
                        tx_byte <= tx_byte_i;
                        uart_state <= start;
                    else
                        uart_state <= idle;
                    end if;

                when start =>
                    tx_bit <= '0'; -- Send out start bit
                    if clk_pos < 216 then
                        clk_pos <= clk_pos + 1;
                        uart_state <= start;
                    else
                        clk_pos <= x"00";
                        uart_state <= data;
                    end if;

                when data =>
                    tx_bit <= tx_byte(bit_count); -- Send out data bits
                    if clk_pos < 216 then
                        clk_pos <= clk_pos + 1;
                        uart_state <= data;
                    else
                        clk_pos <= x"00";
                        if bit_count < 7 then
                            bit_count <= bit_count + 1;
                            uart_state <= data;
                        else
                            bit_count <= 0;
                            uart_state <= stop;
                        end if;
                    end if;

                when stop =>
                    tx_bit <= '1'; -- Send out stop bit
                    if clk_pos < 216 then
                        clk_pos <= clk_pos + 1;
                        uart_state <= stop;
                    else
                        tx_valid_out <= '1';
                        tx_busy <= '0';
                        clk_pos <= x"00";
                        uart_state <= idle;
                    end if;

                when others =>
                    uart_state <= idle;
            end case;
    end if;
end process;

tx_bit_o <= tx_bit;
tx_valid_o <= tx_valid_out;
tx_busy_o <= tx_busy;
   
end rtl;