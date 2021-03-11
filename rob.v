`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    22:03:48 02/26/2021 
// Design Name: 
// Module Name:    rob 
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
module rob(
	input wire clk,
	
	// destination register, value, pc
	// for retiring instruction
	output wire retiring,
	output wire [REGADDRW-0:0] retiring_dst_reg,
	output wire [DATAW-1:0] retiring_value,
	output wire [DATAW-1:0] retiring_pc,
	
	// It is illegal to allocate when stall is 1
	output wire stall,
	
	// Allocate an entry. receive tag next cycle
	input wire alloc,
	input wire [REGADDRW-0:0] alloc_dst_reg,
	output wire [TAGW-1:0] alloc_tag,
	
	// Attach tag broadcast bus
	input wire incoming_en,
	input wire [TAGW-1:0] incoming_tag,
	input wire [DATAW-1:0] incoming_value
);

parameter DATAW = 32;
parameter REGADDRW = 5;
parameter TAGW = 6;
localparam ENTRIES = 1 << TAGW;
localparam REGCOUNT = 1 << REGADDRW;

reg valids[0:ENTRIES-1];
reg [REGADDRW-0:0] dst_regs[0:ENTRIES-1];
reg [DATAW-1:0] values[0:ENTRIES-1];

reg [TAGW-1:0] alloc_tag_output;
assign alloc_tag = alloc_tag_output;

reg retiring_output;
assign retiring = retiring_output;

reg [TAGW-1:0] head = 'b0;
reg [TAGW-1:0] tail = 'b0;

assign alloc_tag = head;

wire [TAGW-1:0] next_head = head + 1'b1;
assign stall = (next_head == tail);

wire [TAGW-1:0] next_tail = tail + 1'b1;

reg [REGADDRW-0:0] retiring_dst_reg_output;
assign retiring_dst_reg = retiring_dst_reg_output;

reg [DATAW-1:0] retiring_value_output;
assign retiring_value = retiring_value_output;

always @(posedge clk)
begin
	alloc_tag_output <= 'bx;
	
	if (alloc) begin
		// Allocate an entry and provide its tag next cycle
		valids[head] <= 1'b0;
		dst_regs[head] <= alloc_dst_reg;
		alloc_tag_output <= head;
		head <= next_head;
	end
	
	// Capture result value and mark valid
	if (incoming_en) begin
		valids[incoming_tag] <= 1'b1;
		values[incoming_tag] <= incoming_value;
	end
	
	retiring_output <= 1'b0;
	retiring_dst_reg_output <= 'bx;
	
	// Retire an instruction if oldest instruction is valid
	if (head != tail && valids[tail]) begin
		retiring_dst_reg_output <= dst_regs[tail];
		retiring_output <= 1'b1;
		tail <= next_tail;
	end	
end

endmodule

// loads and stores enter the mob in program order
// capture address and tag 
module mob(
	input wire clk,
	
	input wire [TAGW-1:0] issue_tag,
	
	// Search the load buffer for the address
	// next cycle you get stlf_hit result
	input wire load_en,
	input wire [ADDRW-1:0] load_addr,	
	output wire stlf_hit,
	output wire [DATAW-1:0] stlf_data
);

parameter LOG2DATAW = 5;
parameter DATAW = 1 << LOG2DATAW;
parameter ADDRW = 26;
parameter TAGW = 5;
localparam ENTRIES = 1 << TAGW;

reg valids[0:ENTRIES-1];
reg addr_valids[0:ENTRIES-1];
reg [ADDRW-1:0] addrs[0:ENTRIES-1];
reg [1:0] sizes[0:ENTRIES-1];

endmodule
