// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Philippe Sauter <phsauter@iis.ee.ethz.ch>
// - Enrico Zelioli <ezelioli@iis.ee.ethz.ch>

`define TRACE_WAVE

module tb_croc_soc #(
  parameter int unsigned GpioCount = 32
);

  import tb_croc_pkg::*;

  // Signals fully controlled by the VIP
  // use VIP functions/tasks to manipulate these signals
  logic rst_n;
  logic sys_clk;
  logic ref_clk;

  logic jtag_tck;
  logic jtag_trst_n;
  logic jtag_tms;
  logic jtag_tdi;
  logic jtag_tdo;

  logic uart_rx;
  logic uart_tx;

  // Signals partially controlled by the VIP
  logic [GpioCount-1:0] gpio_in;
  logic [GpioCount-1:0] gpio_out;
  logic [GpioCount-1:0] gpio_out_en;

  // Signals controlled by the testbench

  /////////////////////////////
  //  Command Line Arguments //
  /////////////////////////////

  string binary_path;

  initial begin
    // $value$plusargs defines what to look for (here +binary=...)
    if ($value$plusargs("binary=%s", binary_path)) begin
      $display("Running program: %s", binary_path);
    end else begin
      $display("No binary path provided. Running helloworld.");
      binary_path = "../sw/bin/helloworld.hex";
    end
  end

  ////////////
  //  VIP   //
  ////////////
  // Verification IP
  // - drives clocks and resets
  // - provides helper tasks and functions for JTAG, namely:
  //   - jtag_load_hex: loads a hex file into the DUT's memory
  //   - jtag_write_reg32: write 32-bit value to DUT
  //   - jtag_read_reg32: read 32-bit value from DUT
  //   - jtag_halt / jtag_resume: control core execution
  //   - jtag_wait_for_eoc: wait for end of code execution (core writes non-zero to status register)
  // - prints UART output to console (you can also write via uart_write_byte)
  // - internal GPIO loopback for helloworld test

  croc_vip #(
    .GpioCount ( GpioCount )
  ) i_vip (
    .rst_no        ( rst_n       ),
    .sys_clk_o     ( sys_clk     ),
    .ref_clk_o     ( ref_clk     ),
    .jtag_tck_o    ( jtag_tck    ),
    .jtag_trst_no  ( jtag_trst_n ),
    .jtag_tms_o    ( jtag_tms    ),
    .jtag_tdi_o    ( jtag_tdi    ),
    .jtag_tdo_i    ( jtag_tdo    ),
    .uart_rx_o     ( uart_rx     ),
    .uart_tx_i     ( uart_tx     ),
    .gpio_out_en_i ( gpio_out_en ),
    .gpio_out_i    ( gpio_out    ),
    .gpio_in_o     ( gpio_in     )
  );

////////////
  //  DUT   //
  ////////////

`ifdef TARGET_NETLIST_OPENROAD
    wire  [GpioCount-1:0] gpio_io_tb;
    logic [GpioCount-1:0] gpio_en_tb;

    // Set port 0-3 to output mode
    // You may need to adjust it for your own tests
    assign gpio_en_tb = 32'h0000_000F;

    for (genvar i = 0; i < GpioCount; i++) begin
        // drive the io pad based on the gpio mode
        assign gpio_io_tb[i] = gpio_en_tb[i] ? 1'bz : gpio_in[i];
    end

    assign gpio_out = gpio_io_tb;

    croc_chip i_croc_soc (
        .clk_i      (sys_clk),
        .testmode_i (1'b0),
        .gpio0_io(gpio_io_tb[0]),
        .gpio1_io(gpio_io_tb[1]),
        .gpio2_io(gpio_io_tb[2]),
        .gpio3_io(gpio_io_tb[3]),
        .gpio4_io(gpio_io_tb[4]),
        .gpio5_io(gpio_io_tb[5]),
        .gpio6_io(gpio_io_tb[6]),
        .gpio7_io(gpio_io_tb[7]),
        .gpio8_io(gpio_io_tb[8]),
        .gpio9_io(gpio_io_tb[9]),
        .gpio10_io(gpio_io_tb[10]),
        .gpio11_io(gpio_io_tb[11]),
        .gpio12_io(gpio_io_tb[12]),
        .gpio13_io(gpio_io_tb[13]),
        .gpio14_io(gpio_io_tb[14]),
        .gpio15_io(gpio_io_tb[15]),
        .gpio16_io(gpio_io_tb[16]),
        .gpio17_io(gpio_io_tb[17]),
        .gpio18_io(gpio_io_tb[18]),
        .gpio19_io(gpio_io_tb[19]),
        .gpio20_io(gpio_io_tb[20]),
        .gpio21_io(gpio_io_tb[21]),
        .gpio22_io(gpio_io_tb[22]),
        .gpio23_io(gpio_io_tb[23]),
        .gpio24_io(gpio_io_tb[24]),
        .gpio25_io(gpio_io_tb[25]),
        .gpio26_io(gpio_io_tb[26]),
        .gpio27_io(gpio_io_tb[27]),
        .gpio28_io(gpio_io_tb[28]),
        .gpio29_io(gpio_io_tb[29]),
        .gpio30_io(gpio_io_tb[30]),
        .gpio31_io(gpio_io_tb[31]),
        .jtag_tck_i (jtag_tck  ),
        .jtag_tdi_i (jtag_tdi  ),
        .jtag_tdo_o (jtag_tdo  ),
        .jtag_tms_i (jtag_tms  ),
        .jtag_trst_ni (jtag_trst_n),
        .ref_clk_i (ref_clk),
        .rst_ni (rst_n),
        .status_o  (         ),
        .uart_rx_i (uart_rx  ),
        .uart_tx_o (uart_tx  )
    );
  `elsif TARGET_NETLIST_YOSYS

    // ---- YOSYS ----
    \croc_soc$croc_chip.i_croc_soc i_croc_soc (
      .clk_i         ( sys_clk     ),
      .rst_ni        ( rst_n       ),
      .ref_clk_i     ( ref_clk     ),
      .testmode_i    ( 1'b0        ),
      .status_o      (             ),
      .jtag_tck_i    ( jtag_tck    ),
      .jtag_tdi_i    ( jtag_tdi    ),
      .jtag_tdo_o    ( jtag_tdo    ),
      .jtag_tms_i    ( jtag_tms    ),
      .jtag_trst_ni  ( jtag_trst_n ),
      .uart_rx_i     ( uart_rx     ),
      .uart_tx_o     ( uart_tx     ),
      .gpio_i        ( gpio_in     ),
      .gpio_o        ( gpio_out    ),
      .gpio_out_en_o ( gpio_out_en )
    );

  `else

    // ---- NORMAL RTL ----
    croc_soc #(
      .GpioCount ( GpioCount )
    ) i_croc_soc (
      .clk_i         ( sys_clk     ),
      .rst_ni        ( rst_n       ),
      .ref_clk_i     ( ref_clk     ),
      .testmode_i    ( 1'b0        ),
      .status_o      (             ),
      .jtag_tck_i    ( jtag_tck    ),
      .jtag_tdi_i    ( jtag_tdi    ),
      .jtag_tdo_o    ( jtag_tdo    ),
      .jtag_tms_i    ( jtag_tms    ),
      .jtag_trst_ni  ( jtag_trst_n ),
      .uart_rx_i     ( uart_rx     ),
      .uart_tx_o     ( uart_tx     ),
      .gpio_i        ( gpio_in     ),
      .gpio_o        ( gpio_out    ),
      .gpio_out_en_o ( gpio_out_en )
    );

  `endif

  /////////////////
  //  Testbench  //
  /////////////////

  logic [31:0] tb_data;
  
  initial begin
    $timeformat(-9, 0, "ns", 12); // 1: scale (ns=-9), 2: decimals, 3: suffix, 4: print-field width

    // wait for reset
    #ClkPeriodSys;

    // init jtag
    i_vip.jtag_init();

    // write test value to sram
    i_vip.jtag_write_reg32(SramBaseAddr, 32'h1234_5678, 1'b1);

    // load binary to sram
    i_vip.jtag_load_hex(binary_path);

    // wake core from WFI by writing to CLINT msip
    $display("@%t | [CORE] Waking core via CLINT msip", $time);
    i_vip.jtag_write_reg32(ClintBaseAddr, 32'h1);

    // halt core
    i_vip.jtag_halt();

    // resume core
    i_vip.jtag_resume();

    // wait for non-zero return value (written into core status register)
    $display("@%t | [CORE] Wait for end of code...", $time);
    i_vip.jtag_wait_for_eoc(tb_data);

    // finish simulation
    repeat(50) @(posedge sys_clk);
    $finish();
  end


  // Only part I've actually modified, changed the waiting time and the dumpvars/file variable to 0 to track everything
  ////////////////
  //  Waveform  //
  ////////////////
  `ifdef TRACE_WAVE
      initial begin
          // wait until VCD dump start time
          #1000000; // wait 1 ms before start dumping, change if you change the CLK
          $display("@%t | [VCD] Start dump", $time);
          `ifdef VERILATOR
          $dumpfile("croc.fst");
          `else
          $dumpfile("croc.vcd");
          `endif
          $dumpvars(0, i_croc_soc);
          // keep dumping for duration X ns
        if ($test$plusargs("power_sim")) begin
            #200000; // dump for 0.2 ms, adjust accordingly as for the delay 
            $display("@%t | [VCD] Stop dump", $time);
            $dumpoff;
            $finish; // finish early when doing power sim
        end
      end
  `endif

  // flush waveform dump when simulation ends
  final begin
    `ifdef TRACE_WAVE
      $dumpflush;
    `endif
  end

endmodule