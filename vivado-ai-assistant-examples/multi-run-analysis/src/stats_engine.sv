// Copyright (C) 2026, Advanced Micro Devices, Inc. All rights reserved.
// SPDX-License-Identifier: MIT

// stats_engine.sv
// Per-channel statistics: running min, max, IIR moving average, sample counter,
// and a BRAM-based histogram. Creates a mix of LUT-heavy comparison paths and
// BRAM timing paths that stress placement differently than the DSP pipelines.

module stats_engine #(
    parameter DATA_WIDTH = 48,
    parameter HIST_BINS  = 256
)(
    input  logic                          clk,
    input  logic                          rst_n,
    input  logic                          enable,

    input  logic signed [DATA_WIDTH-1:0]  data_in,
    input  logic                          data_valid,

    output logic signed [DATA_WIDTH-1:0]  stat_min,
    output logic signed [DATA_WIDTH-1:0]  stat_max,
    output logic signed [DATA_WIDTH-1:0]  stat_mean,
    output logic [31:0]                   sample_count
);

    // ----------------------------------------------------------------
    // Running min/max — wide comparators (LUT-heavy, carry-chain-heavy)
    // ----------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stat_min <= {1'b0, {(DATA_WIDTH-1){1'b1}}}; // max positive
            stat_max <= {1'b1, {(DATA_WIDTH-1){1'b0}}}; // max negative
        end else if (enable && data_valid) begin
            if (data_in < stat_min)
                stat_min <= data_in;
            if (data_in > stat_max)
                stat_max <= data_in;
        end
    end

    // ----------------------------------------------------------------
    // IIR moving average: mean += (data_in - mean) >>> 4
    // Exponential decay — converges to true mean over time
    // ----------------------------------------------------------------
    logic signed [DATA_WIDTH-1:0] mean_reg;
    logic signed [DATA_WIDTH-1:0] diff;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mean_reg <= '0;
        end else if (enable && data_valid) begin
            diff     = data_in - mean_reg;
            mean_reg <= mean_reg + (diff >>> 4);
        end
    end

    assign stat_mean = mean_reg;

    // ----------------------------------------------------------------
    // Sample counter
    // ----------------------------------------------------------------
    logic [31:0] count;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= '0;
        else if (enable && data_valid)
            count <= count + 1;
    end

    assign sample_count = count;

    // ----------------------------------------------------------------
    // BRAM-based histogram — 256 bins × 32-bit counters
    // Read-modify-write pipeline creates BRAM → LUT → BRAM path
    // that competes with DSP paths for placement resources.
    // ----------------------------------------------------------------
    logic [7:0]  hist_addr_r, hist_addr_rr;
    logic [31:0] hist_mem [HIST_BINS-1:0];
    logic [31:0] hist_rdata;
    logic        hist_valid_r, hist_valid_rr;

    // Pipeline stage 1: compute bin address from data upper bits
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hist_addr_r  <= '0;
            hist_valid_r <= 1'b0;
        end else begin
            hist_addr_r  <= data_in[DATA_WIDTH-1 -: 8]; // top 8 bits as bin
            hist_valid_r <= enable && data_valid;
        end
    end

    // Pipeline stage 2: BRAM read
    always_ff @(posedge clk) begin
        hist_rdata    <= hist_mem[hist_addr_r];
        hist_addr_rr  <= hist_addr_r;
        hist_valid_rr <= hist_valid_r;
    end

    // Pipeline stage 3: BRAM write (increment)
    always_ff @(posedge clk) begin
        if (hist_valid_rr)
            hist_mem[hist_addr_rr] <= hist_rdata + 1;
    end

endmodule
