--------------------------------------------------------------
-- Engineer: A Burgess                                      --
--                                                          --
-- Design Name: PS2 Keyboard Interface                      --
--                                                          --
-- October 2024                                             --
--------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity keyboard is
port (
	clk			:	in std_logic;
	reset_n		:	in std_logic;
	ps2_clk		:	inout std_logic;
	ps2_data	:	inout std_logic;
    ps2_valid   :	out std_logic;
	ascii_outcode :	out	std_logic_vector(7 downto 0)
	);
end keyboard;

architecture rtl of keyboard is

signal break		:	std_logic := '0';
signal tx_ena		:	std_logic := '0';
signal tx_cmd		:	std_logic_vector(7 downto 0);
signal tx_busy		:	std_logic := '0';
signal keyb_data	:	std_logic_vector(7 downto 0);
signal keyb_error	:	std_logic;
signal keyb_valid	:	std_logic;
signal keyb_valid_pre :	std_logic;
signal led_code     :	std_logic_vector(2 downto 0);
signal kbscroll     :	std_logic;
signal kbnum		:	std_logic;
signal kbcaps		:	std_logic;
signal shift        :	std_logic;
signal shiftval     :	std_logic_vector(7 downto 0);

signal keyb_ascii   :	std_logic_vector(7 downto 0);

type keyb_machine is ( kb_init, kb_ack1, kb_ack2, kb_ack3, kb_ack4, kb_ack5, kb_led, kb_setled, kb_rep, kb_setrep, kb_bat1, kb_bat2,
                       kb_waitkey, kb_getkey, kb_tcode, kb_output);
signal keyb_state :	keyb_machine := kb_init;

begin

ps2 : entity work.ps2_intf
	port map
	(
		clk => clk,
		reset_n => reset_n,
		ps2_clk => ps2_clk,
		ps2_data => ps2_data,
		tx_ena => tx_ena,
		tx_cmd => tx_cmd,
		tx_busy => tx_busy,
		ps2_code => keyb_data,
		ps2_code_new => keyb_valid
	);

process(clk)
begin
    if rising_edge(clk) then
        led_code <= kbcaps & kbnum & kbscroll;
        if reset_n = '0' then
            break <= '0';
            keyb_state <= kb_init;
            tx_ena <= '0';
            kbscroll <= '0';
            kbnum <= '0';
            kbcaps <= '0';
            ps2_valid <= '0';
            led_code <= (others => '0');
        else
		-- Keyboard FSM
            keyb_valid_pre <= keyb_valid;
			case keyb_state is

				when kb_init =>
					if tx_busy = '0' then
						tx_ena <= '1';
						tx_cmd <= x"FF"; -- Initialise keyboard
						keyb_state <= kb_init;
					elsif tx_busy = '1' then
						tx_ena <= '0';
						keyb_state <= kb_ack1;
					end if;
					
				when kb_ack1 =>
					if keyb_valid = '1' then
						if keyb_data = x"FA" then -- Wait for acknowledgement from keyboard
							keyb_state <= kb_bat1;
						else
							keyb_state <= kb_init;
						end if;
					else
							keyb_state <= kb_ack1;
					end if;
				
				when kb_bat1 =>
					if keyb_valid = '1' then
						if keyb_data = x"AA" then -- Wait for BAT from keyboard - Self test passed
							keyb_state <= kb_led;
						else
							keyb_state <= kb_init;
						end if;
					else
							keyb_state <= kb_bat1;
					end if;					

				when kb_led =>
					if tx_busy = '0' then
						tx_ena <= '1';
						tx_cmd <= x"ED"; -- Send "change LED" code to keyboard
						keyb_state <= kb_led;
					elsif tx_busy = '1' then
						tx_ena <= '0';
						keyb_state <= kb_ack2;
					end if;
							
				when kb_ack2 =>
					if keyb_valid = '1' then
						if keyb_data = x"FA" then -- Wait for acknowledgement from keyboard
							keyb_state <= kb_setled;
						else
							keyb_state <= kb_init;
						end if;
					else
							keyb_state <= kb_ack2;
					end if;

				when kb_setled =>
					if tx_busy = '0' then
						tx_ena <= '1';
						tx_cmd <= "00000" & led_code; -- Set LED
						keyb_state <= kb_setled;
					elsif tx_busy = '1' then
						tx_ena <= '0';
						keyb_state <= kb_ack3;
					end if;

				when kb_ack3 =>
					if keyb_valid = '1' then
						if keyb_data = x"FA" then -- Wait for acknowledgement from keyboard
							keyb_state <= kb_rep;
						else
							keyb_state <= kb_init;
						end if;
					else
							keyb_state <= kb_ack3;
					end if;

				when kb_rep =>
					if tx_busy = '0' then
						tx_ena <= '1';
						tx_cmd <= x"F3"; -- Send "set keyboard speed" code to keyboard
						keyb_state <= kb_rep;
					elsif tx_busy = '1' then
						tx_ena <= '0';
						keyb_state <= kb_ack4;
					end if;
							
				when kb_ack4 =>
					if keyb_valid = '1' then
						if keyb_data = x"FA" then -- Wait for acknowledgement from keyboard
							keyb_state <= kb_setrep;
						else
							keyb_state <= kb_init;
						end if;
					else
							keyb_state <= kb_ack4;
					end if;

				when kb_setrep =>
					if tx_busy = '0' then
						tx_ena <= '1';
						tx_cmd <= "00100100"; -- Set key repeat delay and repeat speed - 7 must be zero, 5 & 6 = Auto repeat delay 11 = 1 sec - 0 to 4 Repeat rate 11111 = 2Hz
						keyb_state <= kb_setrep;
					elsif tx_busy = '1' then
						tx_ena <= '0';
						keyb_state <= kb_ack5;
					end if;
								
				when kb_ack5 =>
					if keyb_valid = '1' then
						if keyb_data = x"FA" then -- Wait for acknowledgement from keyboard
							keyb_state <= kb_waitkey;
						else
							keyb_state <= kb_init;
						end if;
					else
							keyb_state <= kb_ack5;
					end if;
							
--				 Initialise keyboard if just plugged in. Wait for BAT code and then start the initalisation process
--					
--				when kb_bat2 =>
--					if keyb_valid = '1' then
--						if keyb_data = x"AA" then -- Wait for BAT from keyboard
--							keyb_state <= kb_init;
--                        end if;
--                    else
--                        keyb_state <= kb_waitkey;
--                    end if;

                -- Now wait for key presses and process accordingly

                when kb_waitkey =>
					if keyb_valid_pre = '0' and keyb_valid = '1' then
                        ps2_valid <= '0';
                        keyb_state <= kb_getkey;
                    else
                        keyb_state <= kb_waitkey;
                    end if;

                when kb_getkey =>
					if keyb_data = x"f0" then
                        break <= '1';
                        keyb_state <= kb_waitkey;
                    else
                        keyb_state <= kb_tcode;
                    end if;

                when kb_tcode =>
                    break <= '0';
                        case keyb_data is
                            when X"74" => keyb_ascii <= x"36"; -- RIGHT (6)
                            when X"69" => keyb_ascii <= x"31"; -- END (1)
                            when X"29" => keyb_ascii <= x"20"; -- SPACE

                            when X"6B" => keyb_ascii <= x"34"; -- LEFT (4)
                            when X"72" => keyb_ascii <= x"32"; -- DOWN (2)
                            when X"5B" => keyb_ascii <= x"5d"; -- ]
                            when X"5A" => keyb_ascii <= x"0d"; -- RETURN
                            when X"66" => keyb_ascii <= x"08"; -- BACKSPACE
                            when X"4E" => keyb_ascii <= x"2d"; -- -                                      
                            when X"75" => keyb_ascii <= x"38"; -- UP (8)
                            when X"54" => keyb_ascii <= x"5b"; -- [       
                            when X"52" => keyb_ascii <= x"27"; -- '  full colon substitute
                            when X"45" => keyb_ascii <= x"30"; -- 0
                            when X"4D" => keyb_ascii <= x"70" - shiftval; -- p
                            when X"4C" => keyb_ascii <= x"3a"; -- ; CHANGED TO : to work with Apple 1 for now
                            when X"4A" => keyb_ascii <= x"2f"; -- /
                            when X"76" => keyb_ascii <= x"1b"; -- Escape

                            when X"46" => keyb_ascii <= x"39"; -- 9
                            when X"44" => keyb_ascii <= x"6f" - shiftval; -- o
                            when X"4B" => keyb_ascii <= x"6c" - shiftval; -- l
                            when X"49" => keyb_ascii <= x"2e" - shiftval; -- .
                                                                      
                            when X"3E" => keyb_ascii <= x"38"; -- 8                               
                            when X"43" => keyb_ascii <= x"69" - shiftval; -- i
                            when X"42" => keyb_ascii <= x"6b" - shiftval; -- k
                            when X"41" => keyb_ascii <= x"2c" - shiftval; -- ,       

                            when X"3D" => keyb_ascii <= x"37"; -- 7               
                            when X"3C" => keyb_ascii <= x"75" - shiftval; -- u
                            when X"3B" => keyb_ascii <= x"6a" - shiftval; -- j                                       
                            when X"3A" => keyb_ascii <= x"6d" - shiftval; -- m
                                                                    
                            when X"36" => keyb_ascii <= x"36"; -- 6
                            when X"35" => keyb_ascii <= x"79" - shiftval; -- y
                            when X"33" => keyb_ascii <= x"68" - shiftval; -- h                                      
                            when X"31" => keyb_ascii <= x"6e" - shiftval; -- n

                            when X"2E" => keyb_ascii <= x"35"; -- 5                                       
                            when X"2C" => keyb_ascii <= x"74" - shiftval; -- t
                            when X"34" => keyb_ascii <= x"67" - shiftval; -- g
                            when X"32" => keyb_ascii <= x"62" - shiftval; -- b

                            when X"25" => keyb_ascii <= x"34"; -- 4
                            when X"2D" => keyb_ascii <= x"72" - shiftval; -- r
                            when X"2B" => keyb_ascii <= x"66" - shiftval; -- f
                            when X"2A" => keyb_ascii <= x"76" - shiftval; -- v

                            when X"26" => keyb_ascii <= x"33"; -- 3
                            when X"24" => keyb_ascii <= x"65" - shiftval; -- e
                            when X"23" => keyb_ascii <= x"64" - shiftval; -- d
                            when X"21" => keyb_ascii <= x"63" - shiftval; -- c

                            when X"1E" => keyb_ascii <= x"32"; -- 2
                            when X"1D" => keyb_ascii <= x"77" - shiftval; -- w
                            when X"1B" => keyb_ascii <= x"73" - shiftval; -- s
                            when X"22" => keyb_ascii <= x"78" - shiftval; -- x

                            when X"16" => keyb_ascii <= x"31"; -- 1
                            when X"15" => keyb_ascii <= x"71" - shiftval; -- q
                            when X"1C" => keyb_ascii <= x"61" - shiftval; -- a
                            when X"1A" => keyb_ascii <= x"7a" - shiftval; -- z
                            when others => keyb_ascii <= "01010101";
                        end case;
                        if keyb_data = x"58" then -- CAPS lock pressed ?
                            kbcaps <= not kbcaps;
                            keyb_state <= kb_led;
                        end if;

                    if break = '0' then
                        keyb_state <= kb_output;
                    else
                        keyb_state <= kb_waitkey;
                    end if;

                when kb_output =>
                        ps2_valid <= '1';
                        ascii_outcode <= keyb_ascii;
                        keyb_state <= kb_waitkey;
 

--                    elsif keyb_data = x"12" then              -- Shift key pressed ?
--                        shift <= break;
--                    elsif keyb_data = x"77" then              -- Num lock pressed ?
--                        kbnum <= not kbnum;
--                        keyb_state <= kb_led;
--                    elsif keyb_data = x"7e" then              -- Scroll lock pressed ?
--                        kbscroll <= not kbscroll;
--                        keyb_state <= kb_led;
--                    end if;                     

                    --if break = '0' then
                    -- ps2_valid <= keyb_valid;
                    --else
                     --   ps2_valid <= '0';
                    --end if;

                    --if (kbcaps = '0' and shift = '0') or (kbcaps = '1' and shift = '1') then

                    --end if;
            end case;
        end if;
    end if;
end process;
end rtl;
