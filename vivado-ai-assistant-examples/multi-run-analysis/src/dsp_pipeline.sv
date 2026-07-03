// Copyright (C) 2026, Advanced Micro Devices, Inc. All rights reserved.
// SPDX-License-Identifier: MIT

// dsp_pipeline.sv
// A DSP-heavy FIR filter pipeline with pre-adder feedback, configurable
// tap count, and output saturation. Creates multiple arithmetic paths
// that benefit from different placement strategies.
//
// Architecture:
//   data_in → pre-adder (data + feedback) → delay line → multiply × coeff
//   → accumulation chain → saturation → output
//
// Each pipeline instance uses NUM_TAPS DSP48E2 primitives.

module dsp_pipeline #(
    parameter WIDTH      = 18,
    parameter ACC_WIDTH  = 48,
    parameter NUM_TAPS   = 16
)(
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    ce,

    // Data input
    input  logic signed [WIDTH-1:0] data_in,
    input  logic                    data_valid,

    // Coefficient load
    input  logic signed [WIDTH-1:0] coeff_in,
    input  logic [3:0]              coeff_addr,
    input  logic                    coeff_wr,

    // Output
    output logic signed [ACC_WIDTH-1:0] data_out,
    output logic                        data_out_valid,

    // Status
    output logic [3:0]              overflow_flags
);

    // Coefficient storage
    logic signed [WIDTH-1:0] coeffs [NUM_TAPS-1:0];

    // Pre-adder: data_in + feedback from last tap (symmetric FIR structure)
    logic signed [WIDTH:0]   pre_add;
    logic signed [WIDTH-1:0] feedback_reg;

    // Pipeline delay line
    logic signed [WIDTH-1:0] delay_line [NUM_TAPS-1:0];

    // Partial products and accumulator
    logic signed [2*WIDTH-1:0]  products [NUM_TAPS-1:0];
    logic signed [ACC_WIDTH-1:0] accum_chain [NUM_TAPS:0];
    logic [NUM_TAPS-1:0] valid_pipe;

    // Coefficient write
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < NUM_TAPS; i++)
                coeffs[i] <= '0;
        end else if (coeff_wr) begin
            coeffs[coeff_addr] <= coeff_in;
        end
    end

    // Pre-adder — adds feedback from the last tap (symmetric filter optimization)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pre_add      <= '0;
            feedback_reg <= '0;
        end else if (ce && data_valid) begin
            feedback_reg <= delay_line[NUM_TAPS-1];
            pre_add      <= WIDTH'(data_in) + WIDTH'(feedback_reg);
        end
    end

    // Delay line shift register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < NUM_TAPS; i++)
                delay_line[i] <= '0;
        end else if (ce && data_valid) begin
            delay_line[0] <= data_in;
            for (int i = 1; i < NUM_TAPS; i++)
                delay_line[i] <= delay_line[i-1];
        end
    end

    // Multiply stage — uses DSP48 multiplier
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < NUM_TAPS; i++)
                products[i] <= '0;
        end else if (ce) begin
            for (int i = 0; i < NUM_TAPS; i++)
                products[i] <= delay_line[i] * coeffs[i];
        end
    end

    // Accumulation chain — registered per stage (pipelined adder tree)
    assign accum_chain[0] = '0;

    genvar g;
    generate
        for (g = 0; g < NUM_TAPS; g++) begin : acc_stage
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n)
                    accum_chain[g+1] <= '0;
                else if (ce)
                    accum_chain[g+1] <= accum_chain[g] + ACC_WIDTH'(products[g]);
            end
        end
    endgenerate

    // Valid pipeline — tracks data through all stages
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            valid_pipe <= '0;
        else if (ce) begin
            valid_pipe[0] <= data_valid;
            for (int i = 1; i < NUM_TAPS; i++)
                valid_pipe[i] <= valid_pipe[i-1];
        end
    end

    // Output with pre-adder contribution
    logic signed [ACC_WIDTH-1:0] final_accum;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            final_accum <= '0;
        else if (ce)
            final_accum <= accum_chain[NUM_TAPS] + ACC_WIDTH'(pre_add);
    end

    assign data_out       = final_accum;
    assign data_out_valid = valid_pipe[NUM_TAPS-1];

    // Overflow detection on accumulator stages (spread across chain)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            overflow_flags <= '0;
        else if (ce) begin
            overflow_flags[0] <= (accum_chain[4][ACC_WIDTH-1]  != accum_chain[4][ACC_WIDTH-2]);
            overflow_flags[1] <= (accum_chain[8][ACC_WIDTH-1]  != accum_chain[8][ACC_WIDTH-2]);
            overflow_flags[2] <= (accum_chain[12][ACC_WIDTH-1] != accum_chain[12][ACC_WIDTH-2]);
            overflow_flags[3] <= (final_accum[ACC_WIDTH-1]     != final_accum[ACC_WIDTH-2]);
        end
    end

endmodule
