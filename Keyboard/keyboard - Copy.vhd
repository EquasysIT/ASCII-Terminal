-- Added support for usb/ps2 keyboards which issue "AA" BAT code to detect a PS2 connection - A Burgess
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity keyboard is
port (
	clk			:	in std_logic;
	nreset		:	in std_logic;

	-- ps/2 interface
	ps2_clk		:	inout std_logic;
	ps2_data	:	inout std_logic;
	
    kvalid      :	out std_logic;
    -- ASCII Character read from keyboard    
	keyb_ascii	:	out	std_logic_vector(7 downto 0)
	);
end keyboard;

architecture rtl of keyboard is

signal releas		:	std_logic := '0';
signal tx_ena		:	std_logic := '0';
signal tx_cmd		:	std_logic_vector(7 downto 0);
signal tx_busy		:	std_logic := '0';
signal keyb_data	:	std_logic_vector(7 downto 0);
signal keyb_error	:	std_logic;
signal keyb_valid	:	std_logic;
signal led_code     :	std_logic_vector(2 downto 0);
signal kbscroll     :	std_logic;
signal kbnum		:	std_logic;
signal kbcaps		:	std_logic;

type keyb_machine is ( kb_init, kb_ack1, kb_ack2, kb_ack3, kb_ack4, kb_ack5, kb_led, kb_setled, kb_rep, kb_setrep, kb_bat1, kb_bat2 );
signal keyb_rcv_state :	keyb_machine := kb_init;

begin

ps2 : entity work.ps2_intf
	port map
	(
		clk => clk,
		nreset => nreset,
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

        if nreset = '0' then
            releas <= '0';
            keyb_rcv_state <= kb_init;
            tx_ena <= '0';
            kbscroll <= '0';
            kbnum <= '0';
            kbcaps <= '0';
            led_code <= (others => '0');
        else
		-- Keyboard FSM
			case keyb_rcv_state is

				when kb_init =>
					if tx_busy = '0' then
						tx_ena <= '1';
						tx_cmd <= x"FF"; -- Initialise keyboard
						keyb_rcv_state <= kb_init;
					elsif tx_busy = '1' then
						tx_ena <= '0';
						keyb_rcv_state <= kb_ack1;
					end if;
					
				when kb_ack1 =>
					if keyb_valid = '1' then
						if keyb_data = x"FA" then -- Wait for acknowledgement from keyboard
							keyb_rcv_state <= kb_bat1;
						else
							keyb_rcv_state <= kb_init;
						end if;
					else
							keyb_rcv_state <= kb_ack1;
					end if;
				
				when kb_bat1 =>
					if keyb_valid = '1' then
						if keyb_data = x"AA" then -- Wait for BAT from keyboard - Self test passed
							keyb_rcv_state <= kb_led;
						else
							keyb_rcv_state <= kb_init;
						end if;
					else
							keyb_rcv_state <= kb_bat1;
					end if;					

				when kb_led =>
					if tx_busy = '0' then
						tx_ena <= '1';
						tx_cmd <= x"ED"; -- Send "change LED" code to keyboard
						keyb_rcv_state <= kb_led;
					elsif tx_busy = '1' then
						tx_ena <= '0';
						keyb_rcv_state <= kb_ack2;
					end if;
							
				when kb_ack2 =>
					if keyb_valid = '1' then
						if keyb_data = x"FA" then -- Wait for acknowledgement from keyboard
							keyb_rcv_state <= kb_setled;
						else
							keyb_rcv_state <= kb_init;
						end if;
					else
							keyb_rcv_state <= kb_ack2;
					end if;

				when kb_setled =>
					if tx_busy = '0' then
						tx_ena <= '1';
						tx_cmd <= "00000" & led_code; -- Set LED
						keyb_rcv_state <= kb_setled;
					elsif tx_busy = '1' then
						tx_ena <= '0';
						keyb_rcv_state <= kb_ack3;
					end if;

				when kb_ack3 =>
					if keyb_valid = '1' then
						if keyb_data = x"FA" then -- Wait for acknowledgement from keyboard
							keyb_rcv_state <= kb_rep;
						else
							keyb_rcv_state <= kb_init;
						end if;
					else
							keyb_rcv_state <= kb_ack3;
					end if;

				when kb_rep =>
					if tx_busy = '0' then
						tx_ena <= '1';
						tx_cmd <= x"F3"; -- Send "set keyboard speed" code to keyboard
						keyb_rcv_state <= kb_rep;
					elsif tx_busy = '1' then
						tx_ena <= '0';
						keyb_rcv_state <= kb_ack4;
					end if;
							
				when kb_ack4 =>
					if keyb_valid = '1' then
						if keyb_data = x"FA" then -- Wait for acknowledgement from keyboard
							keyb_rcv_state <= kb_setrep;
						else
							keyb_rcv_state <= kb_init;
						end if;
					else
							keyb_rcv_state <= kb_ack4;
					end if;

				when kb_setrep =>
					if tx_busy = '0' then
						tx_ena <= '1';
						tx_cmd <= "00100111"; -- Set key repeat delay and repeat speed - 7 must be zero, 5&6 = Auto repeat delay 11=1 sec - 0to4 Repeat rate 11111=2Hz
						keyb_rcv_state <= kb_setrep;
					elsif tx_busy = '1' then
						tx_ena <= '0';
						keyb_rcv_state <= kb_ack5;
					end if;
								
				when kb_ack5 =>
					if keyb_valid = '1' then
						if keyb_data = x"FA" then -- Wait for acknowledgement from keyboard
							keyb_rcv_state <= kb_bat2;
						else
							keyb_rcv_state <= kb_init;
						end if;
					else
							keyb_rcv_state <= kb_ack5;
					end if;
					
				-- We have reached the end of the initialisation state and setting the LEDs
				
				-- This next state is for when the keyboard is plugged in after the FPGA board has been powered on or sitting waiting a connect/disconnect
					
				when kb_bat2 =>
					if keyb_valid = '1' then
						if keyb_data = x"AA" then -- Wait for BAT from keyboard
							keyb_rcv_state <= kb_init;
						end if;
					else
							keyb_rcv_state <= kb_bat2;
                    end if;
            end case;
            if keyb_valid = '1' then
                if keyb_data = x"f0" then
                    releas <= '1';
                    --keyb_ascii <= x"ff"; -- Needed when screen is read by hardware rather than CPU
                    kvalid <= '0';
                else
                    releas <= '0';
                    if releas = '0' then
                        case keyb_data is
                            when X"74" => keyb_ascii <= x"36";kvalid <= '1'; -- RIGHT (6)
                            when X"69" => keyb_ascii <= x"31";kvalid <= '1'; -- END (1)
                            when X"29" => keyb_ascii <= x"20";kvalid <= '1'; -- SPACE

                            when X"6B" => keyb_ascii <= x"34";kvalid <= '1'; -- LEFT (4)
                            when X"72" => keyb_ascii <= x"32";kvalid <= '1'; -- DOWN (2)
                            when X"5B" => keyb_ascii <= x"5d";kvalid <= '1'; -- ]
                            when X"5A" => keyb_ascii <= x"0d";kvalid <= '1'; -- RETURN
                            when X"66" => keyb_ascii <= x"08";kvalid <= '1'; -- BACKSPACE
                            when X"4E" => keyb_ascii <= x"2d";kvalid <= '1'; -- -                                      
                            when X"75" => keyb_ascii <= x"38";kvalid <= '1'; -- UP (8)
                            when X"54" => keyb_ascii <= x"5b";kvalid <= '1'; -- [       
                            when X"52" => keyb_ascii <= x"27";kvalid <= '1'; -- '  full colon substitute
                            when X"45" => keyb_ascii <= x"30";kvalid <= '1'; -- 0
                            when X"4D" => keyb_ascii <= x"50";kvalid <= '1'; -- P
                            when X"4C" => keyb_ascii <= x"3a";kvalid <= '1'; -- : CHANGED TO : to work with Apple 1 for now
                            when X"4A" => keyb_ascii <= x"2f";kvalid <= '1'; -- /
                            when X"76" => keyb_ascii <= x"1b";kvalid <= '1'; -- Escape

                            when X"46" => keyb_ascii <= x"39";kvalid <= '1'; -- 9
                            when X"44" => keyb_ascii <= x"4f";kvalid <= '1'; -- O
                            when X"4B" => keyb_ascii <= x"4c";kvalid <= '1'; -- L
                            when X"49" => keyb_ascii <= x"2e";kvalid <= '1'; -- .
                                                                      
                            when X"3E" => keyb_ascii <= x"38";kvalid <= '1'; -- 8                               
                            when X"43" => keyb_ascii <= x"49";kvalid <= '1'; -- I
                            when X"42" => keyb_ascii <= x"4b";kvalid <= '1'; -- K
                            when X"41" => keyb_ascii <= x"2c";kvalid <= '1'; -- ,       

                            when X"3D" => keyb_ascii <= x"37";kvalid <= '1'; -- 7               
                            when X"3C" => keyb_ascii <= x"55";kvalid <= '1'; -- U
                            when X"3B" => keyb_ascii <= x"4a";kvalid <= '1'; -- J                                       
                            when X"3A" => keyb_ascii <= x"4d";kvalid <= '1'; -- M
                                                                    
                            when X"36" => keyb_ascii <= x"36";kvalid <= '1'; -- 6
                            when X"35" => keyb_ascii <= x"59";kvalid <= '1'; -- Y
                            when X"33" => keyb_ascii <= x"48";kvalid <= '1'; -- H                                      
                            when X"31" => keyb_ascii <= x"4e";kvalid <= '1'; -- N

                            when X"2E" => keyb_ascii <= x"35";kvalid <= '1'; -- 5                                       
                            when X"2C" => keyb_ascii <= x"54";kvalid <= '1'; -- T
                            when X"34" => keyb_ascii <= x"47";kvalid <= '1'; -- G
                            when X"32" => keyb_ascii <= x"42";kvalid <= '1'; -- B

                            when X"25" => keyb_ascii <= x"34";kvalid <= '1'; -- 4
                            when X"2D" => keyb_ascii <= x"52";kvalid <= '1'; -- R
                            when X"2B" => keyb_ascii <= x"46";kvalid <= '1'; -- F
                            when X"2A" => keyb_ascii <= x"56";kvalid <= '1'; -- V

                            when X"26" => keyb_ascii <= x"33";kvalid <= '1'; -- 3
                            when X"24" => keyb_ascii <= x"45";kvalid <= '1'; -- E       
                            when X"23" => keyb_ascii <= x"44";kvalid <= '1'; -- D
                            when X"21" => keyb_ascii <= x"43";kvalid <= '1'; -- C

                            when X"1E" => keyb_ascii <= x"32";kvalid <= '1'; -- 2
                            when X"1D" => keyb_ascii <= x"57";kvalid <= '1'; -- W
                            when X"1B" => keyb_ascii <= x"53";kvalid <= '1'; -- S
                            when X"22" => keyb_ascii <= x"58";kvalid <= '1'; -- X

                            when X"16" => keyb_ascii <= x"31";kvalid <= '1'; -- 1
                            when X"15" => keyb_ascii <= x"51";kvalid <= '1'; -- Q
                            when X"1C" => keyb_ascii <= x"41";kvalid <= '1'; -- A
                            when X"1A" => keyb_ascii <= x"5a";kvalid <= '1'; -- Z
                            when others => keyb_ascii <= x"ff";
                        end case;
                    end if;
                end if;
            end if;
        end if;
    end if;
end process;
end architecture;
