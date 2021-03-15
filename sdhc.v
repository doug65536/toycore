`timescale 1ns/1ns
`default_nettype none

module sdhc(
  input wire clk,

  // Register access from CPU
  input wire [LOG2REGCOUNT-1:0] mmio_addr,
  input wire mmio_req,
  input wire mmio_read,
  input wire [DATAW-1:0] mmio_wr_data,
  output reg [DATAW-1:0] mmio_rd_data,

  // IRQ and DMA busses
  output wire irq,
  output reg dma_req,
  input wire dma_ack,
  output reg [ADDRW-1:0] dma_addr,
  input wire [DATAW-1:0] dma_rd_data,
  output wire [DATAW-1:0] dma_wr_data,

  // SD card interface  
  inout wire [3:0] sd_data,
  inout wire sd_cmd,
  output reg sd_clk
);

parameter LOG2DATAW = 5;
localparam [LOG2DATAW:0] DATAW = 1 << LOG2DATAW;
parameter ADDRW = 26;
parameter LOG2PAGESZ = 12;
localparam [LOG2PAGESZ:0] PAGESZ = 1 << LOG2PAGESZ;
localparam PFNW = ADDRW - LOG2PAGESZ;
localparam LOG2CMDBYTES = 3;
localparam RINGINDEXW = LOG2PAGESZ - LOG2CMDBYTES;

// Registers
localparam LOG2REGCOUNT = 2;

// Bidirectional sd "data" bus
reg sd_data_dir = 1'b1;
reg [3:0] sd_data_out;
wire [3:0] sd_data_in = sd_data_dir ? sd_data : sd_data_out;
assign sd_data = sd_data_dir ? 4'bz : sd_data_out;

// Bidirectional sd "cmd" line
reg sd_cmd_dir;
reg sd_cmd_out;
wire sd_cmd_in = sd_cmd_dir ? sd_cmd : sd_cmd_out;
assign sd_cmd = sd_cmd_dir ? 1'bz : sd_cmd_out;

// State
reg resetting = 1'b0;
reg ready = 1'b0;
reg ring_running = 1'b0;

// Status flags
reg general_failure = 1'b0;
reg card_initialized = 1'b0;

// IRQ enable
reg completion_unmasked = 1'b0;
reg hotplug_unmasked = 1'b0;

// Ring
reg [PFNW-1:0] command_ring_pfn = {PFNW{1'b0}};
reg [RINGINDEXW-1:0] command_ring_index = {RINGINDEXW{1'b0}};
reg consumer_phase;

// Pending interrupts
reg completion_pending = 1'b0;
reg hotplug_pending = 1'b0;

assign irq = completion_pending | hotplug_pending;

// Registers:
//  
// +0: Interrupt cause and status
//  [31:24]: error conditions
//       31: (RO) general failure
//    30-16: reserved
//   [15:8]: operational status
//       15: (RO) card initialized
//     14-8: reserved
//    [7:4]: commands
//        7: (RW) reset (sticks at 1 until complete)
//      6:4: reserved
//    [3:0]: IRQ pending
//      3:2: reserved
//        1: (RW1C) card insertion/removal IRQ occurred
//        0: (RW1C) command completed IRQ occurred
//
// +1: Interrupt enable
//       31: (RW) consumer phase. 
//           Toggles automatically when the ring wraps
//     30-2: reserved
//        1: (RW) enable card insertion/removal irq
//        0: (RW) enable command completed irq
//
// +2: Command ring physaddr
//      4KB: aligned page containing 512 command and transfer descriptors
//           writing this register resets the consumer to the start of the ring
//    31:26: reserved
//    25:12: 4KB page frame number of command ring
//     11:0: reserved
//
// +3: Reserved
//
// Command ring entry
//  +0 31:26 reserved
//      25:4 physical memory address of data buffer (wiped on completion)
//         2 irq 1=set completion interrupt pending on completion
//         1 r/w 1=read 0=write (on completion, 1=success)
//         0 phase. command is valid if it matches consumer phase
//           When the HC encounters an entry with the wrong phase, it stops
//           until the next write to the cause/status register
//  +4 31:25 Command CRC7
//     15:0 Command CRC7
//  +8  31:0 LBA (sd data address)
// +12  31:0 Unused (available for driver)
 
// SD command (48 bits)
//        0 start bit is always zero
//        1 transmission bit always says H2D
//  command 6-bit command
//      arg 32-bit argument
//      crc 7-bit crc
//        1 end bit is always one

localparam CMDSTATEW = 4;
localparam [CMDSTATEW-1:0] CMDSTATE_OFFLINE = 0;
localparam [CMDSTATEW-1:0] CMDSTATE_STARTING = 1;
localparam [CMDSTATEW-1:0] CMDSTATE_IDLE = 2;
localparam [CMDSTATEW-1:0] CMDSTATE_READCW1 = 3;
localparam [CMDSTATEW-1:0] CMDSTATE_READCW2 = 4;
localparam [CMDSTATEW-1:0] CMDSTATE_READCW3 = 5;
localparam [CMDSTATEW-1:0] CMDSTATE_TXCMD = 6;
localparam [CMDSTATEW-1:0] CMDSTATE_RXRES = 7;
localparam [CMDSTATEW-1:0] CMDSTATE_TXDATA = 8;
localparam [CMDSTATEW-1:0] CMDSTATE_RXDATA = 9;

reg [CMDSTATEW-1:0] cmd_state = CMDSTATE_OFFLINE;

// Current command captured from command ring
reg [ADDRW-4:0] cmd_phys_line_index;
reg cmd_irq;
reg cmd_rw;
reg cmd_phase;
reg [6:0] cmd_crc7;
reg [15:0] cmd_crc16;
reg cmd_reading_lba;
reg [31:0] cmd_lba;

wire [DATAW-1:0] reg_cause_and_status_read = {
  general_failure,
  15'b0,
  card_initialized,
  7'b0,
  resetting,
  7'b0
};

wire [DATAW-1:0] reg_interrupt_enable = {
  consumer_phase,
  29'b0,
  hotplug_unmasked,
  completion_unmasked
};

wire [DATAW-1:0] reg_command_ring = {
  {DATAW-ADDRW{1'b0}},
  command_ring_pfn,
  {LOG2PAGESZ{1'b0}}
};

always @(posedge clk)
begin
  mmio_rd_data <= 32'bx;
  dma_req <= 1'b0;
  dma_addr <= {ADDRW{1'bx}};

  if (mmio_req) begin
    case (mmio_addr[3:2])
    2'b00: begin
      //
      // Command register
      if (mmio_read) begin
        //
        // Read
        mmio_rd_data <= reg_cause_and_status_read;
      end else begin
        //
        // Write
        
        if (mmio_wr_data[0])
          // completion irq acknowledgement
          completion_pending <= 1'b0;
        
        if (mmio_wr_data[1])
          // hotplug irq acknowledgement
          hotplug_pending <= 1'b0;
        
        if (mmio_wr_data[7]) begin
          // Reset
          resetting <= 1'b1;
          ready <= 1'b0;
          general_failure <= 1'b0;
          card_initialized <= 1'b0;
          completion_unmasked <= 1'b0;
          hotplug_unmasked <= 1'b0;
          command_ring_pfn <= {PFNW{1'b0}};
          command_ring_index <= {RINGINDEXW{1'b0}};
          consumer_phase <= 1'b0;
          cmd_state <= CMDSTATE_OFFLINE;
        end
      end
    end
    
    2'b01: begin
      //
      // Interrupt enable
      if (mmio_read) begin
        //
        // Read
        mmio_rd_data <= reg_interrupt_enable;
      end else begin
        //
        // Write
        hotplug_unmasked <= mmio_wr_data[0];
        completion_unmasked <= mmio_wr_data[1];
        consumer_phase <= mmio_wr_data[31];
      end
    end
    
    2'b10: begin
      //
      // Command ring
      if (mmio_read) begin
        mmio_rd_data <= reg_command_ring;
      end else begin
        command_ring_pfn <= mmio_wr_data[ADDRW-1:LOG2PAGESZ];
        command_ring_index <= {RINGINDEXW{1'b0}};
      end
    end
    
    2'b11: begin
    end

    endcase
  end else if (resetting) begin
    // Initialize SD interface
    
  end else if (ready) begin
    // Operating normally

  end
end

// Initialization
//  Initial clock frequency: 400kHz (100MHz divide by 250)

reg [7:0] clk_div = 'd250;
reg [7:0] clk_cur = 'd0;

// Initialize SD bus ASAP
initial
begin
  sd_data_dir = 1'b1;
  sd_data_out <= 4'bz;
  sd_clk <= 1'b0;
  sd_cmd_dir = 1'b0;
  sd_cmd_out <= 1'b0;
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
