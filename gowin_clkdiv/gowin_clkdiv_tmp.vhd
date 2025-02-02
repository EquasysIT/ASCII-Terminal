--Copyright (C)2014-2024 Gowin Semiconductor Corporation.
--All rights reserved.
--File Title: Template file for instantiation
--Tool Version: V1.9.9.03 Education (64-bit)
--Part Number: GW1NR-LV9QN88PC6/I5
--Device: GW1NR-9
--Device Version: C
--Created Time: Wed Jan 22 16:21:43 2025

--Change the instance name and port connections to the signal names
----------Copy here to design--------

component Gowin_CLKDIV
    port (
        clkout: out std_logic;
        hclkin: in std_logic;
        resetn: in std_logic
    );
end component;

your_instance_name: Gowin_CLKDIV
    port map (
        clkout => clkout,
        hclkin => hclkin,
        resetn => resetn
    );

----------Copy end-------------------
