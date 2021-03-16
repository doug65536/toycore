`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   04:25:53 03/16/2021
// Design Name:   sdhc
// Module Name:   /home/doug/code/verilog/simplecpu/test_sdhc.v
// Project Name:  simplecpu
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: sdhc
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module test_sdhc;

// Inputs
reg clk;
reg [3:0] mmio_addr;
reg mmio_req;
reg mmio_read;
reg [31:0] mmio_wr_data;
reg dma_ack;
reg [31:0] dma_rd_data;

// Outputs
wire [31:0] mmio_rd_data;
wire irq;
wire dma_req;
wire [25:0] dma_addr;
wire [31:0] dma_wr_data;
wire sd_clk;

// Bidirs
wire [3:0] sd_data;
wire sd_cmd;

reg sd_data_dir;
reg sd_data_d2h;
wire sd_data_h2d = sd_data_dir
	? sd_cmd
	: 1'bz;
assign sd_cmd = sd_data_dir
	? 1'bz
	: sd_data_d2h;

reg sd_cmd_dir;
reg sd_cmd_d2h;
wire sd_cmd_h2d = sd_cmd_dir
	? sd_cmd
	: 1'bz;
assign sd_cmd = sd_cmd_dir
	? 1'bz
	: sd_cmd_d2h;

// Instantiate the Unit Under Test (UUT)
sdhc uut (
	.clk(clk), 
	.mmio_addr(mmio_addr), 
	.mmio_req(mmio_req), 
	.mmio_read(mmio_read), 
	.mmio_wr_data(mmio_wr_data), 
	.mmio_rd_data(mmio_rd_data), 
	.irq(irq), 
	.dma_req(dma_req), 
	.dma_ack(dma_ack), 
	.dma_addr(dma_addr), 
	.dma_rd_data(dma_rd_data), 
	.dma_wr_data(dma_wr_data), 
	.sd_data(sd_data), 
	.sd_cmd(sd_cmd), 
	.sd_clk(sd_clk)
);

initial begin
	// Initialize Inputs
	clk = 0;
	mmio_addr = 0;
	mmio_req = 0;
	mmio_read = 0;
	mmio_wr_data = 0;
	dma_ack = 0;
	dma_rd_data = 0;

	// Wait 100 ns for global reset to finish
	#100;

	#10;
			
	// Add stimulus here
	mmio_wr_data = 32'b10000000;
	mmio_addr = 0;
	mmio_read = 0;
	mmio_req = 1'b1;
	#10;

	mmio_addr = 0;
	mmio_req = 0;
	mmio_read = 0;
	mmio_wr_data = 0;
	#10;
	
end

initial begin
	#100;
	forever #5 clk = ~clk;
end

endmodule

