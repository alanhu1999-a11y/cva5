// Write-only unit-level formal harness for the CVA5 AXI master.

module axi_master_write_harness
    import riscv_types::*;
#(
    parameter bit BOUND_WRITE_READY_FOR_COVER = 1'b0
) (
    input logic clk,
    input logic rst,

    input logic        ls_new_request,
    input logic [31:0] ls_addr,
    input logic [31:0] ls_data_in,
    input logic [3:0]  ls_be,

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
    logic dut_in_requesting_write;
    logic dut_in_waiting_write;
    logic aw_accepted;
    logic w_accepted;
    logic b_accepted;
    logic aw_pending;
    logic w_pending;
    logic write_pending;
    logic write_completion;
    logic b_accepted_q;
    logic write_pending_q;

    assign ls_if.new_request = ls_new_request;
    assign ls_if.addr = ls_addr;
    assign ls_if.re = 1'b0;
    assign ls_if.we = 1'b1;
    assign ls_if.be = ls_be;
    assign ls_if.data_in = ls_data_in;

    assign amo_if.reservation_valid = 1'b0;
    assign amo_if.rd = '0;

    assign axi_if.awready = axi_awready;
    assign axi_if.wready = axi_wready;
    assign axi_if.bvalid = axi_bvalid;
    assign axi_if.bresp = axi_bresp;
    assign axi_if.bid = axi_bid;
    assign axi_if.arready = 1'b0;
    assign axi_if.rvalid = 1'b0;
    assign axi_if.rdata = '0;
    assign axi_if.rresp = '0;
    assign axi_if.rlast = 1'b0;
    assign axi_if.rid = '0;

    always_ff @(posedge clk) begin
        if (rst)
            formal_active <= 1'b0;
        else
            formal_active <= 1'b1;
    end

    assign aw_accepted = axi_if.awvalid && axi_if.awready;
    assign w_accepted = axi_if.wvalid && axi_if.wready;
    assign b_accepted = axi_if.bvalid && axi_if.bready;
    assign write_pending = aw_pending && w_pending;
    assign write_completion = ls_if.ready;

    always_ff @(posedge clk) begin
        if (rst | !formal_active) begin
            aw_pending <= 1'b0;
            w_pending <= 1'b0;
            b_accepted_q <= 1'b0;
            write_pending_q <= 1'b0;
        end else begin
            b_accepted_q <= b_accepted;
            write_pending_q <= write_pending;
            if (b_accepted) begin
                aw_pending <= 1'b0;
                w_pending <= 1'b0;
            end else begin
                aw_pending <= aw_pending | aw_accepted;
                w_pending <= w_pending | w_accepted;
            end
        end
    end

    env_legal_write_request: assume property (@(posedge clk) disable iff (rst)
        ls_new_request |-> ls_if.ready);

    env_write_request_is_a_pulse: assume property (@(posedge clk) disable iff (rst)
        ls_new_request |=> !ls_new_request);

    env_quiet_during_warmup: assume property (@(posedge clk) disable iff (rst)
        !formal_active |-> !ls_new_request && !axi_bvalid);

    // BREADY is tied high by the DUT, so an early BVALID cannot be rejected.
    // Treat impossible write responses as AXI slave environment errors.
    env_no_early_write_response: assume property (@(posedge clk) disable iff (rst | !formal_active)
        axi_if.bvalid |-> write_pending);

    generate
        if (BOUND_WRITE_READY_FOR_COVER) begin : gen_cover_bound
            env_bounded_write_address_backpressure: assume property (@(posedge clk) disable iff (rst | !formal_active)
                axi_if.awvalid && !axi_if.awready |-> ##[1:4] axi_if.awready);

            env_bounded_write_data_backpressure: assume property (@(posedge clk) disable iff (rst | !formal_active)
                axi_if.wvalid && !axi_if.wready |-> ##[1:4] axi_if.wready);
        end
    endgenerate

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

    assign dut_in_requesting_write = u_dut.current_state == u_dut.REQUESTING_WRITE;
    assign dut_in_waiting_write = u_dut.current_state == u_dut.WAITING_WRITE;

    dut_write_request_enters_requesting_write: assert property (@(posedge clk) disable iff (rst | !formal_active)
        ls_new_request && ls_if.ready |=> dut_in_requesting_write);

    dut_write_request_drives_aw_w_valid: assert property (@(posedge clk) disable iff (rst | !formal_active)
        ls_new_request && ls_if.ready |=> axi_if.awvalid && axi_if.wvalid);

    dut_write_only_no_read_valid: assert property (@(posedge clk) disable iff (rst | !formal_active)
        !axi_if.arvalid);

    dut_awvalid_backpressure_implies_requesting_write: assert property (@(posedge clk) disable iff (rst | !formal_active)
        axi_if.awvalid && !axi_if.awready |-> dut_in_requesting_write);

    dut_requesting_write_holds_awvalid: assert property (@(posedge clk) disable iff (rst | !formal_active)
        dut_in_requesting_write && axi_if.awvalid && !axi_if.awready |=> axi_if.awvalid);

    dut_awvalid_holds_until_ready: assert property (@(posedge clk) disable iff (rst | !formal_active)
        axi_if.awvalid && !axi_if.awready |=> axi_if.awvalid);

    dut_requesting_write_holds_awaddr: assert property (@(posedge clk) disable iff (rst | !formal_active)
        dut_in_requesting_write && axi_if.awvalid && !axi_if.awready
        |=> $stable({axi_if.awaddr, axi_if.awlen, axi_if.awburst,
                     axi_if.awlock, axi_if.awid}));

    dut_awaddr_stable_until_ready: assert property (@(posedge clk) disable iff (rst | !formal_active)
        axi_if.awvalid && !axi_if.awready
        |=> $stable({axi_if.awaddr, axi_if.awlen, axi_if.awburst,
                     axi_if.awlock, axi_if.awid}));

`ifdef AXI_WRITE_INCLUDE_UNDRIVEN_FIELD_CHECKS
    // Review-only checks for AXI fields that are declared as master outputs
    // but are not currently assigned by axi_master.sv.
    dut_aw_full_control_stable_until_ready_review: assert property (@(posedge clk) disable iff (rst | !formal_active)
        axi_if.awvalid && !axi_if.awready
        |=> $stable({axi_if.awaddr, axi_if.awlen, axi_if.awsize,
                     axi_if.awburst, axi_if.awcache, axi_if.awlock,
                     axi_if.awid}));
`endif

    dut_wvalid_backpressure_implies_requesting_write: assert property (@(posedge clk) disable iff (rst | !formal_active)
        axi_if.wvalid && !axi_if.wready |-> dut_in_requesting_write);

    dut_requesting_write_holds_wvalid: assert property (@(posedge clk) disable iff (rst | !formal_active)
        dut_in_requesting_write && axi_if.wvalid && !axi_if.wready |=> axi_if.wvalid);

    dut_wvalid_holds_until_ready: assert property (@(posedge clk) disable iff (rst | !formal_active)
        axi_if.wvalid && !axi_if.wready |=> axi_if.wvalid);

    dut_requesting_write_holds_wdata: assert property (@(posedge clk) disable iff (rst | !formal_active)
        dut_in_requesting_write && axi_if.wvalid && !axi_if.wready
        |=> $stable({axi_if.wdata, axi_if.wstrb}));

    dut_wdata_stable_until_ready: assert property (@(posedge clk) disable iff (rst | !formal_active)
        axi_if.wvalid && !axi_if.wready |=> $stable({axi_if.wdata, axi_if.wstrb}));

`ifdef AXI_WRITE_INCLUDE_UNDRIVEN_FIELD_CHECKS
    // Review-only check for WLAST, which should be a legal single-beat
    // constant if the RTL owner decides to drive it.
    dut_w_full_payload_stable_until_ready_review: assert property (@(posedge clk) disable iff (rst | !formal_active)
        axi_if.wvalid && !axi_if.wready
        |=> $stable({axi_if.wdata, axi_if.wstrb, axi_if.wlast}));
`endif

    dut_aw_accept_sets_aw_pending: assert property (@(posedge clk) disable iff (rst | !formal_active)
        aw_accepted && !b_accepted |=> aw_pending);

    dut_w_accept_sets_w_pending: assert property (@(posedge clk) disable iff (rst | !formal_active)
        w_accepted && !b_accepted |=> w_pending);

    dut_aw_w_acceptance_creates_pending_write: assert property (@(posedge clk) disable iff (rst | !formal_active)
        (aw_pending || aw_accepted) && (w_pending || w_accepted) && !b_accepted
        |=> write_pending);

    dut_write_pending_holds_without_b_response: assert property (@(posedge clk) disable iff (rst | !formal_active)
        write_pending && !b_accepted |=> write_pending);

    dut_write_pending_implies_waiting_write: assert property (@(posedge clk) disable iff (rst | !formal_active)
        write_pending |-> dut_in_waiting_write);

    dut_waiting_write_holds_until_bvalid: assert property (@(posedge clk) disable iff (rst | !formal_active)
        dut_in_waiting_write && !axi_if.bvalid |=> dut_in_waiting_write);

    dut_b_response_clears_pending_write: assert property (@(posedge clk) disable iff (rst | !formal_active)
        b_accepted |=> !write_pending);

    dut_b_response_returns_to_ready: assert property (@(posedge clk) disable iff (rst | !formal_active)
        dut_in_waiting_write && b_accepted |=> u_dut.current_state == u_dut.READY);

    dut_b_response_completes_lsu: assert property (@(posedge clk) disable iff (rst | !formal_active)
        dut_in_waiting_write && b_accepted |=> write_completion);

    dut_write_completion_follows_b_response: assert property (@(posedge clk) disable iff (rst | !formal_active)
        write_completion && write_pending_q |-> b_accepted_q);

    dut_b_response_clears_write_outstanding: assert property (@(posedge clk) disable iff (rst | !formal_active)
        dut_in_waiting_write && b_accepted |=> !write_outstanding);

    cover_write_request: cover property (@(posedge clk) disable iff (rst | !formal_active)
        ls_new_request);

    cover_aw_backpressure: cover property (@(posedge clk) disable iff (rst | !formal_active)
        ls_new_request ##[1:4]
        axi_if.awvalid && !axi_if.awready ##[1:4]
        axi_if.awvalid && axi_if.awready);

    cover_w_backpressure: cover property (@(posedge clk) disable iff (rst | !formal_active)
        ls_new_request ##[1:4]
        axi_if.wvalid && !axi_if.wready ##[1:4]
        axi_if.wvalid && axi_if.wready);

    cover_write_address_data_accept: cover property (@(posedge clk) disable iff (rst | !formal_active)
        ls_new_request && ls_if.ready ##[1:8]
        aw_pending && w_pending);

    cover_write_response_lifecycle: cover property (@(posedge clk) disable iff (rst | !formal_active)
        ls_new_request && ls_if.ready ##[1:8]
        aw_pending && w_pending ##[1:8]
        b_accepted ##1
        write_completion && !write_pending && u_dut.current_state == u_dut.READY);

endmodule

module axi_master_write_formal_wrapper (
    input logic clk,
    input logic rst,

    input logic        ls_new_request,
    input logic [31:0] ls_addr,
    input logic [31:0] ls_data_in,
    input logic [3:0]  ls_be,

    input logic        axi_awready,
    input logic        axi_wready,
    input logic        axi_bvalid,
    input logic [1:0]  axi_bresp,
    input logic [5:0]  axi_bid
);

    axi_master_write_harness #(
        .BOUND_WRITE_READY_FOR_COVER(1'b0)
    ) u_harness (
        .*
    );

endmodule

module axi_master_write_cover_wrapper (
    input logic clk,
    input logic rst,

    input logic        ls_new_request,
    input logic [31:0] ls_addr,
    input logic [31:0] ls_data_in,
    input logic [3:0]  ls_be,

    input logic        axi_awready,
    input logic        axi_wready,
    input logic        axi_bvalid,
    input logic [1:0]  axi_bresp,
    input logic [5:0]  axi_bid
);

    axi_master_write_harness #(
        .BOUND_WRITE_READY_FOR_COVER(1'b1)
    ) u_harness (
        .*
    );

endmodule
