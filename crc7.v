`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Author: Doug Gale
// 
// Create Date:    16:20:36 03/14/2021 
// Design Name: 
// Module Name:    crc7 
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

// crc7 polynomial: x^7 + x^3 + x^0 
module crc7(
  input wire clk,
  input wire rst,
  input wire en,
  input wire data,
  output wire [6:0] crc
);

reg bits[6:0];

assign crc = {
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
  end else if (en) begin
    bits[0] <= bits[6] ^ data;
    bits[1] <= bits[0];
    bits[2] <= bits[1];
    bits[3] <= bits[2] ^ data ^ bits[6];
    bits[4] <= bits[3];
    bits[5] <= bits[4];
    bits[6] <= bits[5];
  end
end

endmodule
