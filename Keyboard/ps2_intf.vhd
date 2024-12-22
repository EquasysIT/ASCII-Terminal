-- Keyboard interface
-- Based loosely on ps2_ctrl.vhd (c) alse. http://www.alse-fr.com
-- Added support for usb/ps2 keyboards which issue "AA" BAT code to detect a PS2 connection - A Burgess
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity ps2_intf is
	generic(clk_freq	:	integer := 28_000_000); -- Set to incoming clock frequency
	port(
		clk				:	in	std_logic;
		reset_n			:	in	std_logic;
		
		-- ps/2 interface (now supports send and receive)
		ps2_clk			:	inout	std_logic;
		ps2_data        :	inout	std_logic;
		
		tx_ena			: in std_logic;
		tx_cmd			: in std_logic_vector(7 downto 0);    
		tx_busy			: out std_logic;
		ps2_code        : out std_logic_vector(7 downto 0);
		ps2_code_new    : out std_logic
		);
	end ps2_intf;

architecture rtl of ps2_intf is
type machine is(receive, inhibit, transact, tx_complete);
signal	state				:	machine := receive;
subtype filter_t is std_logic_vector(7 downto 0);
signal	clk_filter		:	filter_t;
signal	ps2_clk_in		:	std_logic;
signal	ps2_dat_in		:	std_logic;
-- goes high when a clock falling edge is detected
signal	clk_edge			:	std_logic;
signal	bit_count		:	unsigned (3 downto 0);
signal	receivereg		:	std_logic_vector(10 downto 0);
signal	transreg			:	std_logic_vector(8 downto 0);
signal	parity			:	std_logic;
signal	timer		 		:	integer range 0 to clk_freq/10_000 := 0;
signal	rx_error			:	std_logic;

begin

	-- register input signals
	process(reset_n,clk)
	begin
		if reset_n = '0' then
			ps2_clk_in <= '1';
			ps2_dat_in <= '1';
			clk_filter <= (others => '1');
			clk_edge <= '0';
		elsif rising_edge(clk) then
			-- register inputs (and filter clock)
			ps2_dat_in <= ps2_data;
			clk_filter <= ps2_clk & clk_filter(clk_filter'high downto 1);
			clk_edge <= '0';	
			if clk_filter = filter_t'(others => '1') then
				-- filtered clock is high
				ps2_clk_in <= '1';
			elsif clk_filter = filter_t'(others => '0') then
				-- filter clock is low, check for edge
				if ps2_clk_in = '1' then
					clk_edge <= '1';
				end if;
				ps2_clk_in <= '0';
            end if;
		end if;
	end process;
	
	process(reset_n,clk)
	begin
		if reset_n = '0' then
			ps2_clk <= '0';
			ps2_data <= 'Z';
			tx_busy <= '0';
			ps2_code <= (others => '0');
			ps2_code_new <= '0';
			bit_count <= (others => '0');
			receivereg <= (others => '0');
			transreg <= (others => '0');
			parity <= '0';
			state <= receive;
		elsif rising_edge(clk) then
			ps2_code_new <= '0';
			case state is
				when receive =>
					if(tx_ena = '1') then
						tx_busy <= '1';
						timer <= 0;
						transreg <= tx_cmd & '0'; -- Command to send to keyboard including start bit
						bit_count <= (others => '0');
						state <= inhibit;
					else
						tx_busy <= '0';
						ps2_clk <= 'Z';
						ps2_data <= 'Z';
						ps2_code <= (others => '0');
						if clk_edge = '1' then
							-- we have a new bit from the keyboard for processing
							if bit_count = 0 then
								-- idle state, check for start bit (0) only and don't
								-- start counting bits until we get it							
								parity <= '0';
								if ps2_dat_in = '0' then
									-- this is a start bit
									bit_count <= bit_count + 1;
								end if;
							else
								-- running.  8-bit data comes in lsb first followed by
								-- a single stop bit (1)
								if bit_count < 10 then
									-- shift in data and parity (9 bits)
									bit_count <= bit_count + 1;
									receivereg <= ps2_dat_in & receivereg(receivereg'high downto 1);
									parity <= parity xor ps2_dat_in; -- calculate parity
								elsif ps2_dat_in = '1' then
									-- valid stop bit received
									bit_count <= (others => '0'); -- back to idle
									if parity = '1' then
										-- parity correct, submit data to host
										ps2_code <= receivereg(9 downto 2);
										ps2_code_new <= '1';
									else
										-- error
										rx_error <= '1';
									end if;
								else
									bit_count <= (others => '0');
									rx_error <= '1';
								end if;
							end if;
						end if;
							state <= receive;
					end if;
					
				when inhibit =>
					if(timer < clk_freq/10_000) then -- Bring clock low for 100us - This signals request to send from Host
						timer <= timer + 1;
						ps2_data <= 'Z';
						ps2_clk <= '0';
					else
						ps2_data <= transreg(0); -- Bring data low while keeping clock low. This is the host to device start bit. First part of "request to send" signal from host to device
						state <= transact;
					end if;
				
				when transact =>
					ps2_clk <= 'Z';
					if clk_edge = '1' then
						transreg <= ps2_dat_in & transreg(8 downto 1);
						parity <= parity xor transreg(0);
						bit_count <= bit_count + 1;
					end if;
					if (bit_count < 9) then
						ps2_data <= transreg(0);
					elsif (bit_count = 9) then
						-- Parity Bit
						ps2_data <= parity;
					elsif (bit_count = 10) then
						-- Stop Bit
						ps2_data <= '1';
					else
						ps2_data <= 'Z';
					end if;
					if(bit_count = 11) then
						state <= tx_complete;
					else
						state <= transact;
					end if;
					
				when tx_complete =>
					-- Wait Acknowledgement from device
					if(ps2_clk_in = '1' and ps2_dat_in = '1') then
						bit_count <= (others => '0');
						state <= receive;
					end if;				
			end case;
		end if;
	end process;
end rtl;
