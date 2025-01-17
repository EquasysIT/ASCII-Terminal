This is a project to create an ASCII terminal which outputs characters direct to a monitor. The resolution is 640 x 480 VGA, 64 x 40 characters. To create a computer to test it, I've added a 65C02 processor, 16K ROM with MSBASIC and WOZMON and 16K RAM. You can use this to have direct to screen output and PS2 keyboard input. The design is for a Tang Nano 9K board but can easily be adapted to any other FPGA. It also supports keyboard input over UART with settings of 115200,8,N,1. The UART connection runs over the standard USB cable connection to the Tang Nano 9K board.

----------------
-- Memory Map --
----------------
-- 0000 to 3FFF RAM 16K
-- 4000 to BFFF Unallocated 32K
-- C000 to FFFF ROM 16K (Excludes FCE0-FCE3 and FFE0-FFE5)
-- C000 MS BASIC
-- FE00 WOZMON

-- I/O ports within memory map
-- FCE0 read ASCII value of key pressed
-- FCE1 valid key pressed status (1 = pressed)
-- FCE2 read ASCII byte available over the UART interface (115200,8,1,N)
-- FCE3 valid byte available over the UART interface status (1 = byte available)
-- FFE0 send byte to screen
-- FFE1 write to LED control port
-- FFE2 Set character colour (0 = Black, 1 = Blue, 2 = Red, 3 = Magenta, 4 = Green, 5 = Cyan, 6 = Yellow, 7 = White)
-- FFE3 Set background colour
-- FFE4 Set border colour
-- FFE5 Cursor on/off (0 off, 1 on)
