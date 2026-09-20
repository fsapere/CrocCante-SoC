// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Cyril Koenig <cykoenig@iis.ee.ethz.ch>
// - Enrico Zelioli <ezelioli@iis.ee.ethz.ch>

// Simple ROM
module user_rom #(
  // The OBI configuration for all ports
  parameter obi_pkg::obi_cfg_t ObiCfg    = obi_pkg::ObiDefaultConfig,
  parameter type               obi_req_t = logic,
  parameter type               obi_rsp_t = logic
) (
  input  logic     clk_i,
  input  logic     rst_ni,
  input  obi_req_t obi_req_i,
  output obi_rsp_t obi_rsp_o
);

  // Define some registers to hold the requests fields
  logic req_d, req_q;                          // Request valid
  logic we_d, we_q;                            // Write enable
  logic [ObiCfg.AddrWidth-1:0] addr_d, addr_q; // Internal address of the word to read
  logic [ObiCfg.IdWidth-1:0] id_d, id_q;       // Id of the request, must be same for the response

  // Signals used to create the response
  logic [ObiCfg.DataWidth-1:0] rsp_data; // Data field of the obi response
  logic rsp_err;                         // Error field of the obi response
  

  assign req_d  = obi_req_i.req;
  assign id_d   = obi_req_i.a.aid;
  assign we_d   = obi_req_i.a.we;
  assign addr_d = obi_req_i.a.addr;

  // First pipeline stage: Flip-flops
  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (~rst_ni) begin
      req_q  <= '0;
      id_q   <= '0;
      we_q   <= '0;
      addr_q <= '0;
    end else begin
      req_q  <= req_d;
      id_q   <= id_d;
      we_q   <= we_d;
      addr_q <= addr_d;
    end
  end


  // // Assign the OBI response data
  // Names of the students: Luca Antonio Battaglia & Francesco Maria Sapere
  // ROM contains (up to) 64 ASCII chars
  logic [3:0] word_addr; // to access the 16 words of the ROM, each containing 4 chars (32 bits)
  always_comb begin
    rsp_data = '0;
    rsp_err  = '0;
    word_addr = addr_q[5:2];

    if(req_q) begin
      if(~we_q) begin
        case(word_addr)
          4'h0: rsp_data = 32'h6163754c; // "Luca"
          4'h1: rsp_data = 32'h746e4120; // " Ant"
          4'h2: rsp_data = 32'h6f696e6f; // "onio"
          4'h3: rsp_data = 32'h74614220; // " Bat"
          4'h4: rsp_data = 32'h6c676174; // "tagl"
          4'h5: rsp_data = 32'h26206169; // "ia &"
          4'h6: rsp_data = 32'h61724620; // " Fra"
          4'h7: rsp_data = 32'h7365636e; // "nces"
          4'h8: rsp_data = 32'h4d206f63; // "co M"
          4'h9: rsp_data = 32'h61697261; // "aria"
          4'ha: rsp_data = 32'h70615320; // " Sap"
          4'hb: rsp_data = 32'h00657265; // "ere\0"
          default: rsp_data = 32'h0;
        endcase
      end else begin
        rsp_err = '1;
      end
    end
  end

  // Assign the OBI response signals
  // A channel
  assign obi_rsp_o.gnt = obi_req_i.req;
  // R channel
  assign obi_rsp_o.rvalid       = req_q;
  assign obi_rsp_o.r.rdata      = rsp_data;
  assign obi_rsp_o.r.rid        = id_q;
  assign obi_rsp_o.r.err        = rsp_err;
  assign obi_rsp_o.r.r_optional = '0;

endmodule
