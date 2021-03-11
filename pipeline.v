`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    07:35:59 02/28/2021 
// Design Name: 
// Module Name:    pipeline 
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
module pipeline(
	input wire clk,
	input wire rst
);

parameter DATAW = 32;

// Pipeline stages
//  - nextpc - recovery
//  - itlb
//  - fetch
//  - decode + rob insert
//  - rename
//  - dispatch to rs
//  - issue to execution
//  - execute - (alu/branch), fadd, fmul, mem
//  - reorder
//  - writeback

// alu/branch is combinational, 1 stage
//   flags and operands
// fadd is 3 stage
// fmul is 3 stage
// mem

p0_nextpc #(
	.DATAW(DATAW)
) nextpc (
);

parameter LOG2PAGESZ = 12;
parameter ADDRW = 26;
localparam PFNW = ADDRW - LOG2PAGESZ;

wire [DATAW-1:0] insn_addr;
wire [DATAW-1:0] data_addr;
wire [DATAW-1:0] itlb_hitaddr;
wire itlb_invalidate_all;
wire itlb_invalidate_one;
wire [PFNW-1:0] itlb_invalidate_pfn;
wire itlb_write_in;
wire itlb_en;
wire [PFNW-1:0] dirpf;
wire itlb_need_super;

wire itlb_hit;
wire itlb_pfault;
wire itlb_writable;
wire itlb_super;
wire itlb_executable;
wire itlb_read_out;

tlb #(
	.DATAW(DATAW)
) itlb (
	.clk(clk),
	.invalidate_all(itlb_invalidate_all),
	.invalidate_one(itlb_invalidate_one),
	.invalidate_pfn(itlb_invalidate_pfn),
	
	// Output
	.hit(itlb_hit),
	.itlb_hitaddr(itlb_hitaddr),
	.itlb_pfault(itlb_pfault),
	.itlb_writable(itlb_writable),
	.itlb_super(itlb_super),
	.itlb_executable(itlb_executable),
	.itlb_read_out(itlb_read_out),
	
	.write_in(itlb_write_in),
	
	.en(itlb_en),
	.dirpf(dirpf),
	.vaddr(insn_addr),
	.need_super(itlb_need_super),
	
	// You always read an itlb, never write, ever
	.read(1'b1),
	
	// You always need executable on an itlb
	.need_executable(1'b1)
);

p2_fetch #(
	.DATAW(DATAW)
) fetch (
);

p3_decode #(
	.DATAW(DATAW)
) decode (
);


p4_rename #(
	.DATAW(DATAW)
) rename (
);

p5_dispatch #(
	.DATAW(DATAW)
) dispatch (
);

p6_issue #(
	.DATAW(DATAW)
) issue (
);

p7_execute #(
	.DATAW(DATAW)
) exec (
);

p8_reorder #(
	.DATAW(DATAW)
) reorder (
);

p9_writeback #(
	.DATAW(DATAW)
) writeback (
);

endmodule

module p0_nextpc(
	input wire clk,
	
	output wire to_fetch_en,
	output wire to_fetch_pc,
	
	input wire mispredict,
	input wire [DATAW-1:0] redirect_pc,
	
	// When recovering from mispredict, 
	// force read selected retirement register file
	output wire force_prf_read,
	output wire [REGADDRW-1:0] force_prf_sel,
	input wire [DATAW-1:0] force_prf_data_in,
	
	// For recovery, rewinding back to last
	// retired state, force values back into RAT
	output wire rat_force_set,
	output wire [DATAW-1:0] rat_force_value
);

parameter DATAW = 32;
parameter REGADDRW = 5;

endmodule


module p2_fetch(
	input wire clk
	
);

endmodule

module p3_decode(
	input wire              clk,
	
	input wire              insn_bubble_in,
	input wire  [DATAW-1:0] insn_pc_in,
	input wire  [DATAW-1:0] insn_in,
	
	output wire [DATAW-1:0] insn_bubble,
	output wire [DATAW-1:0] insn_pc,
	
	output wire       [4:0] insn_sbj_reg,
	output wire       [4:0] insn_lhs_reg,
	output wire       [4:0] insn_rhs_reg,
	output wire      [11:0] insn_variant,
	output wire             insn_is_alu,
	output wire       [2:0] insn_alu_tp,
	output wire       [2:0] insn_alu_op,
	output wire             insn_alu_zc,
	output wire             insn_alu_oc,
	output wire             insn_alu_zr,
	output wire             insn_alu_ir,
	output wire             insn_alu_wf,
	output wire             insn_alu_wr,
	output wire      [21:0] insn_imm22,
	output wire      [11:0] insn_imm12,
	output wire       [5:0] insn_imm6,
	output wire [DATAW-1:0] insn_pcrel_operand,
	output wire             insn_is_shf,
	output wire             insn_shf_is_reg,
	output wire             insn_shf_is_carry,
	output wire             insn_is_fadd,
	output wire             insn_is_fmul,
	output wire             insn_is_ct,
	output wire             insn_is_jcc,
	output wire             insn_is_jmp,
	output wire             insn_is_intr,
	output wire             insn_is_creg,
	output wire             insn_is_imm,
	output wire             insn_is_call,
	output wire             insn_is_ld,
	output wire             insn_is_st,	
	output wire             insn_ldst_has_base,
	output wire             insn_ld_has_ofs,
	output wire             insn_is_st_postinc,
	output wire             insn_is_st_predec,
	output wire             insn_is_ldst_32bit,
	output wire             insn_is_ldst_16bit,
	output wire             insn_is_ldst_8bit,
	output wire             insn_is_ldst_pcrel
);

parameter DATAW = 32;

reg [DATAW-1:0] insn_bubble_out;
reg [DATAW-1:0] insn_pc_out;
reg       [4:0] insn_opcode_out;
reg       [4:0] insn_sbj_reg_out;
reg       [4:0] insn_lhs_reg_out;
reg       [4:0] insn_rhs_reg_out;
reg      [11:0] insn_variant_out;
reg             insn_is_alu_out;
reg       [2:0] insn_alu_op_out;
reg             insn_alu_zc_out;
reg             insn_alu_oc_out;
reg             insn_alu_zr_out;
reg             insn_alu_ir_out;
reg             insn_alu_wf_out;
reg             insn_alu_wr_out;
reg      [21:0] insn_imm22_out;
reg      [11:0] insn_imm12_out;
reg       [5:0] insn_imm6_out;
reg [DATAW-1:0] insn_pcrel_operand_out;
reg             insn_is_shf_out;
reg             insn_shf_is_reg_out;
reg             insn_shf_is_carry_out;
reg             insn_is_fadd_out;
reg             insn_is_fmul_out;
reg             insn_is_ct_out;
reg             insn_is_jcc_out;
reg             insn_is_jmp_out;
reg             insn_is_intr_out;
reg             insn_is_creg_out;
reg             insn_is_imm_out;
reg             insn_is_call_out;
reg             insn_is_ld_out;
reg             insn_is_st_out;	
reg             insn_ldst_has_base_out;
reg             insn_ld_has_ofs_out;
reg             insn_is_st_postinc_out;
reg             insn_is_st_predec_out;
reg             insn_is_ldst_32bit_out;
reg             insn_is_ldst_16bit_out;
reg             insn_is_ldst_8bit_out;
reg             insn_is_ldst_base_only_out;
reg             insn_is_ld_base_ofs_out;
reg             insn_is_ldst_pcrel_out;

assign insn_bubble = insn_bubble_out;
assign insn_pc = insn_pc_out;
assign insn_sbj_reg = insn_sbj_reg_out;
assign insn_lhs_reg = insn_lhs_reg_out;
assign insn_rhs_reg = insn_rhs_reg_out;
assign insn_variant = insn_variant_out;
assign insn_is_alu = insn_is_alu_out;
assign insn_alu_op = insn_alu_op_out;
assign insn_alu_zc = insn_alu_zc_out;
assign insn_alu_oc = insn_alu_oc_out;
assign insn_alu_zr = insn_alu_zr_out;
assign insn_alu_ir = insn_alu_ir_out;
assign insn_alu_wf = insn_alu_wf_out;
assign insn_alu_wr = insn_alu_wr_out;
assign insn_imm22 = insn_imm22_out;
assign insn_imm12 = insn_imm12_out;
assign insn_imm6 = insn_imm6_out;
assign insn_pcrel_operand = insn_pcrel_operand_out;
assign insn_is_alu = insn_is_alu_out;
assign insn_is_shf = insn_is_shf_out;
assign insn_shf_is_reg = insn_shf_is_reg_out;
assign insn_shf_is_carry = insn_shf_is_carry_out;
assign insn_shf_is_reg = insn_shf_is_reg_out;
assign insn_is_fadd = insn_is_fadd_out;
assign insn_is_fmul = insn_is_fmul_out;
assign insn_is_ct = insn_is_ct_out;
assign insn_is_jcc = insn_is_jcc_out;
assign insn_is_jmp = insn_is_jmp_out;
assign insn_is_intr = insn_is_intr_out;
assign insn_is_creg = insn_is_creg_out;
assign insn_is_imm = insn_is_imm_out;
assign insn_is_call = insn_is_call_out;
assign insn_is_ld = insn_is_ld_out;
assign insn_is_st = insn_is_st_out;	
assign insn_ldst_has_base = insn_ldst_has_base_out;
assign insn_ld_has_ofs = insn_ld_has_ofs_out;
assign insn_is_st_postinc = insn_is_st_postinc_out;
assign insn_is_st_predec = insn_is_st_predec_out;
assign insn_is_ldst_32bit = insn_is_ldst_32bit_out;
assign insn_is_ldst_16bit = insn_is_ldst_16bit_out;
assign insn_is_ldst_8bit = insn_is_ldst_8bit_out;
assign insn_is_ldst_pcrel = insn_is_ldst_pcrel_out;

always @(*)
begin
	
end

always @(posedge clk)
begin
	// All "is" flags are valid, every time
	insn_is_alu_out <= 'b0;
	insn_is_alu_out <= 'b0;
	insn_is_shf_out <= 'b0;
	insn_is_creg_out <= 'b0;
	insn_is_ct_out <= 'b0;
	insn_is_jcc_out <= 'b0;
	insn_is_call_out <= 'b0;
	insn_is_jmp_out <= 'b0;
	insn_is_intr_out <= 'b0;
	insn_is_imm_out <= 'b0;
	insn_is_shf_out <= 'b0;
	insn_is_ldst_base_only_out <= 'b0;
	insn_is_ld_base_ofs_out <= 'b0;
	insn_is_ldst_pcrel_out <= 'b0;
	insn_is_ldst_32bit_out <= 'b0;
	insn_is_ldst_16bit_out <= 'b0;
	insn_is_ldst_8bit_out <= 'b0;

	// Practically every instruction uses most or all of these
	insn_sbj_reg_out <= insn_in[26:22];
	insn_lhs_reg_out <= insn_in[21:17];
	insn_rhs_reg_out <= insn_in[16:12];
	
	insn_alu_op_out <= 'bx;
	insn_alu_op_out <= 'bx;
	insn_alu_zc_out <= 'bx;
	insn_alu_oc_out <= 'bx;
	insn_alu_zr_out <= 'bx;
	insn_alu_ir_out <= 'bx;
	insn_alu_wf_out <= 'bx;
	insn_alu_wr_out <= 'bx;
	
	insn_variant_out <= insn_in[11:0];
	insn_imm22_out <= insn_in[21:0];
	insn_imm12_out <= insn_in[11:0];
	insn_imm6_out <= insn_in[5:0];
		
	insn_pcrel_operand_out <= 
		$signed(insn_pc) + $signed(insn_in[21:0]);

	// Check major opcode type
	casex (insn_in[31:27])
	5'b00000: begin
		//
		// Arithmetic
		
		casex (insn_in[11:9])
		3'b000: begin
			//
			// ALU
			insn_is_alu_out <= 'b1;
			insn_alu_op_out <= insn_in[8:6];
			insn_alu_zc_out <= insn_in[5];
			insn_alu_oc_out <= insn_in[4];
			insn_alu_zr_out <= insn_in[3];
			insn_alu_ir_out <= insn_in[2];
			insn_alu_wf_out <= insn_in[1];
			insn_alu_wr_out <= insn_in[0];
		end
		
		3'b001: begin
			//
			// SHF

			insn_is_shf_out <= 'b1;
		end
		
		endcase
	end
		
	5'b00011: begin
		//
		// Control registers
		
		insn_is_creg_out <= 'b1;
	end
	
	5'b001xx: begin
		//
		// imm
		
		insn_is_imm_out <= 'b1;
	end
	
	5'b010xx: begin
		//
		// Control transfer

		insn_is_ct_out <= 'b1;
		
		casex (insn_in[28:27])
		2'b00: begin
			insn_is_jcc_out <= 'b1;
		end
		
		2'b01: begin
			insn_is_call_out <= 'b1;
		end
		
		2'b10: begin
			insn_is_jmp_out <= 'b1;
		end
		
		2'b11: begin
			insn_is_intr_out <= 'b1;
		end
		
		endcase
		
	end
	
	5'b1xxxx: begin
		//
		// Load/Store

		// Decode operand size
		casex (insn_in[30:29])
			2'b00: insn_is_ldst_32bit_out <= 'b1;
			2'b01: insn_is_ldst_16bit_out <= 'b1;
			2'b10: insn_is_ldst_8bit_out <= 'b1;
		endcase
		
		casex (insn_in[28:27])
			2'b00: begin
				// base only, possibly postinc/predec
				insn_is_ldst_base_only_out <= 'b1;
			end
			
			2'b01: begin
				// base+ofs
				insn_is_ld_base_ofs_out <= 'b1;
			end
			
			2'b10: begin
				// pcrel store
				insn_is_ldst_pcrel_out <= 'b1;
				insn_is_st_out <= 'b1;
			end
			
			2'b11: begin
				// pcrel load
				insn_is_ldst_pcrel_out <= 'b1;
				insn_is_ld_out <= 'b1;			
			end
		endcase
		
		casex (insn_in[13:12])
			2'b00: begin
				insn_is_ld_out <= 'b1;
			end
			
			2'b01: begin
				insn_is_st_out <= 'b1;
			end
			
			2'b10: begin
				insn_is_st_out <= 'b1;
				insn_is_st_postinc_out <= 'b1;
			end
			
			2'b11: begin
				insn_is_st_out <= 'b1;
				insn_is_st_predec_out <= 'b1;
			end
		endcase
	end
	
	endcase
end

endmodule

module p4_rename(
	input wire clk
);

parameter DATAW = 32;
parameter TAGW = 5;
parameter FLAGSW = 4;

rat #(
	.DATAW(DATAW),
	.TAGW(TAGW),
	.FLAGSW(FLAGSW)
) register_alias_table (
	
);

endmodule

module p5_dispatch(
	input wire clk,
	
	// Broadcast bus
	input wire broadcast_en,
	input wire [TAGW-1:0] broadcast_tag,
	input wire [DATAW-1:0] broadcast_value,
	input wire [FLAGSW-1:0] broadcast_flags
);

parameter DATAW = 32;
parameter TAGW = 6;
parameter REGADDRW = 5;
parameter FLAGSW = 4;

localparam ALUEXTRAW = 14;

// Presents the ready op selected for issue
wire alu_rs_ready;
wire [DATAW-1:0] alu_rs_ready_lhs;
wire [DATAW-1:0] alu_rs_ready_rhs;
wire [ALUEXTRAW-1:0] alu_rs_ready_extra;

// Takes the presented op and gets next ready op next cycle
wire alu_rs_accept;

// Pushes new op in
wire alu_rs_assign_ent;
wire assigned_lhs_valid;
wire assigned_rhs_valid;
wire assigned_flags_valid;
wire [TAGW-1:0] assigned_lhs_tag;
wire [TAGW-1:0] assigned_rhs_tag;
wire [TAGW-1:0] assigned_flags_tag;
wire [DATAW-1:0] assigned_lhs_value;
wire [DATAW-1:0] assigned_rhs_value;
wire [FLAGSW-1:0] assigned_flags_value;
wire [ALUEXTRAW-1:0] assigned_rhs_extra;

rs #(
	.DATAW(DATAW),
	.REGADDRW(REGADDRW),
	.FLAGSW(FLAGSW)
) alu_rs (
	.clk(clk),
	.full(),
	
	//
	// Row with both operands ready
	
	.ready(alu_rs_ready),
	.ready_lhs(alu_rs_ready_lhs),
	.ready_rhs(alu_rs_ready_rhs),
	.ready_extra(alu_rs_ready_extra),
	
	//
	// Reset the ready row
	
	.accept(alu_rs_accept),
	
	//
	// Dispatch a new operation to 
	// any empty entry in the reservation station
	
	.assign_ent(alu_rs_assign_ent),
	
	.assigned_lhs_valid(assigned_lhs_valid),
	.assigned_lhs_tag(assigned_lhs_tag),
	.assigned_lhs_value(assigned_lhs_value),
	
	.assigned_rhs_valid(assigned_rhs_valid),
	.assigned_rhs_tag(assigned_rhs_tag),
	.assigned_rhs_value(assigned_rhs_value),
	
	.assgined_flags_valid(assigned_flags_valid),
	.assgined_flags_tag(assigned_flags_tag),
	.assgined_flags_value(assigned_flags_value),
	
	.assigned_extra(assigned_rhs_extra),
	
	//
	// Accept a tag+value broadcast from completion
	
	.broadcast_en(broadcast_en),
	.broadcast_tag(broadcast_tag),
	.broadcast_value(broadcast_value),
	.broadcast_flags(broadcast_flags)
);

endmodule

module p6_issue(
	input wire clk
);

endmodule

module p7_execute_alu_0(
	input wire clk
);

endmodule

module p7_execute_fadd_0(
	input wire clk
);

endmodule

module p7_execute_fadd_1(
	input wire clk
);

endmodule

module p7_execute_fadd_2(
	input wire clk
);

endmodule

module p7_execute_fadd_3(
	input wire clk
);

endmodule

module p8_reorder(
);

endmodule

module p9_writeback(
);

endmodule
