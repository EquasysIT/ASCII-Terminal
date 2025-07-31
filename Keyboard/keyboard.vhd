--------------------------------------------------------------
-- Engineer: A Burgess                                      --
--                                                          --
-- Design Name: Basic Computer System - ASCII Keyboard      --
--                                                          --
--------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity keyboard is
port (
	clk			:	in std_logic;
	reset_n		:	in std_logic;
	ps2_clk		:	inout std_logic;
	ps2_data	:	inout std_logic;
    ps2_valid   :	out std_logic;
	keyb_ascii	:	out	std_logic_vector(7 downto 0)
	);
end keyboard;

architecture rtl of keyboard is

signal break		:	std_logic := '0'; -- Make is 0 break is 1
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
signal shift        :	std_logic;
signal ctrl         :	std_logic;
signal extend       :	std_logic;

type keyb_machine is ( kb_init, kb_ack1, kb_ack2, kb_ack3, kb_ack4, kb_ack5, kb_led, kb_setled, kb_rep, kb_setrep, kb_bat1, kb_bat2, kb_decode );
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
            kbcaps <= '1';
            shift <= '0';
            ps2_valid <= '0';
            led_code <= (others => '0');
        else
		-- Keyboard FSM
			case keyb_state is

				when kb_init =>
                    break <= '0';
                    tx_ena <= '0';
                    kbscroll <= '0';
                    kbnum <= '0';
                    kbcaps <= '1';
                    shift <= '0';
                    ps2_valid <= '0';
                    led_code <= (others => '0');
                    keyb_ascii <= x"ff";
					if tx_busy = '0' then
						tx_ena <= '1';
						tx_cmd <= x"ff";            -- Initialise keyboard
						keyb_state <= kb_init;
					elsif tx_busy = '1' then
						tx_ena <= '0';
						keyb_state <= kb_ack1;
					end if;
					
				when kb_ack1 =>
					if keyb_valid = '1' then
						if keyb_data = x"fa" then   -- Wait for acknowledgement from keyboard
							keyb_state <= kb_bat1;
						else
							keyb_state <= kb_init;
						end if;
					else
							keyb_state <= kb_ack1;
					end if;
				
				when kb_bat1 =>
					if keyb_valid = '1' then
						if keyb_data = x"aa" then   -- Wait for BAT from keyboard - self test passed
							keyb_state <= kb_rep;
						else
							keyb_state <= kb_init;
						end if;
					else
							keyb_state <= kb_bat1;
					end if;					

				when kb_rep =>
					if tx_busy = '0' then
						tx_ena <= '1';
						tx_cmd <= x"f3";            -- Send "set keyboard speed" code to keyboard
						keyb_state <= kb_rep;
					elsif tx_busy = '1' then
						tx_ena <= '0';
						keyb_state <= kb_ack4;
					end if;
							
				when kb_ack4 =>
					if keyb_valid = '1' then
						if keyb_data = x"fa" then   -- Wait for acknowledgement from keyboard
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
						tx_cmd <= "00100100";       -- Set key repeat delay and repeat speed - 7 must be zero, 5 & 6 = auto repeat delay 11 = 1 sec - 0 to 4 repeat rate 11111 = 2hz
						keyb_state <= kb_setrep;
					elsif tx_busy = '1' then
						tx_ena <= '0';
						keyb_state <= kb_ack5;
					end if;
								
				when kb_ack5 =>
					if keyb_valid = '1' then
						if keyb_data = x"fa" then   -- Wait for acknowledgement from keyboard
							keyb_state <= kb_led;
						else
							keyb_state <= kb_init;
						end if;
					else
							keyb_state <= kb_ack5;
					end if;
									
				when kb_led =>
					if tx_busy = '0' then
						tx_ena <= '1';
						tx_cmd <= x"ed";            -- Send "change led" code to keyboard
						keyb_state <= kb_led;
					elsif tx_busy = '1' then
						tx_ena <= '0';
						keyb_state <= kb_ack2;
					end if;
							
				when kb_ack2 =>
					if keyb_valid = '1' then
						if keyb_data = x"fa" then   -- Wait for acknowledgement from keyboard
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
						tx_cmd <= "00000" & led_code; -- Set led
						keyb_state <= kb_setled;
					elsif tx_busy = '1' then
						tx_ena <= '0';
						keyb_state <= kb_ack3;
					end if;

				when kb_ack3 =>
					if keyb_valid = '1' then
						if keyb_data = x"fa" then   -- Wait for acknowledgement from keyboard
							keyb_state <= kb_decode;
						else
							keyb_state <= kb_init;
						end if;
					else
							keyb_state <= kb_ack3;
					end if;

				-- We have reached the end of the initialisation state and setting the leds
				-- Now we decode the keys pressed into ascii values
				when kb_decode =>
                    ps2_valid <= '0';
					if keyb_valid = '1' then
                        if keyb_data = x"f0" then
                            break <= '1';
                            keyb_state <= kb_decode;
                        elsif keyb_data = x"e0" then
                            extend <= '1';
                            keyb_state <= kb_decode;
                        else
                            break <= '0';
                            extend <= '0';
                                ps2_valid <= keyb_valid;
                                case keyb_data is
                                    when x"aa" => keyb_state <= kb_init;    -- Reinitialise keyboard if just plugged in. AA is the BAT code from the keyboard
 
                                    when x"58" => keyb_ascii <= x"ff";      -- Caps lock
                                                  if break = '0' then
                                                    kbcaps <= not kbcaps;
                                                    keyb_state <= kb_led;
                                                  end if;
                                    when x"77" => keyb_ascii <= x"ff";      -- Num lock
                                                  if break = '0' then
                                                    kbnum <= not kbnum;
                                                    keyb_state <= kb_led;
                                                  end if;
                                    when x"7e" => keyb_ascii <= x"ff";      -- Scroll lock
                                                  if break = '0' then
                                                    kbscroll <= not kbscroll;
                                                    keyb_state <= kb_led;
                                                  end if;
                                    when x"12" => keyb_ascii <= x"ff";      -- Left shift key
                                                  shift <= not break;  
                                    when x"59" => keyb_ascii <= x"ff";      -- Right shift key
                                                  shift <= not break;  
                                    when x"14" => keyb_ascii <= x"ff";      -- Control keys
                                                  ctrl <= not break;
                                    when others => keyb_ascii <= x"ff";
                                end case;
                                if break = '0' then
                                    -- Control codes
                                    if ctrl = '1' then
                                      case keyb_data is
                                        when x"1e" => keyb_ascii <= x"00"; --^@  nul
                                        when x"1c" => keyb_ascii <= x"01"; --^a  soh
                                        when x"32" => keyb_ascii <= x"02"; --^b  stx
                                        when x"21" => keyb_ascii <= x"03"; --^c  etx
                                        when x"23" => keyb_ascii <= x"04"; --^d  eot
                                        when x"24" => keyb_ascii <= x"05"; --^e  enq
                                        when x"2b" => keyb_ascii <= x"06"; --^f  ack
                                        when x"34" => keyb_ascii <= x"07"; --^g  bel
                                        when x"33" => keyb_ascii <= x"08"; --^h  bs
                                        when x"43" => keyb_ascii <= x"09"; --^i  ht
                                        when x"3b" => keyb_ascii <= x"0a"; --^j  lf
                                        when x"42" => keyb_ascii <= x"0b"; --^k  vt
                                        when x"4b" => keyb_ascii <= x"0c"; --^l  ff
                                        when x"3a" => keyb_ascii <= x"0d"; --^m  cr
                                        when x"31" => keyb_ascii <= x"0e"; --^n  so
                                        when x"44" => keyb_ascii <= x"0f"; --^o  si
                                        when x"4d" => keyb_ascii <= x"10"; --^p  dle
                                        when x"15" => keyb_ascii <= x"11"; --^q  dc1
                                        when x"2d" => keyb_ascii <= x"12"; --^r  dc2
                                        when x"1b" => keyb_ascii <= x"13"; --^s  dc3
                                        when x"2c" => keyb_ascii <= x"14"; --^t  dc4
                                        when x"3c" => keyb_ascii <= x"15"; --^u  nak
                                        when x"2a" => keyb_ascii <= x"16"; --^v  syn
                                        when x"1d" => keyb_ascii <= x"17"; --^w  etb
                                        when x"22" => keyb_ascii <= x"18"; --^x  can
                                        when x"35" => keyb_ascii <= x"19"; --^y  em
                                        when x"1a" => keyb_ascii <= x"1a"; --^z  sub
                                        when x"54" => keyb_ascii <= x"1b"; --^[  esc
                                        when x"5d" => keyb_ascii <= x"1c"; --^\  fs
                                        when x"5b" => keyb_ascii <= x"1d"; --^]  gs
                                        when x"36" => keyb_ascii <= x"1e"; --^^  rs
                                        when x"4e" => keyb_ascii <= x"1f"; --^_  us
                                        when x"4a" => keyb_ascii <= x"7f"; --^?  del
                                        when others => null;
                                      end case;
                                    else
                                      -- General keys
                                      case keyb_data is
                                        when x"29" => keyb_ascii <= x"20"; -- Space
                                        when x"66" => keyb_ascii <= x"7f"; -- Backspace
                                        when x"0d" => keyb_ascii <= x"09"; -- Tab
                                        when x"5a" => keyb_ascii <= x"0d"; -- Return
                                        when x"76" => keyb_ascii <= x"1b"; -- Esc
                                        when x"70" => 
                                          if extend = '1' then
                                            keyb_ascii <= x"10";           -- Insert
                                          end if;
                                        when x"71" => 
                                          if extend = '1' then
                                            keyb_ascii <= x"7f";           -- Delete
                                          end if;
                                        when x"75" => 
                                          if extend = '1' then
                                            keyb_ascii <= x"11";           -- Up Arrow
                                          end if;
                                        when x"72" => 
                                          if extend = '1' then
                                            keyb_ascii <= x"12";           -- Down Arrow
                                          end if;
                                        when x"6b" => 
                                          if extend = '1' then
                                            keyb_ascii <= x"13";           -- Left Arrow
                                          end if;
                                        when x"74" => 
                                          if extend = '1' then
                                            keyb_ascii <= x"14";           -- Right Arrow
                                          end if;
                                        when others => null;
                                      end case;
                                      -- Upper/Lowercase letters
                                      if (shift = '0' and kbcaps = '0') or (shift = '1' and kbcaps = '1') then
                                        case keyb_data is                    -- Lowercase
                                          when x"1c" => keyb_ascii <= x"61"; -- a
                                          when x"32" => keyb_ascii <= x"62"; -- b
                                          when x"21" => keyb_ascii <= x"63"; -- c
                                          when x"23" => keyb_ascii <= x"64"; -- d
                                          when x"24" => keyb_ascii <= x"65"; -- e
                                          when x"2b" => keyb_ascii <= x"66"; -- f
                                          when x"34" => keyb_ascii <= x"67"; -- g
                                          when x"33" => keyb_ascii <= x"68"; -- h
                                          when x"43" => keyb_ascii <= x"69"; -- i
                                          when x"3b" => keyb_ascii <= x"6a"; -- j
                                          when x"42" => keyb_ascii <= x"6b"; -- k
                                          when x"4b" => keyb_ascii <= x"6c"; -- l
                                          when x"3a" => keyb_ascii <= x"6d"; -- m
                                          when x"31" => keyb_ascii <= x"6e"; -- n
                                          when x"44" => keyb_ascii <= x"6f"; -- o
                                          when x"4d" => keyb_ascii <= x"70"; -- p
                                          when x"15" => keyb_ascii <= x"71"; -- q
                                          when x"2d" => keyb_ascii <= x"72"; -- r
                                          when x"1b" => keyb_ascii <= x"73"; -- s
                                          when x"2c" => keyb_ascii <= x"74"; -- t
                                          when x"3c" => keyb_ascii <= x"75"; -- u
                                          when x"2a" => keyb_ascii <= x"76"; -- v
                                          when x"1d" => keyb_ascii <= x"77"; -- w
                                          when x"22" => keyb_ascii <= x"78"; -- x
                                          when x"35" => keyb_ascii <= x"79"; -- y
                                          when x"1a" => keyb_ascii <= x"7a"; -- z
                                          when others => null;
                                        end case;
                                      else
                                        case keyb_data is                    -- Uppercase
                                          when x"1c" => keyb_ascii <= x"41"; -- A
                                          when x"32" => keyb_ascii <= x"42"; -- B
                                          when x"21" => keyb_ascii <= x"43"; -- C
                                          when x"23" => keyb_ascii <= x"44"; -- D
                                          when x"24" => keyb_ascii <= x"45"; -- E
                                          when x"2b" => keyb_ascii <= x"46"; -- F
                                          when x"34" => keyb_ascii <= x"47"; -- G
                                          when x"33" => keyb_ascii <= x"48"; -- H
                                          when x"43" => keyb_ascii <= x"49"; -- I
                                          when x"3b" => keyb_ascii <= x"4a"; -- J
                                          when x"42" => keyb_ascii <= x"4b"; -- K
                                          when x"4b" => keyb_ascii <= x"4c"; -- L
                                          when x"3a" => keyb_ascii <= x"4d"; -- M
                                          when x"31" => keyb_ascii <= x"4e"; -- N
                                          when x"44" => keyb_ascii <= x"4f"; -- O
                                          when x"4d" => keyb_ascii <= x"50"; -- P
                                          when x"15" => keyb_ascii <= x"51"; -- Q
                                          when x"2d" => keyb_ascii <= x"52"; -- R
                                          when x"1b" => keyb_ascii <= x"53"; -- S
                                          when x"2c" => keyb_ascii <= x"54"; -- T
                                          when x"3c" => keyb_ascii <= x"55"; -- U
                                          when x"2a" => keyb_ascii <= x"56"; -- V
                                          when x"1d" => keyb_ascii <= x"57"; -- W
                                          when x"22" => keyb_ascii <= x"58"; -- X
                                          when x"35" => keyb_ascii <= x"59"; -- Y
                                          when x"1a" => keyb_ascii <= x"5a"; -- Z
                                          when others => null;
                                        end case;
                                      end if;
                                      -- Numbers/Symbols
                                      if shift = '1' then
                                        case keyb_data is              
                                          when x"16" => keyb_ascii <= x"21"; -- !
                                          when x"52" => keyb_ascii <= x"40"; -- "
                                          when x"26" => keyb_ascii <= x"60"; -- £
                                          when x"25" => keyb_ascii <= x"24"; -- $
                                          when x"2e" => keyb_ascii <= x"25"; -- %
                                          when x"36" => keyb_ascii <= x"5e"; -- ^
                                          when x"3d" => keyb_ascii <= x"26"; -- &
                                          when x"3e" => keyb_ascii <= x"2a"; -- *              
                                          when x"46" => keyb_ascii <= x"28"; -- (
                                          when x"45" => keyb_ascii <= x"29"; -- )
                                          when x"55" => keyb_ascii <= x"2b"; -- +
                                          when x"4c" => keyb_ascii <= x"3a"; -- :
                                          when x"41" => keyb_ascii <= x"3c"; -- <
                                          when x"49" => keyb_ascii <= x"3e"; -- >
                                          when x"4a" => keyb_ascii <= x"3f"; -- ?
                                          when x"1e" => keyb_ascii <= x"22"; -- @
                                          when x"4e" => keyb_ascii <= x"5f"; -- _
                                          when x"54" => keyb_ascii <= x"7b"; -- {
                                          when x"5d" => keyb_ascii <= x"7e"; -- ~
                                          when x"5b" => keyb_ascii <= x"7d"; -- }
                                          when x"61" => keyb_ascii <= x"7c"; -- |
                                          when x"0e" => keyb_ascii <= x"7c"; -- |
                                          when others => null;
                                        end case;
                                      else
                                        case keyb_data is  
                                          when x"45" => keyb_ascii <= x"30"; -- 0
                                          when x"16" => keyb_ascii <= x"31"; -- 1
                                          when x"1e" => keyb_ascii <= x"32"; -- 2
                                          when x"26" => keyb_ascii <= x"33"; -- 3
                                          when x"25" => keyb_ascii <= x"34"; -- 4
                                          when x"2e" => keyb_ascii <= x"35"; -- 5
                                          when x"36" => keyb_ascii <= x"36"; -- 6
                                          when x"3d" => keyb_ascii <= x"37"; -- 7
                                          when x"3e" => keyb_ascii <= x"38"; -- 8
                                          when x"46" => keyb_ascii <= x"39"; -- 9
                                          when x"52" => keyb_ascii <= x"27"; -- '
                                          when x"41" => keyb_ascii <= x"2c"; -- ,
                                          when x"4e" => keyb_ascii <= x"2d"; -- -
                                          when x"49" => keyb_ascii <= x"2e"; -- .
                                          when x"4a" => keyb_ascii <= x"2f"; -- /
                                          when x"4c" => keyb_ascii <= x"3b"; -- ;
                                          when x"55" => keyb_ascii <= x"3d"; -- =
                                          when x"54" => keyb_ascii <= x"5b"; -- [
                                          when x"5d" => keyb_ascii <= x"23"; -- #
                                          when x"5b" => keyb_ascii <= x"5d"; -- ]
                                          when x"61" => keyb_ascii <= x"5c"; -- \
                                          when x"0e" => keyb_ascii <= x"5c"; -- \
                                          when others => null;
                                        end case;
                                end if;
                            end if;
                        end if;
                    end if;
                end if;
                when others => null;
            end case;
        end if;
    end if;
end process;
end rtl;
