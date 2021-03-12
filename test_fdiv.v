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
	reg clk = 1;
	reg dispatch = 0;
	reg [31:0] a = 0;
	reg [31:0] b = 0;
	reg [1:0] op = 0;
	
	// Outputs
	wire [31:0] q;
	wire done;

	reg [31:0] expect = 0;
	wire failed = expect != q;

	// Instantiate the Unit Under Test (UUT)
	fdiv uut (
		.clk(clk), 
		.a(a), 
		.b(b),
		.dispatch(dispatch),		
		.done(done),		
		.op(op), 
		.q(q)
	);

	initial begin
		// Wait 100 ns for global reset to finish
		#100;
		
		// Add stimulus here

		// pi=40490fdb e=402df854
		// pi/e=3f93eee0
		// e/pi=3f5d816a

		a = 'h3f800000;
		b = 'h3f800000;
		dispatch = 1;
		expect = 'h3f800000;
		#10;
		
		dispatch = 0;
		while (~done)
			#10;
		
		a = 'h3f800000;
		b = 'h3f000000;
		dispatch = 1;
		expect = 'h40000000;
		#10;
		
		dispatch = 0;
		while (~done)
			#10;
		
		a = 'h40490fdb;
		b = 'h402df854;
		dispatch = 1;
		expect = 'h3f93eee0;
		#10;
		
		dispatch = 0;
		while (~done)
			#10;
		
		a = 'h402df854;
		b = 'h40490fdb;
		dispatch = 1;
		expect = 'h3f5d816a;
		#10;

		dispatch = 0;
		while (~done)
			#10;
		
		a = 'h3f800000;
		b = 'hffffface;
		dispatch = 1;
		expect = 'h3f800000;
		#10;
		
		dispatch = 0;
		while (~done)
			#10;
		
		a = 'hffffface;
		b = 'h3f800000;
		dispatch = 1;
		expect = 'h3f800000;
		#10;
		
		dispatch = 0;
		while (~done)
			#10;
		
		a = 'hffffface;
		b = 'hffffbeef;
		dispatch = 1;
		expect = 'h3f800000;
		#10;
		
		dispatch = 0;
		while (~done)
			#10;
		
		a = 'h00000000;
		b = 'h3f800000;
		dispatch = 1;
		expect = 'h00000000;
		#10;
		
		dispatch = 0;
		while (~done)
			#10;
		
		a = 'h3f800000;
		b = 'h00000000;
		dispatch = 1;
		expect = 'h7f800000;
		#10;
		
		dispatch = 0;
		while (~done)
			#10;
		
		a = 'h00000000;
		b = 'h00000000;
		dispatch = 1;
		expect = 'h3f800000;
		#10;
		
		dispatch = 0;
		while (~done)
			#10;
		
		a = 'h3f800000;
		b = 'h3f800000;
		dispatch = 1;
		expect = 'h3f800000;
		#10;
		
		
	end

	initial
	begin
		#1;
		forever #5 clk = ~clk;
	end

endmodule

