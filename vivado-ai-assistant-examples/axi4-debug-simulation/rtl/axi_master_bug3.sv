//------------------------------------------------------------------------------
// Module:      axi_master_bug3
// Description: AXI4 Full Master with burst write/read transactions.
//
//              12 operations: 6 burst writes + 6 read-back verifications.
//              Formula-based data: {op, A, beat, op^beat, C, ~beat}
//
// Reference: ARM IHI0022H — AMBA AXI Protocol Specification
//------------------------------------------------------------------------------

module axi_master_bug3 #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int ID_WIDTH   = 4
)(
    input  logic                        aclk,
    input  logic                        aresetn,
    input  logic                        start,
    output logic                        done,
    output logic                        error,
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
    output logic [DATA_WIDTH-1:0]       m_axi_wdata,
    output logic [(DATA_WIDTH/8)-1:0]   m_axi_wstrb,
    output logic                        m_axi_wlast,
    output logic                        m_axi_wvalid,
    input  logic                        m_axi_wready,
    input  logic [ID_WIDTH-1:0]         m_axi_bid,
    input  logic [1:0]                  m_axi_bresp,
    input  logic                        m_axi_bvalid,
    output logic                        m_axi_bready,
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
    input  logic [ID_WIDTH-1:0]         m_axi_rid,
    input  logic [DATA_WIDTH-1:0]       m_axi_rdata,
    input  logic [1:0]                  m_axi_rresp,
    input  logic                        m_axi_rlast,
    input  logic                        m_axi_rvalid,
    output logic                        m_axi_rready
);
    localparam int STRB_WIDTH = DATA_WIDTH / 8;
    localparam int NUM_OPS    = 12;
    localparam int NUM_WR_OPS = 6;

    // Internal data bus from write FIFO
    logic [DATA_WIDTH-1:0] wdata_from_fifo;

    logic [3:0] op_idx_q;
    logic cur_is_read;
    logic [ADDR_WIDTH-1:0] cur_addr;
    logic [7:0] cur_len;
    logic [ID_WIDTH-1:0] cur_id;

    always_comb begin
        cur_is_read = 1'b0; cur_addr = '0; cur_len = 8'd0; cur_id = '0;
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

    logic [7:0] beat_q;
    logic [DATA_WIDTH-1:0] cur_beat_wdata, cur_beat_expected;

    logic [3:0] data_op;
    assign data_op = cur_is_read ? (op_idx_q - NUM_WR_OPS[3:0]) : op_idx_q;
    assign cur_beat_wdata    = {data_op, 4'hA, beat_q, data_op ^ beat_q[3:0], 4'hC, ~beat_q};
    assign cur_beat_expected = {data_op, 4'hA, beat_q, data_op ^ beat_q[3:0], 4'hC, ~beat_q};

    // FSM
    typedef enum logic [2:0] {
        ST_IDLE, ST_DISPATCH, ST_WR_ADDR, ST_WR_DATA,
        ST_WR_RESP, ST_RD_ADDR, ST_RD_DATA, ST_DONE
    } state_e;
    state_e state_q;
    logic error_resp_q, error_data_q, error_timeout_q;
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

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            state_q <= ST_IDLE; op_idx_q <= '0; beat_q <= '0;
            error_resp_q <= 1'b0; error_data_q <= 1'b0; error_timeout_q <= 1'b0;
        end else begin
            case (state_q)
                ST_IDLE: if (start) begin
                    state_q <= ST_DISPATCH; op_idx_q <= '0;
                    error_resp_q <= 1'b0; error_data_q <= 1'b0; error_timeout_q <= 1'b0;
                end
                ST_DISPATCH: if (op_idx_q < NUM_OPS) state_q <= cur_is_read ? ST_RD_ADDR : ST_WR_ADDR;
                             else state_q <= ST_DONE;
                ST_WR_ADDR: begin
                    if (wdog_q == '0) begin error_timeout_q <= 1'b1; state_q <= ST_DONE; end
                    else if (m_axi_awready) begin state_q <= ST_WR_DATA; beat_q <= '0; end
                end
                ST_WR_DATA: begin
                    if (wdog_q == '0) begin error_timeout_q <= 1'b1; state_q <= ST_DONE; end
                    else if (m_axi_wready) begin
                        if (beat_q == cur_len) state_q <= ST_WR_RESP;
                        else beat_q <= beat_q + 1'b1;
                    end
                end
                ST_WR_RESP: begin
                    if (wdog_q == '0) begin error_timeout_q <= 1'b1; state_q <= ST_DONE; end
                    else if (m_axi_bvalid) begin
                        if (m_axi_bresp != 2'b00) error_resp_q <= 1'b1;
                        op_idx_q <= op_idx_q + 1'b1; state_q <= ST_DISPATCH;
                    end
                end
                ST_RD_ADDR: begin
                    if (wdog_q == '0) begin error_timeout_q <= 1'b1; state_q <= ST_DONE; end
                    else if (m_axi_arready) begin state_q <= ST_RD_DATA; beat_q <= '0; end
                end
                ST_RD_DATA: begin
                    if (wdog_q == '0) begin error_timeout_q <= 1'b1; state_q <= ST_DONE; end
                    else if (m_axi_rvalid) begin
                        if (m_axi_rresp != 2'b00) error_resp_q <= 1'b1;
                        if (m_axi_rdata != cur_beat_expected) error_data_q <= 1'b1;
                        if (beat_q == cur_len) begin op_idx_q <= op_idx_q + 1'b1; state_q <= ST_DISPATCH; end
                        else beat_q <= beat_q + 1'b1;
                    end
                end
                ST_DONE: state_q <= ST_DONE;
                default: state_q <= ST_IDLE;
            endcase
        end
    end

    // AW channel
    always_comb begin
        m_axi_awid = '0; m_axi_awaddr = '0; m_axi_awlen = 8'd0;
        m_axi_awsize = 3'b010; m_axi_awburst = 2'b01; m_axi_awlock = 1'b0;
        m_axi_awcache = 4'b0011; m_axi_awprot = 3'b000; m_axi_awqos = 4'd0;
        m_axi_awvalid = 1'b0;
        if (state_q == ST_WR_ADDR) begin
            m_axi_awvalid = 1'b1; m_axi_awid = cur_id;
            m_axi_awaddr = cur_addr; m_axi_awlen = cur_len;
        end
    end

    // W channel
    always_comb begin
        m_axi_wdata = '0; m_axi_wstrb = '0; m_axi_wlast = 1'b0; m_axi_wvalid = 1'b0;
        if (state_q == ST_WR_DATA) begin
            m_axi_wvalid = 1'b1;
            m_axi_wdata  = wdata_from_fifo;
            m_axi_wstrb  = {STRB_WIDTH{1'b1}};
            m_axi_wlast  = (beat_q == cur_len);
        end
    end

    assign m_axi_bready = (state_q == ST_WR_RESP);

    // AR channel
    always_comb begin
        m_axi_arid = '0; m_axi_araddr = '0; m_axi_arlen = 8'd0;
        m_axi_arsize = 3'b010; m_axi_arburst = 2'b01; m_axi_arlock = 1'b0;
        m_axi_arcache = 4'b0011; m_axi_arprot = 3'b000; m_axi_arqos = 4'd0;
        m_axi_arvalid = 1'b0;
        if (state_q == ST_RD_ADDR) begin
            m_axi_arvalid = 1'b1; m_axi_arid = cur_id;
            m_axi_araddr = cur_addr; m_axi_arlen = cur_len;
        end
    end

    assign m_axi_rready = (state_q == ST_RD_DATA);
    assign done  = (state_q == ST_DONE);
    assign error = error_resp_q | error_data_q | error_timeout_q;

endmodule
