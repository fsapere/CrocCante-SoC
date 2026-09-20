`include "common_cells/registers.svh"

module cordic_sbr #(
  parameter obi_pkg::obi_cfg_t ObiCfg = obi_pkg::ObiDefaultConfig,
  parameter type obi_req_t = logic,
  parameter type obi_rsp_t = logic
) (
  input  logic        clk_i,
  input  logic        rst_ni,

  // OBI Subordinate interface
  input  obi_req_t    sbr_req_i,
  output obi_rsp_t    sbr_rsp_o,

  // Registers to top
  output logic [31:0] src_addr_o,
  output logic [31:0] dst_addr_o,
  output logic [15:0] length_o,
  output logic        start_pulse_o,
  output logic        status_read_o,
  output logic        irq_en_o,

  // Status from top
  input  logic        busy_i,
  input  logic        done_i,
  input  logic        err_i,
  input  logic [15:0] remaining_i,

  // Interrupt out
  output logic        irq_o
);

  // Register map definition (word-aligned offsets, relative to user subordinate base)
  localparam logic [2:0] ADDR_SRC_ADDR = 3'h0; // 0x00 : src pointer
  localparam logic [2:0] ADDR_DST_ADDR = 3'h1; // 0x04 : dst pointer
  localparam logic [2:0] ADDR_LENGTH   = 3'h2; // 0x08 : length
  localparam logic [2:0] ADDR_CTRL     = 3'h3; // 0x0C : control
  localparam logic [2:0] ADDR_STATUS   = 3'h4; // 0x10 : status

  // Internal signals
  logic req_d, req_q;
  logic we_d, we_q;
  logic [ObiCfg.IdWidth-1:0] aid_d, aid_q;
  logic [ObiCfg.AddrWidth-1:0] addr_d, addr_q;
  logic [ObiCfg.DataWidth-1:0] wdata_d, wdata_q;

  // Registers
  logic [31:0] src_addr_d, src_addr_q;
  logic [31:0] dst_addr_d, dst_addr_q;
  logic [15:0] length_d, length_q;
  logic        irq_en_d, irq_en_q;

  // Status snapshot registers
  logic [15:0] status_remaining_q;
  logic        status_busy_q, status_done_q, status_err_q;

  // OBI address decode (word index)
  logic [2:0] addr_idx;
  assign addr_idx = sbr_req_i.a.addr[4:2];
  
  logic is_config_write;
  assign is_config_write = sbr_req_i.a.we && (addr_idx == ADDR_SRC_ADDR || addr_idx == ADDR_DST_ADDR || addr_idx == ADDR_LENGTH || addr_idx == ADDR_CTRL);

  always_comb begin
    // Default values for OBI sequential capture
    req_d    = 1'b0;
    we_d     = we_q;
    addr_d   = addr_q;
    wdata_d  = wdata_q;
    aid_d    = aid_q;

    // Registers keep state
    src_addr_d = src_addr_q;
    dst_addr_d = dst_addr_q;
    length_d   = length_q;
    irq_en_d   = irq_en_q;

    start_pulse_o = 1'b0;
    status_read_o = 1'b0;

    // Default OBI response
    sbr_rsp_o.rvalid     = req_q;
    sbr_rsp_o.r.rid      = aid_q;
    sbr_rsp_o.r.rdata    = '0;
    sbr_rsp_o.r.err      = 1'b0;
    sbr_rsp_o.r.r_optional = '0;

    // Grant logic with backpressure
    // Freeze CPU config writes while job runs
    sbr_rsp_o.gnt = sbr_req_i.req && !(busy_i && is_config_write);

    // Capture OBI request
    req_d = sbr_req_i.req && sbr_rsp_o.gnt;
    if (req_d) begin
      we_d    = sbr_req_i.a.we;
      addr_d  = sbr_req_i.a.addr;
      wdata_d  = sbr_req_i.a.wdata;
      aid_d   = sbr_req_i.a.aid;
    end

    // Handle previous cycle's request
    if (req_q) begin
      if (we_q) begin
        // Write operations
        unique case (addr_q[4:2])
          ADDR_SRC_ADDR: src_addr_d = wdata_q;
          ADDR_DST_ADDR: dst_addr_d = wdata_q;
          ADDR_LENGTH:   length_d   = wdata_q[15:0];
          ADDR_CTRL: begin
            irq_en_d = wdata_q[1];
            if (wdata_q[0] && !busy_i) begin // START bit
              start_pulse_o = 1'b1;
            end
          end
          default: ; // write to STATUS or undefined is ignored
        endcase
      end else begin
        // Read operations
        unique case (addr_q[4:2])
          ADDR_SRC_ADDR: sbr_rsp_o.r.rdata = src_addr_q;
          ADDR_DST_ADDR: sbr_rsp_o.r.rdata = dst_addr_q;
          ADDR_LENGTH:   sbr_rsp_o.r.rdata = {16'h0, length_q};
          ADDR_CTRL:     sbr_rsp_o.r.rdata = {30'h0, irq_en_q, 1'b0};
          ADDR_STATUS: begin
            sbr_rsp_o.r.rdata = {8'h0, status_remaining_q, 5'h0, status_err_q, status_done_q, status_busy_q};
            status_read_o     = 1'b1;
          end
          default:       sbr_rsp_o.r.rdata = '0;
        endcase
      end
    end
  end

  // Sequential registers
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      req_q      <= 1'b0;
      we_q       <= 1'b0;
      addr_q     <= '0;
      wdata_q    <= '0;
      aid_q      <= '0;
      src_addr_q <= '0;
      dst_addr_q <= '0;
      length_q   <= '0;
      irq_en_q   <= 1'b0;
      status_remaining_q <= '0;
      status_busy_q      <= 1'b0;
      status_done_q      <= 1'b0;
      status_err_q       <= 1'b0;
    end else begin
      req_q      <= req_d;
      we_q       <= we_d;
      addr_q     <= addr_d;
      wdata_q    <= wdata_d;
      aid_q      <= aid_d;
      src_addr_q <= src_addr_d;
      dst_addr_q <= dst_addr_d;
      length_q   <= length_d;
      irq_en_q   <= irq_en_d;
      status_remaining_q <= remaining_i;
      status_busy_q      <= busy_i;
      status_done_q      <= done_i;
      status_err_q       <= err_i;
    end
  end

  // Exports
  assign src_addr_o = src_addr_q;
  assign dst_addr_o = dst_addr_q;
  assign length_o   = length_q;
  assign irq_en_o   = irq_en_q;

  // Level sensitive IRQ. Asserted while job is done. 
  // Cleared when done_i goes low (on read of STATUS from wrapper).
  assign irq_o = irq_en_q && done_i;

endmodule
