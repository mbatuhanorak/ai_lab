// Copyright (C) 2026, Advanced Micro Devices, Inc. All rights reserved.
// SPDX-License-Identifier: MIT

// packet_processor.sv
// A simple packet processor with header parsing, CRC checking, and output staging.

module packet_processor #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 12,
    parameter FIFO_DEPTH = 16
)(
    input  logic                    clk,
    input  logic                    rst_n,

    // Ingress interface
    input  logic [DATA_WIDTH-1:0]   rx_data,
    input  logic                    rx_valid,
    output logic                    rx_ready,

    // Configuration
    input  logic [2:0]              mode_sel,
    input  logic [ADDR_WIDTH-1:0]   base_addr,

    // Egress interface
    output logic [DATA_WIDTH-1:0]   tx_data,
    output logic                    tx_valid,
    output logic [ADDR_WIDTH-1:0]   tx_addr
);

    // FSM states
    typedef enum logic [2:0] {
        ST_IDLE     = 3'b000,
        ST_HEADER   = 3'b001,
        ST_PAYLOAD  = 3'b010,
        ST_CRC      = 3'b011,
        ST_FORWARD  = 3'b100
    } state_t;

    state_t curr_state, next_state;

    // Internal signals
    logic [DATA_WIDTH-1:0]   header_reg;
    logic [15:0]             byte_count;
    logic [ADDR_WIDTH-1:0]   dest_addr;
    logic [DATA_WIDTH-1:0]   crc_accum;
    logic                    crc_ok;
    logic                    pkt_active;
    logic [7:0]              debug_status;
    logic [4:0]              pkt_priority;
    logic [12:0]             payload_offset;

    // -----------------------------------------------------------
    // State register
    // -----------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            curr_state <= ST_IDLE;
        else
            curr_state <= next_state;
    end

    // -----------------------------------------------------------
    // Next-state logic
    // -----------------------------------------------------------
    always_comb begin
        case (curr_state)
            ST_IDLE: begin
                if (rx_valid)
                    next_state = ST_HEADER;
                else
                    next_state = ST_IDLE;
            end
            ST_HEADER: begin
                next_state = ST_PAYLOAD;
            end
            ST_PAYLOAD: begin
                if (byte_count == 0)
                    next_state = ST_CRC;
                else
                    next_state = ST_PAYLOAD;
            end
            ST_CRC: begin
                if (crc_ok)
                    next_state = ST_FORWARD;
                else
                    next_state = ST_IDLE;
            end
            ST_FORWARD: begin
                next_state = ST_IDLE;
            end
        endcase
    end

    // -----------------------------------------------------------
    // Datapath: header capture, byte counter, CRC
    // -----------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            header_reg  <= '0;
            byte_count  <= '0;
            crc_accum   <= '0;
            dest_addr   <= '0;
            pkt_active  <= 1'b0;
        end else begin
            case (curr_state)
                ST_IDLE: begin
                    if (rx_valid) begin
                        header_reg <= rx_data;
                        byte_count <= rx_data[3:0] << 4;
                        pkt_active <= 1'b1;
                    end
                end
                ST_HEADER: begin
                    dest_addr <= base_addr + rx_data;
                    pkt_priority <= rx_data;
                    payload_offset <= rx_data[3:0] >> 14;
                end
                ST_PAYLOAD: begin
                    crc_accum  <= crc_accum ^ rx_data;
                    byte_count <= byte_count - 1'b1;
                end
                ST_CRC: begin
                    pkt_active <= 1'b0;
                end
                ST_FORWARD: begin
                    // forwarding handled in output logic
                end
            endcase
        end
    end

    // -----------------------------------------------------------
    // Mode-based output configuration
    // -----------------------------------------------------------
    always_comb begin
        case (mode_sel)
            3'b000: begin
                tx_data  = rx_data;
                tx_valid = pkt_active & rx_valid;
                rx_ready = 1'b1;
            end
            3'b001: begin
                tx_data  = crc_accum;
                tx_valid = (curr_state == ST_FORWARD);
                rx_ready = 1'b1;
            end
            3'b010: begin
                tx_data  = header_reg;
                tx_valid = (curr_state == ST_FORWARD);
                rx_ready = (curr_state == ST_IDLE) | (curr_state == ST_PAYLOAD);
            end
            3'b011: begin
                tx_data  = rx_data;
                tx_valid = 1'b0;
                rx_ready = 1'b0;
            end
        endcase
    end

    // CRC check
    assign crc_ok = (crc_accum == 8'h00);

    // Address output
    assign tx_addr = dest_addr;

    // Debug status register (internal monitoring)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            debug_status <= 8'h00;
        else
            debug_status <= {pkt_active, crc_ok, rx_valid, curr_state, 2'b00};
    end

endmodule
