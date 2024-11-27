library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity crg is
    Port ( clk 		   : in   std_logic;
		   enable	   : in   std_logic;
           dataascii   : in   std_logic_vector(7 downto 0);
           hcur_pos    : in   std_logic_vector(4 downto 0);
           vcur_pos    : in   std_logic_vector(4 downto 0);
           addrascii   : out  std_logic_vector(9 downto 0);
           nCSync	   : out  std_logic;
		   nVSync	   : out  std_logic;
           R		   : out  std_logic;
           G		   : out  std_logic;
		   B		   : out  std_logic
		);
end crg;

architecture Behavioral of crg is

-------------
-- Signals
-------------


-- Screen pixel counters
signal hcounter     :   std_logic_vector(8 downto 0) := (others => '0');
signal vcounter	    :   std_logic_vector(8 downto 0) := (others => '0');

-- Screen character counters
signal hchar        :   std_logic_vector(4 downto 0);
signal vchar	    :   std_logic_vector(4 downto 0);

-- Cursor signals
signal cursor       :   std_logic_vector(7 downto 0);
signal flshcount    :   std_logic_vector(21 downto 0);

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

-- ASCII Character RAM to Character ROM pixel mappings
signal addrpixel    :   std_logic_vector(9 downto 0) := (others => '0');
signal datapixel    :   std_logic_vector(7 downto 0) := (others => '0');
signal dataascii32  :   std_logic_vector(7 downto 0) := (others => '0');

Begin

U1 : entity work.pixelrom port map
    (
        clk  => clk,
        addr => addrpixel,
        data  => datapixel
    );

process(clk)
begin
	if rising_edge(clk) then
	 if enable = '1' then
		if hcounter = 448 then
			hcounter <= (others => '0');
		else
			hcounter <= hcounter + 1;
		end if;
	 end if;
	end if;
end process;

process(clk)
begin
	if rising_edge(clk) then
	 if enable = '1' then
		if hcounter = 448 then
			if vcounter = 311 then 
				vcounter <= (others => '0');
			else
				vcounter <= vcounter + 1;
			end if;	
		end if;
	 end if;	
	end if;
end process;	
		
-- Horizontal Signals
process(clk)
begin
	if rising_edge(clk) then            -- Length 256
		if enable = '1' then
            if hcounter = 0 then
                hgenvideo <= '1';
            elsif hcounter = 256 then
                hgenvideo <= '0';
            end if;
            
            -- Right Border
            if hcounter = 256 then      -- Length 48
                hborder <= '1';
            elsif hcounter = 304 then
                hborder <= '0';
            end if;

            if hcounter = 304 then      -- Length 96
                hblanking <= '0';
            elsif hcounter = 400 then
                hblanking <= '1';
            end if;

            if hcounter = 320 then      -- Length 32
                hsync <= '0';
            elsif hcounter = 352 then
                hsync <= '1';
            end if;

            -- Left Border
            if hcounter = 400 then      -- Length 48
                hborder <= '1';
            elsif hcounter = 448 then
                hborder <= '0';
            end if;
		end if;
	end if;                         -- Total 448 (Hsync is inside same area as blanking so we don't add this)
end process;

-- Vertical Signals
process(clk)
begin		
	if rising_edge(clk) then        -- Length 192
		if enable = '1' then
        if vcounter = 0 then
            vgenvideo <= '1';
        elsif vcounter = 192 then
            vgenvideo <= '0';
        end if;

        -- Bottom Border
        if vcounter = 192 then     -- Length 56
            vborder <= '1';
        elsif vcounter = 248 then
            vborder <= '0';
        end if;

        if vcounter = 248 then     -- Length 8
            vblanking <= '0';
        elsif vcounter = 256 then
            vblanking <= '1';
        end if;

        if vcounter = 248 then     -- Length 4
            vsync <= '0';
        elsif vcounter = 252 then
            vsync <= '1';
        end if;

        -- Top Border
        if vcounter = 256 then     -- Length 56  (Vsync is inside same area as blanking so we don't add this)
            vborder <= '1';
        elsif vcounter = 312 then
            vborder <= '0';
        end if;
		end if;
	end if;                        -- Total 312
end process;

process(clk)
begin
	if rising_edge(clk) then
		if enable = '1' then
        flshcount <= flshcount + 1;
		end if;
	end if;
end process;

-- Divide pixel counters by 8 to get character counters
hchar <= hcounter(7 downto 3);
vchar <= vcounter(7 downto 3);

-- Pixel ROM address decoding
-- Subtract 32 from dataascii to create signal which enables easier pixelrom address decoding
dataascii32 <= dataascii - 32;
addrascii <= vchar & hchar;
addrpixel <= dataascii32(6 downto 5) & vcounter(2 downto 0) & dataascii(4 downto 0);

-- Hardware Cursor
process(clk)
begin
	if rising_edge(clk) then
        if hchar = hcur_pos and vchar = vcur_pos and vcounter(2 downto 0) = "111" then
            if flshcount(21) = '1' then
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
		if hcounter(2 downto 0) = "000" then
			pixelreg <= datapixel xor cursor;
		else
			pixelreg <= pixelreg(6 downto 0) & '1';
		end if;
	 end if;
	end if;
end process;

pixel <= not pixelreg(7);

border <= '1' when (hborder = '1' or vborder = '1') and hblanking = '1' and vblanking = '1' else '0';
video <= '1' when hgenvideo = '1' and vgenvideo = '1' else '0';

process(video, pixel, border)
begin		
    if video = '1' then -- Main video display area
        R <= '0';
		G <= pixel;
		B <= '0';
    elsif border = '1' then -- Border area
		R <= '1';
		G <= '1';
		B <= '1';
    else -- Stop pixel output during sync and blanking signals
        R <= '0';
		G <= '0';
		B <= '0';
    end if;
end process;

nCSync <= hsync and vsync;
nVSync <= vsync;

end Behavioral;

