--------------------------------------------------------------
-- Engineer: A Burgess                                      --
--                                                          --
-- Design Name: Basic Computer System - Uses ASCII Terminal --
--                                                          --
-- Started October 2024                                     --
--------------------------------------------------------------

-- Design for the TANG Nano 20K installed in the BeebFPGA Dock board

----------------
-- Memory Map --
----------------
-- 0000 to 3FFF RAM 16K
-- 4000 to 41FF WOZMON 512 Bytes
-- 4200 to 7FFF Unallocated
-- 8000 to BFDF BBC BASIC
-- BFE0 to BFFF I/O
-- C000 to FFFF ROM 16K - MOS

-- I/O ports within memory map

-- BFE0 - Terminal Status Register (trm_status)
-- 76543210
-- ||||||||___________ Terminal Busy Status (0 = not busy, 1 = busy)
-- |||||||____________ Not Used
-- ||||||_____________ Not Used
-- |||||______________ Not Used
-- ||||_______________ Not Used
-- |||________________ Not Used
-- ||_________________ Not Used
-- |__________________ Not Used

-- BFE1 - Terminal Control Register (trm_ctrl)
-- 76543210
-- ||||||||___________ Set Cursor On/Off State (0 = off, 1 = on)
-- |||||||____________ Set Cursor Flashing State (0 = no flash, 1 = flash)
-- ||||||_____________ Set Cursor Underline or Block (0 = block, 1 = underline)
-- |||||______________ Set Screen Mode (0 = 32 x 20, 1 = 64 x 40)
-- ||||_______________ Clear Screen - Writing a 1 will clear the screen
-- |||________________ Edit Mode on/off
-- ||_________________ Not Used
-- |__________________ Not Used

-- BFE2 - Interrupt Status Register (int_status)
-- 76543210
-- ||||||||___________ Key Pressed (0 = no, 1 = yes)
-- |||||||____________ Byte Received From UART (0 = no, 1 = yes)
-- ||||||_____________ Timer Crossing Zero (0 = no, 1 = yes)
-- |||||______________ Not Used
-- ||||_______________ Not Used
-- |||________________ Not Used
-- ||_________________ Not Used
-- |__________________ Terminal Interrupt Status (0 = no interrupt from the terminal, 1 = the terminal generated an interrupt)

-- BFE3 - Interrupt Control Register (int_ctrl)
-- 76543210
-- ||||||||___________ Enable/Disable Keyboard Interrupts (0 = disable, 1 = enable)
-- |||||||____________ Enable/Disable UART Byte Received Interrupts (0 = disable, 1 = enable)
-- ||||||_____________ Enable/Disable Timer Interrupts on Crossing Zero (0 = disable, 1 = enable)
-- |||||______________ Not Used
-- ||||_______________ Not Used
-- |||________________ Not Used
-- ||_________________ Not Used
-- |__________________ Not Used

-- BFE4 (wr_trm)       Send byte to terminal
-- BFE5 (re_key)       Read ASCII value of key pressed
-- BFE6 (re_uart)      Read ASCII value available over the UART interface (115200,8,1,N)
-- BFE7 (for_col)      Set foreground colour (0 = Black, 1 = Blue, 2 = Red, 3 = Magenta, 4 = Green, 5 = Cyan, 6 = Yellow, 7 = White, 8+ reserved)
-- BFE8 (bck_col)      Set background colour
-- BFE9 (bor_col)      Set border colour
-- BFEA (led)          Write to LED control port
-- BFEB (timer1_l)     Write to timer latch low byte
-- BFEC (timer1_h)     Write to timer latch high byte
-- BFED (edt_hcursor)  Read/Write Editor Horizontal Cursor Position
-- BFEE (edt_vcursor)  Read/Write Editor Vertical Cursor Position
-- BFEF (m_hcursor)    Read Main Horizontal Cursor Position
-- BFF0 (m_vcursor)    Read Main Vertical Cursor Position
-- BFF1 (r_ecursor)    Read ASCII value of character at Edit cursor position

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity comp_top is
    Port ( clk27    : in    std_logic;
        irq         : out   std_logic;
        btn1        : in    std_logic;
        btn2        : in    std_logic;
        ps2_clk     : inout	std_logic;
        ps2_data    : inout	std_logic;
        rxd         : in    std_logic;
        txd         : out   std_logic;
        sndl        : out   std_logic;
        sndr        : out   std_logic;
        nCSync		: out   std_logic;
        nVSync		: out   std_logic;
        R			: out   std_logic;
        G			: out   std_logic;
        B			: out   std_logic;
        led         : out   std_logic_vector(5 downto 0)
		);			  
end comp_top;

architecture rtl of comp_top is

-------------
-- Signals --
-------------

-- Main Clocks
signal clk100       :   std_logic;
signal clk25        :   std_logic;
signal cpu_clken    :   std_logic;
signal crg_clken    :   std_logic;
signal clken_counter:	std_logic_vector(15 downto 0);

-- Main Reset
signal reset_n      :   std_logic := '0';
signal reset_counter:   std_logic_vector(18 downto 0) := (others => '0');

-- Memory Signals
--signal rom_data   :	std_logic_vector(7 downto 0);
signal mosrom_data  :	std_logic_vector(7 downto 0);
signal basicrom_data:	std_logic_vector(7 downto 0);
signal wozrom_data  :	std_logic_vector(7 downto 0);
signal ram_data     :	std_logic_vector(7 downto 0);
--signal rom_enable   :   std_logic;
signal mosrom_enable   :   std_logic;
signal basicrom_enable :   std_logic;
signal wozrom_enable:   std_logic;
signal ram_enable   :   std_logic;
signal ram_rw       :   std_logic;

-- CPU Signals
signal cpu_mode     :	std_logic_vector(1 downto 0);
signal cpu_ready    :	std_logic;
signal cpu_irq_n    :	std_logic;
signal cpu_nmi_n    :	std_logic;
signal cpu_so_n     :	std_logic;
signal cpu_nwr      :	std_logic;
signal cpu_sync     :	std_logic;
signal cpu_ef       :	std_logic;
signal cpu_mf       :	std_logic;
signal cpu_xf       :	std_logic;
signal cpu_ml_n     :	std_logic;
signal cpu_vp_n     :	std_logic;
signal cpu_vda      :	std_logic;
signal cpu_vpa      :	std_logic;
signal cpu_addr     :	std_logic_vector(23 downto 0);
signal cpu_di       :	std_logic_vector(7 downto 0);
signal cpu_do       :	std_logic_vector(7 downto 0);
signal cpu_do_us    :   unsigned(7 downto 0);
signal cpu_addr_us  :   unsigned(15 downto 0);

-- Terminal Status/Control Signals
signal keyb_valid   :   std_logic;
signal keyb_int     :   std_logic;
signal rx_valid     :   std_logic;
signal uart_int     :   std_logic;
signal timer_valid  :   std_logic;
signal timer_int    :   std_logic;
signal trm_do       :   std_logic_vector(7 downto 0);
signal trm_nmi      :   std_logic;
signal trm_irq      :   std_logic;
signal trm_enable   :   std_logic;

-- Buttons
signal btn1_db      :   std_logic;
signal btn2_db      :   std_logic;

begin

-- Clocks

clk1: entity work.Gowin_rPLL
    port map (
        clkout => clk100, -- 100.286 Mhz
        clkin => clk27
    );

clk2: entity work.Gowin_CLKDIV
    port map (
        clkout => clk25,  -- 100.286/4 = 25.0715 Mhz (VGA pixel clock is 25.125 Mhz)
        hclkin => clk100,
        resetn => '1'
    );

-- 25Mhz master clock
process(clk25)
begin
    if rising_edge(clk25) then
		clken_counter <= clken_counter + 1;
    end if;
end process;

cpu_clken <= '1' when clken_counter(2 downto 0) = "111" else '0'; -- 3.1339 Mhz CPU clock speed
crg_clken <= '1'; -- Must be close to 25.125 Mhz for screen pixel clock and timings

-- MOS ROM 16K
mosrom: entity work.mosrom port map
    (
        clk => clk25,
        addr => cpu_addr(13 downto 0),
        data => mosrom_data
    );
	 
-- BASIC ROM 16K
basicrom: entity work.basicrom port map
    (
        clk => clk25,
        addr => cpu_addr(13 downto 0),
        data => basicrom_data
    );

-- WOZ ROM 512 Bytes
wozrom: entity work.wozrom port map
    (
        clk => clk25,
        addr => cpu_addr(8 downto 0),
        data => wozrom_data
    );
	 
-- Main system RAM 16K
ram: entity work.ram port map
    (
        clk => clk25,
        we => ram_rw,
        addr => cpu_addr(13 downto 0),
        datain => cpu_do,
        dataout => ram_data
    );

-- 65C02 CPU
cpu: entity work.r65c02 port map
    (
        reset    => reset_n and not btn1_db,
        clk      => clk25,
        enable   => cpu_clken,
        nmi_n    => cpu_nmi_n,
        irq_n    => cpu_irq_n,
        di       => unsigned(cpu_di),
        do       => cpu_do_us,
        addr     => cpu_addr_us,
        nwe      => cpu_nwr,
        sync     => cpu_sync,
        sync_irq => open,
        Regs     => open
    );
cpu_do <= std_logic_vector(cpu_do_us);
cpu_addr(15 downto 0) <= std_logic_vector(cpu_addr_us);
cpu_addr(23 downto 16) <= (others => '0');

-- Timer produces NMI interrupt when crossing zero
cpu_nmi_n <= trm_nmi;

-- Keyboard and UART interrupts CPU if enabled
cpu_irq_n <= trm_irq;

irq <= trm_nmi; -- Show NMI externally for testing

debounce1: entity work.debounce port map
    (
        clk         => clk25,
        btn_in      => btn1,
        btn_out     => btn1_db
	);			  

debounce2: entity work.debounce port map
    (
        clk         => clk25,
        btn_in      => btn2,
        btn_out     => btn2_db
	);			  

terminal: entity work.ascii_term port map
    (
        clk         => clk25,
        reset_n     => reset_n,
        trm_do      => trm_do,
        trm_nmi     => trm_nmi,
        trm_irq     => trm_irq,
        trm_enable  => trm_enable,
        cpu_addr    => cpu_addr(15 downto 0),
        cpu_do      => cpu_do,
        cpu_nwr     => cpu_nwr,
        enable      => cpu_clken,
        crg_clken   => crg_clken,
        rxd         => rxd,
        txd         => txd,
        led         => led,
        sndl        => sndl,
        sndr        => sndr,
        ps2_clk     => ps2_clk,
        ps2_data    => ps2_data,
        nCSync      => nCSync,
		nVSync      => nVSync,
        R           => R,
        G           => G,
		B           => B
	);			  

mosrom_enable <= '1' when cpu_addr(15 downto 14) = "11" and cpu_nwr = '1' else '0'; -- MOS 16K ROM (C000 - FFFF)
basicrom_enable <= '1' when (cpu_addr >= x"8000" and cpu_addr <= x"BFDF") and cpu_nwr = '1' else '0'; -- BBC BASIC 16K ROM (8000-BFDF)
wozrom_enable <= '1' when cpu_addr(15 downto 9) = "0100000" and cpu_nwr = '1' else '0'; -- WOZROM 512 Bytes ROM (4000 - 41FF)
ram_enable <= '1' when cpu_addr(15 downto 14) = "00" else '0'; -- 16K RAM (0000 - 3FFF)
ram_rw <= '1' when ram_enable = '1' and cpu_nwr = '0' and cpu_clken = '1' else '0';

-- CPU Read
cpu_di <= trm_do when trm_enable = '1' else -- CPU reading from the Terminal
          mosrom_data when mosrom_enable = '1' else
          basicrom_data when basicrom_enable = '1' else
		  wozrom_data when wozrom_enable = '1' else
          ram_data when ram_enable = '1' and cpu_nwr = '1' else
          x"ff";

-- Reset
process(clk25)
begin
    if rising_edge(clk25) then
        if (reset_counter(reset_counter'high) = '0') then
            reset_counter <= reset_counter + 1;
        end if;
        reset_n <= reset_counter(reset_counter'high) and not btn2_db;
    end if;
end process;


end rtl;