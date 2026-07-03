// Copyright (C) 2026, Advanced Micro Devices, Inc. All rights reserved.
// SPDX-License-Identifier: MIT

// opt_design_demo.v — Design crafted to exercise opt_design optimization phases
//
// This design includes patterns that trigger:
//   1. Retarget       — carry chain with invertable inputs
//   2. Propconst      — constant-tied logic that propagates
//   3. Sweep          — unconnected registers and dead logic
//   4. BUFG insertion — high-fanout clock-enable net
//   5. SRL remap      — shift register chains
//   6. BRAM power opt — dual-port BRAM in READ_FIRST mode
//   7. Control sets   — multiple reset/enable combinations
//   8. DONT_TOUCH     — properties blocking optimization
//   9. MARK_DEBUG     — debug attributes on signals
//  10. Inverter push  — inverted control signals through LUTs

module opt_design_demo (
    input  wire        clk,
    input  wire        rst_n,        // Active-low async reset
    input  wire        rst_p,        // Active-high sync reset (control set frag)
    input  wire        en_global,    // High-fanout enable (triggers BUFG insertion)
    input  wire [15:0] data_in,
    input  wire [3:0]  sel,
    input  wire        wr_en,
    input  wire [9:0]  addr,
    output wire [15:0] data_out,
    output wire [15:0] bram_rdata,
    output wire [7:0]  accum_out,
    output wire        carry_out,
    output wire [3:0]  dead_port     // Port connected to swept logic
);

    // =========================================================================
    // 1. HIGH-FANOUT ENABLE — triggers BUFG insertion (Opt 31-194)
    // =========================================================================
    // en_global drives 256+ loads → opt_design should insert a BUFG
    wire en_fanout;
    assign en_fanout = en_global;

    reg [255:0] fanout_regs;
    integer i;
    always @(posedge clk) begin
        if (!rst_n)
            fanout_regs <= 256'd0;
        else if (en_fanout)
            for (i = 0; i < 256; i = i + 1)
                fanout_regs[i] <= data_in[i % 16];
    end

    // =========================================================================
    // 2. SHIFT REGISTER CHAIN — triggers SRL remap (Opt 31-49, Opt 31-389)
    // =========================================================================
    reg [15:0] srl_chain [0:31];
    always @(posedge clk) begin
        if (en_fanout) begin
            srl_chain[0] <= data_in;
            for (i = 1; i < 32; i = i + 1)
                srl_chain[i] <= srl_chain[i-1];
        end
    end

    // =========================================================================
    // 3. CONSTANT PROPAGATION — triggers propconst (Opt 31-389)
    // =========================================================================
    // Tie some inputs to constants; opt_design should propagate and simplify
    wire [15:0] const_and_result;
    wire [15:0] const_or_result;
    assign const_and_result = data_in & 16'hFF00;  // Lower 8 bits always 0
    assign const_or_result  = data_in | 16'h00FF;  // Lower 8 bits always 1

    reg [15:0] const_prop_reg;
    always @(posedge clk) begin
        if (rst_p)
            const_prop_reg <= 16'd0;
        else
            const_prop_reg <= const_and_result ^ const_or_result;
    end

    // =========================================================================
    // 4. CARRY CHAIN with INVERTED INPUT — triggers retarget + inverter push
    // =========================================================================
    reg [7:0] accumulator;
    wire [7:0] add_operand;
    assign add_operand = ~data_in[7:0];  // Inverted — triggers inverter push

    always @(posedge clk) begin
        if (!rst_n)
            accumulator <= 8'd0;
        else if (en_fanout)
            accumulator <= accumulator + add_operand + 8'd1;
    end
    assign accum_out = accumulator;

    // Extra carry chain with unused carry-out (loadless carry)
    reg [15:0] wide_adder;
    wire       wide_carry;
    always @(posedge clk) begin
        if (!rst_n)
            wide_adder <= 16'd0;
        else
            wide_adder <= wide_adder + {8'd0, ~data_in[7:0]};
    end
    assign carry_out = wide_adder[15]; // Only top bit used

    // =========================================================================
    // 5. DEAD LOGIC / SWEEP TARGETS — triggers sweep (Opt 31-389)
    // =========================================================================
    // Registers that are written but never read → should be swept
    (* DONT_TOUCH = "FALSE" *)
    reg [15:0] dead_reg_a;
    reg [15:0] dead_reg_b;
    reg [7:0]  dead_reg_c;

    always @(posedge clk) begin
        if (!rst_n) begin
            dead_reg_a <= 16'd0;
            dead_reg_b <= 16'd0;
            dead_reg_c <= 8'd0;
        end else begin
            dead_reg_a <= data_in;
            dead_reg_b <= dead_reg_a;           // Chain of dead logic
            dead_reg_c <= dead_reg_b[7:0];
        end
    end
    // dead_reg_c is never read → entire chain should be swept

    // =========================================================================
    // 6. CONTROL SET FRAGMENTATION — multiple reset/enable combos
    // =========================================================================
    // Using different resets and enables creates many control sets
    reg [15:0] cs_reg_a;  // async rst_n, no enable
    reg [15:0] cs_reg_b;  // sync rst_p, en_fanout
    reg [15:0] cs_reg_c;  // async rst_n, en_fanout
    reg [15:0] cs_reg_d;  // no reset, no enable

    always @(posedge clk or negedge rst_n)
        if (!rst_n) cs_reg_a <= 16'd0;
        else        cs_reg_a <= data_in ^ srl_chain[31];

    always @(posedge clk)
        if (rst_p)        cs_reg_b <= 16'd0;
        else if (en_fanout) cs_reg_b <= data_in & srl_chain[15];

    always @(posedge clk or negedge rst_n)
        if (!rst_n)         cs_reg_c <= 16'd0;
        else if (en_fanout) cs_reg_c <= data_in | srl_chain[7];

    always @(posedge clk)
        cs_reg_d <= data_in + const_prop_reg;

    // =========================================================================
    // 7. DONT_TOUCH / MARK_DEBUG — blocking properties
    // =========================================================================
    (* DONT_TOUCH = "TRUE" *)
    reg [7:0] keep_me_reg;
    always @(posedge clk)
        if (!rst_n) keep_me_reg <= 8'd0;
        else        keep_me_reg <= data_in[7:0];

    (* MARK_DEBUG = "TRUE" *)
    reg [7:0] debug_reg;
    always @(posedge clk)
        if (rst_p) debug_reg <= 8'd0;
        else       debug_reg <= accumulator;

    // =========================================================================
    // 8. BRAM — triggers BRAM power optimization
    // =========================================================================
    bram_block u_bram (
        .clk    (clk),
        .we     (wr_en),
        .addr   (addr),
        .din    (data_in),
        .dout   (bram_rdata)
    );

    // =========================================================================
    // 9. MUX TREE — triggers MUXF optimization (Opt 31-1005, 31-1064)
    // =========================================================================
    reg [15:0] mux_result;
    always @(*) begin
        case (sel)
            4'd0:  mux_result = cs_reg_a;
            4'd1:  mux_result = cs_reg_b;
            4'd2:  mux_result = cs_reg_c;
            4'd3:  mux_result = cs_reg_d;
            4'd4:  mux_result = fanout_regs[15:0];
            4'd5:  mux_result = fanout_regs[31:16];
            4'd6:  mux_result = fanout_regs[47:32];
            4'd7:  mux_result = fanout_regs[63:48];
            4'd8:  mux_result = srl_chain[0];
            4'd9:  mux_result = srl_chain[8];
            4'd10: mux_result = srl_chain[16];
            4'd11: mux_result = srl_chain[24];
            4'd12: mux_result = const_prop_reg;
            4'd13: mux_result = {keep_me_reg, debug_reg};
            4'd14: mux_result = wide_adder;
            4'd15: mux_result = {8'd0, accumulator};
        endcase
    end

    assign data_out = mux_result;

    // dead_port driven by disconnected logic (swept)
    assign dead_port = 4'd0; // Tied to constant — outputs still declared

endmodule
