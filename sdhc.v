`timescale 1ns/1ns
`default_nettype none

module sdhc(
  input wire clk,

  // Register access from CPU
  input wire [LOG2REGCOUNT-1:0] mmio_addr,
  input wire mmio_req,
  input wire [DATAW-1:0] mmio_wr_data,
  output wire [DATAW-1:0] mmio_rd_data,

  // IRQ and DMA busses
  output wire irq,
  output wire dma_req,
  input wire dma_ack,
  output wire [ADDRW-1:0] dma_addr,
  input wire [DATAW-1:0] dma_rd_data,
  output wire [DATAW-1:0] dma_wr_data,

  // SD card interface  
  inout wire [3:0] sd_data,
  output wire sd_cmd,
  output wire sd_clk
);

parameter DATAW = 32;
parameter ADDRW = 26;

// Registers
localparam LOG2REGCOUNT = 2;



// Registers:
//  

// Initialization
//  Initial clock frequency: 400kHz (100MHz divide by 250)

reg [7:0] clk_div = 'd250;
reg [7:0] clk_cur = 'd0;

// Initialize SD bus ASAP
initial
begin
  sd_data <= 4'bz;
  sd_clk <= 'b0;
  sd_cmd <= 'b0;
end

// Command is sent serially on CMD line

always @(posedge clk)
begin
  if (clk_cur == 0) begin
    clk_cur <= clk_div;

  end else begin
    clk_cur = clk_cur - 'b1;
  end
end

endmodule
