`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   18:10:15 03/14/2021
// Design Name:   crc7
// Module Name:   /home/doug/code/verilog/simplecpu/test_crc7.v
// Project Name:  simplecpu
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: crc7
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module test_crc7;

// Inputs
reg clk;
reg rst;
reg en;
reg data;

// Outputs
wire [6:0] crc;

// Instantiate the Unit Under Test (UUT)
crc7 uut (
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

	rst = 1;
	#10;
	rst = 0;

	// SDHC test values
	en = 1;
	data = 0; #10;
	data = 1; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	en = 0; #10;
	
	en = 1;
	data = 0; #10;
	data = 1; #10;
	data = 0; #10;
	data = 1; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 1; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	en = 0; #10;

	en = 1;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 1; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 1; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 1; #10;
	data = 0; #10;
	data = 0; #10;
	data = 1; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	data = 0; #10;
	en = 0; #10;
	
	$finish();
end

initial forever #5 clk = ~clk;
      
endmodule

