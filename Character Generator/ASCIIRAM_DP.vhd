library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity asciiram_dp is
    port (
        clka  : in  std_logic;
        wea  : in  std_logic;
        addra : in  std_logic_vector(9 downto 0);
        dataina : in std_logic_vector(7 downto 0);
        dataouta : out std_logic_vector(7 downto 0);
        clkb  : in  std_logic;
        web  : in  std_logic;
        addrb : in  std_logic_vector(9 downto 0);
        datainb : in std_logic_vector(7 downto 0);
        dataoutb : out std_logic_vector(7 downto 0)
        );
end;

architecture behavioral of asciiram_dp is

    type ram_type is array (0 to 767) of std_logic_vector (7 downto 0);
    shared variable RAM : ram_type := (others => "00100000"); -- Fill with spaces, ASCII 32

begin

    process (clka)
    begin
        if rising_edge(clka) then
            if (wea = '1') then
					RAM(conv_integer(addra)) := dataina;
            end if;
            dataouta <= RAM(conv_integer(addra));
        end if;
    end process;

    process (clkb)
    begin
        if rising_edge(clkb) then
            if (web = '1') then
                RAM(conv_integer(addrb)) := datainb;
            end if;
            dataoutb <= RAM(conv_integer(addrb));
        end if;
    end process;

end behavioral;