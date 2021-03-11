`timescale 1ns / 1ps
`default_nettype none

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   18:50:49 03/03/2021
// Design Name:   itlb
// Module Name:   /home/doug/code/verilog/simplecpu/test_itlb.v
// Project Name:  simplecpu
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: itlb
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module test_itlb;

	// Inputs
	reg clk;
	reg invalidate_all;
	reg invalidate_one;
	reg [32-12-1:0] invalidate_pfn;
	reg en;
	reg [25-12:0] dirpf;
	reg [31:0] vaddr;
	reg read;
	reg need_super;
	reg need_executable;
	reg mem_ack;
	reg [31:0] mem_read_value;

	// Outputs
	wire [31:0] insn_out;
	wire hit;
	wire hit_pfault;
	wire hit_writable;
	wire hit_super;
	wire hit_executable;
	wire [25:0] mem_paddr;
	wire mem_req;
	wire mem_read;
	wire [31:0] mem_write_value;
	
	reg [31:0] mem[0:(1<<24)-1];

	// Instantiate the Unit Under Test (UUT)
	tlb uut (
		.clk(clk), 
		.invalidate_all(invalidate_all), 
		.invalidate_one(invalidate_one), 
		.invalidate_pfn(invalidate_pfn), 
		.read_out(insn_out), 
		.write_in('b0),
		.en(en), 
		.dirpf(dirpf), 
		.vaddr(vaddr), 
		.read(read),
		.need_super(need_super),
		.need_executable(need_executable),
		.hit(hit), 
		.hit_pfault(hit_pfault), 
		.hit_writable(hit_writable), 
		.hit_super(hit_super), 
		.hit_executable(hit_executable), 
		.mem_paddr(mem_paddr), 
		.mem_req(mem_req), 
		.mem_ack(mem_ack), 
		.mem_read(mem_read), 
		.mem_read_value(mem_read_value),
		.mem_write_value(mem_write_value)		
	);
	
	always @*//(posedge clk)
	begin
		if (mem_read)
			mem_read_value <= mem[mem_paddr/4];
		else if (mem_req)
			mem[mem_paddr/4] <= mem_write_value;
		
		mem_ack <= mem_req;
	end
	
	initial
	begin : GENERATE_GIANT_MEM
		integer i;
		for (i = 0; i < (1<<(26-2)); i = i + 1)
			mem[i] = 'b0;
		
		dirpf = 'h3000000 >> 12;

		// Page directory with a 4MB region at 0
		mem['h3000000/4] = 'h3001007;
		
		// And that region contains one 4KB page
		// Page table with one 4KB region at 'h4000
		mem['h3001010/4] = 'he007; //-swp
		
		// Data at vaddr 'h4000 is at paddr 'he000
		mem['h000e000/4] = 'hfeedbeef;
		
		mem['h000e004/4] = 'hdef5a1ad;
		
		// A large page at vaddr 'h400000
		// mapped to 4MB region 
		// at physaddr 'h00c00000-'h00ffffff
		mem['h3000004/4] = 'hc00017;
		
		// Put something in the large mapping to see
		mem['hcf1234/4] = 'hdef5a1ad;
	end
	
	initial forever #5 clk = ~clk;

	initial
	begin : TEST_ITLB
		integer addr;
		integer perm;
		// Initialize Inputs
		clk = 0;
		invalidate_all = 0;
		invalidate_one = 0;
		invalidate_pfn = 0;
		en = 0;
		vaddr = 0;
		read = 'b1;
		need_super = 'b1;
		need_executable = 'b0;
		mem_ack = 0;
		mem_read_value = 0;

		// Wait 100 ns for global reset to finish
		#100;
        
		// Add stimulus here
		
		// Set page directory
		dirpf = 'h3000;
		
		en = 'b1;
		vaddr = 'h4000;
		
		#80;
		
		en = 'b0;
		
		#10;
		
		// Should be physaddr 
		en = 'b1;
		vaddr = 'h4f1234;
		
		#30;
		
		vaddr = 'h4000;
		#10;
		
		for (addr = 'h400000; 
			addr < 'h40ffff; 
			addr = (addr + (hit ? 'h4 : 0)) ^ 'hffff)
		begin
			for (perm = 0; perm < 8; perm = perm + 'b1)
			begin
				read = ~perm[0];
				need_super = perm[1];
				need_executable = perm[2];
				vaddr = addr;
				#10;
			end
		end
		
		// Cause permission fault
		need_executable = 'b1;
		
		#40;
	end
      
endmodule

