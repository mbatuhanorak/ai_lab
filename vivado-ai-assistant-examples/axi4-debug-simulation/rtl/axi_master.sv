//------------------------------------------------------------------------------
// Module:      axi_master
// Description: Production-quality AXI4 Full Master DUT (synthesizable SV)
//
//              Implements burst write and burst read transactions exercising
//              the full AXI4 protocol:
//
//                - Multi-beat INCR bursts (AWLEN > 0)
//                - Proper WLAST assertion on the final write data beat
//                - Transaction IDs (AWID / ARID) for routing
//                - AWSIZE / ARSIZE matching the data bus width
//                - Watchdog timer to detect hung buses
//                - Read-back verification with per-beat data checking
//
//              Test Sequence (12 operations — 6 writes + 6 reads):
//
//                Op  Type   Addr          Len  Beats  ID
//                ──  ─────  ──────────    ───  ─────  ──
//                 0  Write  0x4000_0000    7    8      0
//                 1  Write  0x4000_1000   15   16      1
//                 2  Write  0x4000_2000    3    4      2
//                 3  Write  0x4000_3000    0    1      3
//                 4  Write  0x4000_0100    1    2      0
//                 5  Write  0x4000_0200    7    8      1
//                6–11 Read-back verification of ops 0–5
//
//              Total: 39 write beats + 39 read beats = 78 beats
//              Data: formula-based {op[3:0], A, beat, op^beat, C, ~beat}
//
// AXI4 protocol compliance (ARM IHI0022H):
//
//   § A3.3.1  VALID must not depend combinationally on READY.
//   § A3.3.1  Once VALID is asserted it must remain HIGH until READY.
//   § A3.4.1  Write data burst must be exactly AWLEN+1 beats.
//   § A3.4.1  WLAST must be asserted on the final write data beat.
//   § A3.1.2  All outputs LOW during reset.
//   § A3.4.4  Burst must not cross a 4 KB address boundary.
//   § A3.4.2  AWSIZE must not exceed the data bus width.
//
// References:
//   - ARM IHI0022H — AMBA AXI and ACE Protocol Specification
//   - PG267 — AXI Verification IP
//   - PG101 — AXI Protocol Checker
//------------------------------------------------------------------------------

module axi_master #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int ID_WIDTH   = 4
)(
    // Global
    input  logic                        aclk,
    input  logic                        aresetn,

    // Control
    input  logic                        start,
    output logic                        done,
    output logic                        error,

    // AXI4 Write Address Channel (AW)
    output logic [ID_WIDTH-1:0]         m_axi_awid,
    output logic [ADDR_WIDTH-1:0]       m_axi_awaddr,
    output logic [7:0]                  m_axi_awlen,
    output logic [2:0]                  m_axi_awsize,
    output logic [1:0]                  m_axi_awburst,
    output logic                        m_axi_awlock,
    output logic [3:0]                  m_axi_awcache,
    output logic [2:0]                  m_axi_awprot,
    output logic [3:0]                  m_axi_awqos,
    output logic                        m_axi_awvalid,
    input  logic                        m_axi_awready,

    // AXI4 Write Data Channel (W)
    output logic [DATA_WIDTH-1:0]       m_axi_wdata,
    output logic [(DATA_WIDTH/8)-1:0]   m_axi_wstrb,
    output logic                        m_axi_wlast,
    output logic                        m_axi_wvalid,
    input  logic                        m_axi_wready,

    // AXI4 Write Response Channel (B)
    input  logic [ID_WIDTH-1:0]         m_axi_bid,
    input  logic [1:0]                  m_axi_bresp,
    input  logic                        m_axi_bvalid,
    output logic                        m_axi_bready,

    // AXI4 Read Address Channel (AR)
    output logic [ID_WIDTH-1:0]         m_axi_arid,
    output logic [ADDR_WIDTH-1:0]       m_axi_araddr,
    output logic [7:0]                  m_axi_arlen,
    output logic [2:0]                  m_axi_arsize,
    output logic [1:0]                  m_axi_arburst,
    output logic                        m_axi_arlock,
    output logic [3:0]                  m_axi_arcache,
    output logic [2:0]                  m_axi_arprot,
    output logic [3:0]                  m_axi_arqos,
    output logic                        m_axi_arvalid,
    input  logic                        m_axi_arready,

    // AXI4 Read Data Channel (R)
    input  logic [ID_WIDTH-1:0]         m_axi_rid,
    input  logic [DATA_WIDTH-1:0]       m_axi_rdata,
    input  logic [1:0]                  m_axi_rresp,
    input  logic                        m_axi_rlast,
    input  logic                        m_axi_rvalid,
    output logic                        m_axi_rready
);

    localparam int STRB_WIDTH = DATA_WIDTH / 8;

    // =========================================================================
    // Transaction table — 12 operations (6 writes + 6 read-back verifications)
    //
    //   Op  Type   Address       Len  Beats  ID
    //    0  Write  0x4000_0000    7    8      0
    //    1  Write  0x4000_1000   15   16      1
    //    2  Write  0x4000_2000    3    4      2
    //    3  Write  0x4000_3000    0    1      3
    //    4  Write  0x4000_0100    1    2      0
    //    5  Write  0x4000_0200    7    8      1
    //    6  Read   0x4000_0000    7    8      0   (verify op 0)
    //    7  Read   0x4000_1000   15   16      1   (verify op 1)
    //    8  Read   0x4000_2000    3    4      2   (verify op 2)
    //    9  Read   0x4000_3000    0    1      3   (verify op 3)
    //   10  Read   0x4000_0100    1    2      0   (verify op 4)
    //   11  Read   0x4000_0200    7    8      1   (verify op 5)
    //
    // Total: 39 write beats + 39 read beats = 78 beats
    // =========================================================================
    localparam int NUM_OPS    = 12;
    localparam int NUM_WR_OPS = 6;

    logic [3:0]              op_idx_q;
    logic                    cur_is_read;
    logic [ADDR_WIDTH-1:0]   cur_addr;
    logic [7:0]              cur_len;        // AWLEN / ARLEN
    logic [ID_WIDTH-1:0]     cur_id;

    always_comb begin
        cur_is_read = 1'b0;
        cur_addr    = '0;
        cur_len     = 8'd0;
        cur_id      = '0;
        case (op_idx_q)
            4'd0:  begin                     cur_addr = 32'h4000_0000; cur_len = 8'd7;  cur_id = 4'd0; end
            4'd1:  begin                     cur_addr = 32'h4000_1000; cur_len = 8'd15; cur_id = 4'd1; end
            4'd2:  begin                     cur_addr = 32'h4000_2000; cur_len = 8'd3;  cur_id = 4'd2; end
            4'd3:  begin                     cur_addr = 32'h4000_3000; cur_len = 8'd0;  cur_id = 4'd3; end
            4'd4:  begin                     cur_addr = 32'h4000_0100; cur_len = 8'd1;  cur_id = 4'd0; end
            4'd5:  begin                     cur_addr = 32'h4000_0200; cur_len = 8'd7;  cur_id = 4'd1; end
            4'd6:  begin cur_is_read = 1'b1; cur_addr = 32'h4000_0000; cur_len = 8'd7;  cur_id = 4'd0; end
            4'd7:  begin cur_is_read = 1'b1; cur_addr = 32'h4000_1000; cur_len = 8'd15; cur_id = 4'd1; end
            4'd8:  begin cur_is_read = 1'b1; cur_addr = 32'h4000_2000; cur_len = 8'd3;  cur_id = 4'd2; end
            4'd9:  begin cur_is_read = 1'b1; cur_addr = 32'h4000_3000; cur_len = 8'd0;  cur_id = 4'd3; end
            4'd10: begin cur_is_read = 1'b1; cur_addr = 32'h4000_0100; cur_len = 8'd1;  cur_id = 4'd0; end
            4'd11: begin cur_is_read = 1'b1; cur_addr = 32'h4000_0200; cur_len = 8'd7;  cur_id = 4'd1; end
            default: ;
        endcase
    end

    // =========================================================================
    // Formula-based data — unique pattern per (operation, beat)
    //
    //   data = { data_op[3:0], 4'hA, beat[7:0],
    //            data_op[3:0] ^ beat[3:0], 4'hC, ~beat[7:0] }
    //
    // Read ops (6–11) map to write ops (0–5) so expected data matches.
    // =========================================================================
    logic [7:0]              beat_q;         // Current beat index within burst
    logic [DATA_WIDTH-1:0]   cur_beat_wdata;
    logic [DATA_WIDTH-1:0]   cur_beat_expected;

    logic [3:0] data_op;
    assign data_op = cur_is_read ? (op_idx_q - NUM_WR_OPS[3:0]) : op_idx_q;

    assign cur_beat_wdata    = {data_op, 4'hA, beat_q, data_op ^ beat_q[3:0], 4'hC, ~beat_q};
    assign cur_beat_expected = {data_op, 4'hA, beat_q, data_op ^ beat_q[3:0], 4'hC, ~beat_q};

    // =========================================================================
    // FSM
    // =========================================================================
    typedef enum logic [2:0] {
        ST_IDLE,
        ST_DISPATCH,
        ST_WR_ADDR,     // Assert AWVALID
        ST_WR_DATA,     // Send burst data beats (WLAST on last)
        ST_WR_RESP,     // Wait for BVALID
        ST_RD_ADDR,     // Assert ARVALID
        ST_RD_DATA,     // Receive read data beats
        ST_DONE
    } state_e;

    state_e state_q;

    // Error tracking (sticky)
    logic error_resp_q, error_data_q, error_timeout_q;

    // Watchdog
    localparam int WDOG_BITS = 12;
    localparam logic [WDOG_BITS-1:0] WDOG_MAX = {WDOG_BITS{1'b1}};
    logic [WDOG_BITS-1:0] wdog_q;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) wdog_q <= WDOG_MAX;
        else case (state_q)
            ST_IDLE, ST_DISPATCH, ST_DONE: wdog_q <= WDOG_MAX;
            default: if (wdog_q != '0) wdog_q <= wdog_q - 1'b1;
        endcase
    end

    // =========================================================================
    // Main FSM
    // =========================================================================
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            state_q         <= ST_IDLE;
            op_idx_q        <= '0;
            beat_q          <= '0;
            error_resp_q    <= 1'b0;
            error_data_q    <= 1'b0;
            error_timeout_q <= 1'b0;
        end else begin
            case (state_q)
                ST_IDLE: begin
                    if (start) begin
                        state_q  <= ST_DISPATCH;
                        op_idx_q <= '0;
                        error_resp_q <= 1'b0;
                        error_data_q <= 1'b0;
                        error_timeout_q <= 1'b0;
                    end
                end

                ST_DISPATCH: begin
                    if (op_idx_q < NUM_OPS)
                        state_q <= cur_is_read ? ST_RD_ADDR : ST_WR_ADDR;
                    else
                        state_q <= ST_DONE;
                end

                // ----- Write Address Phase -----
                ST_WR_ADDR: begin
                    if (wdog_q == '0) begin
                        error_timeout_q <= 1'b1; state_q <= ST_DONE;
                    end else if (m_axi_awready) begin
                        state_q <= ST_WR_DATA;
                        beat_q  <= '0;
                    end
                end

                // ----- Write Data Phase (burst beats) -----
                // Send AWLEN+1 beats. WLAST on the final beat.
                ST_WR_DATA: begin
                    if (wdog_q == '0) begin
                        error_timeout_q <= 1'b1; state_q <= ST_DONE;
                    end else if (m_axi_wready) begin
                        if (beat_q == cur_len) begin
                            // Last beat accepted → wait for response
                            state_q <= ST_WR_RESP;
                        end else begin
                            beat_q <= beat_q + 1'b1;
                        end
                    end
                end

                // ----- Write Response Phase -----
                ST_WR_RESP: begin
                    if (wdog_q == '0) begin
                        error_timeout_q <= 1'b1; state_q <= ST_DONE;
                    end else if (m_axi_bvalid) begin
                        if (m_axi_bresp != 2'b00)
                            error_resp_q <= 1'b1;
                        op_idx_q <= op_idx_q + 1'b1;
                        state_q  <= ST_DISPATCH;
                    end
                end

                // ----- Read Address Phase -----
                ST_RD_ADDR: begin
                    if (wdog_q == '0) begin
                        error_timeout_q <= 1'b1; state_q <= ST_DONE;
                    end else if (m_axi_arready) begin
                        state_q <= ST_RD_DATA;
                        beat_q  <= '0;
                    end
                end

                // ----- Read Data Phase (burst beats) -----
                ST_RD_DATA: begin
                    if (wdog_q == '0) begin
                        error_timeout_q <= 1'b1; state_q <= ST_DONE;
                    end else if (m_axi_rvalid) begin
                        if (m_axi_rresp != 2'b00)
                            error_resp_q <= 1'b1;
                        if (m_axi_rdata != cur_beat_expected)
                            error_data_q <= 1'b1;
                        if (beat_q == cur_len) begin
                            // Last beat received
                            op_idx_q <= op_idx_q + 1'b1;
                            state_q  <= ST_DISPATCH;
                        end else begin
                            beat_q <= beat_q + 1'b1;
                        end
                    end
                end

                ST_DONE: state_q <= ST_DONE;
                default: state_q <= ST_IDLE;
            endcase
        end
    end

    // =========================================================================
    // Output assignments — from REGISTERED state only (§ A3.3.1)
    // =========================================================================

    // -- Write Address Channel --
    always_comb begin
        m_axi_awid    = '0;
        m_axi_awaddr  = '0;
        m_axi_awlen   = 8'd0;
        m_axi_awsize  = 3'b010;        // 4 bytes (32-bit bus)
        m_axi_awburst = 2'b01;         // INCR
        m_axi_awlock  = 1'b0;          // Normal access
        m_axi_awcache = 4'b0011;       // Normal Non-Cacheable Bufferable
        m_axi_awprot  = 3'b000;        // Unprivileged, Secure, Data
        m_axi_awqos   = 4'd0;
        m_axi_awvalid = 1'b0;

        if (state_q == ST_WR_ADDR) begin
            m_axi_awvalid = 1'b1;
            m_axi_awid    = cur_id;
            m_axi_awaddr  = cur_addr;
            m_axi_awlen   = cur_len;
        end
    end

    // -- Write Data Channel --
    // WLAST is asserted on the final beat (beat_q == cur_len).
    // This is the KEY AXI4 protocol rule for bursts.
    always_comb begin
        m_axi_wdata  = '0;
        m_axi_wstrb  = '0;
        m_axi_wlast  = 1'b0;
        m_axi_wvalid = 1'b0;

        if (state_q == ST_WR_DATA) begin
            m_axi_wvalid = 1'b1;
            m_axi_wdata  = cur_beat_wdata;
            m_axi_wstrb  = {STRB_WIDTH{1'b1}};
            m_axi_wlast  = (beat_q == cur_len);     // Correct: last beat
        end
    end

    // -- Write Response Channel --
    assign m_axi_bready = (state_q == ST_WR_RESP);

    // -- Read Address Channel --
    always_comb begin
        m_axi_arid    = '0;
        m_axi_araddr  = '0;
        m_axi_arlen   = 8'd0;
        m_axi_arsize  = 3'b010;
        m_axi_arburst = 2'b01;
        m_axi_arlock  = 1'b0;
        m_axi_arcache = 4'b0011;
        m_axi_arprot  = 3'b000;
        m_axi_arqos   = 4'd0;
        m_axi_arvalid = 1'b0;

        if (state_q == ST_RD_ADDR) begin
            m_axi_arvalid = 1'b1;
            m_axi_arid    = cur_id;
            m_axi_araddr  = cur_addr;
            m_axi_arlen   = cur_len;
        end
    end

    // -- Read Data Channel --
    assign m_axi_rready = (state_q == ST_RD_DATA);

    // -- Control outputs --
    assign done  = (state_q == ST_DONE);
    assign error = error_resp_q | error_data_q | error_timeout_q;

endmodule
