`include "common_cells/registers.svh"

module cordic_mgr #(
  parameter obi_pkg::obi_cfg_t ObiCfg = obi_pkg::ObiDefaultConfig,
  parameter type obi_req_t = logic,
  parameter type obi_rsp_t = logic
) (
  input  logic        clk_i,
  input  logic        rst_ni,

  // OBI Manager interface
  output obi_req_t    mgr_req_o,
  input  obi_rsp_t    mgr_rsp_i,

  // Command from top
  input  logic        read_en_i,
  input  logic        write_en_i,
  input  logic [31:0] addr_i,
  input  logic [31:0] wdata_i,
  
  // Response to top
  output logic [31:0] rdata_o,
  output logic        rvalid_o,
  output logic        txn_done_o,
  output logic        err_o,
  input  logic        ready_i
);

  typedef enum logic [1:0] {
    MGR_IDLE,
    MGR_REQ,
    MGR_WAIT_R
  } mgr_state_e;

  mgr_state_e state_d, state_q;
  logic we_d, we_q;
  logic [31:0] addr_d, addr_q;
  logic [31:0] wdata_d, wdata_q;

  always_comb begin
    state_d = state_q;
    we_d    = we_q;
    addr_d  = addr_q;
    wdata_d = wdata_q;

    mgr_req_o = '0;
    mgr_req_o.a.be = 4'hF;
    
    rdata_o = mgr_rsp_i.r.rdata;
    rvalid_o = 1'b0;
    txn_done_o = 1'b0;
    err_o = mgr_rsp_i.r.err;

    unique case (state_q)
      MGR_IDLE: begin
        if (read_en_i || write_en_i) begin
          state_d = MGR_REQ;
          we_d    = write_en_i;
          addr_d  = addr_i;
          wdata_d = wdata_i;
        end
      end

      MGR_REQ: begin
        mgr_req_o.req     = 1'b1;
        mgr_req_o.a.we    = we_q;
        mgr_req_o.a.addr  = addr_q;
        mgr_req_o.a.wdata = wdata_q;

        if (mgr_rsp_i.gnt) begin
          state_d = MGR_WAIT_R;
        end
      end

      MGR_WAIT_R: begin
        if (mgr_rsp_i.rvalid && ready_i) begin
          if (!we_q) begin
            rvalid_o = 1'b1;
          end
          txn_done_o = 1'b1;
          state_d    = MGR_IDLE;
        end
      end
      
      default: state_d = MGR_IDLE;
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      state_q <= MGR_IDLE;
      we_q    <= 1'b0;
      addr_q  <= '0;
      wdata_q <= '0;
    end else begin
      state_q <= state_d;
      we_q    <= we_d;
      addr_q  <= addr_d;
      wdata_q <= wdata_d;
    end
  end

endmodule
