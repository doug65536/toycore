`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   18:10:28 03/14/2021
// Design Name:   crc16
// Module Name:   /home/doug/code/verilog/simplecpu/test_crc16.v
// Project Name:  simplecpu
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: crc16
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module test_crc16;

	// Inputs
	reg clk;
	reg rst;
	reg en;
	reg data;

	// Outputs
	wire [15:0] crc;

	// Instantiate the Unit Under Test (UUT)
	crc16 uut (
		.clk(clk), 
		.rst(rst), 
		.en(en), 
		.data(data), 
		.crc(crc)
	);

	initial begin
		// Initialize Inputs
		clk = 0;
		rst = 0;
		en = 0;
		data = 0;

		// Wait 100 ns for global reset to finish
		#100;
        
		// Add stimulus here

	end
      
endmodule

