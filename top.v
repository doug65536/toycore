`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    03:45:46 02/23/2021 
// Design Name: 
// Module Name:    top 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module top(
	input wire clk_in,
	
	// VGA
	output wire [2:0] vga_red,
	output wire [2:0] vga_grn,
	output wire [2:1] vga_blu,
	output wire vga_hs,
	output wire vga_vs,
	
	// Switches
	input wire [6:0] sw,
	input wire [3:0] dip,
	
	// LEDs
	output wire [7:0] leds,
	
	// 7-segment
	output wire [7:0] seg7,
	output wire [2:0] seg7en,
	
	// DDR
	inout wire [15:0] mcb3_dram_dq,
	output wire [12:0] mcb3_dram_a,
	output wire [1:0] mcb3_dram_ba,
	output wire mcb3_dram_ras_n,
	output wire mcb3_dram_cas_n,
	output wire mcb3_dram_we_n,
	output wire mcb3_dram_ck,
	output wire mcb3_dram_ck_n,
	output wire mcb3_dram_cke,
	output wire mcb3_dram_dm,
	output wire mcb3_dram_udm,
	inout wire mcb3_dram_dqs,
	inout wire mcb3_dram_udqs,
	inout wire mcb3_rzq,
	
	// Ethernet
	output wire eth_tx_clk,
	output wire eth_rx_clk,
	output wire eth_crs,
	output wire eth_dv,
	input wire [3:0] eth_rx_data,
	output wire eth_col,       
	output wire eth_rx_en,     
	output wire eth_rst_n,
	output wire eth_tx_en,     
	output wire [3:0] eth_tx_data,
	output wire eth_mdc,      
	output wire eth_mdio,      

	inout wire [7:0] io_p4,
	inout wire [7:0] io_p5,
	inout wire [2:0] io_p8,
	inout wire [2:0] io_p9,

	// GPIO
	inout wire [7:0] io_p3
);

wire clk;
wire rst_in = sw[0];
wire rst;



mc mem_ctrl(
	.clk_in(clk_in),
	.rst_in(rst_in),
	
	.clk(clk),
	.rst(rst),
	
	.data_out(io_p4),
	.run(io_p5[0]),

	// LPDDR-333
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
	.mcb3_rzq(mcb3_rzq)
);

endmodule
