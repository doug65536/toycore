`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    22:06:04 02/26/2021 
// Design Name: 
// Module Name:    rat 
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
// Register Alias Table
module rat(
	input wire clk,
	
	input wire en,
	
	// Register selects
	input wire [REGADDRW-1:0] res_reg,
	input wire [REGADDRW-1:0] lhs_reg,
	input wire [REGADDRW-1:0] rhs_reg,
	
	// renamed destination
	input wire [TAGW-1:0] res_tag,
	
	// Enable renaming result register
	input wire res_en,
	
	// Enable renaming flags register
	input wire flags_en,
	
	// Force set an entry (for mispredict recovery)
	input wire force_set,
	input wire force_set_flags,
	input wire [DATAW-1:0] force_value,
	
	// lhs output
	output wire lhs_valid,
	output wire [TAGW-1:0] lhs_tag,
	output wire [DATAW-1:0] lhs_value,
	
	// rhs output
	output wire rhs_valid,
	output wire [TAGW-1:0] rhs_tag,
	output wire [DATAW-1:0] rhs_value,
	
	// flags output
	output wire flags_valid,
	output wire flags_tag,
	output wire [FLAGSW-1:0] flags_value,
	
	// Tag broadcast bus connection
	input wire incoming_en,
	input wire [TAGW-1:0] incoming_tag,
	input wire [DATAW-1:0] incoming_value,
	input wire [FLAGSW-1:0] incoming_flags
);

parameter DATAW = 32;
parameter TAGW = 6;
parameter REGADDRW = 5;
parameter FLAGSW = 4;
localparam [REGADDRW:0] REGCOUNT = {1'b1,{REGADDRW{1'b0}}};

reg [REGCOUNT-1:0] assign_ens;

// RAT entry for renaming flags
// Separate so it can easily operate concurrently 
// with general register rename
rs_ent #(
	.DATAW(FLAGSW),
	.TAGW(TAGW)
) rat_entry_flags (
	.clk(clk),
	.rst(1'b0),
	
	// Capture outputs
	.valid(flags_valid),
	.tag(flags_tag),
	.value(flags_value),
	
	// Attach assignment bus (mispredict recovery)
	.assign_en(force_set_flags),
	.assigned_valid(1'b1),
	.assigned_tag('bx),
	.assigned_value(force_value),
	
	// Attach tag broadcast bus
	// Flag broadcasts use same tag,
	// but use flags as value
	.incoming_en(incoming_en),
	.incoming_tag(incoming_tag),
	.incoming_value(incoming_flags)	
);

wire valids[0:REGCOUNT-1];
wire [TAGW-1:0] tags[0:REGCOUNT-1];
wire [DATAW-1:0] values[0:REGCOUNT-1];

always @*
	assign_ens = en << res_reg;

wire [REGCOUNT-1:0] resets = 'b0;

generate
	genvar r;
	
	for (r = 0; r < REGCOUNT; r = r + 1)
	begin : GENERATE_RAT_ENTRY
		rs_ent #(
			.DATAW(DATAW),
			.TAGW(TAGW)
		) rat_entry (
			.clk(clk),
			.rst(resets[r]),
			
			// Capture outputs
			.valid(valids[r]),
			.tag(tags[r]),
			.value(values[r]),
			
			// Attach assignment bus (renamed destination)
			.assign_en(assign_ens[r]),
			.assigned_valid(force_set),
			.assigned_tag(res_tag),
			.assigned_value(force_value),
			
			// Attach tag broadcast bus
			.incoming_en(incoming_en),
			.incoming_tag(incoming_tag),
			.incoming_value(incoming_value)
		);
	end
endgenerate

reg lhs_valid_output;
reg rhs_valid_output;

assign lhs_valid = lhs_valid_output;
assign rhs_valid = rhs_valid_output;

reg [TAGW-1:0] lhs_tag_output;
reg [TAGW-1:0] rhs_tag_output;

assign lhs_tag = lhs_tag_output;
assign rhs_tag = rhs_tag_output;

reg [DATAW-1:0] lhs_value_output;
reg [DATAW-1:0] rhs_value_output;

assign lhs_value = lhs_value_output;
assign rhs_value = rhs_value_output;

always @(posedge clk)
begin
	lhs_valid_output <= valids[lhs_reg];
	lhs_tag_output <= tags[lhs_reg];
	lhs_value_output <= values[lhs_reg];
	
	rhs_valid_output <= valids[rhs_reg];
	rhs_tag_output <= tags[rhs_reg];
	rhs_value_output <= values[rhs_reg];
end

endmodule

