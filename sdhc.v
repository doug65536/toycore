`timescale 1ns/1ns
`default_nettype none

module sdhc(
  input wire clk,

  // Register access from CPU
  input wire [LOG2REGCOUNT+LOG2DATABYTES-1:0] mmio_addr,
  input wire mmio_req,
  input wire mmio_read,
  input wire [DATAW-1:0] mmio_wr_data,
  output reg [DATAW-1:0] mmio_rd_data,

  // IRQ and DMA busses
  output wire irq,
  output reg dma_req,
  output reg dma_read,
  input wire dma_ack,
  output reg [ADDRW-1:0] dma_addr,
  input wire [DATAW-1:0] dma_rd_data,
  output reg [DATAW-1:0] dma_wr_data,

  // SD card interface  
  inout wire [3:0] sd_data,
  inout wire sd_cmd,
  output reg sd_clk
);

parameter LOG2DATAW = 5;
localparam LOG2DATABYTES = LOG2DATAW - 3;
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
reg [PFNW-1:0] request_ring_pfn = {PFNW{1'b0}};
reg [RINGINDEXW-1:0] request_ring_index = {RINGINDEXW{1'b0}};
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
// +4: Interrupt enable
//       31: (RW) consumer phase. 
//           Toggles automatically when the ring wraps
//     30-2: reserved
//        1: (RW) enable card insertion/removal irq
//        0: (RW) enable command completed irq
//
// +8: Command ring physaddr
//      4KB: aligned page containing 512 command and transfer descriptors
//           writing this register resets the consumer to the start of the ring
//    31:26: reserved
//    25:12: 4KB page frame number of command ring
//     11:0: reserved
//
// +c: Reserved
//
// Pair of 32 bit words per request ring entry
// Either a command or a data (LBA) transfer
//
// Both types, one data, one command
//
//  31  
// +---+
// |cmd|
// +---+--------+-------+---+----+----+-----+
// |   |30    26|35    4|  3|   2|   1|    0|
// | 0 |reserved|address|irq|read|done|phase|
// +---+--------+-------+---+----+----+-----+
// |                    lba                 |
// +---+--------+-------+---+----+----+-----+
// |
// +---+--------+-------+---+----+----+-----+
// |   |30    12|11    4|  3|   2|   1|    0|
// | 1 |reserved|command|irq|resp|done|phase|
// +---+--------+-------+---+----+----+-----+
// |                    arg                 |
// +---+--------+-------+---+----+----+-----+
//
// Request ring entry
//  +0    31 cmd 1=command 0=data
//     30:26 reserved
//      25:4 cmd=0 physical memory address of data buffer (wiped on completion)
//     25:12 cmd=1 reserved
//      11:4 cmd=1 command number
//         3 irq 1=set completion interrupt pending on completion
//         2 r/w cmd=0: 1=read 0=write (on completion, 1=success)
//               cmd=1: 1=has response, 0=no response
//         1 done 0=not done, 1=done
//         0 phase. command is valid if it matches consumer phase
//           When the HC encounters an entry with the wrong phase, it stops
//           until the next write to the cause/status register
//  +4  31:0 cmd=1 command argument
//      31:0 cmd=0 LBA (sd data address)

// SD command (48 bits)
//        0 start bit is always zero
//        1 transmission bit: 1=host-to-device (request), 
//                            0=device-to-host (reply)
//  command 6-bit command
//      arg 32-bit argument
//      crc 7-bit crc
//        1 end bit is always one

// Request ring word bits
localparam REQUEST_COMMAND_BIT = 31;
localparam REQUEST_MEMADDR_W = 22;
localparam REQUEST_MEMADDR_BIT = 4;
localparam REQUEST_CMD_W = 8;
localparam REQUEST_CMD_BIT = 4;
localparam REQUEST_IRQ_BIT = 3;
localparam REQUEST_RW_BIT = 2;
localparam REQUEST_DONE_BIT = 1;
localparam REQUEST_PHASE_BIT = 0;

// Current command captured from command ring
reg [ADDRW-4:0] request_phys_line_index;
reg request_irq;
reg [ADDRW-4-1:0] request_payload_addr;
reg request_rw;
reg request_phase;
reg [6:0] cmd_crc7;
reg [15:0] data_crc16[0:4-1];
reg request_cmd;
reg [31:0] request_lba;
reg cmd_pending;

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
  request_ring_pfn,
  {LOG2PAGESZ{1'b0}}
};

localparam RINGSTATEW = 3;
localparam [RINGSTATEW-1:0] RINGSTATE_IDLE = 0;

// Read request word 1 (lots of fields)
localparam [RINGSTATEW-1:0] RINGSTATE_READRW1 = 1;

// Read request word 2 (command argument)
localparam [RINGSTATEW-1:0] RINGSTATE_READRW2 = 2;

// Wait for command idle
localparam [RINGSTATEW-1:0] RINGSTATE_WAITIDLE = 3;

// Wait for command reply
localparam [RINGSTATEW-1:0] RINGSTATE_WAITCMD = 4;

// Transfer data
localparam [RINGSTATEW-1:0] RINGSTATE_XFERDAT = 5;

// Write result back into to request ring with DMA
localparam [RINGSTATEW-1:0] RINGSTATE_WRITRES = 6;

localparam SDCMD_RDSINGLE = 8'd18;
localparam SDCMD_WRSINGLE = 8'd24;

reg [RINGSTATEW-1:0] ring_state;

localparam BLOCKWORDIDXW = 7;
reg [BLOCKWORDIDXW-1:0] request_word_index;

always @(posedge clk)
begin
  // Usually don't care MMIO read data
  mmio_rd_data <= 32'bx;

  // Usually access the ring
  dma_addr <= {
    request_ring_pfn, 
    request_ring_index, 
    3'h0
  };

  // Usually DMA read
  dma_read <= 1'b1;

  // Usually don't request DMA
  dma_req <= 1'b0;

  if (mmio_req) begin
    // MMIO supersedes everything

    case (mmio_addr[LOG2DATABYTES+LOG2REGCOUNT-1:LOG2DATABYTES])
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
          cmd_pending <= 1'b0;
          
          // Clear error conditions
          general_failure <= 1'b0;
          card_initialized <= 1'b0;
          
          // Clear IRQ unmasks
          completion_unmasked <= 1'b0;
          hotplug_unmasked <= 1'b0;

          // Ring state
          request_ring_pfn <= {PFNW{1'b0}};
          request_ring_index <= {RINGINDEXW{1'b0}};          
          consumer_phase <= 1'b1;
          
          // Ring entry
          request_lba <= 32'b0;
          request_phase <= 1'b0;
          request_rw <= 1'b0;
          request_irq <= 1'b0;
          request_phys_line_index <= 0;
          
          // Reset CRCs
          cmd_crc_reset <= 1'b1;
          data_crc_reset <= 1'b1;

          // Go IDLE
          sd_cmd_state <= SDCMDSTATE_IDLE;
        end else if (ring_state == RINGSTATE_IDLE) begin
          // Doorbell access that does not reset wakes up ring
          ring_state <= RINGSTATE_READRW1;
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
        request_ring_pfn <= mmio_wr_data[ADDRW-1:LOG2PAGESZ];
        request_ring_index <= {RINGINDEXW{1'b0}};
      end
    end
    
    2'b11: begin
      // Reserved
      mmio_rd_data <= {DATAW{1'b0}};
    end

    endcase
  end else if (resetting) begin
    // Reset is priority 2
    resetting <= 1'b0;
    ready <= 1'b1;
    ring_running <= 1'b1;
    ring_state <= RINGSTATE_IDLE;
  end else if (ready) begin
    // Ring is priority 3
    // Operating normally
    if (ring_running) begin
      case (ring_state)
      RINGSTATE_IDLE: begin
      end

      RINGSTATE_READRW1: begin
        if (dma_req & dma_ack) begin
          // Capture address of buffer
          request_payload_addr <= {
            dma_rd_data[
              REQUEST_MEMADDR_BIT+REQUEST_MEMADDR_W-1:
              REQUEST_MEMADDR_BIT],
            {REQUEST_MEMADDR_BIT{1'b0}}
          };
          request_cmd <= dma_rd_data[REQUEST_COMMAND_BIT];
          request_irq = dma_rd_data[REQUEST_IRQ_BIT];
          request_rw = dma_rd_data[REQUEST_RW_BIT];
          request_phase = dma_rd_data[REQUEST_PHASE_BIT];
          
          ring_state <= ring_state + 1'b1;
        end else begin
          dma_req <= 1'b1;
        end
      end

      RINGSTATE_READRW2: begin
        if (request_phase != consumer_phase) begin
          // If the command has the wrong phase, 
          // stop reading the ring until next doorbell
          ring_state <= RINGSTATE_IDLE;
        end else if (dma_req && dma_ack) begin
          request_lba <= dma_rd_data;

          request_word_index <= {BLOCKWORDIDXW{1'b0}};

          if (request_cmd) begin
            // Assemble arbitrary command from
            // request address field and LBA field
            sd_cmd_buf <= {
              request_payload_addr[7:0],

              // Second request word from data bus
              dma_rd_data
            };
          end else begin
            // Select read or write LBA command
            sd_cmd_buf <= {
              (request_rw
              ? SDCMD_RDSINGLE
              : SDCMD_WRSINGLE),
              
              // Second request word from data bus
              dma_rd_data
            };
          end
          
          ring_state <= ring_state + 1'b1;
        end else begin
          // Keep requesting DMA until complete
          dma_addr <= {
            request_ring_pfn, 
            request_ring_index, 
            3'h4
          };
          dma_req <= 1'b1;
        end
      end

      RINGSTATE_WAITIDLE: begin
        // When possible to begin sending command, start that,
        // and go to next ring state
        if (sd_cmd_state == SDCMDSTATE_IDLE) begin
          cmd_pending <= 1'b1;
          ring_state <= RINGSTATE_WAITCMD;
        end
      end

      RINGSTATE_WAITCMD: begin
        if (sd_cmd_state == SDCMDSTATE_IDLE) begin
          ring_state <= ring_state + 1'b1;
        end
      end

      RINGSTATE_XFERDAT: begin
        ring_state <= ring_state + 1'b1;
      end

      RINGSTATE_WRITRES: begin
        ring_state <= ring_state + 1'b1;
      end

      endcase
    end
  end
end

localparam SDCMDCRCW = 7;
reg cmd_crc_reset;
reg cmd_crc_en;
reg cmd_crc_data;
reg cmd_framing_error;
wire [SDCMDCRCW-1:0] cmd_crc_out;

crc7 cmd_crc(
  .clk(clk),
  .rst(cmd_crc_reset),
  .en(cmd_crc_en),
  .data(cmd_crc_data),
  .crc(cmd_crc_out)
);

localparam SDDATAW = 4;

// data crc, 4 parallel 1-bit crc16 instances
reg [SDDATAW-1:0] data_crc_data;
reg data_crc_en;
reg data_crc_reset;

wire [15:0] data_crc_out[0:3];

generate
genvar i;
for (i = 0; i < 4; i = i + 1) begin
  crc16 data_crc_n(
    .clk(clk),
    .rst(data_crc_reset),
    .en(data_crc_en),
    .data(data_crc_data[i]),
    .crc(data_crc_out[i])
  );
end
endgenerate

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
//  47 46 45:40 39:8 7:1 0
//   |  |     |    |   | |
//   |  |     |    |   | always 1 end bit
//   |  |     |    |   crc7 
//   |  |     |    arg
//   |  |     command
//   |  always 1 transmission bit
//   always 0 start bit

// The subset of that that actually contains data
//   31:0 arg
//  39:32 command
localparam SDCMDSTATEW = 7;

localparam SDCMDSTATE_CRCW = 7;

localparam [SDCMDSTATEW-1:0] SDCMDSTATE_VARYINGW = 40;

localparam [SDCMDSTATEW-1:0] SDCMDSTATE_IDLE = 0;

localparam [SDCMDSTATEW-1:0] SDCMDSTATE_TXSTARTBIT = 
  SDCMDSTATE_IDLE + 1;

localparam [SDCMDSTATEW-1:0] SDCMDSTATE_TXDIRBIT = 
  SDCMDSTATE_TXSTARTBIT + 1;

localparam [SDCMDSTATEW-1:0] SDCMDSTATE_TXVARYING = 3;

localparam [SDCMDSTATEW-1:0] SDCMDSTATE_TXCRC = 
  SDCMDSTATE_TXVARYING + SDCMDSTATE_VARYINGW;

localparam [SDCMDSTATEW-1:0] SDCMDSTATE_TXENDBIT = 
  SDCMDSTATE_TXCRC + SDCMDSTATE_CRCW;

localparam [SDCMDSTATEW-1:0] SDCMDSTATE_RXSTART = 
  SDCMDSTATE_TXENDBIT + 1;

localparam [SDCMDSTATEW-1:0] SDCMDSTATE_RXDIRBIT = 
  SDCMDSTATE_RXSTART + 1;

localparam [SDCMDSTATEW-1:0] SDCMDSTATE_RXVARYING = 
  SDCMDSTATE_RXDIRBIT + 1;

localparam [SDCMDSTATEW-1:0] SDCMDSTATE_RXCRC = 
  SDCMDSTATE_RXVARYING + SDCMDSTATE_VARYINGW;

localparam [SDCMDSTATEW-1:0] SDCMDSTATE_RXENDBIT = 
  SDCMDSTATE_RXCRC + SDCMDSTATE_CRCW;

localparam [SDCMDSTATEW-1:0] SDCMDSTATE_COMMIT = 
  SDCMDSTATE_RXENDBIT + 1;

localparam SDCMDBUFW = 40;

reg sd_cmd_state;
reg [5:0] sd_cmd_bit;
reg [SDCMDBUFW-1:0] sd_cmd_buf;

always @(posedge clk)
begin
  cmd_crc_reset <= 1'b0;
  data_crc_reset <= 1'b0;
  data_crc_data <= 4'b0;

  // Data not shifted shifted when waiting for clocks
  cmd_crc_en <= 1'b0;
  data_crc_en <= 1'b0;

  // Zero is shifted into command CRC unless specified otherwise
  cmd_crc_data <= 1'b0;

  // Command crc reset defaults off
  cmd_crc_reset <= 1'b0;

  // Data crc reset defaults off
  data_crc_reset <= 1'b0;

  if (clk_cur == 0) begin
    // Set up next delay
    clk_cur <= clk_div;

    // Almost always toggle the sd clk
    sd_clk <= ~sd_clk;
  end

  // Update outputs if clock edge
  // Update outputs with no wait for clock if idle
  if (clk_cur == 0 || sd_cmd_state == SDCMDSTATE_IDLE) begin
    // Almost always advance state machine
    sd_cmd_state <= sd_cmd_state + 1'b1;

    // SD command direction is out unless specified otherwise
    sd_cmd_dir <= 1'b0;

    // SD command output is 0 unless specified otherwise
    sd_cmd_out <= 1'b0;
  
    // Data is shifted into command CRC unless specified otherwise
    cmd_crc_en <= 1'b1;

    case (sd_cmd_state)
    SDCMDSTATE_IDLE: begin
      // Don't toggle clk when idle
      sd_clk <= sd_clk;

      // Don't auto-advance state machine when idle
      if (cmd_pending) begin
        cmd_pending <= 1'b0;
      end else begin
        sd_cmd_state <= SDCMDSTATE_IDLE;
      end

      // Don't shift data into command CRC
      cmd_crc_en <= 1'b0;
    end

    SDCMDSTATE_TXSTARTBIT: begin
      cmd_crc_reset <= 1'b1;
    end

    SDCMDSTATE_TXDIRBIT: begin
      sd_cmd_out <= 1'b1;
      cmd_crc_data <= 1'b1;
    end

    // Data transfer state handled in default: below

    SDCMDSTATE_TXCRC: begin
      // Send first CRC bit
      sd_cmd_out <= cmd_crc_out[6];
      cmd_crc_data <= cmd_crc_out[6];

      // Put rest of crc into MSB of buffer and let them shift out
      // let the default case shift them out
      sd_cmd_buf <= {cmd_crc_out[5:0], {40-6{1'b0}}};
    end

    // CRC transfer state handled in default: below

    SDCMDSTATE_TXENDBIT: begin
      // End bit is always 1
      sd_cmd_out <= 1'b1;
      cmd_crc_data <= 1'b1;

      // Clear framing error before first one can occur
      cmd_framing_error <= 1'b0;
    end

    SDCMDSTATE_RXSTART,
    SDCMDSTATE_RXDIRBIT: begin
      sd_cmd_dir <= 1'b1;

      // Expect zero bit for both start and dir
      cmd_framing_error <= cmd_framing_error | sd_cmd_in;
      cmd_crc_reset <= 1'b1;
      cmd_crc_data <= sd_cmd_in;
    end

    SDCMDSTATE_RXENDBIT: begin
      sd_cmd_dir <= 1'b1;

      cmd_crc_en <= 1'b0;

      // Flag error if end bit is not 1
      cmd_framing_error <= cmd_framing_error | ~sd_data_in;

      // Done!
      sd_cmd_state <= SDCMDSTATE_IDLE;
    end

    default: begin
      // Multi-bit states (keeps working until end of crc)
      if (sd_cmd_state >= SDCMDSTATE_TXVARYING &&
          sd_cmd_state < SDCMDSTATE_TXENDBIT) begin
        // Send a bit
        sd_cmd_out <= sd_cmd_buf[SDCMDBUFW-1];
        cmd_crc_data <= sd_cmd_buf[SDCMDBUFW-1];

        // Put next bit in MSB
        sd_cmd_buf <= sd_cmd_buf << 1;
      end else if (sd_cmd_state >= SDCMDSTATE_RXVARYING &&
          sd_cmd_state < SDCMDSTATE_RXENDBIT) begin
        // Receive a bit
        sd_cmd_dir <= 1'b1;
        
        // Rotate incoming bit into LSB
        sd_cmd_buf <= {sd_cmd_buf[SDCMDBUFW-2:0], sd_cmd_in};
        cmd_crc_data <= sd_cmd_in;
      end
    end

    endcase

  end else begin
    clk_cur = clk_cur - 'b1;
  end
end

endmodule
