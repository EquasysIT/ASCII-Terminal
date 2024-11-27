--------------------------------------------------------------
-- Engineer: A Burgess                                      --
--                                                          --
-- Design Name: Basic Computer System - Uses ASCII Terminal --
--                                                          --
-- October 2024                                             --
--------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity comp_top is
    Port ( clk27		: in   std_logic;
           btn1         : in   std_logic;
           btn2         : in   std_logic;
           ps2_clk      : inout	std_logic;
           ps2_data     : inout	std_logic;
           nCSync		: out  std_logic;
		   nVSync		: out  std_logic;
           R			: out  std_logic;
           G			: out  std_logic;
		   B			: out  std_logic;
           led          : out  std_logic_vector(5 downto 0)
		);			  
end comp_top;

architecture behavioral of comp_top is

-------------
-- Signals --
-------------

-- Main Clocks
signal clk140       :   std_logic;
signal clk28        :   std_logic;
signal cpu_clken    :   std_logic;
signal clken_counter:	std_logic_vector(4 downto 0);

-- Main Reset
signal reset_n      :   std_logic := '0';
signal reset_counter:   std_logic_vector(20 downto 0) := (others => '0');

-- Memory Signals
signal rom_data     :	std_logic_vector(7 downto 0);
signal ram_data     :	std_logic_vector(7 downto 0);
signal rom_enable   :   std_logic;
signal ram_enable   :   std_logic;
signal ram_rw       :   std_logic;

-- CPU Signals
signal cpu_mode     :	std_logic_vector(1 downto 0);
signal cpu_ready    :	std_logic;
signal cpu_abort_n  :   std_logic;
signal cpu_irq_n    :	std_logic;
signal cpu_nmi_n    :	std_logic;
signal cpu_so_n     :	std_logic;
signal cpu_r_nw     :	std_logic;
signal cpu_sync     :	std_logic;
signal cpu_ef       :	std_logic;
signal cpu_mf       :	std_logic;
signal cpu_xf       :	std_logic;
signal cpu_ml_n     :	std_logic;
signal cpu_vp_n     :	std_logic;
signal cpu_vda      :	std_logic;
signal cpu_vpa      :	std_logic;
signal cpu_a        :	std_logic_vector(23 downto 0);
signal cpu_di       :	std_logic_vector(7 downto 0);
signal cpu_do       :	std_logic_vector(7 downto 0);
signal cpu_do_us    :	unsigned(7 downto 0);
signal cpu_a_us     :	unsigned(15 downto 0);

-- Character Generator Clock Enable
signal crg_clken    :   std_logic;

-- PS2 Keyboard
signal keyb_valid   :   std_logic;
signal ps2_ascii    :   std_logic_vector(7 downto 0);


begin

-- Clocks

U1: entity work.Gowin_rPLL
    port map (
        clkout => clk140,
        clkin => clk27
    );

U2: entity work.Gowin_CLKDIV
    port map (
        clkout => clk28,
        hclkin => clk140,
        resetn => '1'
    );
	
-- 28Mhz master clock
process(clk28)
begin
    if rising_edge(clk28) then
		clken_counter <= clken_counter + 1;
    end if;
end process;

cpu_clken <= clken_counter(0) and clken_counter(1) and clken_counter(2) and clken_counter(3); -- 1.75 Mhz
crg_clken <= clken_counter(0) and clken_counter(1); -- Must be 7 Mhz for screen pixel clock and timings

-- Main system ROM
U3: entity work.ROM port map
    (
        clk => clk28,
        addr => cpu_a(13 downto 0),
        data => rom_data
    );

-- Main system RAM
U4: entity work.RAM port map
    (
        clk => clk28,
        we => ram_rw,
        addr => cpu_a(13 downto 0),
        datain => cpu_do,
        dataout => ram_data
    );

-- 65C02 CPU
U5: entity work.r65c02 port map
    (
        reset    => reset_n and btn1,
        clk      => clk28,
        enable   => cpu_clken,
        nmi_n    => cpu_nmi_n,
        irq_n    => cpu_irq_n,
        di       => unsigned(cpu_di),
        do       => cpu_do_us,
        addr     => cpu_a_us,
        nwe      => cpu_r_nw,
        sync     => cpu_sync,
        sync_irq => open,
        Regs     => open
    );
cpu_do <= std_logic_vector(cpu_do_us);
cpu_a(15 downto 0) <= std_logic_vector(cpu_a_us);
cpu_a(23 downto 16) <= (others => '0');
-- Tie unused interrupts high
cpu_nmi_n <= '1';
cpu_irq_n <= '1';

U6: entity work.ascii_term port map
    (
        clk         => clk28,
        reset_n     => reset_n,
        cpu_a       => cpu_a(15 downto 0),
        cpu_do      => cpu_do,
        cpu_r_nw    => cpu_r_nw,
        enable      => cpu_clken,
        crg_clken   => crg_clken,
        keyb_valid  => keyb_valid,
        ps2_ascii   => ps2_ascii,
        ps2_clk     => ps2_clk,
        ps2_data    => ps2_data,
        nCSync      => nCSync,
		nVSync      => nVSync,
        R           => R,
        G           => G,
		B           => B
	);			  

rom_enable <= '1' when cpu_a(15) = '1' and cpu_a(14) = '1' and cpu_r_nw = '1' and cpu_a /= x"fce0" and cpu_a /= x"fce1" and cpu_a /= x"ffe0" else '0';
ram_enable <= '1' when cpu_a(15) = '0' and cpu_a(14) = '0' else '0';
ram_rw <= '1' when ram_enable = '1' and cpu_r_nw = '0' and cpu_clken = '1' else '0';

cpu_di <= "0000000" & keyb_valid when cpu_a = x"fce1" and cpu_r_nw = '1' else -- CPU read keyboard status
          ps2_ascii when cpu_a = x"fce0" and cpu_r_nw = '1' else -- CPU read ascii value of key pressed
          rom_data when rom_enable = '1' else
          ram_data when ram_enable = '1' else
          x"ff";


-- Reset
process(clk28)
begin
    if rising_edge(clk28) then
        if (reset_counter(reset_counter'high) = '0') then
            reset_counter <= reset_counter + 1;
        end if;
        reset_n <= reset_counter(reset_counter'high) and btn2;
    end if;
end process;

led <= "011111" when reset_n = '0' else "111111";

end behavioral;