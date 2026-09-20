`include "common_cells/registers.svh"

module cordic_wrapper #(
  parameter obi_pkg::obi_cfg_t SbrObiCfg = obi_pkg::ObiDefaultConfig,
  parameter obi_pkg::obi_cfg_t MgrObiCfg = obi_pkg::ObiDefaultConfig,
  parameter type sbr_obi_req_t = logic,
  parameter type sbr_obi_rsp_t = logic,
  parameter type mgr_obi_req_t = logic,
  parameter type mgr_obi_rsp_t = logic,
  parameter int unsigned CORDIC_LATENCY = 19
) (
  input  logic         clk_i,
  input  logic         rst_ni,

  // Bus 1: Subordinate — CPU programs device @ 0x20001000
  input  sbr_obi_req_t obi_req_i, // Reusing existing name from user_domain instantiation
  output sbr_obi_rsp_t obi_rsp_o,

  // Bus 2: Manager — device accesses SRAM autonomously
  output mgr_obi_req_t mgr_req_o,
  input  mgr_obi_rsp_t mgr_rsp_i,

  output logic         irq_o
);

  // sbr to top signals
  logic [31:0] sbr_src_addr;
  logic [31:0] sbr_dst_addr;
  logic [15:0] sbr_length;
  logic        sbr_start_pulse;
  logic        sbr_status_read;

  // top to sbr signals
  logic        busy_o, done_o, err_o;
  // remaining_q is a live FSM counter sampled by sbr in status_*_q for export to CPU
  logic [15:0] remaining_q;

  // mgr signals
  logic        fsm_read_en;
  logic        fsm_write_en;
  logic [31:0] fsm_addr;
  logic [31:0] fsm_wdata;
  logic [31:0] mgr_rdata;
  logic        mgr_rvalid;
  logic        mgr_txn_done;
  logic        mgr_err;

  // cordic_top signals
  logic [16:0] input_angle_d, input_angle_q;
  logic signed [15:0] cos_out;
  logic signed [15:0] sin_out;

  // Job FSM state
  typedef enum logic [2:0] {
    JOB_IDLE,
    MGR_READ,
    WAIT_COMPUTE,
    MGR_WRITE,
    JOB_DONE
  } job_state_e;

  job_state_e state_d, state_q;

  // Running pointers
  logic [31:0] src_ptr_d, src_ptr_q;
  logic [31:0] dst_ptr_d, dst_ptr_q;
  logic [15:0] remaining_d;
  logic        done_d, done_q;
  logic        err_d, err_q;

  // valid shift
  logic [CORDIC_LATENCY-1:0] valid_shift_d, valid_shift_q;
  logic core_result_valid;
  logic signed [15:0] cos_d, cos_q;
  logic signed [15:0] sin_d, sin_q;
  logic result_ready_d, result_ready_q;
  logic status_read_q;

  cordic_sbr #(
    .ObiCfg    (SbrObiCfg),
    .obi_req_t (sbr_obi_req_t),
    .obi_rsp_t (sbr_obi_rsp_t)
  ) i_sbr (
    .clk_i         (clk_i),
    .rst_ni        (rst_ni),
    .sbr_req_i     (obi_req_i),
    .sbr_rsp_o     (obi_rsp_o),
    .src_addr_o    (sbr_src_addr),
    .dst_addr_o    (sbr_dst_addr),
    .length_o      (sbr_length),
    .start_pulse_o (sbr_start_pulse),
    .status_read_o (sbr_status_read),
    .irq_en_o      (),
    .busy_i        (busy_o),
    .done_i        (done_q),
    .err_i         (err_q),
    .remaining_i   (remaining_q),
    .irq_o         (irq_o)
  );

  cordic_mgr #(
    .ObiCfg    (MgrObiCfg),
    .obi_req_t (mgr_obi_req_t),
    .obi_rsp_t (mgr_obi_rsp_t)
  ) i_mgr (
    .clk_i      (clk_i),
    .rst_ni     (rst_ni),
    .mgr_req_o  (mgr_req_o),
    .mgr_rsp_i  (mgr_rsp_i),
    .read_en_i  (fsm_read_en),
    .write_en_i (fsm_write_en),
    .addr_i     (fsm_addr),
    .wdata_i    (fsm_wdata),
    .rdata_o    (mgr_rdata),
    .rvalid_o   (mgr_rvalid),
    .txn_done_o (mgr_txn_done),
    .err_o      (mgr_err),
    .ready_i    (1'b1)
  );

  cordic_top i_cordic (
    .Clk         (clk_i),
    .Reset       (rst_ni),
    .Input_angle (input_angle_q),
    .Cos_out     (cos_out),
    .Sin_out     (sin_out)
  );

  assign core_result_valid = valid_shift_q[CORDIC_LATENCY-2];

  always_comb begin
    state_d        = state_q;
    src_ptr_d      = src_ptr_q;
    dst_ptr_d      = dst_ptr_q;
    remaining_d    = remaining_q;
    valid_shift_d  = valid_shift_q << 1;
    done_d         = done_q;
    err_d          = err_q;
    
    input_angle_d  = input_angle_q;
    
    cos_d          = cos_q;
    sin_d          = sin_q;
    result_ready_d = result_ready_q;

    fsm_read_en    = 1'b0;
    fsm_write_en   = 1'b0;
    fsm_addr       = '0;
    fsm_wdata      = '0;

    busy_o         = (state_q != JOB_IDLE && state_q != JOB_DONE);
    
    if (status_read_q) begin
      done_d = 1'b0;
    end
    
    if (mgr_err) begin
      err_d = 1'b1;
    end

    if (core_result_valid) begin
      cos_d = cos_out;
      sin_d = sin_out;
      result_ready_d = 1'b1;
    end

    unique case (state_q)
      JOB_IDLE: begin
        if (sbr_start_pulse && sbr_length > 0) begin
          src_ptr_d   = sbr_src_addr;
          dst_ptr_d   = sbr_dst_addr;
          remaining_d = sbr_length;
          done_d      = 1'b0;
          err_d       = 1'b0;
          state_d     = MGR_READ;
        end else if (sbr_start_pulse && sbr_length == 0) begin
          done_d      = 1'b1;
          err_d       = 1'b0;
          state_d     = JOB_DONE;
        end
      end

      MGR_READ: begin
        fsm_read_en = 1'b1;
        fsm_addr    = src_ptr_q;

        if (mgr_rvalid) begin
          input_angle_d = mgr_rdata[16:0];
          valid_shift_d = (valid_shift_q << 1) | 1'b1;
          state_d = WAIT_COMPUTE;
        end
      end

      WAIT_COMPUTE: begin
        if (result_ready_q) begin
          result_ready_d = 1'b0;
          state_d = MGR_WRITE;
        end
      end

      MGR_WRITE: begin
        fsm_write_en = 1'b1;
        fsm_addr     = dst_ptr_q;
        fsm_wdata    = {sin_q, cos_q};

        if (mgr_txn_done) begin
          remaining_d = remaining_q - 1;
          src_ptr_d   = src_ptr_q + 4;
          dst_ptr_d   = dst_ptr_q + 4;
          
          if (remaining_q == 1) begin
            done_d  = 1'b1;
            state_d = JOB_DONE;
          end else begin
            state_d = MGR_READ;
          end
        end
      end

      JOB_DONE: begin
        if (sbr_start_pulse && sbr_length > 0) begin
          src_ptr_d   = sbr_src_addr;
          dst_ptr_d   = sbr_dst_addr;
          remaining_d = sbr_length;
          done_d      = 1'b0;
          err_d       = 1'b0;
          state_d     = MGR_READ;
        end else if (sbr_start_pulse && sbr_length == 0) begin
          done_d      = 1'b1;
          err_d       = 1'b0;
          state_d     = JOB_DONE;
        end else if (!done_q) begin
          state_d     = JOB_IDLE;
        end
      end
      
      default: state_d = JOB_IDLE;
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      state_q        <= JOB_IDLE;
      src_ptr_q      <= '0;
      dst_ptr_q      <= '0;
      remaining_q    <= '0;
      valid_shift_q  <= '0;
      input_angle_q  <= '0;
      cos_q          <= '0;
      sin_q          <= '0;
      result_ready_q <= 1'b0;
      done_q         <= 1'b0;
      err_q          <= 1'b0;
      status_read_q  <= 1'b0;
    end else begin
      state_q        <= state_d;
      src_ptr_q      <= src_ptr_d;
      dst_ptr_q      <= dst_ptr_d;
      remaining_q    <= remaining_d;
      valid_shift_q  <= valid_shift_d;
      input_angle_q  <= input_angle_d;
      cos_q          <= cos_d;
      sin_q          <= sin_d;
      result_ready_q <= result_ready_d;
      done_q         <= done_d;
      err_q          <= err_d;
      status_read_q  <= sbr_status_read;
    end
  end

endmodule