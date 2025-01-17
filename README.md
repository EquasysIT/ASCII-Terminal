This is a project to create an ASCII terminal which outputs characters direct to a monitor. The resolution is 640 x 480 VGA, 64 x 40 characters. To create a computer to test it, I've added a 65C02 processor, 16K ROM with MSBASIC and WOZMON and 16K RAM. You can use this to have direct to screen output and PS2 keyboard input. The design is for a Tang Nano 9K board but can easily be adapted to any other FPGA. It also supports keyboard input over UART with settings of 115200,8,N,1. The UART connection runs over the standard USB cable connection to the Tang Nano 9K board.
