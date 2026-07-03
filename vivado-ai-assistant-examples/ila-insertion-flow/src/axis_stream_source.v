// Copyright (C) 2026, Advanced Micro Devices, Inc. All rights reserved.
// SPDX-License-Identifier: MIT

`timescale 1ns / 1ps

module axis_stream_source (
    input  wire        aclk,
    input  wire        aresetn,
    // VIO control inputs
    input  wire        stream_enable,
    input  wire [1:0]  pattern_sel,
    // AXI-Stream master interface
    output wire [63:0] m_axis_tdata,
    output wire [7:0]  m_axis_tkeep,
    output wire        m_axis_tvalid,
    output wire        m_axis_tlast,
    input  wire        m_axis_tready,
    // VIO status outputs
    output wire [31:0] packet_count
);

    // Beat counter: counts 0-255 within each packet
    reg [7:0] beat_cnt;
    // Packet counter: increments on each completed packet
    reg [31:0] pkt_cnt;
    // Data generators
    reg [63:0] counter_data;
    reg [63:0] walking_data;
    reg [63:0] prbs_data;

    wire handshake = m_axis_tvalid & m_axis_tready;

    // Beat counter — wraps at 255 to generate tlast
    always @(posedge aclk) begin
        if (!aresetn) begin
            beat_cnt <= 8'd0;
        end else if (handshake) begin
            beat_cnt <= beat_cnt + 8'd1;
        end
    end

    // Packet counter — increments on tlast handshake
    always @(posedge aclk) begin
        if (!aresetn) begin
            pkt_cnt <= 32'd0;
        end else if (handshake && beat_cnt == 8'hFF) begin
            pkt_cnt <= pkt_cnt + 32'd1;
        end
    end

    // Pattern 0: incrementing 64-bit counter
    always @(posedge aclk) begin
        if (!aresetn)
            counter_data <= 64'd0;
        else if (handshake)
            counter_data <= counter_data + 64'd1;
    end

    // Pattern 1: walking-1 (shifts left each beat, wraps)
    always @(posedge aclk) begin
        if (!aresetn)
            walking_data <= 64'd1;
        else if (handshake)
            walking_data <= {walking_data[62:0], walking_data[63]};
    end

    // Pattern 2: XOR-feedback pseudo-random (LFSR-like)
    always @(posedge aclk) begin
        if (!aresetn)
            prbs_data <= 64'hACE1_ACE1_ACE1_ACE1;
        else if (handshake)
            prbs_data <= {prbs_data[62:0], prbs_data[63] ^ prbs_data[62] ^ prbs_data[60] ^ prbs_data[59]};
    end

    // Data pattern mux
    reg [63:0] tdata_mux;
    always @(*) begin
        case (pattern_sel)
            2'b00:   tdata_mux = counter_data;
            2'b01:   tdata_mux = walking_data;
            2'b10:   tdata_mux = prbs_data;
            2'b11:   tdata_mux = 64'hDEADBEEF_CAFEBABE;
            default: tdata_mux = counter_data;
        endcase
    end

    // Output assignments
    assign m_axis_tdata  = tdata_mux;
    assign m_axis_tkeep  = 8'hFF;
    assign m_axis_tvalid = stream_enable & aresetn;
    assign m_axis_tlast  = (beat_cnt == 8'hFF);
    assign packet_count  = pkt_cnt;

endmodule
