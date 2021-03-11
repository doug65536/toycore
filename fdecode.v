`timescale 1ns/1ns
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    04:59:20 02/14/2021 
// Design Name: 
// Module Name:    fadd 
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

module fdecode(
	input wire [DATAW-1:0] a,
	output wire sign,
	output wire [EXPW-1:0] exponent,
	output wire [MANW:0] fullman,
	output wire zeroexp,
	output wire hidden,
	output wire infexp,
	output wire zeroman,
	output wire maxman,
  output wire nan,
	output wire infinity,
	output wire zero
);

parameter DATAW = 32;
parameter EXPW = 8;
parameter MANW = 23;

assign sign = a[MANW+EXPW];
assign exponent = a[MANW+EXPW-1:MANW];
wire [MANW-1:0] mantissa = a[MANW-1:0];
wire anyman = |mantissa;

assign hidden = |exponent;
assign infexp = &exponent;
assign zeroexp = ~hidden;
assign zeroman = ~anyman;
assign maxman = &mantissa;
assign fullman = {hidden, mantissa};
assign infinity = infexp & zeroman;
assign zero = zeroexp & zeroman;
assign nan = infexp & ~zeroman;

endmodule
