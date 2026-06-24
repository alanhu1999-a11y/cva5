// Unit-level formal harness for the CVA5 AXI master.

module axi_master_formal_wrapper
    import riscv_types::*;
(
    input logic clk,
    input logic rst,

    input logic        ls_new_request,
    input logic [31:0] ls_addr,
    input logic        ls_re,
    input logic        ls_we,
    input logic [3:0]  ls_be,
    input logic [31:0] ls_data_in,

    input logic        axi_arready,
    input logic        axi_rvalid,
    input logic [31:0] axi_rdata,
    input logic [1:0]  axi_rresp,
    input logic        axi_rlast,
    input logic [5:0]  axi_rid,
    input logic        axi_awready,
    input logic        axi_wready,
    input logic        axi_bvalid,
    input logic [1:0]  axi_bresp,
    input logic [5:0]  axi_bid
);

    axi_interface axi_if();
    amo_interface amo_if();
    memory_sub_unit_interface ls_if();

    logic write_outstanding;
    logic formal_active;

    assign ls_if.new_request = ls_new_request;
    assign ls_if.addr = ls_addr;
    assign ls_if.re = ls_re;
    assign ls_if.we = ls_we;
    assign ls_if.be = ls_be;
    assign ls_if.data_in = ls_data_in;

    assign amo_if.reservation_valid = 1'b0;
    assign amo_if.rd = '0;

    assign axi_if.arready = axi_arready;
    assign axi_if.rvalid = axi_rvalid;
    assign axi_if.rdata = axi_rdata;
    assign axi_if.rresp = axi_rresp;
    assign axi_if.rlast = axi_rlast;
    assign axi_if.rid = axi_rid;
    assign axi_if.awready = axi_awready;
    assign axi_if.wready = axi_wready;
    assign axi_if.bvalid = axi_bvalid;
    assign axi_if.bresp = axi_bresp;
    assign axi_if.bid = axi_bid;

    always_ff @(posedge clk) begin
        if (rst)
            formal_active <= 1'b0;
        else
            formal_active <= 1'b1;
    end

    // Requests are one-cycle commands accepted only while the subunit is ready.
    env_legal_request: assume property (@(posedge clk) disable iff (rst)
        ls_new_request |-> (ls_re ^ ls_we) && ls_if.ready);

    env_request_is_a_pulse: assume property (@(posedge clk) disable iff (rst)
        ls_new_request |=> !ls_new_request);

    env_quiet_during_warmup: assume property (@(posedge clk) disable iff (rst)
        !formal_active |-> !ls_new_request && !axi_rvalid && !axi_bvalid);

    env_bounded_read_address_backpressure: assume property (@(posedge clk) disable iff (rst | !formal_active)
        axi_if.arvalid && !axi_if.arready |-> ##[1:4] axi_if.arready);

    axi_master u_dut (
        .clk,
        .rst,
        .write_outstanding,
        .m_axi         (axi_if),
        .amo           (1'b0),
        .amo_type      (AMO_ADD_FN5),
        .amo_unit      (amo_if),
        .ls            (ls_if)
    );

    axi4_basic_props u_axi_props (
        .clk,
        .rst    (rst | !formal_active),
        .axi_if (axi_if)
    );

    dut_arvalid_holds_until_ready: assert property (@(posedge clk) disable iff (rst | !formal_active)
        axi_if.arvalid && !axi_if.arready |=> axi_if.arvalid);

    cover_read_request: cover property (@(posedge clk) disable iff (rst | !formal_active)
        ls_new_request && ls_re);

    cover_read_backpressure: cover property (@(posedge clk) disable iff (rst | !formal_active)
        ls_new_request && ls_re ##[1:4]
        axi_if.arvalid && !axi_if.arready ##[1:4]
        axi_if.arvalid && axi_if.arready);

    cover_write_request: cover property (@(posedge clk) disable iff (rst | !formal_active)
        ls_new_request && ls_we);

endmodule
