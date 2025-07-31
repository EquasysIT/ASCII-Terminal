--------------------------------------------------------------
-- Engineer: A Burgess                                      --
--                                                          --
-- Design Name: Basic Computer System - ASCII Terminal      --
--                                                          --
--------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity ascii_term is
    Port ( clk			: in   std_logic;
           reset_n  	: in   std_logic;
           trm_do       : out  std_logic_vector(7 downto 0);
           trm_nmi  	: out  std_logic;
           trm_irq  	: out  std_logic;
           trm_enable   : out  std_logic;
           cpu_addr     : in   std_logic_vector(15 downto 0);
           cpu_do       : in   std_logic_vector(7 downto 0);
           cpu_nwr  	: in   std_logic;
           enable     	: in   std_logic;
           crg_clken    : in   std_logic;
           rxd          : in   std_logic;
           txd          : out  std_logic;
           led          : out  std_logic_vector(5 downto 0);
           sndl         : out  std_logic;
           sndr         : out  std_logic;
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

-- Terminal Status/Control Signals
signal trm_int      :   std_logic;
signal keyb_int     :   std_logic;
signal uart_int     :   std_logic;
signal timer_int    :   std_logic;
signal timer_valid  :   std_logic;
signal timer        :   std_logic_vector(15 downto 0);
signal trm_timer_l  :   std_logic_vector(7 downto 0);
signal trm_timer_h  :   std_logic_vector(7 downto 0);

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
signal scrn_width   :   std_logic_vector(5 downto 0);
signal scrn_height  :   std_logic_vector(5 downto 0);
signal scrn_chars   :   std_logic_vector(11 downto 0);
signal curonoff     :   std_logic;
signal curflash     :   std_logic;
signal curtype      :   std_logic;
signal cpu_w_term   :   std_logic;
signal mode         :   std_logic;
signal edit         :   std_logic;
signal term_busy    :   std_logic;

-- CPU Signals
signal addrascii_c  :	std_logic_vector(11 downto 0);
signal dataascii_in :	std_logic_vector(7 downto 0);
signal datain_cpu   :	std_logic_vector(7 downto 0);
signal cpu_fcounter :   std_logic_vector(12 downto 0) := (others => '0');
signal cpu_fc_reset :   std_logic := '0';

-- Scroll Screen Signals
signal scnpos       :   std_logic_vector(11 downto 0);
signal scnchar      :   std_logic_vector(7 downto 0);

-- Main & Edit Cursor Control
signal hcursor      :   std_logic_vector(5 downto 0) := (others => '0');
signal vcursor      :   std_logic_vector(5 downto 0) := (others => '0');
signal hcursor_e    :   std_logic_vector(5 downto 0) := (others => '0');
signal vcursor_e    :   std_logic_vector(5 downto 0) := (others => '0');

-- PS2 Keyboard
signal ps2_ascii_s  :   std_logic_vector(7 downto 0);
signal keyb_valid   :   std_logic;
signal ps2_valid    :   std_logic;
signal ps2_ascii    :   std_logic_vector(7 downto 0);

-- UART Receiver signals
signal urx_valid    :   std_logic;
signal rx_valid     :   std_logic;
signal rx_byte      :   std_logic_vector(7 downto 0);

-- UART Transmitter signals
signal term_cw      :   std_logic;
signal tx_valid     :   std_logic;

-- Bell Sound
signal bell_state   :   std_logic;
signal bell_dur     :   std_logic_vector(22 downto 0);

-- Screen update control signals
type scn_machine is ( init, norm, srlread, srlwrite, srlblank, ansi_code_ctrl, ansi_code_par_1, ansi_code_action, ansi_code_cls, ansi_code_par_2, ansi_code_poscur_H, ansi_code_poscur );
signal scn_state    :	scn_machine := init;

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
        mode => mode,
        edit => edit,
        dataascii => dataascii_v,
        hcur_pos => hcursor,
        vcur_pos => vcursor,
        hcur_pos_e => hcursor_e,
        vcur_pos_e => vcursor_e,
        addrascii => addrascii_v,
        txtcol => txtcol,
        bckcol => bckcol,
        brdcol => brdcol,
        curonoff => curonoff,
        curflash => curflash,
        curtype => curtype,
        nCSync => nCSync,
		nVSync => nVSync,
        R => R,
        G => G,
		B => B
	);	

uartrx: entity work.UART_RX port map
    (
    clk         => clk,
    rx_bit_i    => rxd,
    rx_valid_o  => urx_valid,
    rx_byte_o   => rx_byte
    );

--- CHANGE SO THAT THE CPU CONTROLS TRANMISSION OF THE DATA AND USES XON/XOFF ---
uarttx: entity work.UART_TX port map
    (
    clk         => clk,
    tx_valid_i  => term_cw,
    tx_byte_i   => cpu_do,
    tx_bit_o    => txd,
    tx_valid_o  => tx_valid
    );

-- CPU Writing to terminal screen
cpu_w_term <= '1' when cpu_addr = x"bfe4" and cpu_nwr = '0' and enable = '1' else '0';
term_cw <= cpu_w_term;


-- Write to screen and manage scrolling
process(clk)
begin
	if rising_edge(clk) then
		if reset_n = '0' then
            scrn_width <= "111111"; -- 0 to 63
            scrn_height <= "100111"; -- 0 to 39
            scrn_chars <= scrn_height & scrn_width;
            scn_state <= init;
            txtcol <= "000"; -- Character colour black
            bckcol <= "111"; -- Background colour white
            brdcol <= "101"; -- Border colour cyan
            curonoff <= '1'; -- Cursor state on
            curflash <= '1'; -- Cursor flashing
            curtype <= '1';  -- Cursor type underline
            mode <= '1';     -- Screen mode 64 x 40
            edit <= '0';     -- Edit mode off
            keyb_valid <= '0';
            rx_valid <= '0';
            led <= "010101";
            trm_int <= '0';
            keyb_int <= '1';
            uart_int <= '1';
            timer_int <= '1';
            timer_valid <= '0';
            trm_timer_l <= x"6b";
            trm_timer_h <= x"7a"; -- Default to 100hz timer -- 31339 decimal (CPU clock speed / 100 = 31339)
            timer <= trm_timer_h & trm_timer_l;
            cpu_fc_reset <= '1';
        else
            -- Count CPU ticks
            if cpu_fc_reset = '1' then
                cpu_fcounter <= (others => '0');
                cpu_fc_reset <= '0';
            elsif enable = '1' then
                cpu_fcounter <= cpu_fcounter + 1;
            end if;
            if mode = '0' then
                scrn_width <= "011111";  -- 0 to 31
                scrn_height <= "010011"; -- 0 to 19
                scrn_chars <= scrn_height & scrn_width;
            else
                scrn_width <= "111111";  -- 0 to 63
                scrn_height <= "100111"; -- 0 to 39
                scrn_chars <= scrn_height & scrn_width;
            end if;

            --------------------
            -- Screen control --
            --------------------
            case scn_state is
                when init =>
                    -- Initialise (clear) screen after reset
                    term_busy <= '1';
                    addrascii_c <= cpu_fcounter(11 downto 0);
                    dataascii_in <= x"20";
                    ascii_r_w <= '1';
                    hcursor <= "000000";
                    vcursor <= "000000";
                    hcursor_e <= hcursor;
                    vcursor_e <= vcursor;
                    scnpos <= "0000" & x"40";
                    if cpu_fcounter = scrn_chars then -- Clear all characters from the screen
                        scn_state <= norm;
                    end if;
                -- Screen in normal none scroll state
                when norm =>
                    term_busy <= '0';
                    if cpu_w_term = '1' then -- CPU writing to screen with valid character
                        ascii_r_w <= '1';
                        if cpu_do = x"1b" then -- Escape sequence so process ANSI code
                            cpu_fc_reset <= '1';
                            scn_state <= ansi_code_ctrl;
                        elsif cpu_do = x"07" then -- Make bell sound
                            bell_state <= '1';
                        elsif cpu_do = x"08" or cpu_do = x"7f" then -- Backspace and delete character (7f) or move cursor left (08)
                            if hcursor /= 0 or vcursor /= 0 then
                                if cpu_do = x"7f" then
                                    dataascii_in <= x"20";
                                end if;
                                hcursor <= hcursor - 1;
                                if cpu_do = x"7f" then
                                    addrascii_c <= vcursor & hcursor - 1;
                                end if;
                                if hcursor = 0 then
                                    if mode = '0' then -- Need to reduce hcursor by extra 32 chars every row in mode 32 x 20 as memory layout also covers 64 x 40 mode
                                        hcursor <= hcursor - 33;
                                        if cpu_do = x"7f" then
                                            addrascii_c <= vcursor & hcursor - 33;
                                        end if;
                                    end if;
                                    vcursor <= vcursor - 1;
                                end if;
                            end if;
                        elsif cpu_do = x"09" then -- Forward main cursor one character
                            hcursor <= hcursor + 1;
                            if hcursor = scrn_width then
                                hcursor <= "000000";
                                if vcursor /= scrn_height then
                                    vcursor <= vcursor + 1;
                                else
                                    scn_state <= srlread;
                                end if;
                            end if;
                        elsif cpu_do = x"0a" then -- Move main cursor down one line
                            if vcursor /= scrn_height then
                                vcursor <= vcursor + 1;
                            else
                                scn_state <= srlread;
                            end if;
                        elsif cpu_do = x"0b" then -- Move main cursor up one line
                            if vcursor /= 0 then
                                vcursor <= vcursor - 1;
                            end if;
                        elsif cpu_do = x"0c" then -- Clear screen
                            cpu_fc_reset <= '1';
                            scn_state <= ansi_code_cls;
                        elsif cpu_do = x"0d" then -- Carriage Return ascii code
                            hcursor <= "000000";
                        elsif cpu_do /= x"ff" then -- Any other valid ascii code
                            dataascii_in <= cpu_do;
                            hcursor <= hcursor + 1;
                            addrascii_c <= vcursor & hcursor;
                            if hcursor = scrn_width then
                                hcursor <= "000000";
                                if vcursor /= scrn_height then
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
                    if scnpos <= scrn_chars + 1 then
                        ascii_r_w <= '0';
                        addrascii_c <= scnpos;
                        scnchar <= dataascii_out;
                        scn_state <= srlwrite;
                    end if;
                when srlwrite =>
                    -- Write character to row above where it was read
                    if scnpos <= scrn_chars + 1 then
                        if scnpos = scrn_chars + 1 then
                            scn_state <= srlblank;
                        else
                            scn_state <= srlread;
                        end if;
                        ascii_r_w <= '1';
                        addrascii_c <= (scnpos - 65);
                        dataascii_in <= scnchar;
                        if scnpos(5) = '1' and mode = '0' then -- Skip bit 5 (32 chars) every row in mode 32 x 20 as memory layout also covers 64 x 40 mode
                            scnpos(11 downto 5) <= (scnpos(11 downto 6) + 1) & '0';
                        else
                            scnpos <= scnpos + 1;
                        end if;
                    end if;
                when srlblank =>
                    -- Blank bottom line after scroll
                    if addrascii_c <= scrn_chars then
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
                -- NEED TO CHANGE SO IT WORKS WITH BBC VDU CODES AND ANSI CODES -- PRINT TAB IS SAME AS VDU CODES --
                -- BBC positions cursor with VDU 31,X,Y or PRINT TAB(X,Y)
                when ansi_code_ctrl =>
                    -- Wait for ANSI code "[" -- Start of control sequence
                    if cpu_w_term = '1'  then
                        if cpu_do = x"5b" then
                            scn_state <= ansi_code_par_1;
                        else
                            scn_state <= norm;
                        end if;
                    end if;
                when ansi_code_par_1 =>
                    -- Wait for ANSI parameter value 1
                    if cpu_w_term = '1' then
                        if cpu_do >= 0 and cpu_do <= scrn_height then -- Get screen row or clear screen
                            ansi_par1 <= cpu_do(5 downto 0);
                            scn_state <= ansi_code_action;
                        else
                            scn_state <= norm;
                        end if;
                    end if;
                when ansi_code_action =>
                    -- Wait for ANSI action code
                    if cpu_w_term = '1' then
                        if cpu_do = x"4a" then -- "J" = Clear Screen
                            scn_state <= ansi_code_cls;
                        elsif cpu_do = x"3b" then -- ";" = Position cursor
                            scn_state <= ansi_code_par_2;
                        else
                            scn_state <= norm;
                        end if;
                    end if;
                when ansi_code_cls =>
                    -- Clear screen
                    term_busy <= '1';
                    addrascii_c <= cpu_fcounter(11 downto 0);
                    dataascii_in <= x"20";
                    ascii_r_w <= '1';
                    hcursor <= "000000";
                    vcursor <= "000000";
                    scnpos <= "0000" & x"40";
                    if cpu_fcounter = scrn_chars then -- Clear all characters from the screen
                        scn_state <= norm;
                    end if;
                when ansi_code_par_2 =>
                    -- Wait for ANSI parameter value 2
                    if cpu_w_term = '1' then
                        if cpu_do >= 0 and cpu_do <= scrn_width then -- Get screen column
                            ansi_par2 <= cpu_do(5 downto 0);
                            scn_state <= ansi_code_poscur_H;
                        else
                            scn_state <= norm;
                        end if;
                    end if;
                when ansi_code_poscur_H =>
                    -- Wait for ANSI code H -- Final position cursor value
                    if cpu_w_term = '1' then
                        if cpu_do = x"48" then
                            scn_state <= ansi_code_poscur;
                        else
                            scn_state <= norm;
                        end if;
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

            -------------------------------
            -- Terminal Status & Control --
            -------------------------------
            -- Set screen attributes and cursor state
            -- CPU Writes
            if cpu_nwr = '0' and enable = '1' then
                if cpu_addr = x"bfee" then    -- CPU write to Edit Mode Vertical Cursor Position
                    if cpu_do >= 0 and cpu_do <= scrn_height then -- Keep within screen boundary
                        vcursor_e <= cpu_do(5 downto 0);
                    end if;
                elsif cpu_addr = x"bfed" then -- CPU write to Edit Mode Horizontal Cursor Position
                    if cpu_do >= 0 and cpu_do <= scrn_width then -- Keep within screen boundary
                        hcursor_e <= cpu_do(5 downto 0);
                    end if;
                elsif cpu_addr = x"bfec" then -- CPU write to timer latch high byte
                    trm_timer_h <= cpu_do;
                elsif cpu_addr = x"bfeb" then -- CPU write to timer latch low byte
                    trm_timer_l <= cpu_do;              
                elsif cpu_addr = x"bfea" then -- CPU write to LED control port
                    led <= not cpu_do(5 downto 0);
                elsif cpu_addr = x"bfe9" then -- CPU write to border colour
                    brdcol <= cpu_do(2 downto 0);
                elsif cpu_addr = x"bfe8" then -- CPU write to background colour
                    bckcol <= cpu_do(2 downto 0);
                elsif cpu_addr = x"bfe7" then -- CPU write to foreground colour
                    txtcol <= cpu_do(2 downto 0);
                elsif cpu_addr = x"bfe3" then -- CPU write to Interrupt Enable Register
                    keyb_int <= cpu_do(0);
                    uart_int <= cpu_do(1);
                    timer_int <= cpu_do(2);
                elsif cpu_addr = x"bfe1" then -- CPU write to Terminal Control Register
                    curonoff <= cpu_do(0);
                    curflash <= cpu_do(1);
                    curtype <= cpu_do(2);
                    edit <= cpu_do(5);
                    -- Change mode then clear screen
                    if mode /= cpu_do(3) then
                        mode <= cpu_do(3);
                        cpu_fc_reset <= '1';
                        scn_state <= ansi_code_cls;
                    end if;
                    -- Clear screen
                    if cpu_do(4) = '1' then
                        cpu_fc_reset <= '1';
                        scn_state <= ansi_code_cls;
                    end if;
                end if;
            elsif cpu_nwr = '1' then
            -- CPU Reads
                trm_enable <= '1';            -- Set terminal enable when CPU reading from it
                if cpu_addr = x"bff1" then    -- CPU read ASCII value of character at editor cursor position
                    ascii_r_w <= '0';
                    if addrascii_c /= vcursor_e & hcursor_e then
                        addrascii_c <= vcursor_e & hcursor_e; -- Set address to editor cursor position
                        trm_do <= dataascii_out; -- Character read within 1 cycle
                    else
                        addrascii_c <= vcursor & hcursor; -- and then straight back to main cursor position after 1 cycle
                    end if;
                elsif cpu_addr = x"bff0" then -- CPU read Main Vertical Cursor Position
                    trm_do <= "00" & vcursor;
                elsif cpu_addr = x"bfef" then -- CPU read Main Horizontal Cursor Position
                    trm_do <= "00" & hcursor;
                elsif cpu_addr = x"bfee" then -- CPU read Edit Mode Vertical Cursor Position
                    trm_do <= "00" & vcursor_e;
                elsif cpu_addr = x"bfed" then -- CPU read Edit Mode Horizontal Cursor Position
                    trm_do <= "00" & hcursor_e;
                elsif cpu_addr = x"bfe6" then -- CPU read ascii value over UART of key pressed
                    trm_do <= rx_byte;
                elsif cpu_addr = x"bfe5" then -- CPU read ascii value of key pressed
                    trm_do <= ps2_ascii;
                elsif cpu_addr = x"bfe2" then -- CPU read Timer, UART & keyboard status from Interrupt Status Register
                    trm_do <= trm_int & "0000" & timer_valid & rx_valid & keyb_valid;
                elsif cpu_addr = x"bfe1" then -- CPU read Terminal Control Register
                    trm_do <= "00" & edit & "0" & mode & curtype & curflash & curonoff;
                elsif cpu_addr = x"bfe0" then -- CPU read Terminal Status Register
                    trm_do <= "0000000" & term_busy;
                else
                    trm_do <= x"ff";
                    trm_enable <= '0';
                end if;
            end if;
            -- Set overall interrupt status
            trm_int <= keyb_valid or rx_valid or timer_valid;

            -- Below are dependant on either read or write state of CPU and hence are not included in above statement
            -- Process key pressed status
            if ps2_valid = '1' and ps2_ascii /= x"ff" then
                keyb_valid <= '1';
            elsif cpu_addr = x"bfe5" and cpu_nwr = '1' then -- CPU reads key so clear state
                keyb_valid <= '0';
            end if;
            -- Process UART byte received status
            if urx_valid = '1' then
                rx_valid <= '1';
            elsif cpu_addr = x"bfe6" and cpu_nwr = '1' then -- CPU reads UART byte so clear state
                rx_valid <= '0';
            end if;
            -- Process timer crossing zero
            if enable = '1' then
                timer <= timer - 1;
                if timer = 0 then
                    timer <= trm_timer_h & trm_timer_l; -- Reload timer
                    timer_valid <= '1';
                elsif cpu_addr = x"bfe2" and cpu_do(2) = '0' and cpu_nwr = '0' then -- CPU writes to ISR timer status bit so clear timer interrupt
                    timer_valid <= '0';
                end if;
            end if;
           -- Set overall interrupt status
            trm_int <= keyb_valid or rx_valid or timer_valid;
            -- Make bell sound
            if bell_state = '1' then
                if (bell_dur(bell_dur'high) = '1') then
                    bell_state <= '0';
                    bell_dur <= (others => '0');
                else
                    bell_dur <= bell_dur + 1;
                end if;
                if bell_dur(15) = '1' then -- Controls frequency of bell sound
                    sndl <= not sndl;
                    sndr <= not sndr;
                end if;
            end if;
        end if;
    end if;
end process;

trm_nmi <= '0' when timer_valid = '1' and timer_int = '1' else '1';

trm_irq <= '0' when (keyb_valid = '1' and keyb_int = '1') or 
                    (rx_valid = '1' and uart_int = '1')
                     else '1'; -- Interrupt CPU when byte received from keyboard or UART

end rtl;