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
signal addrascii_v  :   std_logic_vector(9 downto 0) := (others => '0');
signal dataascii_v  :   std_logic_vector(7 downto 0) := (others => '0');
signal dataascii_out:   std_logic_vector(7 downto 0);
signal ascii_r_w    :   std_logic;
signal txtcol       :   std_logic_vector(2 downto 0);
signal bckcol       :   std_logic_vector(2 downto 0);

-- Scroll Screen Signals
signal scnpos       :   std_logic_vector(9 downto 0);
signal scnchar      :   std_logic_vector(7 downto 0);

-- Cursor Control
signal hcursor      :   std_logic_vector(4 downto 0) := (others => '0');
signal vcursor      :   std_logic_vector(4 downto 0) := (others => '0');

-- PS2 Keyboard
signal ps2_valid    :   std_logic;
signal ps2_ascii_s  :   std_logic_vector(7 downto 0);

-- CPU Signals
signal addrascii_c  :	std_logic_vector(9 downto 0);
signal dataascii_in :	std_logic_vector(7 downto 0);
signal datain_cpu   :	std_logic_vector(7 downto 0);

-- General counter
signal gcounter     :   std_logic_vector(9 downto 0);

-- Screen update control signals
type scn_machine is ( norm, srlread, srlwrite, srlblank );
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
		enable => crg_clken,
        dataascii => dataascii_v,
        hcur_pos => hcursor,
        vcur_pos => vcursor,
        addrascii => addrascii_v,
        txtcol => txtcol,
        bckcol => bckcol,
        nCSync => nCSync,
		nVSync => nVSync,
        R => R,
        G => G,
		B => B
	);	

-- Set character and background colour
process(clk)
begin
    if rising_edge(clk) then
        if reset_n = '0' then
            txtcol <= "111";
            bckcol <= "000";
        elsif cpu_a = x"ffe2" and cpu_r_nw = '0' then
            txtcol <= cpu_do(2 downto 0);
        elsif cpu_a = x"ffe3" and cpu_r_nw = '0' then
            bckcol <= cpu_do(2 downto 0);
        end if;
    end if;
end process;

-- Write to screen and manage scrolling
process(clk)
begin
	if rising_edge(clk) then
        gcounter <= gcounter + 1;
		if reset_n = '0' then
			addrascii_c <= gcounter(9 downto 0); -- Clear screen
			dataascii_in <= x"20";
			ascii_r_w <= '1';
			hcursor <= "00000";
			vcursor <= "00000";
            scnpos <= "00" & x"20";
        else
            case scn_state is
                -- Screen in normal none scroll state
                when norm =>
                    if (cpu_a = x"ffe0" and cpu_r_nw = '0' and enable = '1' and cpu_do /= x"ff") then -- CPU writing to screen with valid character
                        ascii_r_w <= '1';
                        if cpu_do = x"08" then -- Backspace ascii code                                
                            if hcursor /= 0 or vcursor /= 0 then
                                dataascii_in <= x"20";
                                hcursor <= hcursor - 1;
                                addrascii_c <= vcursor & hcursor - 1;
                                if hcursor = 0 then
                                    vcursor <= vcursor - 1;
                                end if;
                            end if;
                        elsif cpu_do = x"0d" then -- Carriage Return ascii code
                            hcursor <= "00000";
                        elsif cpu_do = x"0a" then -- Line feed ascii code
                            hcursor <= "00000";
                            if vcursor /= 23 then
                                vcursor <= vcursor + 1;
                            else
                                scn_state <= srlread;
                            end if;
                        elsif cpu_do /= x"ff" then -- Any other valid ascii code
                            dataascii_in <= cpu_do;
                            hcursor <= hcursor + 1;
                            addrascii_c <= vcursor & hcursor;
                            if hcursor = 31 then
                                hcursor <= "00000";
                                if vcursor /= 23 then
                                    vcursor <= vcursor + 1;
                                else
                                    scn_state <= srlread;
                                end if;
                            end if;
                        end if;
                    end if;
                -- Scroll the screen --
                when srlread =>
                    -- Read character from row
                    if scnpos <= 768 then
                        ascii_r_w <= '0';
                        addrascii_c <= scnpos;
                        scnchar <= dataascii_out;
                        scn_state <= srlwrite;
                    end if;
                when srlwrite =>
                    -- Write character to row above where it was read
                    if scnpos <= 768 then
                        if scnpos = 768 then
                            scn_state <= srlblank;
                        else
                            scn_state <= srlread;
                        end if;
                        ascii_r_w <= '1';
                        addrascii_c <= scnpos - 33;
                        dataascii_in <= scnchar;
                        scnpos <= scnpos + 1;
                    end if;
                when srlblank =>
                    -- Blank bottom line after scroll
                    if addrascii_c <= 767 then
                        ascii_r_w <= '1';
                        addrascii_c <= addrascii_c + 1;
                        dataascii_in <= x"20";
                    else
                        ascii_r_w <= '0';
                        scnpos <= "00" & x"20";
                        scn_state <= norm;
                    end if;
                -- End scroll the screen --
            end case;
        end if;
    end if;
end process;
end rtl;
