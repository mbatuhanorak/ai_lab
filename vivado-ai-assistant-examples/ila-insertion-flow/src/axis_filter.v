// Copyright (C) 2026, Advanced Micro Devices, Inc. All rights reserved.
// SPDX-License-Identifier: MIT

`timescale 1ns / 1ps

module axis_filter (
    input  wire        aclk,
    input  wire        aresetn,
    // VIO control input
    input  wire        bypass_enable,
    // Slave interface (from upstream)
    input  wire [63:0] s_axis_tdata,
    input  wire [7:0]  s_axis_tkeep,
    input  wire        s_axis_tvalid,
    input  wire        s_axis_tlast,
    output wire        s_axis_tready,
    // Master interface (to downstream)
    output wire [63:0] m_axis_tdata,
    output wire [7:0]  m_axis_tkeep,
    output wire        m_axis_tvalid,
    output wire        m_axis_tlast,
    input  wire        m_axis_tready
);

    // bypass_enable=1: passthrough (default)
    // bypass_enable=0: gate tvalid and tready (stops data flow, backpressures source)
    assign m_axis_tdata  = s_axis_tdata;
    assign m_axis_tkeep  = s_axis_tkeep;
    assign m_axis_tvalid = s_axis_tvalid & bypass_enable;
    assign m_axis_tlast  = s_axis_tlast;
    assign s_axis_tready = m_axis_tready & bypass_enable;

endmodule
