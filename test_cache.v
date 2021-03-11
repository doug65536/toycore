`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   20:18:27 03/06/2021
// Design Name:   cache
// Module Name:   /home/doug/code/verilog/simplecpu/test_cache.v
// Project Name:  simplecpu
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: cache
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module test_cache;

	// Inputs
	reg clk;
	reg read;
	reg mem_req;
	reg [25:0] paddr;
	reg [31:0] write_data;
	reg [1:0] access_sz;
	reg mc_ack;
	reg [127:0] mc_fill_line;

	// Outputs
	wire hit;
	wire [31:0] read_data_out;
	wire mc_req;
	wire mc_read;
	wire [25:0] mc_paddr;
	wire [127:0] mc_writeback_line;
	wire [3:0] mc_writeback_mask;

	// Instantiate the Unit Under Test (UUT)
	cache uut (
		.clk(clk), 
		.read(read), 
		.mem_req(mem_req), 
		.hit(hit), 
		.paddr(paddr), 
		.write_data_in(write_data), 
		.read_data_out(read_data_out), 
		.access_sz(access_sz), 
		.mc_req_out(mc_req), 
		.mc_read(mc_read), 
		.mc_ack(mc_ack), 
		.mc_paddr(mc_paddr), 
		.mc_fill_line(mc_fill_line), 
		.mc_writeback_mask(mc_writeback_mask), 
		.mc_writeback_line(mc_writeback_line)
	);

	integer sz;

	reg [127:0] mem[0:1023];
	
	always @(posedge clk)
	begin
		mc_ack <= 'b0;
		
		if (mc_req) begin
			if (mc_read)
				mc_fill_line <= mem[mc_paddr[14:4]];
			else
				mem[mc_paddr[14:4]] <= mc_writeback_line;

			mc_ack <= 'b1;
		end
	end

	integer i;

	initial begin// : XFUCKOFF
		// Initialize Inputs
		clk = 0;
		read = 0;
		mem_req = 0;
		paddr = 0;
		write_data = 0;
		access_sz = 0;
		mc_ack = 0;
		mc_fill_line = 0;

		// Wait 100 ns for global reset to finish
		#100;
		
		mem_req = 'b1;
		
		for (sz = 2'b10; sz >= 0; sz = sz - 1)
		begin : GENERATE_TEST_ACCESS_SZ
			access_sz = sz;

			read = 'b0;

			// Add stimulus here
			for (i = 0; i < 8; i = i + hit) begin
				paddr = i << access_sz;
				write_data = i;
				#10;
			end

			// Cause a set conflict
			read = 'b1;
			paddr = 8192;
			#10;

			while (~hit)
				#10;

			for (i = 0; i < 8; i = i + hit) begin
				paddr = i << access_sz;
				#10;
			end

		end
	end
      
	initial forever #5 clk = ~clk;

endmodule

