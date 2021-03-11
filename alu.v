`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    06:06:22 02/28/2021 
// Design Name: 
// Module Name:    alu 
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
module alu(
	input wire clk,

	// Operands
	input wire [31:0] a,
	input wire [31:0] b,

	// Incoming carry
	input wire c,

	// Result
	output reg [31:0] q,

	// Result carry
	output reg qc,

	// Result overflow
	output reg qv,

	// zero b
	input wire zb,

	// invert b
	input wire ib,

	// zero incoming carry
	input wire zc,

	// force incoming carry to 1
	input wire oc,

	// Operation
	input wire [1:0] op
);

// Instructions
//          | zb | ib | c | op
//  mov     |  1 |  0 | 0 | 00 
//  add     |  0 |  0 | 0 |  "
//  adc     |  0 |  0 | c |  "
//  sbb     |  0 |  1 | c |  "
//  cmpc    |    |    | c |  "
//  sub     |  0 |  1 | 1 |  "
//  cmp     |  0 |  1 | 1 |  "

//  or      |  0 |  0 | x | 01
//  orn     |  0 |  0 | x |  "

//  and     |  0 |  0 | x | 10
//  andn    |  0 |  1 | x |  "
//  test    |  0 |  0 | x |  "
//  testn   |  0 |  1 | x |  "

//  xor     |  0 |  0 | x | 11
//  xorn    |  0 |  1 | x |  "
//  not     |  1 |  1 | x |  "

wire [31:0] b_az = zb ? 31'b0 : b;
wire [31:0] b_ai = ib ? ~b : b;
wire [31:0] rhs = b_ai;

localparam OP_ADC  = 2'b00;	// q = a + b + c
localparam OP_AND  = 2'b01;	// q = a & b
localparam OP_OR   = 2'b10;	// q = a | b
localparam OP_XOR  = 2'b11;	// q = a ^ b

wire [31:0] lhs = a;

wire ic = (c & ~zc) | oc;

wire [32:0] sum = lhs + rhs + ic;

wire lhs_sign = lhs[31];
wire rhs_sign = rhs[31];
wire sum_sign = sum[31];
wire both_pos = ~lhs_sign & ~rhs_sign;
wire both_neg = lhs_sign & rhs_sign;

always @(posedge clk)
begin
	case (op)
	OP_ADC: begin
		q <= sum[31:0];
		qc <= sum[32];
		
		// Overflow when
		//  both inputs are positive and result is negative,
		//  or,
		//  both inputs are negative and result is positive
		qv <= (both_pos & ~sum_sign) |
			(both_neg & sum_sign);
	end
	
	OP_AND: begin
		q <= lhs & rhs;
		qc <= 1'b0;
		qv <= 1'b0;		
	end
	
	OP_OR: begin
		q <= lhs | rhs;
		qc <= 1'b0;
		qv <= 1'b0;
	end

	OP_XOR: begin
		q <= lhs ^ rhs;
		qc <= 1'b0;
		qv <= 1'b0;
	end
	
	endcase
end

endmodule
