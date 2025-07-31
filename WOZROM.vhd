--------------------------------------------------------------
-- Engineer: A Burgess                                      --
--                                                          --
-- Design Name: Basic Computer System - WOZROM              --
--                                                          --
-- October 2024                                             --
--------------------------------------------------------------


-- NEEDS UPDATING TO USE NEW REGISTERS

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity wozrom is
	port (
		clk		: in    std_logic;
		addr	: in    std_logic_vector(8 downto 0);
		data	: out   std_logic_vector(7 downto 0)
	);
end;

architecture rtl of wozrom is
	type romdata is array(0 to 271) of std_logic_vector(7 downto 0);
	constant rom : romdata := (
		x"78",x"A0",x"7F",x"C9",x"7F",x"F0",x"18",x"C9", -- 0x0000
		x"1B",x"F0",x"03",x"C8",x"10",x"14",x"A9",x"5C", -- 0x0008
		x"20",x"FD",x"80",x"A9",x"0D",x"20",x"FD",x"80", -- 0x0010
		x"A9",x"0A",x"20",x"FD",x"80",x"A0",x"01",x"88", -- 0x0018
		x"30",x"F1",x"AD",x"EA",x"BF",x"29",x"01",x"F0", -- 0x0020
		x"06",x"AD",x"E9",x"BF",x"4C",x"39",x"80",x"AD", -- 0x0028
		x"EC",x"BF",x"29",x"01",x"F0",x"EC",x"AD",x"EB", -- 0x0030
		x"BF",x"99",x"00",x"02",x"20",x"FD",x"80",x"C9", -- 0x0038
		x"0D",x"D0",x"C0",x"A0",x"FF",x"A9",x"00",x"AA", -- 0x0040
		x"0A",x"0A",x"85",x"2B",x"C8",x"B9",x"00",x"02", -- 0x0048
		x"C9",x"0D",x"F0",x"BF",x"C9",x"2E",x"90",x"F4", -- 0x0050
		x"F0",x"EE",x"C9",x"3A",x"F0",x"EB",x"C9",x"52", -- 0x0058
		x"F0",x"3B",x"86",x"28",x"86",x"29",x"84",x"2A", -- 0x0060
		x"B9",x"00",x"02",x"49",x"30",x"C9",x"0A",x"90", -- 0x0068
		x"06",x"69",x"88",x"C9",x"FA",x"90",x"11",x"0A", -- 0x0070
		x"0A",x"0A",x"0A",x"A2",x"04",x"0A",x"26",x"28", -- 0x0078
		x"26",x"29",x"CA",x"D0",x"F8",x"C8",x"D0",x"E0", -- 0x0080
		x"C4",x"2A",x"F0",x"82",x"24",x"2B",x"50",x"10", -- 0x0088
		x"A5",x"28",x"81",x"26",x"E6",x"26",x"D0",x"B5", -- 0x0090
		x"E6",x"27",x"4C",x"4D",x"80",x"6C",x"24",x"00", -- 0x0098
		x"30",x"30",x"A2",x"02",x"B5",x"27",x"95",x"25", -- 0x00A0
		x"95",x"23",x"CA",x"D0",x"F7",x"D0",x"19",x"A9", -- 0x00A8
		x"0D",x"20",x"FD",x"80",x"A9",x"0A",x"20",x"FD", -- 0x00B0
		x"80",x"A5",x"25",x"20",x"EA",x"80",x"A5",x"24", -- 0x00B8
		x"20",x"EA",x"80",x"A9",x"3A",x"20",x"FD",x"80", -- 0x00C0
		x"A9",x"20",x"20",x"FD",x"80",x"A1",x"24",x"20", -- 0x00C8
		x"EA",x"80",x"86",x"2B",x"A5",x"24",x"C5",x"28", -- 0x00D0
		x"A5",x"25",x"E5",x"29",x"B0",x"BC",x"E6",x"24", -- 0x00D8
		x"D0",x"02",x"E6",x"25",x"A5",x"24",x"29",x"07", -- 0x00E0
		x"10",x"C3",x"48",x"4A",x"4A",x"4A",x"4A",x"20", -- 0x00E8
		x"F3",x"80",x"68",x"29",x"0F",x"09",x"30",x"C9", -- 0x00F0
		x"3A",x"90",x"02",x"69",x"06",x"48",x"AD",x"E1", -- 0x00F8
		x"BF",x"29",x"01",x"D0",x"F9",x"68",x"8D",x"E0", -- 0x0100
		x"BF",x"60",x"00",x"00",x"00",x"00",x"00",x"00"  -- 0x0108
	);
begin
	process(clk)
	begin
		if rising_edge(clk) then
			data <= rom(to_integer(unsigned(addr)));
		end if;
	end process;
end rtl;