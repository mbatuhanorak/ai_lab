// Copyright (C) 2026, Advanced Micro Devices, Inc. All rights reserved.
// SPDX-License-Identifier: MIT

// bram_block.v — Simple dual-port BRAM in READ_FIRST mode
// Infers RAMB36E2 with power optimization opportunity

module bram_block (
    input  wire        clk,
    input  wire        we,
    input  wire [9:0]  addr,
    input  wire [15:0] din,
    output reg  [15:0] dout
);

    (* ram_style = "block" *)
    reg [15:0] mem [0:1023];

    // READ_FIRST mode — opt_design can convert to NO_CHANGE for power savings
    always @(posedge clk) begin
        dout <= mem[addr];
        if (we)
            mem[addr] <= din;
    end

endmodule
