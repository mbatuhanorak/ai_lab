// Copyright (C) 2026, Advanced Micro Devices, Inc. All rights reserved.
// SPDX-License-Identifier: MIT

// multi_channel_processor.sv
// Top-level: 8 parallel DSP pipeline channels with crossbar routing,
// per-channel statistics engines, and a configuration register bank.
// Creates significant logic + routing pressure for meaningful strategy comparison.
//
// Resource mix (creates differentiation between strategies):
//   - 128 DSP48E2 (8 channels × 16-tap FIR filters)
//   - 8 BRAMs (per-channel histogram in stats engines)
//   - ~4K LUTs (crossbar, stats comparators, config fanout)
//   - ~6K FFs (pipeline registers, config bank, stats accumulators)

module multi_channel_processor #(
    parameter NUM_CHANNELS = 8,
    parameter DATA_WIDTH   = 18,
    parameter ACC_WIDTH    = 48,
    parameter NUM_TAPS     = 16,
    parameter NUM_CONFIGS  = 32
)(
    input  logic                          clk,
    input  logic                          rst_n,

    // Per-channel data input
    input  logic signed [DATA_WIDTH-1:0]  ch_data_in  [NUM_CHANNELS-1:0],
    input  logic [NUM_CHANNELS-1:0]       ch_valid_in,

    // Coefficient broadcast (shared bus — one channel at a time)
    input  logic signed [DATA_WIDTH-1:0]  coeff_data,
    input  logic [3:0]                    coeff_addr,   // 16 taps
    input  logic [2:0]                    coeff_ch_sel, // 8 channels
    input  logic                          coeff_wr,

    // Crossbar control
    input  logic [2:0]                    xbar_src [NUM_CHANNELS-1:0],

    // Configuration register bank
    input  logic [4:0]                    cfg_addr,
    input  logic [31:0]                   cfg_wdata,
    input  logic                          cfg_wr,
    output logic [31:0]                   cfg_rdata,

    // Per-channel output (post-crossbar)
    output logic signed [ACC_WIDTH-1:0]   ch_data_out [NUM_CHANNELS-1:0],
    output logic [NUM_CHANNELS-1:0]       ch_valid_out,
    output logic [NUM_CHANNELS-1:0]       ch_overflow,

    // Statistics readback (selected channel)
    input  logic [2:0]                    stat_ch_sel,
    output logic signed [ACC_WIDTH-1:0]   stat_min_out,
    output logic signed [ACC_WIDTH-1:0]   stat_max_out,
    output logic signed [ACC_WIDTH-1:0]   stat_mean_out,
    output logic [31:0]                   stat_count_out
);

    // ----------------------------------------------------------------
    // Configuration register bank — high-fanout broadcast
    // ----------------------------------------------------------------
    // cfg[0]  = channel enable mask [7:0]
    // cfg[1]  = stats enable mask [7:0]
    // cfg[2]  = crossbar bypass (1 = straight-through, no mux)
    // cfg[3]  = global gain shift [3:0]
    // cfg[4:7] = reserved
    logic [31:0] cfg_regs [NUM_CONFIGS-1:0];
    logic [NUM_CHANNELS-1:0] ch_enable;
    logic [NUM_CHANNELS-1:0] stats_enable;
    logic                    xbar_bypass;
    logic [3:0]              gain_shift;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < NUM_CONFIGS; i++)
                cfg_regs[i] <= '0;
            cfg_regs[0] <= 32'h0000_00FF; // all channels enabled
            cfg_regs[1] <= 32'h0000_00FF; // all stats enabled
        end else if (cfg_wr) begin
            cfg_regs[cfg_addr] <= cfg_wdata;
        end
    end

    assign cfg_rdata    = cfg_regs[cfg_addr];
    assign ch_enable    = cfg_regs[0][NUM_CHANNELS-1:0];
    assign stats_enable = cfg_regs[1][NUM_CHANNELS-1:0];
    assign xbar_bypass  = cfg_regs[2][0];
    assign gain_shift   = cfg_regs[3][3:0];

    // ----------------------------------------------------------------
    // DSP pipeline instances (128 DSP48E2s total)
    // ----------------------------------------------------------------
    logic signed [ACC_WIDTH-1:0] pipe_out   [NUM_CHANNELS-1:0];
    logic [NUM_CHANNELS-1:0]     pipe_valid;
    logic [3:0]                  pipe_oflow [NUM_CHANNELS-1:0];

    genvar ch;
    generate
        for (ch = 0; ch < NUM_CHANNELS; ch++) begin : channel
            dsp_pipeline #(
                .WIDTH     (DATA_WIDTH),
                .ACC_WIDTH (ACC_WIDTH),
                .NUM_TAPS  (NUM_TAPS)
            ) u_dsp (
                .clk            (clk),
                .rst_n          (rst_n),
                .ce             (ch_enable[ch]),
                .data_in        (ch_data_in[ch]),
                .data_valid     (ch_valid_in[ch]),
                .coeff_in       (coeff_data),
                .coeff_addr     (coeff_addr),
                .coeff_wr       (coeff_wr && (coeff_ch_sel == ch[2:0])),
                .data_out       (pipe_out[ch]),
                .data_out_valid (pipe_valid[ch]),
                .overflow_flags (pipe_oflow[ch])
            );
        end
    endgenerate

    // ----------------------------------------------------------------
    // Gain scaling — apply configurable shift (high-fanout from cfg_regs[3])
    // ----------------------------------------------------------------
    logic signed [ACC_WIDTH-1:0] scaled_out [NUM_CHANNELS-1:0];
    logic [NUM_CHANNELS-1:0]     scaled_valid;

    always_ff @(posedge clk) begin
        for (int i = 0; i < NUM_CHANNELS; i++) begin
            scaled_out[i]   <= pipe_out[i] >>> gain_shift;
            scaled_valid[i] <= pipe_valid[i];
        end
    end

    // ----------------------------------------------------------------
    // 8×8 Output crossbar — pipelined for timing
    // ----------------------------------------------------------------
    logic signed [ACC_WIDTH-1:0] xbar_out   [NUM_CHANNELS-1:0];
    logic [NUM_CHANNELS-1:0]     xbar_valid;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < NUM_CHANNELS; i++) begin
                xbar_out[i]   <= '0;
                xbar_valid[i] <= 1'b0;
            end
        end else begin
            for (int i = 0; i < NUM_CHANNELS; i++) begin
                if (xbar_bypass) begin
                    xbar_out[i]   <= scaled_out[i];
                    xbar_valid[i] <= scaled_valid[i];
                end else begin
                    xbar_out[i]   <= scaled_out[xbar_src[i]];
                    xbar_valid[i] <= scaled_valid[xbar_src[i]];
                end
            end
        end
    end

    // ----------------------------------------------------------------
    // Output saturation — clamp to signed range [-(2^31), 2^31-1]
    // Creates carry-chain-heavy comparison logic
    // ----------------------------------------------------------------
    localparam logic signed [ACC_WIDTH-1:0] SAT_MAX =  (1 <<< 31) - 1;
    localparam logic signed [ACC_WIDTH-1:0] SAT_MIN = -(1 <<< 31);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < NUM_CHANNELS; i++) begin
                ch_data_out[i]  <= '0;
                ch_valid_out[i] <= 1'b0;
                ch_overflow[i]  <= 1'b0;
            end
        end else begin
            for (int i = 0; i < NUM_CHANNELS; i++) begin
                ch_valid_out[i] <= xbar_valid[i];
                if (xbar_out[i] > SAT_MAX) begin
                    ch_data_out[i] <= SAT_MAX;
                    ch_overflow[i] <= 1'b1;
                end else if (xbar_out[i] < SAT_MIN) begin
                    ch_data_out[i] <= SAT_MIN;
                    ch_overflow[i] <= 1'b1;
                end else begin
                    ch_data_out[i] <= xbar_out[i];
                    ch_overflow[i] <= 1'b0;
                end
            end
        end
    end

    // ----------------------------------------------------------------
    // Per-channel statistics engines (8 × BRAM + comparators)
    // ----------------------------------------------------------------
    logic signed [ACC_WIDTH-1:0] s_min  [NUM_CHANNELS-1:0];
    logic signed [ACC_WIDTH-1:0] s_max  [NUM_CHANNELS-1:0];
    logic signed [ACC_WIDTH-1:0] s_mean [NUM_CHANNELS-1:0];
    logic [31:0]                 s_cnt  [NUM_CHANNELS-1:0];

    generate
        for (ch = 0; ch < NUM_CHANNELS; ch++) begin : stats
            stats_engine #(
                .DATA_WIDTH (ACC_WIDTH)
            ) u_stats (
                .clk          (clk),
                .rst_n        (rst_n),
                .enable       (stats_enable[ch]),
                .data_in      (xbar_out[ch]),
                .data_valid   (xbar_valid[ch]),
                .stat_min     (s_min[ch]),
                .stat_max     (s_max[ch]),
                .stat_mean    (s_mean[ch]),
                .sample_count (s_cnt[ch])
            );
        end
    endgenerate

    // Stats output mux
    assign stat_min_out   = s_min[stat_ch_sel];
    assign stat_max_out   = s_max[stat_ch_sel];
    assign stat_mean_out  = s_mean[stat_ch_sel];
    assign stat_count_out = s_cnt[stat_ch_sel];

endmodule
