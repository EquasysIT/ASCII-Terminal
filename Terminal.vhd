-------------------------------------------------
-- Engineer: A Burgess                         --
--                                             --
-- Design Name: ASCII Terminal                 --
--                                             --
-- October 2024                                --
-------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity ascii_term is
    Port ( clk			: in   std_logic;
           reset_n  	: in   std_logic;
           cpu_a        : in   std_logic_vector(15 downto 0);
           cpu_do       : in   std_logic_vector(7 downto 0);
           cpu_r_nw  	: in   std_logic;
           enable     	: in   std_logic;
           crg_clken    : in   std_logic;
           keyb_valid   : out  std_logic;
           term_busy    : out  std_logic;
           ps2_ascii    : out  std_logic_vector(7 downto 0);
           ps2_clk      : inout	std_logic;
           ps2_data     : inout	std_logic;
           nCSync		: out  std_logic;
		   nVSync		: out  std_logic;
           R			: out  std_logic;
           G			: out  std_logic;
		   B			: out  std_logic
		);			  
end ascii_term;


architecture rtl of ascii_term is

-------------
-- Signals --
-------------

-- Character Generator Signals
signal addrascii_v  :   std_logic_vector(11 downto 0) := (others => '0');
signal dataascii_v  :   std_logic_vector(7 downto 0) := (others => '0');
signal dataascii_out:   std_logic_vector(7 downto 0);
signal ascii_r_w    :   std_logic;
signal txtcol       :   std_logic_vector(2 downto 0);
signal bckcol       :   std_logic_vector(2 downto 0);
signal brdcol       :   std_logic_vector(2 downto 0);
signal ansi_par1    :   std_logic_vector(5 downto 0);
signal ansi_par2    :   std_logic_vector(5 downto 0);
signal curctrl      :   std_logic;

-- Scroll Screen Signals
signal scnpos       :   std_logic_vector(11 downto 0);
signal scnchar      :   std_logic_vector(7 downto 0);

-- Cursor Control
signal hcursor      :   std_logic_vector(5 downto 0) := (others => '0');
signal vcursor      :   std_logic_vector(5 downto 0) := (others => '0');

-- PS2 Keyboard
signal ps2_valid    :   std_logic;
signal ps2_ascii_s  :   std_logic_vector(7 downto 0);

-- CPU Signals
signal addrascii_c  :	std_logic_vector(11 downto 0);
signal dataascii_in :	std_logic_vector(7 downto 0);
signal datain_cpu   :	std_logic_vector(7 downto 0);
signal cpu_fcounter :   std_logic_vector(12 downto 0) := (others => '0');
signal cpu_fc_reset :   std_logic := '0';

-- Screen update control signals
type scn_machine is ( norm, srlread, srlwrite, srlblank, ansi_code_ctrl, ansi_code_par_1, ansi_code_action, ansi_code_cls, ansi_code_par_2, ansi_code_poscur_H, ansi_code_poscur );
signal scn_state    :	scn_machine := norm;

begin

-- Keyboard
U1 : entity work.keyboard port map
    (
        clk => clk,
        reset_n => reset_n,
        ps2_clk => ps2_clk,
        ps2_data => ps2_data,
        ps2_valid => ps2_valid,
        keyb_ascii => ps2_ascii_s
	);
ps2_ascii <= ps2_ascii_s;

-- Ensure keypress "valid state" is only valid again after the CPU has read a valid key
process(clk)
begin
    if rising_edge(clk) then
        if reset_n = '0' then
            keyb_valid <= '0';
        elsif ps2_valid = '1' and ps2_ascii_s /= x"ff" then
            keyb_valid <= '1';
        elsif cpu_a = x"fce0" and cpu_r_nw = '1' then -- CPU reads key, reset valid state to not valid
            keyb_valid <= '0';
        end if;
    end if;
end process;

-- Character Generator ASCII RAM
U2 : entity work.asciiram_dp port map
    (
        -- Port A is for CPU to read/write the character RAM
        clka  => clk,
        wea  => ascii_r_w,
        addra => addrascii_c,
        dataina  => dataascii_in,
        dataouta  => dataascii_out,
        -- Port B is for the Character ROM Generator
        clkb  => clk,
        web  => '0', -- Read only
        addrb => addrascii_v,
        datainb => x"00",
        dataoutb => dataascii_v
    );

-- Character Generator
U3: entity work.crg port map
    (
        clk => clk,
        reset_n => reset_n,
		enable => crg_clken,
        dataascii => dataascii_v,
        hcur_pos => hcursor,
        vcur_pos => vcursor,
        addrascii => addrascii_v,
        txtcol => txtcol,
        bckcol => bckcol,
        brdcol => brdcol,
        curctrl => curctrl,
        nCSync => nCSync,
		nVSync => nVSync,
        R => R,
        G => G,
		B => B
	);	

-- Set screen attributes and cursor state
process(clk)
begin
    if rising_edge(clk) then
        if reset_n = '0' then
            txtcol <= "111"; -- Character colour
            bckcol <= "000"; -- Background colour
            brdcol <= "111"; -- Border colour
            curctrl <= '1';  -- Cursor state
        elsif cpu_a = x"ffe3" and cpu_r_nw = '0' then
            txtcol <= cpu_do(2 downto 0);
        elsif cpu_a = x"ffe4" and cpu_r_nw = '0' then
            bckcol <= cpu_do(2 downto 0);
        elsif cpu_a = x"ffe5" and cpu_r_nw = '0' then
            brdcol <= cpu_do(2 downto 0);
        elsif cpu_a = x"ffe6" and cpu_r_nw = '0' then
            curctrl <= cpu_do(0);
        end if;
    end if;
end process;

-- Write to screen and manage scrolling
process(clk)
begin
	if rising_edge(clk) then
        -- Count CPU ticks
        if cpu_fc_reset = '1' then
            cpu_fcounter <= (others => '0');
            cpu_fc_reset <= '0';
        elsif enable = '1' then
            cpu_fcounter <= cpu_fcounter + 1;
        end if;
		if reset_n = '0' then
			addrascii_c <= cpu_fcounter(11 downto 0); -- Clear screen
			dataascii_in <= x"20";
			ascii_r_w <= '1';
			hcursor <= "000000";
			vcursor <= "000000";
            scnpos <= "0000" & x"40";
            term_busy <= '0';
        else
            case scn_state is
                -- Screen in normal none scroll state
                when norm =>
                    term_busy <= '0';
                    if (cpu_a = x"ffe0" and cpu_r_nw = '0' and enable = '1' and cpu_do /= x"ff") then -- CPU writing to screen with valid character
                        ascii_r_w <= '1';
                        if cpu_do = x"1b" then -- Escape sequence so process ANSI code
                            cpu_fc_reset <= '1';
                            scn_state <= ansi_code_ctrl;
                        elsif cpu_do = x"08" then -- Backspace ascii code                                
                            if hcursor /= 0 or vcursor /= 0 then
                                dataascii_in <= x"20";
                                hcursor <= hcursor - 1;
                                addrascii_c <= vcursor & hcursor - 1;
                                if hcursor = 0 then
                                    vcursor <= vcursor - 1;
                                end if;
                            end if;
                        elsif cpu_do = x"0d" then -- Carriage Return ascii code
                            hcursor <= "000000";
                        elsif cpu_do = x"0a" then -- Line feed ascii code
                            hcursor <= "000000";
                            if vcursor /= 39 then
                                vcursor <= vcursor + 1;
                            else
                                scn_state <= srlread;
                            end if;
                        elsif cpu_do /= x"ff" then -- Any other valid ascii code
                            dataascii_in <= cpu_do;
                            hcursor <= hcursor + 1;
                            addrascii_c <= vcursor & hcursor;
                            if hcursor = 63 then
                                hcursor <= "000000";
                                if vcursor /= 39 then
                                    vcursor <= vcursor + 1;
                                else
                                    scn_state <= srlread;
                                end if;
                            end if;
                        end if;
                    end if;
                -- Scroll the screen --
                when srlread =>
                    term_busy <= '1';
                    -- Read character from row
                    if scnpos <= 2560 then
                        ascii_r_w <= '0';
                        addrascii_c <= scnpos;
                        scnchar <= dataascii_out;
                        scn_state <= srlwrite;
                    end if;
                when srlwrite =>
                    -- Write character to row above where it was read
                    if scnpos <= 2560 then
                        if scnpos = 2560 then
                            scn_state <= srlblank;
                        else
                            scn_state <= srlread;
                        end if;
                        ascii_r_w <= '1';
                        addrascii_c <= scnpos - 65;
                        dataascii_in <= scnchar;
                        scnpos <= scnpos + 1;
                    end if;
                when srlblank =>
                    -- Blank bottom line after scroll
                    if addrascii_c <= 2559 then
                        ascii_r_w <= '1';
                        addrascii_c <= addrascii_c + 1;
                        dataascii_in <= x"20";
                    else
                        ascii_r_w <= '0';
                        scnpos <= "0000" & x"40";
                        scn_state <= norm;
                    end if;
                -- End scroll the screen --

                -- Process ANSI codes --
                when ansi_code_ctrl =>
                    -- Wait for ANSI code "[" -- Start of control sequence
                    if cpu_a = x"ffe0" and cpu_r_nw = '0' and enable = '1'  then
                        if cpu_do = x"5b" then
                            cpu_fc_reset <= '1';
                            scn_state <= ansi_code_par_1;
                        end if;
                    elsif cpu_fcounter = '1' & x"300" then -- Wait for max of &1300 CPU cycles for next code to arrive
                        scn_state <= norm;
                    end if;
                when ansi_code_par_1 =>
                    -- Wait for ANSI parameter value 1
                    if cpu_a = x"ffe0" and cpu_r_nw = '0' and enable = '1'  then
                        if cpu_do >= 1 and cpu_do <= 40 then -- Get screen row
                            cpu_fc_reset <= '1';
                            ansi_par1 <= cpu_do(5 downto 0) - 1;
                            scn_state <= ansi_code_action;
                        end if;
                    elsif cpu_fcounter = '1' & x"300" then -- Wait for max of &1300 CPU cycles for next code to arrive
                        scn_state <= norm;
                    end if;
                when ansi_code_action =>
                    -- Wait for ANSI action code
                    if cpu_a = x"ffe0" and cpu_r_nw = '0' and enable = '1'  then
                        if cpu_do = x"4a" then -- "J" = Clear Screen
                            cpu_fc_reset <= '1';
                            scn_state <= ansi_code_cls;
                        elsif cpu_do = x"3b" then -- ";" = Position cursor
                            cpu_fc_reset <= '1';
                            scn_state <= ansi_code_par_2;
                        end if;
                    elsif cpu_fcounter = '1' & x"300" then -- Wait for max of &1300 CPU cycles for next code to arrive
                        scn_state <= norm;
                    end if;
                when ansi_code_cls =>
                    -- Clear screen
                    addrascii_c <= cpu_fcounter(11 downto 0);
                    dataascii_in <= x"20";
                    ascii_r_w <= '1';
                    hcursor <= "000000";
                    vcursor <= "000000";
                    scnpos <= "0000" & x"40";
                    if cpu_fcounter = x"a00" then -- Cycle 2560 times to clear all characters from the screen
                        scn_state <= norm;
                    end if;
                when ansi_code_par_2 =>
                    -- Wait for ANSI parameter value 2
                    if cpu_a = x"ffe0" and cpu_r_nw = '0' and enable = '1' then
                        if cpu_do >= 1 and cpu_do <= 64 then -- Get screen column
                            cpu_fc_reset <= '1';
                            ansi_par2 <= cpu_do(5 downto 0) - 1;
                            scn_state <= ansi_code_poscur_H;
                        end if;
                    elsif cpu_fcounter = '1' & x"300" then -- Wait for max of &1300 CPU cycles for next code to arrive
                        scn_state <= norm;
                    end if;
                when ansi_code_poscur_H =>
                    -- Wait for ANSI code H -- Final position cursor value
                    if cpu_a = x"ffe0" and cpu_r_nw = '0' and enable = '1' then
                        if cpu_do = x"48" then
                            cpu_fc_reset <= '1';
                            scn_state <= ansi_code_poscur;
                        end if;
                    elsif cpu_fcounter = '1' & x"300" then -- Wait for max of &1300 CPU cycles for next code to arrive
                        scn_state <= norm;
                    end if;
                when ansi_code_poscur =>
                    -- Position cursor
                    if enable = '1' then -- Update cursor values in sync with the CPU
                        hcursor <= ansi_par2;
                        vcursor <= ansi_par1;
                        scn_state <= norm;
                    end if;
                when others => null;
            end case;
        end if;
    end if;
end process;
end rtl;