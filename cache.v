`timescale 1ns / 1ps
`default_nettype none

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    20:17:45 03/06/2021 
// Design Name: 
// Module Name:    cache 
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
module cache(
	input wire clk,

	//
	// consumer interface

	// Result
	output wire hit,

	// Request
	input wire read,
	input wire mem_req,
	input wire [ADDRW-1:0] paddr,
	input wire [DATAW-1:0] write_data_in,
	output wire [DATAW-1:0] read_data_out,
	
	// 00=8-bit, 01=16 bit, 10=32 bit, N=2**(N+3) bit, N=2**N byte
	input wire [1:0] access_sz,
	
	// Memory interface
	output reg mc_req_out,
	output wire mc_read,
	input wire mc_ack,
	output wire [ADDRW-1:0] mc_paddr,
	input wire [LINEW-1:0] mc_fill_line,
	output wire [LOG2LINEBYTES-1:0] mc_writeback_mask,
	output wire [LINEW-1:0] mc_writeback_line
);

// 64MB RAM coverage, 32 bit words, 128-bit lines, 128 lines, 4 banks, 8KB
// single cycle fill and writeback
parameter ADDRW = 26;
parameter LOG2DATAW = 5;
localparam LOG2DATABYTES = LOG2DATAW - 3;
localparam DATABYTES = 1 << LOG2DATABYTES;
localparam DATAW = 1 << LOG2DATAW;
parameter LOG2LINEW = 7;
localparam LOG2LINEBYTES = LOG2LINEW - 3;
parameter LOG2ENTRIES = 7;
localparam LOG2BANKCOUNT = LOG2LINEBYTES - 2;
localparam BANKCOUNT = 1 << LOG2BANKCOUNT;
localparam LINEW = 1 << LOG2LINEW;
localparam LINEBYTES = 1 << (LOG2LINEW-3);
localparam LINECOUNT = 1 << LOG2ENTRIES;
localparam TAGW = ADDRW - LOG2ENTRIES - LOG2LINEBYTES;

reg hit_out = 'b0;
assign hit = hit_out;

wire [DATAW-1:0] store_16bit = {(DATAW/16){write_data_in[15:0]}};
wire [DATAW-1:0] store_8bit = {(DATAW/8){write_data_in[7:0]}};

// Mux over 16-bit and 8-bit writes
wire [DATAW-1:0] store_value =
	access_sz == 'b10 ? write_data_in :
	access_sz == 'b01 ? store_16bit :
	access_sz == 'b00 ? store_8bit :
	'bx;

// Generate byte enables from address and access size
wire [DATABYTES-1:0] store_enables =
	(state != STATE_NORMAL || read) ? 'b0 :
	access_sz == 'b10 ? {DATABYTES{1'b1}} :
	access_sz == 'b01 ? {{2{paddr[1]}}, {2{~paddr[1]}}} : {
		paddr[1:0] == 'b11,
		paddr[1:0] == 'b10,
		paddr[1:0] == 'b01,
		paddr[1:0] == 'b00
	};

reg [ADDRW-1:0] mc_paddr_out;
assign mc_paddr = mc_paddr_out;

reg mc_read_out;
assign mc_read = mc_read_out;

// Top bit is dirty bit
reg [TAGW-1:0] tags[0:LINECOUNT-1];
reg valids[0:LINECOUNT-1];

wire [LINEBYTES-1:0] access_dirty_bits;
wire [LINEBYTES-1:0] line_dirty_bits;
assign mc_writeback_mask = line_dirty_bits;
wire [LINEBYTES-1:0] dirty_bus = 
	(state == STATE_NORMAL)
	? access_dirty_bits
	: line_dirty_bits;
wire dirty = |dirty_bus;

wire [DATAW-1:0] mem_read_banks[0:BANKCOUNT-1];

wire [13:0] ram_addr = {
	paddr[LOG2DATABYTES+LOG2BANKCOUNT+LOG2ENTRIES-1
	:LOG2DATABYTES+LOG2BANKCOUNT], 
	{LOG2DATAW{1'b0}}
};

//
// Select parts of the incoming address

wire [TAGW-1:0] addr_tag =
	paddr[ADDRW-1:LOG2LINEBYTES+LOG2ENTRIES];

wire [LOG2ENTRIES-1:0] addr_index =
	paddr[LOG2LINEBYTES+LOG2ENTRIES-1:LOG2LINEBYTES];

wire [LOG2LINEBYTES-1:0] addr_word =
	paddr[LOG2DATABYTES+LOG2LINEBYTES-1:LOG2DATABYTES];

//
// Generate banks so we can read/write one for 32-bit
// access, and also read/write several to do an entire
// cache line writeback or fill in one cycle

wire [LOG2BANKCOUNT-1:0] bank_sel =
	paddr[LOG2DATABYTES+LOG2BANKCOUNT:LOG2DATABYTES];

wire [DATABYTES-1:0] fill_byte_enables =
	{4{state == STATE_FILLING}};

generate
	genvar bn;
	for (bn = 0; bn < BANKCOUNT; bn = bn + 1'b1)
	begin : GENERATE_CACHE_BANK
		localparam [LOG2BANKCOUNT-1:0] b = bn;
		localparam ST = b * 32;
		localparam EN = ST + 32 - 1;
		localparam BST = b * DATABYTES;
		localparam BEN = BST + DATABYTES - 1;
		
		wire normal_state = (state == STATE_NORMAL);
		wire bank_match = (bank_sel == b);

		wire [DATABYTES-1:0] bank_write_byte_enables =
			(normal_state && bank_match)
			? store_enables
			: {DATABYTES{1'b0}};

		// Port A for normal accesses
		// Port B for writeback/fill
		RAMB16BWER #(
			.DATA_WIDTH_A(36),
			.DATA_WIDTH_B(36),
			.RSTTYPE("SYNC"),
			.WRITE_MODE_A("NO_CHANGE"),
			.WRITE_MODE_B("NO_CHANGE"),
			.DOA_REG(0),
			.DOB_REG(0),
			.SIM_DEVICE("SPARTAN6")
		) data_ram (
			.CLKA(clk),
			.CLKB(clk),
			
			.ENA(state == STATE_NORMAL),
			.ENB(state != STATE_NORMAL),
			
			// Select when a data access writes this bank
			// then use byte enables
			.WEA(bank_write_byte_enables), 
			.WEB(fill_byte_enables),
			
			.REGCEA(1'b1),
			.REGCEB(1'b1),
			
			.RSTA(1'b0),
			.RSTB(1'b0),
			
			.ADDRA(ram_addr),
			.ADDRB(ram_addr),

			// Regular read/write
			.DIA(store_value),
			.DOA(mem_read_banks[b]),

			// Cache line fill/writeback
			.DIB(mc_fill_line[EN:ST]),
			.DOB(mc_writeback_line[EN:ST]),
			
			// When CPU writes, set dirty bits
			.DIPA({DATABYTES{1'b1}}),
			
			// When cache line fill, clear dirty bit
			.DIPB({DATABYTES{1'b0}}),
			
			// Ignore dirty when cpu reads
			// Send dirty bits to memory controller
			.DOPA(access_dirty_bits[BEN:BST]),
			.DOPB(line_dirty_bits[BEN:BST])
		);
	end
endgenerate

assign read_data_out = mem_read_banks[bank_sel];

// Look up what we get for incoming address

wire current_valid = valids[addr_index];

wire [TAGW-1:0] current_tag = 
	tags[addr_index];

wire current_dirty =
	current_valid &&
	dirty;

wire tag_match =
	current_valid &&
	current_tag == addr_tag;

localparam LOG2STATES = 2;
localparam [LOG2STATES-1:0] STATE_NORMAL = 0;
localparam [LOG2STATES-1:0] STATE_WRITING = 1;
localparam [LOG2STATES-1:0] STATE_FILLING = 2;
reg [LOG2STATES-1:0] state = STATE_NORMAL;

always @(posedge clk)
begin
	hit_out <= 'b0;

	case (state)
	
	STATE_NORMAL: begin
		mc_req_out <= 'b0;

		if (mem_req) begin
			// Read
			if (tag_match) begin
				// Hit
				hit_out <= 'b1;
			end else if (dirty && current_valid) begin
				// This is the wrong line, and it is dirty, therefore
				// we have to write it back and fill the right line
				// Begin writeback
				mc_paddr_out <= {
					current_tag, 
					addr_index,
					{LOG2LINEBYTES{1'b0}}
				};
				mc_read_out <= 'b0;

				state <= STATE_WRITING;
			end else begin
				// We can overwrite this line
				mc_paddr_out <= {
					addr_tag, 
					addr_index,
					{LOG2LINEBYTES{1'b0}}
				};
				mc_read_out <= 'b1;

				state <= STATE_FILLING;
			end
		end
	end

	STATE_WRITING: begin
		mc_req_out <= 'b1;
		
		if (mc_ack) begin
			// Writeback completed
			// Read the requested line
			mc_paddr_out <= {
				addr_tag,
				addr_index,
				{LOG2LINEBYTES{1'b0}}
			};
			mc_read_out <= 'b1;
			mc_req_out <= 'b1;

			state <= STATE_FILLING;
		end
	end

	STATE_FILLING: begin
		if (mc_ack) begin
			mc_req_out <= 'b0;
			tags[addr_index] <= addr_tag;
			valids[addr_index] <= 'b1;

			state <= STATE_NORMAL;
		end else begin
			mc_req_out <= 'b1;
		end
	end

	endcase

end

// Dumbass simulator
initial
begin : GENERATE_SILLY_SIMULATOR_INIT
	integer i;
	for (i = 0; i < LINECOUNT; i = i + 1) begin
		tags[i] = 0;
		valids[i] = 0;		
	end
end

endmodule

