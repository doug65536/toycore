`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    18:49:50 03/03/2021 
// Design Name: 
// Module Name:    itlb 
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
module tlb(
	input wire clk,
	
	// full invalidation takes 4 cycles
	input wire invalidate_all,
	
	// Bus to request invalidation of a single entry
	input wire invalidate_one,
	input wire [DATAW-LOG2PAGESZ-1:0] invalidate_pfn,
	
	// tlb is middleman between cache
	// and cpu, so it can do fetches
	// from page tables on miss and walk.
	// cache only sees physical addresses.
	// two pipeline stages when itlb+ic hit
	//  1) tlb lookup
	//  2) icache fetch
	// arbitrary delays are possible when
	// ic miss and going to memory controller
	
	// Valid if hit==1
	output wire [DATAW-1:0] read_out,
	input wire [DATAW-1:0] write_in,
	
	// Incoming lookup request
	input wire en,
	input wire [ADDRW-LOG2PAGESZ-1:0] dirpf,
	input wire [DATAW-1:0] vaddr,
	input wire read,
	input wire need_super,
	input wire need_executable,
	
	// Acknowledgement and value on hit
	output wire hit,
	output wire hit_pfault,
	output wire hit_writable,
	output wire hit_super,
	output wire hit_executable,
	
	// Access to memory interface
	output wire mem_req,
	output wire mem_read,
	input wire mem_ack,
	output wire [ADDRW-1:0] mem_paddr,
	input wire [DATAW-1:0] mem_read_value,
	output wire [DATAW-1:0] mem_write_value
);

// 2**5=32
parameter LOG2DATAW = 5;
// 2**26=64MB
parameter ADDRW = 26;
// 2**12=4KB
parameter LOG2PAGESZ = 12;
// 2**11=2048 entries
parameter LOG2ENTRIES = 11;

// 2**(5-3)=2**2=4 bytes per word
localparam LOG2DATABYTES = LOG2DATAW - 3;
localparam DATAW = 1 << LOG2DATAW;
localparam TAGST = LOG2PAGESZ + LOG2ENTRIES;
localparam ENTRIES = 1 << LOG2ENTRIES;
localparam PAGESZ = 1 << LOG2PAGESZ;
localparam PERMW = 4;
localparam ENTRYW = PERMW + (ADDRW - LOG2PAGESZ);

localparam PFNW = ADDRW - LOG2PAGESZ;
localparam TAGW = DATAW - TAGST;

localparam TABINDEXW = LOG2PAGESZ - LOG2DATABYTES;

localparam PTE_PERMS_P = 0;
localparam PTE_PERMS_W = 1;
localparam PTE_PERMS_S = 2;
localparam PTE_PERMS_X = 3;

localparam ENTRY_PERMS_P = PFNW+PTE_PERMS_P;
localparam ENTRY_PERMS_W = PFNW+PTE_PERMS_W;
localparam ENTRY_PERMS_S = PFNW+PTE_PERMS_S;
localparam ENTRY_PERMS_X = PFNW+PTE_PERMS_X;

// 2 bits, invalidate 4 entries per invalidation
localparam INVALW = LOG2ENTRIES - TAGW;

assign read_out = mem_read_value;
assign mem_write_value = write_in;

// Pipeline output
reg hit_out;
reg hit_pfault_out;
reg hit_writable_out;
reg hit_super_out;
reg hit_executable_out;
reg [ADDRW-1:0] mem_paddr_out;

reg mem_req_out;
reg mem_read_out;

// Flag that enforces one memory read 
// for each walk fetch
reg in_walk_read = 'b0;

// Incremented each invalidation
reg [TAGW-1:0] current_version = 'b0;
// Incremented each cycle to proceed through 
// invalidating 1<<INVALW entries
reg [INVALW-0:0] invalidation_cycle = {1'b1, {INVALW{1'b0}}};

assign hit = hit_out;
assign hit_pfault = hit_pfault_out;
assign hit_writable = hit_writable_out;
assign hit_super = hit_super_out;
assign hit_executable = hit_executable_out;
assign mem_paddr = mem_paddr_out;

assign mem_req = mem_req_out;
assign mem_read = mem_read_out;

// on spartan6, should be inferred as 3 18kbit block rams
//
// entry:
//   |<--------18--------->|
//   |<--4->|<-----14----->|<--12-->|
//   |      |25          12|11     0|
//   | XUWP |      pfn     |   ofs  |
//
//   | perm |     pfn     |
//   |17  14|13          0|
//     XUWP  25         12
//
// tag:
// |<-----9----->|<----11--->|<--12-->|
// |     tag     |   index   | offset |
// |DATAW-1      | LOG2PAGESZ|        |
// |31         23|22       12|11     0|
// tags@2048, 2048*9 bits fits 18kbit block ram
//
// ents@2048, 2048*7 bits fits 18kbit block ram

// 22 bit large page offset
wire [LOG2PAGESZ+TABINDEXW-1:0] vaddr_large_offset =
	vaddr[LOG2PAGESZ+TABINDEXW-1:0];

// 12 bit normal page offset
wire [LOG2PAGESZ-1:0] vaddr_offset =
	vaddr_large_offset[LOG2PAGESZ-1:0];

wire [LOG2ENTRIES-1:0] vaddr_index =
	vaddr[TAGST-1:LOG2PAGESZ];

wire [TAGW-1:0] vaddr_tag =
	vaddr[DATAW-1:TAGST];

// Should be 9 bit wide 18kbit block ram
reg [TAGW-1:0] versions[0:ENTRIES-1];

// Should be 9 bit wide 18kbit block ram
reg [TAGW-1:0] tags[0:ENTRIES-1];

// Should be 18 bit wide pair of 18kbit block rams
reg [ENTRYW-1:0] entries[0:ENTRIES-1];

// Can attach itself to a single level2 page table
reg current_level1_index_is_valid = 'b0;
reg current_level1_is_large = 'b0;
reg [TABINDEXW-1:0] current_level1_index = 'b0;
reg [PFNW-1:0] current_level2_pfn = 'b0;
reg [PERMW-1:0] current_level1_perms = 'b0;

wire [ENTRYW-1:0] stored_entry = entries[vaddr_index];
wire [TAGW-1:0] stored_tag = tags[vaddr_index];
wire [TAGW-1:0] stored_version = versions[vaddr_index];

wire current_level1_present =
	current_level1_perms[PTE_PERMS_P];

wire current_level1_writable =
	current_level1_present &
	current_level1_perms[PTE_PERMS_W];

wire current_level1_super =
	current_level1_present &
	current_level1_perms[PTE_PERMS_S];

wire current_level1_executable =
	current_level1_present &
	current_level1_perms[PTE_PERMS_X];

wire stored_entry_is_present =
	stored_entry[ENTRY_PERMS_P];

wire stored_entry_is_writable =
	stored_entry_is_present &
	stored_entry[ENTRY_PERMS_W];

wire stored_entry_is_super =
	stored_entry_is_present &
	stored_entry[ENTRY_PERMS_S];

wire stored_entry_is_executable =
	stored_entry_is_present &
	stored_entry[ENTRY_PERMS_X];

wire stored_version_is_match =
	stored_version == current_version;

wire stored_tag_is_match =
	stored_version_is_match &&
	(stored_tag == vaddr_tag);

wire [PERMW-1:0] stored_entry_perms =
	stored_entry[PFNW+PERMW-1:PFNW];

// Figure out the level2 and level1 index of the address
wire [TABINDEXW-1:0] level1_index = 
	vaddr[DATAW-1:DATAW-TABINDEXW];

wire [TABINDEXW-1:0] level2_index = 
	vaddr[DATAW-TABINDEXW-1:DATAW-TABINDEXW-TABINDEXW];

wire current_level1_index_match =
	current_level1_index_is_valid &&
	current_level1_index == level1_index;

// Fault determination has two sources:
//  the level1 permissions if large page access
//  the stored permissions
// the level1 permissions must not be mixed up
// with the stored permissions, level1 might
// be wrong one

wire large_page_match =
	current_level1_index_match &&
	current_level1_is_large;

wire [PERMW-1:0] selected_perms =
	large_page_match
	? current_level1_perms
	: stored_entry_perms;

wire selected_perms_present =
	selected_perms[PTE_PERMS_P];

wire selected_perms_writable =
	selected_perms[PTE_PERMS_W];

wire selected_perms_super =
	selected_perms[PTE_PERMS_S];

wire selected_perms_executable =
	selected_perms[PTE_PERMS_X];

wire selected_perms_fault =
	!selected_perms_present |
	(~read & ~selected_perms_writable) |
	(need_super ^ selected_perms_super) |
	(need_executable & selected_perms_executable);

always @(posedge clk)
begin
	hit_out <= 'b0;
	hit_pfault_out <= 'b0;
	hit_writable_out <= 'b0;
	hit_super_out <= 'b0;
	hit_executable_out <= 'b0;
	mem_paddr_out <= 'bx;
	mem_req_out <= 'b0;
	
	// In decreasing priority...
	if (invalidate_one) begin
		// Flush the entry which corresponds to that vaddr
		// regardless of whether that tag is actually the
		// same tag as that being flushed, because it is
		// not worth it to read and mux out the tag for that
		// and put it into a big comparator
		// an unnecessary walk is likely to hit icache
		entries[invalidate_pfn[LOG2ENTRIES-1:0]] <= 'b0;
		
		// Invalidating anything anywhere forgets the location
		// of the last used level2 page, and invalidates any
		// cached large page at any address
		current_level1_index_is_valid <= 'b0;
	end else if (~invalidation_cycle[INVALW]) begin
		//
		// Zero out an entry
		
		entries[{
			current_version, 
			invalidation_cycle[INVALW-1:0]
		}] <= 'bx0;
		
		// Bump to next one
		invalidation_cycle <= 
			invalidation_cycle + 1'b1;
	end else if (invalidate_all) begin
		//
		// Begin a new invalidation cycle
		
		invalidation_cycle <= 'b0;
		
		// Invalidate cached level2 page
		current_level1_index_is_valid <= 'b0;
		
		// Bump version number
		current_version <= current_version + 'b1;
	end else if (en &&
		~selected_perms_fault &&
		large_page_match) begin
		//
		// TLB hit - large page
		
		// Mask the permissions 
		// against level1 permissions
		{ hit_executable_out, hit_super_out, 
			hit_writable_out, hit_out } <= 
			current_level1_perms;
		
		// Output translated large page address
		mem_paddr_out <= {
			current_level2_pfn[PFNW-1:TABINDEXW],
			vaddr_large_offset
		};
		
		mem_read_out <= read;		
		mem_req_out <= 'b1;
	end else if (en &&
		(stored_tag_is_match &&
		~selected_perms_fault)) begin
		//
		// TLB hit - normal page
		
		// Mask the permissions 
		// against level1 permissions
		{ hit_executable_out, hit_super_out, 
			hit_writable_out, hit_out } <= 
			stored_entry_perms;
		
		// Output translated address
		mem_paddr_out <= {
			stored_entry[PFNW-1:0],
			vaddr_offset
		};
		
		mem_read_out <= read;		
		mem_req_out <= 'b1;
	end else if (en && ~current_level1_index_match) begin
		// We are on the wrong page table
		// Need to fetch row from level1 table
		
		if (mem_ack & in_walk_read) begin
			// Got level1 PTE
			
			// Check present bit
			if (mem_read_value[0]) begin
				// Attach to level2 table 
				// (the address in level1 pte)
				
				// Remember that we currently
				// attached to a level1 page
				current_level1_index_is_valid <= 'b1;
				
				// Remember index to which we attached
				current_level1_index <= level1_index;
				
				// Capture page table physical address
				if (~mem_read_value[PERMW]) begin
					// Normal page table
					current_level2_pfn <= 
						mem_read_value[ADDRW-1:LOG2PAGESZ];
				end else begin
					// Large page
					current_level2_pfn <= {
						mem_read_value[ADDRW-1:TABINDEXW+LOG2PAGESZ],
						{TABINDEXW{1'b0}}
					};
				end
				
				// Capture level1 permissions
				current_level1_perms <=
					mem_read_value[PERMW-1:0];
				
				// Capture level1 largeness
				current_level1_is_large <=
					mem_read_value[PERMW];
			end else begin
				// Level 1 PTE says whole range not present
				// Ban everything
				current_level1_index_is_valid <= 'b0;
				current_level1_index <= 'bx;
				current_level2_pfn <= 'bx;
				current_level1_perms <= 'b0;
				current_level1_is_large <= 'b0;
				
				// Page fault
				hit_pfault_out <= 'b1;
			end
			
			in_walk_read <= 'b0;
		end else begin
			// Request to read level1 PTE
			mem_paddr_out <= 
				{dirpf, {LOG2PAGESZ{1'b0}}} + 
				{level1_index, {LOG2DATABYTES{1'b0}}};
			
			if (~in_walk_read) begin
				mem_read_out <= 'b1;
				mem_req_out <= 'b1;
			end

			in_walk_read <= 'b1;
		end
	end else if (en) begin
		//
		// We are already attached to the correct level2 table
		
		if (in_walk_read & mem_ack) begin
			in_walk_read <= 'b0;
		
			// fault if level2 PTE says not present
			hit_pfault_out <= ~mem_read_value[0];

			// Got level2 PTE, update TLB entry
			// Place permission bits in upper bits of TLB entry
			entries[vaddr_index] <= {
				mem_read_value[PERMW-1:0] & current_level1_perms,
				mem_read_value[PFNW+LOG2PAGESZ-1:LOG2PAGESZ]
			};
			
			// Update tag
			tags[vaddr_index] <= vaddr_tag;
			
			// Store valid (current) version
			versions[vaddr_index] <= current_version;
		end else if (~in_walk_read) begin
			// Request to read the level2 PTE
			mem_paddr_out <= 
				{current_level2_pfn, {LOG2PAGESZ{1'b0}}} +
				{level2_index, {LOG2DATABYTES{1'b0}}};
			
			if (~in_walk_read) begin
				mem_read_out <= 'b1;
				mem_req_out <= 'b1;
			end
			
			in_walk_read <= 'b1;
		end
	end
end

// Simulations don't have a clue that it is an FPGA that is zero initialized
initial
begin : GENERATE_TLB_INIT
	integer i;
	for (i = 0; i < 1<<11; i = i + 'b1)
	begin
		tags[i] = 'b0;
		entries[i] = 'b0;
		versions[i] = 'b0;
	end	
end

endmodule

