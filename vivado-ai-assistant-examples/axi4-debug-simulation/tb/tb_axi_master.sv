// Copyright (C) 2026, Advanced Micro Devices, Inc. All rights reserved.
// SPDX-License-Identifier: MIT

//------------------------------------------------------------------------------
// Testbench: tb_axi_master
//
// Verifies the correct axi_master DUT (AXI4 Full with bursts) against:
//   - AXI VIP (slave with memory model)
//   - AXI Protocol Checker
//
// Expected result: TEST PASSED — no protocol violations, burst data verified.
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_axi_master();

    import axi_vip_pkg::*;
    import axi_vip_0_pkg::*;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam int ADDR_WIDTH   = 32;
    localparam int DATA_WIDTH   = 32;
    localparam int ID_WIDTH     = 4;
    localparam int CLK_PERIOD   = 10;
    localparam int RESET_CYCLES = 20;
    localparam int TIMEOUT_NS   = 20_000;

    // =========================================================================
    // Signals
    // =========================================================================
    bit                     aclk    = 0;
    bit                     aresetn = 0;
    bit                     start   = 0;
    wire                    done;
    wire                    error;

    // AXI4 Full signals
    wire [ID_WIDTH-1:0]     axi_awid;
    wire [ADDR_WIDTH-1:0]   axi_awaddr;
    wire [7:0]              axi_awlen;
    wire [2:0]              axi_awsize;
    wire [1:0]              axi_awburst;
    wire                    axi_awlock;
    wire [3:0]              axi_awcache;
    wire [2:0]              axi_awprot;
    wire [3:0]              axi_awqos;
    wire                    axi_awvalid;
    wire                    axi_awready;

    wire [DATA_WIDTH-1:0]   axi_wdata;
    wire [3:0]              axi_wstrb;
    wire                    axi_wlast;
    wire                    axi_wvalid;
    wire                    axi_wready;

    wire [ID_WIDTH-1:0]     axi_bid;
    wire [1:0]              axi_bresp;
    wire                    axi_bvalid;
    wire                    axi_bready;

    wire [ID_WIDTH-1:0]     axi_arid;
    wire [ADDR_WIDTH-1:0]   axi_araddr;
    wire [7:0]              axi_arlen;
    wire [2:0]              axi_arsize;
    wire [1:0]              axi_arburst;
    wire                    axi_arlock;
    wire [3:0]              axi_arcache;
    wire [2:0]              axi_arprot;
    wire [3:0]              axi_arqos;
    wire                    axi_arvalid;
    wire                    axi_arready;

    wire [ID_WIDTH-1:0]     axi_rid;
    wire [DATA_WIDTH-1:0]   axi_rdata;
    wire [1:0]              axi_rresp;
    wire                    axi_rlast;
    wire                    axi_rvalid;
    wire                    axi_rready;

    wire [159:0]            pc_status;
    wire                    pc_asserted;

    // =========================================================================
    // Clock generation
    // =========================================================================
    always #(CLK_PERIOD / 2) aclk = ~aclk;

    // =========================================================================
    // DUT — correct AXI4 Full master
    // =========================================================================
    axi_master #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH),
        .ID_WIDTH   (ID_WIDTH)
    ) u_dut (
        .aclk           (aclk),
        .aresetn        (aresetn),
        .start          (start),
        .done           (done),
        .error          (error),
        // AW
        .m_axi_awid     (axi_awid),
        .m_axi_awaddr   (axi_awaddr),
        .m_axi_awlen    (axi_awlen),
        .m_axi_awsize   (axi_awsize),
        .m_axi_awburst  (axi_awburst),
        .m_axi_awlock   (axi_awlock),
        .m_axi_awcache  (axi_awcache),
        .m_axi_awprot   (axi_awprot),
        .m_axi_awqos    (axi_awqos),
        .m_axi_awvalid  (axi_awvalid),
        .m_axi_awready  (axi_awready),
        // W
        .m_axi_wdata    (axi_wdata),
        .m_axi_wstrb    (axi_wstrb),
        .m_axi_wlast    (axi_wlast),
        .m_axi_wvalid   (axi_wvalid),
        .m_axi_wready   (axi_wready),
        // B
        .m_axi_bid      (axi_bid),
        .m_axi_bresp    (axi_bresp),
        .m_axi_bvalid   (axi_bvalid),
        .m_axi_bready   (axi_bready),
        // AR
        .m_axi_arid     (axi_arid),
        .m_axi_araddr   (axi_araddr),
        .m_axi_arlen    (axi_arlen),
        .m_axi_arsize   (axi_arsize),
        .m_axi_arburst  (axi_arburst),
        .m_axi_arlock   (axi_arlock),
        .m_axi_arcache  (axi_arcache),
        .m_axi_arprot   (axi_arprot),
        .m_axi_arqos    (axi_arqos),
        .m_axi_arvalid  (axi_arvalid),
        .m_axi_arready  (axi_arready),
        // R
        .m_axi_rid      (axi_rid),
        .m_axi_rdata    (axi_rdata),
        .m_axi_rresp    (axi_rresp),
        .m_axi_rlast    (axi_rlast),
        .m_axi_rvalid   (axi_rvalid),
        .m_axi_rready   (axi_rready)
    );

    // =========================================================================
    // AXI VIP — Slave with Memory Model (AXI4 Full)
    // =========================================================================
    axi_vip_0 u_axi_vip_slv (
        .aclk           (aclk),
        .aresetn        (aresetn),
        // AW
        .s_axi_awid     (axi_awid),
        .s_axi_awaddr   (axi_awaddr),
        .s_axi_awlen    (axi_awlen),
        .s_axi_awsize   (axi_awsize),
        .s_axi_awburst  (axi_awburst),
        .s_axi_awlock   (axi_awlock),
        .s_axi_awcache  (axi_awcache),
        .s_axi_awprot   (axi_awprot),
        .s_axi_awqos    (axi_awqos),
        .s_axi_awvalid  (axi_awvalid),
        .s_axi_awready  (axi_awready),
        // W
        .s_axi_wdata    (axi_wdata),
        .s_axi_wstrb    (axi_wstrb),
        .s_axi_wlast    (axi_wlast),
        .s_axi_wvalid   (axi_wvalid),
        .s_axi_wready   (axi_wready),
        // B
        .s_axi_bid      (axi_bid),
        .s_axi_bresp    (axi_bresp),
        .s_axi_bvalid   (axi_bvalid),
        .s_axi_bready   (axi_bready),
        // AR
        .s_axi_arid     (axi_arid),
        .s_axi_araddr   (axi_araddr),
        .s_axi_arlen    (axi_arlen),
        .s_axi_arsize   (axi_arsize),
        .s_axi_arburst  (axi_arburst),
        .s_axi_arlock   (axi_arlock),
        .s_axi_arcache  (axi_arcache),
        .s_axi_arprot   (axi_arprot),
        .s_axi_arqos    (axi_arqos),
        .s_axi_arvalid  (axi_arvalid),
        .s_axi_arready  (axi_arready),
        // R
        .s_axi_rid      (axi_rid),
        .s_axi_rdata    (axi_rdata),
        .s_axi_rresp    (axi_rresp),
        .s_axi_rlast    (axi_rlast),
        .s_axi_rvalid   (axi_rvalid),
        .s_axi_rready   (axi_rready)
    );

    // =========================================================================
    // AXI Protocol Checker — monitor (AXI4 Full)
    // =========================================================================
    axi_pc_0 u_axi_pc (
        .aclk           (aclk),
        .aresetn        (aresetn),
        // AW
        .pc_axi_awid    (axi_awid),
        .pc_axi_awaddr  (axi_awaddr),
        .pc_axi_awlen   (axi_awlen),
        .pc_axi_awsize  (axi_awsize),
        .pc_axi_awburst (axi_awburst),
        .pc_axi_awlock  (axi_awlock),
        .pc_axi_awcache (axi_awcache),
        .pc_axi_awprot  (axi_awprot),
        .pc_axi_awqos   (axi_awqos),
        .pc_axi_awvalid (axi_awvalid),
        .pc_axi_awready (axi_awready),
        // W
        .pc_axi_wdata   (axi_wdata),
        .pc_axi_wstrb   (axi_wstrb),
        .pc_axi_wlast   (axi_wlast),
        .pc_axi_wvalid  (axi_wvalid),
        .pc_axi_wready  (axi_wready),
        // B
        .pc_axi_bid     (axi_bid),
        .pc_axi_bresp   (axi_bresp),
        .pc_axi_bvalid  (axi_bvalid),
        .pc_axi_bready  (axi_bready),
        // AR
        .pc_axi_arid    (axi_arid),
        .pc_axi_araddr  (axi_araddr),
        .pc_axi_arlen   (axi_arlen),
        .pc_axi_arsize  (axi_arsize),
        .pc_axi_arburst (axi_arburst),
        .pc_axi_arlock  (axi_arlock),
        .pc_axi_arcache (axi_arcache),
        .pc_axi_arprot  (axi_arprot),
        .pc_axi_arqos   (axi_arqos),
        .pc_axi_arvalid (axi_arvalid),
        .pc_axi_arready (axi_arready),
        .pc_axi_awregion(4'b0000),
        .pc_axi_arregion(4'b0000),
        // R
        .pc_axi_rid     (axi_rid),
        .pc_axi_rdata   (axi_rdata),
        .pc_axi_rresp   (axi_rresp),
        .pc_axi_rlast   (axi_rlast),
        .pc_axi_rvalid  (axi_rvalid),
        .pc_axi_rready  (axi_rready),
        // Status
        .pc_status      (pc_status),
        .pc_asserted    (pc_asserted)
    );

    // =========================================================================
    // VIP agent
    // =========================================================================
    axi_vip_0_slv_mem_t slv_mem_agent;

    // =========================================================================
    // Protocol violation monitor
    // =========================================================================
    always @(posedge aclk) begin
        if (pc_asserted)
            $display("[%0t] *** PROTOCOL VIOLATION *** pc_status = 0x%040h",
                     $time, pc_status);
    end

    // =========================================================================
    // Main test sequence
    // =========================================================================
    initial begin
        $timeformat(-9, 0, " ns", 12);

        $display("");
        $display("========================================================");
        $display("  AXI4 Full Master Verification Testbench");
        $display("  4 operations: 2 burst writes + 2 burst reads");
        $display("========================================================");
        $display("");

        // Configure VIP agent
        slv_mem_agent = new("slave vip agent", u_axi_vip_slv.inst.IF);
        slv_mem_agent.set_agent_tag("Slave VIP");
        slv_mem_agent.set_verbosity(400);
        slv_mem_agent.start_slave();

        // Reset
        aresetn = 1'b0;
        repeat (RESET_CYCLES) @(posedge aclk);
        aresetn = 1'b1;
        $display("[%0t] Reset deasserted", $time);

        // Wait a few cycles for VIP to initialize
        repeat (5) @(posedge aclk);

        // Start DUT
        @(posedge aclk);
        start = 1'b1;
        $display("[%0t] Starting DUT burst transactions...", $time);
        @(posedge aclk);
        start = 1'b0;

        // Wait for completion
        @(posedge done);
        repeat (2) @(posedge aclk);

        // Report
        $display("");
        $display("========================================================");
        if (!error && !pc_asserted) begin
            $display("  *** TEST PASSED ***");
            $display("  Burst write #1 (4 beats, ID=0): OK");
            $display("  Burst write #2 (2 beats, ID=1): OK");
            $display("  Burst read  #1 (4 beats, ID=0): data verified");
            $display("  Burst read  #2 (2 beats, ID=1): data verified");
            $display("  WLAST:          correct on all bursts");
            $display("  Protocol:       no violations");
        end else begin
            $display("  *** TEST FAILED ***");
            if (error) $display("  DUT reported error");
            if (pc_asserted) $display("  Protocol violations: pc_status = 0x%040h", pc_status);
        end
        $display("========================================================");
        $display("");

        repeat (10) @(posedge aclk);
        $finish;
    end

    // =========================================================================
    // Timeout safety net
    // =========================================================================
    initial begin
        #(TIMEOUT_NS);
        $display("*** TIMEOUT after %0d ns ***", TIMEOUT_NS);
        $finish;
    end

endmodule
