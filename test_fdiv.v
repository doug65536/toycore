`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   17:39:52 03/08/2021
// Design Name:   fdiv
// Module Name:   /home/doug/code/verilog/simplecpu/test_fdiv.v
// Project Name:  simplecpu
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: fdiv
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module test_fdiv;

	// Inputs
	reg clk;
	reg [31:0] a;
	reg [31:0] b;
	reg [1:0] op;
	
	// Outputs
	wire [31:0] q;

	reg [31:0] expect;
	wire failed = expect != q;

	// Instantiate the Unit Under Test (UUT)
	fdiv uut (
		.clk(clk), 
		.a(a), 
		.b(b), 
		.op(op), 
		.q(q)
	);

	initial forever #5 clk = ~clk;

	initial begin
		// Initialize Inputs
		clk = 0;
		a = 0;
		b = 0;
		op = 0;
		
		// Wait 100 ns for global reset to finish
		#100;
        
		// Add stimulus here

		// pi=40490fdb e=402df854
		// pi/e=3f93eee0
		// e/pi=3f5d816a

		a = 'h3f800000;
		b = 'h3f800000;
		expect = 'h3f800000;
		#10;
		
		a = 'h3f800000;
		b = 'h3f000000;
		expect = 'h40000000;
		#10;
		
		a = 'h40490fdb;
		b = 'h402df854;
		expect = 'h3f93eee0;
		#10;
		
		a = 'h402df854;
		b = 'h40490fdb;
		expect = 'h3f5d816a;
		#10;

		a = 'h3f800000;
		b = 'hffffface;
		expect = 'h3f800000;
		#10;
		
		a = 'hffffface;
		b = 'h3f800000;
		expect = 'h3f800000;
		#10;
		
		a = 'hffffface;
		b = 'hffffbeef;
		expect = 'h3f800000;
		#10;
		
		a = 'h00000000;
		b = 'h3f800000;
		expect = 'h00000000;
		#10;
		
		a = 'h3f800000;
		b = 'h00000000;
		expect = 'h7f800000;
		#10;
		
		a = 'h00000000;
		b = 'h00000000;
		expect = 'h3f800000;
		#10;
		
		a = 'h3f800000;
		b = 'h3f800000;
		expect = 'h3f800000;
		#10;
		
		
	end

endmodule

