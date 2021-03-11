`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    07:14:53 02/28/2021 
// Design Name: 
// Module Name:    mc 
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
module mc(
	input wire clk_in,
	input wire rst_in,
	
	output wire clk,
	output wire rst,
	
	output wire [7:0] data_out,
	input wire run,

	// LPDDR-333
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
	inout wire mcb3_rzq
);

localparam WRITE_CMD =  2'b00;
localparam READ_CMD =   2'b01;
localparam READPC_CMD = 2'b10;

reg cmd_en;
wire cmd_empty;
wire cmd_full;
reg [2:0] cmd_instr;
reg [5:0] cmd_bl;
reg [29:0] cmd_byte_addr;

reg wr_en;
reg [15:0] wr_mask;
reg [127:0] wr_data;
wire wr_full;
wire wr_empty;
wire [6:0] wr_count;
wire wr_underrun;
wire wr_error;

reg rd_en;
wire [127:0] rd_data;
wire rd_full;
wire rd_empty;
wire [6:0] rd_count;
wire rd_overflow;
wire rd_error;

wire calib_done;

reg [1:0] state = 0;

reg [7:0] io_p5_out;
assign data_out = io_p5_out;

always @(posedge clk)
begin
	wr_data <= 128'h0000000000000000;
	wr_mask <= 16'h0000;
	wr_en <= 1'b0;
	rd_en <= 1'b0;
	cmd_en <= 1'b0;
	cmd_instr <= WRITE_CMD;
	cmd_bl <= 0;
	cmd_byte_addr <= 0;
	
	if (run) begin
		case (state)
		'd0: begin
			if (wr_empty) begin
				wr_data <= 128'hA12345789abcde55edcba987654321A;
				wr_mask <= {16{1'b1}};
				wr_en <= 1'b1;
				cmd_instr <= WRITE_CMD;
				cmd_en <= 1'b1;
				state <= 'd1;
			end
		end
		
		'd1: begin
			if (wr_empty) begin
				cmd_instr <= READ_CMD;
				cmd_en <= 1'b1;
				rd_en <= 1'b1;
				state <= 'd2;
			end
		end
			
		'd2: begin
			if (~rd_empty) begin
				rd_en <= 1'b1;
				io_p5_out <= rd_data[7:0];
				state <= 'd0;
			end
		end
		
		endcase
	end
end

custom_mem_ctrl #(
	.C3_SIMULATION("YES")
) mem_ctrl (
	.c3_sys_clk(clk_in),
	.c3_sys_rst_i(rst_in),

	.c3_clk0(clk),
	.c3_rst0(rst),
	
	.c3_calib_done(calib_done),
        
	.c3_p0_cmd_clk       (clk),
	.c3_p0_cmd_en        (cmd_en),
	.c3_p0_cmd_instr     (cmd_instr),
	.c3_p0_cmd_bl        (cmd_bl),
	.c3_p0_cmd_byte_addr (cmd_byte_addr),
	.c3_p0_cmd_empty     (cmd_empty),
	.c3_p0_cmd_full      (cmd_full),
	.c3_p0_wr_clk        (clk),
	.c3_p0_wr_en         (wr_en),
	.c3_p0_wr_mask       (wr_mask),
	.c3_p0_wr_data       (wr_data),
	.c3_p0_wr_full       (wr_full),
	.c3_p0_wr_empty      (wr_empty),
	.c3_p0_wr_count      (wr_count),
	.c3_p0_wr_underrun   (wr_underrun),
	.c3_p0_wr_error      (wr_error),
	.c3_p0_rd_clk        (clk),
	.c3_p0_rd_en         (rd_en),
	.c3_p0_rd_data       (rd_data),
	.c3_p0_rd_full       (rd_full),
	.c3_p0_rd_empty      (rd_empty),
	.c3_p0_rd_count      (rd_count),
	.c3_p0_rd_overflow   (rd_overflow),
	.c3_p0_rd_error      (rd_error),

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
