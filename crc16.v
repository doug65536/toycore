`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Author: Doug Gale
// 
// Create Date:    16:20:46 03/14/2021 
// Design Name: 
// Module Name:    crc16 
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

// CRC polynomial: x^16 + x^12 + x^5 + x^0
module crc16(
  input wire clk,
  input wire rst,
  input wire en,
  input wire data,
  output wire [15:0] crc
);

reg bits[15:0];

assign crc = {
  bits[15],
  bits[14],
  bits[13],
  bits[12],
  bits[11],
  bits[10],
  bits[9],
  bits[8],
  bits[7],
  bits[6],
  bits[5],
  bits[4],
  bits[3],
  bits[2],
  bits[1],
  bits[0]
};

always @(posedge clk)
begin
  if (rst) begin
    bits[0] <= data;
    bits[1] <= data;
    bits[2] <= data;
    bits[3] <= data;
    bits[4] <= data;
    bits[5] <= data;
    bits[6] <= data;
    bits[7] <= data;
    bits[8] <= data;
    bits[9] <= data;
    bits[10] <= data;
    bits[11] <= data;
    bits[12] <= data;
    bits[13] <= data;
    bits[14] <= data;
    bits[15] <= data;
  end else if (en) begin
    bits[0] <= bits[15] ^ data;
    bits[1] <= bits[0];
    bits[2] <= bits[1];
    bits[3] <= bits[2];
    bits[4] <= bits[3];
    bits[5] <= bits[4] ^ data;
    bits[6] <= bits[5];
    bits[7] <= bits[6];
    bits[8] <= bits[7];
    bits[9] <= bits[6];
    bits[10] <= bits[9];
    bits[11] <= bits[10];
    bits[12] <= bits[11] ^ data;
    bits[13] <= bits[12];
    bits[14] <= bits[13];
    bits[15] <= bits[14];
  end
end

endmodule
