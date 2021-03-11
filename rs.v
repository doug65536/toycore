`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    09:13:20 02/25/2021 
// Design Name: 
// Module Name:    reservation_station 
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

// Reservation Station
module rs(
	input wire clk,
	output wire full,
	
	//
	// Row with both operands and flags ready
	
	output wire ready,
	output wire [DATAW-1:0] ready_lhs,
	output wire [DATAW-1:0] ready_rhs,
	output wire [FLAGSW-1:0] ready_flags,
	output wire [EXTRAW-1:0] ready_extra,
	
	// Reset the ready row
	input wire accept,
	
	//
	// Dispatch a new operation to 
	// any empty entry in the reservation station
	
	input wire assign_ent,
	
	input wire assigned_lhs_valid,
	input wire [TAGW-1:0] assigned_lhs_tag,
	input wire [DATAW-1:0] assigned_lhs_value,
	
	input wire assigned_rhs_valid,
	input wire [TAGW-1:0] assigned_rhs_tag,
	input wire [DATAW-1:0] assigned_rhs_value,
	
	input wire assigned_flags_valid,
	input wire [TAGW-1:0] assigned_flags_tag,
	input wire [FLAGSW-1:0] assigned_flags_value,
	
	input wire [EXTRAW-1:0] assigned_extra,
	
	// Accept a tag+value broadcast from completion
	input wire broadcast_en,
	input wire [TAGW-1:0] broadcast_tag,
	input wire [DATAW-1:0] broadcast_value,
	input wire [FLAGSW-1:0] broadcast_flags
);

parameter DATAW = 32;
parameter TAGW = 6;
parameter EXTRAW = 18;
parameter LOG2ENTRIES = 2;
parameter ENTRIES = 1 << LOG2ENTRIES;
parameter FLAGSW = 4;

//
// 0=lhs, 1=rhs

//
// outputs

// lhs,rhs,flags
wire valids[0:ENTRIES-1][0:2];
// lhs,rhs
wire [DATAW-1:0] values[0:ENTRIES-1][0:1];
// flags
wire [FLAGSW-1:0] flags[0:ENTRIES-1];

// per-row inputs
reg [ENTRIES-1:0] resets;
reg [ENTRIES-1:0] assign_ens;

// per-column inputs
wire assigned_valids[0:2];
assign assigned_valids[0] = assigned_lhs_valid;
assign assigned_valids[1] = assigned_rhs_valid;
assign assigned_valids[2] = assigned_flags_valid;

wire [TAGW-1:0] assigned_tags[0:2];
assign assigned_tags[0] = assigned_lhs_tag;
assign assigned_tags[1] = assigned_rhs_tag;
assign assigned_tags[2] = assigned_flags_tag;

wire [DATAW-1:0] assigned_values[0:1];
assign assigned_values[0] = assigned_lhs_value;
assign assigned_values[1] = assigned_rhs_value;

wire readies[0:ENTRIES-1];

reg allocated[0:ENTRIES-1];
reg [LOG2ENTRIES:0] first_free = 'b0;
assign full = first_free[LOG2ENTRIES];

reg [EXTRAW-1:0] extras[0:ENTRIES-1];
reg [EXTRAW-1:0] extra_output;
assign ready_extra = extra_output;

initial
begin : GENERATE_ALLOCATED_INIT
	integer i;
	for (i = 0; i < ENTRIES; i = i + 1)
		allocated[i] = 'b0;
end

reg ready_output;
assign ready = ready_output;

// Prevent starvation by giving each
// slot one cycle at top priority, round robin
reg [LOG2ENTRIES-1:0] preferred_select_index = 'b0;
wire [LOG2ENTRIES-1:0] preferred_insert_index =
	preferred_select_index - 1'b1;
reg preferred_select_is_ready = 'b0;
reg preferred_insert_is_free = 'b0;

always @*
begin : GENERATE_RS_FIRST_FREE
	integer i, first_free_i;
	
	first_free_i = ENTRIES;
	
	for (i = 0; i < ENTRIES; i = i + 1) begin
		if (~allocated[i] && first_free_i == ENTRIES)
			first_free_i = i;
	end
	
	first_free = preferred_insert_is_free
		? preferred_insert_index
		: first_free_i;
end

reg [LOG2ENTRIES:0] first_ready;

reg [DATAW-1:0] ready_lhs_output = 'b0;
reg [DATAW-1:0] ready_rhs_output = 'b0;
assign ready_lhs = ready_lhs_output;
assign ready_rhs = ready_rhs_output;

always @*
begin : GENERATE_RS_FIRST_READY
	integer r, first_ready_r;
	
	first_ready_r = ENTRIES;
	
	for (r = 0; r < ENTRIES; r = r + 1) begin
		if (readies[r] && first_ready_r == ENTRIES)
			first_ready_r = r;
	end
	
	first_ready = preferred_select_is_ready
		? preferred_select_index
		: first_ready_r;
end

generate
	genvar r, c;
	
	for (r = 0; r < ENTRIES; r = r + 1)
	begin : GENERATE_RS_ENT_ROW
		// Row is ready if allocated and both sides are valid
		assign readies[r] =
			allocated[r] &
			valids[r][0] &
			valids[r][1] &
			valids[r][2];
		
		for (c = 0; c < 2; c = c + 1)
		begin : GENERATE_RS_ENT_COL
			rs_ent #(
				.DATAW(DATAW),
				.TAGW(TAGW)
			) rs_entry_lr_col (
				.clk(clk),
				.rst(resets[r]),
				
				// Capture outputs
				.valid(valids[r][c]),
				.tag(),
				.value(values[r][c]),
				
				// Attach assignment bus
				.assign_en(assign_ens[r]),
				.assigned_valid(assigned_valids[c]),
				.assigned_tag(assigned_tags[c]),
				.assigned_value(assigned_values[c]),
				
				// Attach tag broadcast bus, capture value
				.incoming_en(broadcast_en),
				.incoming_tag(broadcast_tag),
				.incoming_value(broadcast_value)
			);
		end
		
		if (FLAGSW > 0)
		begin : GENERATE_FLAGS_CAPTURE
			rs_ent #(
				.DATAW(FLAGSW),
				.TAGW(TAGW)
			) rs_flags_col (
				.clk(clk),
				.rst(resets[r]),
				
				// Capture outputs
				.valid(valids[r][2]),
				.tag(),
				.value(values[r][2]),
				
				// Attach assignment bus
				.assign_en(assign_ens[r]),
				.assigned_valid(assigned_valids[2]),
				.assigned_tag(assigned_tags[2]),
				.assigned_value(assigned_values[2]),
				
				// Attach tag broadcast bus, capture flags
				.incoming_en(broadcast_en),
				.incoming_tag(broadcast_tag),
				.incoming_value(broadcast_flags)
			);
		end
	end
endgenerate

always @*
begin
	resets = accept << first_ready;
	assign_ens = assign_ent << first_free;
end

always @(posedge clk)
begin
	preferred_select_index <= preferred_select_index + 1'b1;
	preferred_select_is_ready <= readies[preferred_select_index + 1'b1];
	preferred_insert_is_free <= ~allocated[preferred_select_index];

	if (assign_ent) begin
		allocated[first_free] <= 'b1;
		extras[first_free] <= assigned_extra;
	end
	
	if (accept) begin
		allocated[first_ready] <= 'b0;
	end
	
	if (~first_ready[LOG2ENTRIES]) begin
		ready_output <= 'b1;
		ready_lhs_output <= values[first_ready][0];	
		ready_rhs_output <= values[first_ready][1];
		extra_output <= extras[first_ready];
	end else begin
		ready_output <= 'b0;
		ready_lhs_output <= 'bx;
		ready_rhs_output <= 'bx;
		extra_output <= 'bx;
	end
end

endmodule

// Reservation Station Entry
module rs_ent(
	input wire clk,
	input wire rst,
	
	// Status
	output wire valid,
	output wire [TAGW-1:0] tag,
	output wire [DATAW-1:0] value,
	
	// Entry initialization
	input wire assign_en,
	input wire assigned_valid,
	input wire [TAGW-1:0] assigned_tag,
	input wire [DATAW-1:0] assigned_value,
	
	// Tag broadcast bus connection
	input wire incoming_en,
	input wire [TAGW-1:0] incoming_tag,
	input wire [DATAW-1:0] incoming_value
);

parameter DATAW = 31;
parameter TAGW = 6;

reg current_valid = 'b0;
reg [TAGW-1:0] current_tag = 'bx;
reg [DATAW-1:0] current_value = 'bx;

assign valid = current_valid;
assign tag = current_tag;
assign value = current_value;

always @(posedge clk)
begin
	if (rst) begin
		current_valid <= 'b0;
	end else if (assign_en) begin
		current_valid <= assigned_valid;
		current_tag <= assigned_tag;
		current_value <= assigned_value;
	end else if (incoming_en && 
			~current_valid &&
			current_tag == incoming_tag) begin
		current_valid <= 'b1;
		current_value <= incoming_value;
	end
end

endmodule

// pipeline:
//  itlb
//  fetch
//  decode + rob alloc
//    rs queue
//  execution
//    rob queue
//  writeback
