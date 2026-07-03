// Copyright (C) 2026, Advanced Micro Devices, Inc. All rights reserved.
// SPDX-License-Identifier: MIT

// top_design.sv
// ============================================================================
// Multi-clock domain datapath design for timing closure practice on xcvu5p.
//
// Four functional blocks running on different clock domains:
//   Block A — Single-bit control signal crossing between clk_a and clk_b
//   Block B — 64-bit data pipeline from SLR0 to SLR1 on clk_slr (500 MHz)
//   Block C — Wide enable distribution to 32K loads across SLR0 on clk_a
//   Block D — 12-stage cascaded processing chain on clk_combo (500 MHz)
// ============================================================================

module top_design #(
    parameter DATA_WIDTH   = 64,
    parameter FANOUT_WIDTH = 32768
)(
    input  logic                  sys_clk,     // 100 MHz — MMCM1 reference
    input  logic                  clk_b_ref,   // 100 MHz — MMCM2 reference, independent oscillator
    input  logic                  rst_n,

    input  logic [DATA_WIDTH-1:0] data_in,
    input  logic                  valid_in,

    output logic [DATA_WIDTH-1:0] data_out,
    output logic                  valid_out
);

    // =========================================================================
    // CLOCKING INFRASTRUCTURE — Two Clocking Wizard IPs (MMCM-based)
    // =========================================================================
    // MMCM1 (mmcm1_ip): sys_clk (100 MHz) → clk_a (333.333 MHz)
    //                                      + clk_slr (500 MHz)
    //                                      + clk_combo (500 MHz)
    // MMCM2 (mmcm2_ip): clk_b_ref (100 MHz) → clk_b (350 MHz)
    // =========================================================================

    logic clk_a, clk_b, clk_slr, clk_combo;
    logic mmcm1_locked, mmcm2_locked;

    mmcm1_ip mmcm1_inst (
        .clk_a     (clk_a),
        .clk_slr   (clk_slr),
        .clk_combo (clk_combo),
        .resetn    (rst_n),
        .locked    (mmcm1_locked),
        .clk_in1   (sys_clk)
    );

    mmcm2_ip mmcm2_inst (
        .clk_b   (clk_b),
        .resetn  (rst_n),
        .locked  (mmcm2_locked),
        .clk_in1 (clk_b_ref)
    );

    // =========================================================================
    // BLOCK A: CLOCK DOMAIN CROSSING — clk_a → clk_b
    // =========================================================================

    (* DONT_TOUCH = "true" *) logic cdc_src;

    always_ff @(posedge clk_a or negedge rst_n) begin
        if (!rst_n) cdc_src <= 1'b0;
        else        cdc_src <= valid_in;
    end

    (* DONT_TOUCH = "true" *) logic cdc_dst;

    always_ff @(posedge clk_b or negedge rst_n) begin
        if (!rst_n) cdc_dst <= 1'b0;
        else        cdc_dst <= cdc_src;
    end

    // =========================================================================
    // BLOCK B: SLR CROSSING PIPELINE — SLR0 → SLR1 on clk_slr (500 MHz)
    // =========================================================================

    (* DONT_TOUCH = "true" *) logic [DATA_WIDTH-1:0] slr0_stage0;
    (* DONT_TOUCH = "true" *) logic [DATA_WIDTH-1:0] slr0_stage1;
    (* DONT_TOUCH = "true" *) logic [DATA_WIDTH-1:0] slr0_stage2;
    (* DONT_TOUCH = "true" *) logic                  slr0_valid;

    always_ff @(posedge clk_slr or negedge rst_n) begin
        if (!rst_n) begin
            slr0_stage0 <= '0;
            slr0_valid  <= 1'b0;
        end else begin
            slr0_stage0 <= data_in;
            slr0_valid  <= valid_in;
        end
    end

    always_ff @(posedge clk_slr or negedge rst_n) begin
        if (!rst_n) slr0_stage1 <= '0;
        else        slr0_stage1 <= slr0_stage0 ^ {slr0_stage0[0], slr0_stage0[DATA_WIDTH-1:1]};
    end

    always_ff @(posedge clk_slr or negedge rst_n) begin
        if (!rst_n) slr0_stage2 <= '0;
        else        slr0_stage2 <= slr0_stage1 ^ {slr0_stage1[0], slr0_stage1[DATA_WIDTH-1:1]};
    end

    (* DONT_TOUCH = "true" *) logic [DATA_WIDTH-1:0] slr1_captured;
    (* DONT_TOUCH = "true" *) logic                  slr1_valid;

    always_ff @(posedge clk_slr or negedge rst_n) begin
        if (!rst_n) begin
            slr1_captured <= '0;
            slr1_valid    <= 1'b0;
        end else begin
            slr1_captured <= slr0_stage2;
            slr1_valid    <= slr0_valid;
        end
    end

    // =========================================================================
    // BLOCK C: WIDE ENABLE DISTRIBUTION — 32K loads across SLR0
    // =========================================================================

    localparam LOADS_PER_CORNER = FANOUT_WIDTH / 4;

    (* DONT_TOUCH = "true" *) logic fanout_enable;

    always_ff @(posedge clk_a or negedge rst_n) begin
        if (!rst_n) fanout_enable <= 1'b0;
        else        fanout_enable <= valid_in;
    end

    genvar g;
    generate
        for (g = 0; g < 4; g++) begin : fanout_corner
            (* DONT_TOUCH = "true" *) logic [LOADS_PER_CORNER-1:0] loads;

            always_ff @(posedge clk_a or negedge rst_n) begin
                if (!rst_n) begin
                    loads <= '0;
                end else begin
                    for (int i = 0; i < LOADS_PER_CORNER; i++)
                        loads[i] <= fanout_enable ^ loads[i];
                end
            end
        end
    endgenerate

    // =========================================================================
    // BLOCK D: CASCADED PROCESSING CHAIN — 12 stages on clk_combo (500 MHz)
    // =========================================================================

    (* DONT_TOUCH = "true" *) logic [DATA_WIDTH-1:0] combo_data_in;

    always_ff @(posedge clk_combo or negedge rst_n) begin
        if (!rst_n) combo_data_in <= '0;
        else        combo_data_in <= data_in;
    end

    (* DONT_TOUCH = "true" *) logic [DATA_WIDTH-1:0] combo_seed [0:11];

    always_ff @(posedge clk_combo or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 12; i++) combo_seed[i] <= '0;
        end else begin
            combo_seed[0]  <= data_in ^ {data_in[0],    data_in[DATA_WIDTH-1:1]};
            combo_seed[1]  <= data_in ^ {data_in[1:0],  data_in[DATA_WIDTH-1:2]};
            combo_seed[2]  <= data_in ^ {data_in[2:0],  data_in[DATA_WIDTH-1:3]};
            combo_seed[3]  <= data_in ^ {data_in[3:0],  data_in[DATA_WIDTH-1:4]};
            combo_seed[4]  <= data_in ^ {data_in[4:0],  data_in[DATA_WIDTH-1:5]};
            combo_seed[5]  <= data_in ^ {data_in[5:0],  data_in[DATA_WIDTH-1:6]};
            combo_seed[6]  <= data_in ^ {data_in[6:0],  data_in[DATA_WIDTH-1:7]};
            combo_seed[7]  <= data_in ^ {data_in[7:0],  data_in[DATA_WIDTH-1:8]};
            combo_seed[8]  <= data_in ^ {data_in[8:0],  data_in[DATA_WIDTH-1:9]};
            combo_seed[9]  <= data_in ^ {data_in[9:0],  data_in[DATA_WIDTH-1:10]};
            combo_seed[10] <= data_in ^ {data_in[10:0], data_in[DATA_WIDTH-1:11]};
            combo_seed[11] <= data_in ^ {data_in[11:0], data_in[DATA_WIDTH-1:12]};
        end
    end

    (* KEEP = "true" *) logic [DATA_WIDTH-1:0] chain_0;
    (* KEEP = "true" *) logic [DATA_WIDTH-1:0] chain_1;
    (* KEEP = "true" *) logic [DATA_WIDTH-1:0] chain_2;
    (* KEEP = "true" *) logic [DATA_WIDTH-1:0] chain_3;
    (* KEEP = "true" *) logic [DATA_WIDTH-1:0] chain_4;
    (* KEEP = "true" *) logic [DATA_WIDTH-1:0] chain_5;
    (* KEEP = "true" *) logic [DATA_WIDTH-1:0] chain_6;
    (* KEEP = "true" *) logic [DATA_WIDTH-1:0] chain_7;
    (* KEEP = "true" *) logic [DATA_WIDTH-1:0] chain_8;
    (* KEEP = "true" *) logic [DATA_WIDTH-1:0] chain_9;
    (* KEEP = "true" *) logic [DATA_WIDTH-1:0] chain_10;
    (* KEEP = "true" *) logic [DATA_WIDTH-1:0] chain_11;

    assign chain_0  = combo_data_in ^ combo_seed[0];
    assign chain_1  = chain_0       ^ combo_seed[1];
    assign chain_2  = chain_1       ^ combo_seed[2];
    assign chain_3  = chain_2       ^ combo_seed[3];
    assign chain_4  = chain_3       ^ combo_seed[4];
    assign chain_5  = chain_4       ^ combo_seed[5];
    assign chain_6  = chain_5       ^ combo_seed[6];
    assign chain_7  = chain_6       ^ combo_seed[7];
    assign chain_8  = chain_7       ^ combo_seed[8];
    assign chain_9  = chain_8       ^ combo_seed[9];
    assign chain_10 = chain_9       ^ combo_seed[10];
    assign chain_11 = chain_10      ^ combo_seed[11];

    (* DONT_TOUCH = "true" *) logic [DATA_WIDTH-1:0] combo_result;
    (* DONT_TOUCH = "true" *) logic                  combo_valid;

    always_ff @(posedge clk_combo or negedge rst_n) begin
        if (!rst_n) begin
            combo_result <= '0;
            combo_valid  <= 1'b0;
        end else begin
            combo_result <= chain_11;
            combo_valid  <= 1'b1;
        end
    end

    // =========================================================================
    // OUTPUT
    // =========================================================================

    assign data_out  = slr1_captured
                     ^ fanout_corner[0].loads[DATA_WIDTH-1:0]
                     ^ fanout_corner[1].loads[DATA_WIDTH-1:0]
                     ^ fanout_corner[2].loads[DATA_WIDTH-1:0]
                     ^ fanout_corner[3].loads[DATA_WIDTH-1:0]
                     ^ combo_result;

    assign valid_out = slr1_valid & cdc_dst
                     & fanout_corner[0].loads[LOADS_PER_CORNER-1]
                     & fanout_corner[1].loads[LOADS_PER_CORNER-1]
                     & fanout_corner[2].loads[LOADS_PER_CORNER-1]
                     & fanout_corner[3].loads[LOADS_PER_CORNER-1]
                     & combo_valid;

endmodule
