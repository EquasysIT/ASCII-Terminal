--------------------------------------------------------------
-- Engineer: A Burgess                                      --
--                                                          --
-- Design Name: Character ROM Generator                     --
--                                                          --
-- October 2024                                             --
--------------------------------------------------------------

-- 640 x 480 Total Pixels
-- 512 x 320 Active Pixels due to border
-- 64 x 40 Character Resolution - Each character is 8 x 8 pixels

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity crg is
    Port ( clk 		   : in   std_logic;
           reset_n     : in   std_logic;
		   enable	   : in   std_logic;
           dataascii   : in   std_logic_vector(7 downto 0);
           hcur_pos    : in   std_logic_vector(5 downto 0);
           vcur_pos    : in   std_logic_vector(5 downto 0);
           addrascii   : out  std_logic_vector(11 downto 0);
           txtcol      : in   std_logic_vector(2 downto 0);
           bckcol      : in   std_logic_vector(2 downto 0);
           brdcol      : in   std_logic_vector(2 downto 0);
           curctrl     : in   std_logic;
           nCSync	   : out  std_logic;
		   nVSync	   : out  std_logic;
           R		   : out  std_logic;
           G		   : out  std_logic;
		   B		   : out  std_logic
		);
end crg;

architecture rtl of crg is

-------------
-- Signals
-------------


-- Screen pixel counters
signal hcounter     :   std_logic_vector(9 downto 0);
signal hcounter2    :   std_logic_vector(9 downto 0);
signal vcounter	    :   std_logic_vector(9 downto 0);

-- Screen character counters
signal hchar        :   std_logic_vector(5 downto 0);
signal vchar	    :   std_logic_vector(5 downto 0);

-- Cursor signals
signal cursor       :   std_logic_vector(7 downto 0);
signal flshcount    :   std_logic_vector(23 downto 0);

-- Screen timing signals
signal hblanking    :   std_logic;
signal vblanking    :   std_logic;
signal hborder      :   std_logic;
signal vborder      :   std_logic;
signal hsync        :   std_logic;
signal vsync        :   std_logic;
signal hgenvideo    :   std_logic;
signal vgenvideo    :   std_logic;
signal border       :   std_logic;
signal video        :   std_logic;

signal pixel        :   std_logic;
signal pixelreg	    :   std_logic_vector(7 downto 0);
signal red          :   std_logic;
signal green        :   std_logic;
signal blue         :   std_logic;

-- ASCII Character RAM to Character ROM pixel mappings
signal addrpixel    :   std_logic_vector(9 downto 0);
signal datapixel    :   std_logic_vector(7 downto 0);
signal dataascii32  :   std_logic_vector(7 downto 0);

Begin

U1 : entity work.pixelrom port map
    (
        clk  => clk,
        addr => addrpixel,
        data  => datapixel
    );

-- VGA Timing Counters
process(clk)
begin
    if rising_edge(clk) then
        if reset_n = '0' then
            hcounter <= (others => '0');
            vcounter <= (others => '0');
        elsif enable = '1' then
            if hcounter = 799 then
                hcounter <= (others => '0');
                if vcounter = 524 then 
                    vcounter <= (others => '0');
                else
                    vcounter <= vcounter + 1;
                end if;
            else
                hcounter <= hcounter + 1;
            end if;
        end if;
    end if;
end process;

-- VGA Timing Signals
process(clk)
begin
	if rising_edge(clk) then
		if enable = '1' then
            -- Horizontal signals       -- 800 Total
            if hcounter = 226 then      -- Length 512 (Border is 130, 66 left and 62 right)
                hgenvideo <= '1';       -- Left border is larger by 2 pixels to give time for first character to be read before output
            elsif hcounter = 738 then
                hgenvideo <= '0';
            end if;
			
            if hcounter = 0 then        -- Front Porch, Back Porch, HSync is within these timings - Length 160
                hblanking <= '0';
            elsif hcounter = 160 then
                hblanking <= '1';
            end if;

            if hcounter = 16 then       -- Length 96
                hsync <= '0';
            elsif hcounter = 112 then
                hsync <= '1';
            end if;

            -- Vertical signals         -- 525 Total
            if vcounter = 0 then        -- Length 320 (Border is therefore 160, 80 top and bottom)
                vgenvideo <= '1';
            elsif vcounter = 320 then
                vgenvideo <= '0';
            end if;

            if vcounter = 400 then      -- Front Porch, Back Porch, VSync is within these timings - Length 45
                vblanking <= '0';
            elsif vcounter = 445 then
                vblanking <= '1';
            end if;

            if vcounter = 410 then      -- Length 2
                vsync <= '0';
            elsif vcounter = 412 then
                vsync <= '1';
            end if;
		end if;
	end if;
end process;

process(clk)
begin
	if rising_edge(clk) then
		if enable = '1' then
            flshcount <= flshcount + 1;
		end if;
	end if;
end process;

-- Video output starts when hcounter is 224. We therefore subtract 224 to ensure hcounter2 starts at 0. hcounter2 feeds hchar which is the position of character output
-- It is 224 so that hsync is aligned with vsync on the last line and doesn't therefore affect the first line.
-- This prevents the first few pixels of the top left border from being black which would be due to vblanking being low
hcounter2 <= hcounter - 224; -- Must start on a "divide by 8" boundary

-- Get character at current pixel position on screen
-- Divide pixel counters by 8 to get character counters
hchar <= hcounter2(8 downto 3);
vchar <= vcounter(8 downto 3);

-- Pixel ROM address decoding
-- Subtract 32 from dataascii to create signal which enables easier pixelrom address decoding
dataascii32 <= dataascii - 32;
addrascii <= vchar & hchar;
addrpixel <= dataascii32(6 downto 5) & vcounter(2 downto 0) & dataascii(4 downto 0);

-- Hardware Cursor
process(clk)
begin
	if rising_edge(clk) then
        if hchar = hcur_pos and vchar = vcur_pos and vcounter(2 downto 0) = "111" and curctrl = '1' then
            if flshcount(23) = '1' then
                cursor <= "11111111";
            else
                cursor <= "00000000";
            end if;
        else
            cursor <= "00000000";
        end if;
	end if;
end process;

-- Serialise bitstream to screen
process(clk)
begin
    if rising_edge(clk) then
        if enable = '1' then
            if hcounter(2 downto 0) = "010" then        -- Delay by 2 pixel clock ticks to give time for Character RAM and Pixel ROM to deliver data for first character.
                pixelreg <= datapixel xor cursor;       -- Left border is wider by 2 pixels to cover this
            else
                pixelreg <= pixelreg(6 downto 0) & '1';
            end if;
        end if;
    end if;
end process;

red <= txtcol(1) when pixelreg(7) = '0' else bckcol(1);
green <= txtcol(2) when pixelreg(7) = '0' else bckcol(2);
blue <= txtcol(0) when pixelreg(7) = '0' else bckcol(0);

video <= '1' when hgenvideo = '1' and vgenvideo = '1' else '0';

process(video, pixel, red, green, blue, brdcol, hblanking, vblanking)
begin		
    if video = '1' then -- Main video display area
        R <= red;
		G <= green;
		B <= blue;
    elsif hblanking = '1' and vblanking = '1' then -- Not blanking so border area
		R <= brdcol(1);
		G <= brdcol(2);
		B <= brdcol(0);
    else -- Stop pixel output during sync and blanking signals
        R <= '0';
		G <= '0';
		B <= '0';
    end if;
end process;

nCSync <= hsync;-- and vsync; Csync if RGB, separate signals if VGA
nVSync <= vsync;

end rtl;

