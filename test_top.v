`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   04:18:36 02/23/2021
// Design Name:   top
// Module Name:   /home/doug/code/verilog/simplecpu/test_top.v
// Project Name:  simplecpu
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: top
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module test_top;

	// Inputs
	reg clk_in;

	// Outputs
	wire [12:0] mcb3_dram_a;
	wire [1:0] mcb3_dram_ba;
	wire mcb3_dram_ras_n;
	wire mcb3_dram_cas_n;
	wire mcb3_dram_we_n;
	wire mcb3_dram_ck;
	wire mcb3_dram_ck_n;
	wire mcb3_dram_cke;
	wire mcb3_dram_dm;
	wire mcb3_dram_udm;

	// Bidirs
	wire [15:0] mcb3_dram_dq;
	wire mcb3_dram_dqs;
	wire mcb3_dram_udqs;
	wire mcb3_rzq;
	
	reg [7:0] io_p4_out;
	wire [7:0] io_p4 = io_p4_out;
	wire [7:0] io_p5;
	reg [7:0] sw;

	// Instantiate the Unit Under Test (UUT)
	top uut (
		.clk_in(clk_in), 
		.mcb3_dram_dq(mcb3_dram_dq), 
		.mcb3_dram_a(mcb3_dram_a), 
		.mcb3_dram_ba(mcb3_dram_ba), 
		.mcb3_dram_ras_n(mcb3_dram_ras_n), 
		.mcb3_dram_cas_n(mcb3_dram_cas_n), 
		.mcb3_dram_we_n(mcb3_dram_we_n), 
		.mcb3_dram_ck(mcb3_dram_ck), 
		.mcb3_dram_ck_n(mcb3_dram_ck_n), 
		.mcb3_dram_cke(mcb3_dram_cke), 
		.mcb3_dram_dm(mcb3_dram_dm), 
		.mcb3_dram_udm(mcb3_dram_udm), 
		.mcb3_dram_dqs(mcb3_dram_dqs), 
		.mcb3_dram_udqs(mcb3_dram_udqs), 
		.mcb3_rzq(mcb3_rzq),
		.io_p4(io_p4),
		.io_p5(io_p5),
		.sw(sw)
	);

	initial begin
		// Initialize Inputs
		clk_in = 0;

		// Wait 100 ns for global reset to finish
		#100;
		
		#7500;
		
//		sw = 'b1;
//		#10;
//		sw = 'b0;
//		#10;
//		
//		#450;
	  
		// Add stimulus here
		io_p4_out = 'b1;
	end
	
	initial forever #5 clk_in = ~clk_in;
      
endmodule

