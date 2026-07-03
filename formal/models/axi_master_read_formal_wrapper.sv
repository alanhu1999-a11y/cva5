// Read-only unit-level formal harness for the CVA5 AXI master.

module axi_master_read_harness
    import riscv_types::*;
#(
    parameter bit BOUND_ARREADY_FOR_COVER = 1'b0
) (
    input logic clk,
    input logic rst,

    input logic        ls_new_request,
    input logic [31:0] ls_addr,

    input logic        axi_arready,
    input logic        axi_rvalid,
    input logic [31:0] axi_rdata,
    input logic [1:0]  axi_rresp,
    input logic        axi_rlast,
    input logic [5:0]  axi_rid
);

    axi_interface axi_if();
    amo_interface amo_if();
    memory_sub_unit_interface ls_if();

    logic write_outstanding;
    logic formal_active;
    logic dut_in_requesting_read;
    logic dut_in_waiting_read;
    logic accept_new_lsu_request;
    logic ar_backpressure_seen;
    logic ar_accepted;
    logic r_accepted;
    logic read_pending;
    logic read_completion;
    logic r_accepted_q;
    logic read_pending_q;
    logic [31:0] rdata_q;

    assign ls_if.new_request = ls_new_request;
    assign ls_if.addr = ls_addr;
    assign ls_if.re = 1'b1;
    assign ls_if.we = 1'b0;
    assign ls_if.be = '0;
    assign ls_if.data_in = '0;

    assign amo_if.reservation_valid = 1'b0;
    assign amo_if.rd = '0;

    assign axi_if.arready = axi_arready;
    assign axi_if.rvalid = axi_rvalid;
    assign axi_if.rdata = axi_rdata;
    assign axi_if.rresp = axi_rresp;
    assign axi_if.rlast = axi_rlast;
    assign axi_if.rid = axi_rid;
    assign axi_if.awready = 1'b0;
    assign axi_if.wready = 1'b0;
    assign axi_if.bvalid = 1'b0;
    assign axi_if.bresp = '0;
    assign axi_if.bid = '0;

    always_ff @(posedge clk) begin
        if (rst)
            formal_active <= 1'b0;
        else
            formal_active <= 1'b1;
    end

    always_ff @(posedge clk) begin
        if (rst | !formal_active)
            ar_backpressure_seen <= 1'b0;
        else
            ar_backpressure_seen <= axi_if.arvalid && !axi_if.arready;
    end

    assign ar_accepted = axi_if.arvalid && axi_if.arready;
    assign r_accepted = axi_if.rvalid && axi_if.rready;
    assign read_completion = ls_if.data_valid && ls_if.ready;

    always_ff @(posedge clk) begin
        if (rst | !formal_active) begin
            read_pending <= 1'b0;
        end else begin
            unique case ({r_accepted, ar_accepted})
                2'b01: read_pending <= 1'b1;
                2'b10: read_pending <= 1'b0;
                default: read_pending <= read_pending;
            endcase
        end
    end

    always_ff @(posedge clk) begin
        if (rst | !formal_active) begin
            r_accepted_q <= 1'b0;
            read_pending_q <= 1'b0;
            rdata_q <= '0;
        end else begin
            r_accepted_q <= r_accepted;
            read_pending_q <= read_pending;
            rdata_q <= axi_if.rdata;
        end
    end

    // Read requests are one-cycle commands accepted only while the subunit is
    // ready. The final proof target intentionally does not assume eventual
    // ARREADY; that bound is used only by the cover/debug top.
    env_legal_read_request: assume property (@(posedge clk) disable iff (rst)
        ls_new_request |-> ls_if.ready);

    env_read_request_is_a_pulse: assume property (@(posedge clk) disable iff (rst)
        ls_new_request |=> !ls_new_request);

    env_quiet_during_warmup: assume property (@(posedge clk) disable iff (rst)
        !formal_active |-> !ls_new_request && !axi_rvalid);

    // The DUT ties RREADY high, so an early RVALID cannot be rejected by this
    // master. Treat impossible read responses as AXI slave environment errors.
    env_no_early_read_response: assume property (@(posedge clk) disable iff (rst | !formal_active)
        axi_if.rvalid |-> read_pending);

    env_single_beat_read_response: assume property (@(posedge clk) disable iff (rst | !formal_active)
        axi_if.rvalid |-> axi_if.rlast);

    generate
        if (BOUND_ARREADY_FOR_COVER) begin : gen_cover_bound
            env_bounded_read_address_backpressure: assume property (@(posedge clk) disable iff (rst | !formal_active)
                axi_if.arvalid && !axi_if.arready |-> ##[1:4] axi_if.arready);
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

    assign dut_in_requesting_read = u_dut.current_state == u_dut.REQUESTING_READ;
    assign dut_in_waiting_read = u_dut.current_state == u_dut.WAITING_READ;
    assign accept_new_lsu_request = ls_new_request && ls_if.ready;

    dut_read_request_enters_requesting_read: assert property (@(posedge clk) disable iff (rst | !formal_active)
        ls_new_request && ls_if.ready |=> dut_in_requesting_read);

    dut_requesting_read_waits_for_arready: assert property (@(posedge clk) disable iff (rst | !formal_active)
        dut_in_requesting_read && !axi_if.arready |=> dut_in_requesting_read);

    dut_requesting_read_exits_on_arready: assert property (@(posedge clk) disable iff (rst | !formal_active)
        dut_in_requesting_read && axi_if.arready |=> dut_in_waiting_read);

    dut_requesting_read_drives_arvalid: assert property (@(posedge clk) disable iff (rst | !formal_active)
        dut_in_requesting_read |-> axi_if.arvalid);

    dut_requesting_read_holds_arvalid: assert property (@(posedge clk) disable iff (rst | !formal_active)
        dut_in_requesting_read && !axi_if.arready |=> axi_if.arvalid);

    dut_arvalid_backpressure_implies_requesting_read: assert property (@(posedge clk) disable iff (rst | !formal_active)
        axi_if.arvalid && !axi_if.arready |-> dut_in_requesting_read);

`ifdef AXI_READ_USE_PROVEN_LEMMAS
    // Assume-guarantee cuts. These lemmas must be proven independently under
    // the same read-only harness assumptions before enabling this mode.
    cut_arvalid_backpressure_implies_requesting_read: assume property (@(posedge clk) disable iff (rst | !formal_active)
        axi_if.arvalid && !axi_if.arready |-> dut_in_requesting_read);

    cut_requesting_read_holds_arvalid: assume property (@(posedge clk) disable iff (rst | !formal_active)
        dut_in_requesting_read && !axi_if.arready |=> axi_if.arvalid);
`endif

    dut_requesting_read_holds_araddr: assert property (@(posedge clk) disable iff (rst | !formal_active)
        dut_in_requesting_read && !axi_if.arready
        |=> $stable({axi_if.araddr, axi_if.arlen, axi_if.arburst,
                     axi_if.arlock, axi_if.arid}));

    dut_requesting_read_holds_araddr_only: assert property (@(posedge clk) disable iff (rst | !formal_active)
        dut_in_requesting_read && !axi_if.arready |=> $stable(axi_if.araddr));

    dut_araddr_matches_addr_reg: assert property (@(posedge clk) disable iff (rst | !formal_active)
        axi_if.araddr == {u_dut.addr, 2'b0});

    dut_no_lsu_accept_in_requesting_read: assert property (@(posedge clk) disable iff (rst | !formal_active)
        dut_in_requesting_read |-> !accept_new_lsu_request);

    dut_requesting_read_holds_ready_low: assert property (@(posedge clk) disable iff (rst | !formal_active)
        dut_in_requesting_read |-> !ls_if.ready);

    dut_requesting_read_holds_addr_reg: assert property (@(posedge clk) disable iff (rst | !formal_active)
        dut_in_requesting_read && !axi_if.arready |=> $stable(u_dut.addr));

    dut_requesting_read_holds_addr_reg_explicit: assert property (@(posedge clk) disable iff (rst | !formal_active)
        dut_in_requesting_read && !axi_if.arready |=> u_dut.addr == $past(u_dut.addr));

    dut_requesting_read_holds_arlen: assert property (@(posedge clk) disable iff (rst | !formal_active)
        dut_in_requesting_read && !axi_if.arready |=> $stable(axi_if.arlen));

    dut_requesting_read_holds_arburst: assert property (@(posedge clk) disable iff (rst | !formal_active)
        dut_in_requesting_read && !axi_if.arready |=> $stable(axi_if.arburst));

    dut_requesting_read_holds_arlock: assert property (@(posedge clk) disable iff (rst | !formal_active)
        dut_in_requesting_read && !axi_if.arready |=> $stable(axi_if.arlock));

    dut_requesting_read_holds_arid: assert property (@(posedge clk) disable iff (rst | !formal_active)
        dut_in_requesting_read && !axi_if.arready |=> $stable(axi_if.arid));

    dut_read_request_drives_arvalid: assert property (@(posedge clk) disable iff (rst | !formal_active)
        ls_new_request && ls_if.ready |=> axi_if.arvalid);

    dut_arvalid_holds_until_ready: assert property (@(posedge clk) disable iff (rst | !formal_active)
        axi_if.arvalid && !axi_if.arready |=> axi_if.arvalid);

    debug_arvalid_holds_when_requesting_read: assert property (@(posedge clk) disable iff (rst | !formal_active)
        axi_if.arvalid && !axi_if.arready && u_dut.current_state == u_dut.REQUESTING_READ |=> axi_if.arvalid);

    debug_tracked_arvalid_hold: assert property (@(posedge clk) disable iff (rst | !formal_active)
        ar_backpressure_seen |-> axi_if.arvalid);

    dut_araddr_stable_until_ready: assert property (@(posedge clk) disable iff (rst | !formal_active)
        axi_if.arvalid && !axi_if.arready
        |=> $stable({axi_if.araddr, axi_if.arlen, axi_if.arburst,
                     axi_if.arlock, axi_if.arid}));

    dut_read_only_no_write_valid: assert property (@(posedge clk) disable iff (rst | !formal_active)
        !axi_if.awvalid && !axi_if.wvalid);

    dut_ar_accept_creates_pending_read: assert property (@(posedge clk) disable iff (rst | !formal_active)
        ar_accepted |=> read_pending);

    dut_read_pending_holds_without_r_response: assert property (@(posedge clk) disable iff (rst | !formal_active)
        read_pending && !r_accepted |=> read_pending);

    dut_read_pending_implies_waiting_read: assert property (@(posedge clk) disable iff (rst | !formal_active)
        read_pending |-> dut_in_waiting_read);

    dut_waiting_read_holds_until_rvalid: assert property (@(posedge clk) disable iff (rst | !formal_active)
        dut_in_waiting_read && !axi_if.rvalid |=> dut_in_waiting_read);

    dut_r_response_clears_pending_read: assert property (@(posedge clk) disable iff (rst | !formal_active)
        r_accepted |=> !read_pending);

    dut_r_response_returns_to_ready: assert property (@(posedge clk) disable iff (rst | !formal_active)
        dut_in_waiting_read && r_accepted |=> u_dut.current_state == u_dut.READY);

    dut_r_response_completes_lsu: assert property (@(posedge clk) disable iff (rst | !formal_active)
        dut_in_waiting_read && r_accepted |=> read_completion);

    dut_read_completion_follows_r_response: assert property (@(posedge clk) disable iff (rst | !formal_active)
        read_completion |-> r_accepted_q && read_pending_q);

    dut_rdata_maps_to_ls_data_out: assert property (@(posedge clk) disable iff (rst | !formal_active)
        read_completion |-> ls_if.data_out == rdata_q);

    dut_rvalid_drives_ls_data_valid: assert property (@(posedge clk) disable iff (rst | !formal_active)
        dut_in_waiting_read && r_accepted |=> ls_if.data_valid);

    dut_rvalid_drives_ls_ready: assert property (@(posedge clk) disable iff (rst | !formal_active)
        dut_in_waiting_read && r_accepted |=> ls_if.ready);

    cover_read_request: cover property (@(posedge clk) disable iff (rst | !formal_active)
        ls_new_request);

    cover_read_backpressure: cover property (@(posedge clk) disable iff (rst | !formal_active)
        ls_new_request ##[1:4]
        axi_if.arvalid && !axi_if.arready ##[1:4]
        axi_if.arvalid && axi_if.arready);

    cover_read_response: cover property (@(posedge clk) disable iff (rst | !formal_active)
        ar_accepted ##[1:8] r_accepted);

    cover_read_response_lifecycle: cover property (@(posedge clk) disable iff (rst | !formal_active)
        ls_new_request && ls_if.ready ##[1:8]
        ar_accepted ##[1:8]
        r_accepted ##1
        read_completion && !read_pending && u_dut.current_state == u_dut.READY);

    cover_addr_changes_during_requesting_read_wait: cover property (@(posedge clk) disable iff (rst | !formal_active)
        dut_in_requesting_read && !axi_if.arready ##1 $changed(u_dut.addr));

    cover_cut_violation_arvalid_drop: cover property (@(posedge clk) disable iff (rst | !formal_active)
        axi_if.arvalid && !axi_if.arready ##1 !axi_if.arvalid);

    cover_tracked_arvalid_drop: cover property (@(posedge clk) disable iff (rst | !formal_active)
        ar_backpressure_seen && !axi_if.arvalid);

endmodule

module axi_master_read_formal_wrapper (
    input logic clk,
    input logic rst,

    input logic        ls_new_request,
    input logic [31:0] ls_addr,

    input logic        axi_arready,
    input logic        axi_rvalid,
    input logic [31:0] axi_rdata,
    input logic [1:0]  axi_rresp,
    input logic        axi_rlast,
    input logic [5:0]  axi_rid
);

    axi_master_read_harness #(
        .BOUND_ARREADY_FOR_COVER(1'b0)
    ) u_harness (
        .*
    );

endmodule

module axi_master_read_cover_wrapper (
    input logic clk,
    input logic rst,

    input logic        ls_new_request,
    input logic [31:0] ls_addr,

    input logic        axi_arready,
    input logic        axi_rvalid,
    input logic [31:0] axi_rdata,
    input logic [1:0]  axi_rresp,
    input logic        axi_rlast,
    input logic [5:0]  axi_rid
);

    axi_master_read_harness #(
        .BOUND_ARREADY_FOR_COVER(1'b1)
    ) u_harness (
        .*
    );

endmodule
