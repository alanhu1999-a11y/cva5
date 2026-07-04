// Combined read/write unit-level formal harness for the CVA5 AXI master.

module axi_master_combined_harness
    import riscv_types::*;
#(
    parameter bit BOUND_READY_FOR_COVER = 1'b0
) (
    input logic clk,
    input logic rst,

    input logic        ls_new_request,
    input logic        ls_re,
    input logic        ls_we,
    input logic [31:0] ls_addr,
    input logic [31:0] ls_data_in,
    input logic [3:0]  ls_be,

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

    logic dut_in_ready;
    logic dut_in_requesting_read;
    logic dut_in_waiting_read;
    logic dut_in_requesting_write;
    logic dut_in_waiting_write;

    logic ar_accepted;
    logic r_accepted;
    logic aw_accepted;
    logic w_accepted;
    logic b_accepted;

    logic read_pending;
    logic aw_pending;
    logic w_pending;
    logic write_pending;

    logic read_completion;
    logic write_completion;
    logic r_accepted_q;
    logic b_accepted_q;
    logic read_pending_q;
    logic write_pending_q;
    logic [31:0] rdata_q;

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

    assign ar_accepted = axi_if.arvalid && axi_if.arready;
    assign r_accepted = axi_if.rvalid && axi_if.rready;
    assign aw_accepted = axi_if.awvalid && axi_if.awready;
    assign w_accepted = axi_if.wvalid && axi_if.wready;
    assign b_accepted = axi_if.bvalid && axi_if.bready;

    assign write_pending = aw_pending && w_pending;
    assign read_completion = ls_if.ready && ls_if.data_valid;
    assign write_completion = ls_if.ready && !ls_if.data_valid && write_pending_q;

    always_ff @(posedge clk) begin
        if (rst | !formal_active) begin
            read_pending <= 1'b0;
            aw_pending <= 1'b0;
            w_pending <= 1'b0;
            r_accepted_q <= 1'b0;
            b_accepted_q <= 1'b0;
            read_pending_q <= 1'b0;
            write_pending_q <= 1'b0;
            rdata_q <= '0;
        end else begin
            r_accepted_q <= r_accepted;
            b_accepted_q <= b_accepted;
            read_pending_q <= read_pending;
            write_pending_q <= write_pending;
            rdata_q <= axi_if.rdata;

            unique case ({r_accepted, ar_accepted})
                2'b01: read_pending <= 1'b1;
                2'b10: read_pending <= 1'b0;
                default: read_pending <= read_pending;
            endcase

            if (b_accepted) begin
                aw_pending <= 1'b0;
                w_pending <= 1'b0;
            end else begin
                aw_pending <= aw_pending | aw_accepted;
                w_pending <= w_pending | w_accepted;
            end
        end
    end

    // Legal LSU traffic is one request at a time: either read or write, not
    // both. A simultaneous re/we command is an unsupported environment case.
    env_legal_lsu_request_type: assume property (@(posedge clk) disable iff (rst)
        ls_new_request |-> (ls_if.re ^ ls_if.we));

    env_lsu_request_only_when_ready: assume property (@(posedge clk) disable iff (rst)
        ls_new_request |-> ls_if.ready);

    env_lsu_request_is_a_pulse: assume property (@(posedge clk) disable iff (rst)
        ls_new_request |=> !ls_new_request);

    env_quiet_during_warmup: assume property (@(posedge clk) disable iff (rst)
        !formal_active |-> !ls_new_request && !axi_if.rvalid && !axi_if.bvalid);

    // RREADY/BREADY are tied high by the DUT, so early responses cannot be
    // rejected. Treat impossible responses as AXI slave environment errors.
    env_no_early_read_response: assume property (@(posedge clk) disable iff (rst | !formal_active)
        axi_if.rvalid |-> read_pending);

    env_single_beat_read_response: assume property (@(posedge clk) disable iff (rst | !formal_active)
        axi_if.rvalid |-> axi_if.rlast);

    env_no_early_write_response: assume property (@(posedge clk) disable iff (rst | !formal_active)
        axi_if.bvalid |-> write_pending);

    generate
        if (BOUND_READY_FOR_COVER) begin : gen_cover_bound
            env_bounded_read_address_backpressure: assume property (@(posedge clk) disable iff (rst | !formal_active)
                axi_if.arvalid && !axi_if.arready |-> ##[1:4] axi_if.arready);

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

    assign dut_in_ready = u_dut.current_state == u_dut.READY;
    assign dut_in_requesting_read = u_dut.current_state == u_dut.REQUESTING_READ;
    assign dut_in_waiting_read = u_dut.current_state == u_dut.WAITING_READ;
    assign dut_in_requesting_write = u_dut.current_state == u_dut.REQUESTING_WRITE;
    assign dut_in_waiting_write = u_dut.current_state == u_dut.WAITING_WRITE;

    dut_legal_read_request_enters_requesting_read: assert property (@(posedge clk) disable iff (rst | !formal_active)
        ls_new_request && ls_if.ready && ls_if.re && !ls_if.we |=> dut_in_requesting_read);

    dut_legal_write_request_enters_requesting_write: assert property (@(posedge clk) disable iff (rst | !formal_active)
        ls_new_request && ls_if.ready && ls_if.we && !ls_if.re |=> dut_in_requesting_write);

    dut_request_accepted_only_from_ready_state: assert property (@(posedge clk) disable iff (rst | !formal_active)
        ls_new_request && ls_if.ready |-> dut_in_ready);

    dut_no_simultaneous_read_write_valid: assert property (@(posedge clk) disable iff (rst | !formal_active)
        !(axi_if.arvalid && (axi_if.awvalid || axi_if.wvalid)));

    dut_no_simultaneous_read_write_handshake: assert property (@(posedge clk) disable iff (rst | !formal_active)
        !(ar_accepted && (aw_accepted || w_accepted)));

    dut_no_read_write_pending_overlap: assert property (@(posedge clk) disable iff (rst | !formal_active)
        !(read_pending && write_pending));

    dut_busy_states_hold_ready_low: assert property (@(posedge clk) disable iff (rst | !formal_active)
        (dut_in_requesting_read ||
         dut_in_requesting_write ||
         (dut_in_waiting_read && !axi_if.rvalid) ||
         (dut_in_waiting_write && !axi_if.bvalid)) |-> !ls_if.ready);

    dut_read_request_drives_only_arvalid: assert property (@(posedge clk) disable iff (rst | !formal_active)
        ls_new_request && ls_if.ready && ls_if.re && !ls_if.we
        |=> axi_if.arvalid && !axi_if.awvalid && !axi_if.wvalid);

    dut_write_request_drives_only_aw_wvalid: assert property (@(posedge clk) disable iff (rst | !formal_active)
        ls_new_request && ls_if.ready && ls_if.we && !ls_if.re
        |=> axi_if.awvalid && axi_if.wvalid && !axi_if.arvalid);

    dut_ar_accept_creates_read_pending: assert property (@(posedge clk) disable iff (rst | !formal_active)
        ar_accepted |=> read_pending);

    dut_read_pending_holds_without_r_response: assert property (@(posedge clk) disable iff (rst | !formal_active)
        read_pending && !r_accepted |=> read_pending);

    dut_read_pending_implies_waiting_read: assert property (@(posedge clk) disable iff (rst | !formal_active)
        read_pending |-> dut_in_waiting_read);

    dut_r_response_clears_read_pending: assert property (@(posedge clk) disable iff (rst | !formal_active)
        r_accepted |=> !read_pending);

    dut_r_response_returns_to_ready: assert property (@(posedge clk) disable iff (rst | !formal_active)
        dut_in_waiting_read && r_accepted |=> u_dut.current_state == u_dut.READY);

    dut_read_completion_follows_r_response: assert property (@(posedge clk) disable iff (rst | !formal_active)
        read_completion |-> r_accepted_q && read_pending_q);

    dut_no_read_completion_from_b_response: assert property (@(posedge clk) disable iff (rst | !formal_active)
        read_completion |-> !b_accepted_q);

    dut_rdata_maps_to_ls_data_out: assert property (@(posedge clk) disable iff (rst | !formal_active)
        read_completion |-> ls_if.data_out == rdata_q);

    dut_aw_accept_sets_aw_pending: assert property (@(posedge clk) disable iff (rst | !formal_active)
        aw_accepted && !b_accepted |=> aw_pending);

    dut_w_accept_sets_w_pending: assert property (@(posedge clk) disable iff (rst | !formal_active)
        w_accepted && !b_accepted |=> w_pending);

    dut_aw_w_acceptance_creates_write_pending: assert property (@(posedge clk) disable iff (rst | !formal_active)
        (aw_pending || aw_accepted) && (w_pending || w_accepted) && !b_accepted
        |=> write_pending);

    dut_write_pending_holds_without_b_response: assert property (@(posedge clk) disable iff (rst | !formal_active)
        write_pending && !b_accepted |=> write_pending);

    dut_write_pending_implies_waiting_write: assert property (@(posedge clk) disable iff (rst | !formal_active)
        write_pending |-> dut_in_waiting_write);

    dut_b_response_clears_write_pending: assert property (@(posedge clk) disable iff (rst | !formal_active)
        b_accepted |=> !write_pending);

    dut_b_response_returns_to_ready: assert property (@(posedge clk) disable iff (rst | !formal_active)
        dut_in_waiting_write && b_accepted |=> u_dut.current_state == u_dut.READY);

    dut_write_completion_follows_b_response: assert property (@(posedge clk) disable iff (rst | !formal_active)
        write_completion |-> b_accepted_q && write_pending_q);

    dut_no_write_completion_from_r_response: assert property (@(posedge clk) disable iff (rst | !formal_active)
        write_completion |-> !r_accepted_q);

    dut_b_response_clears_write_outstanding: assert property (@(posedge clk) disable iff (rst | !formal_active)
        dut_in_waiting_write && b_accepted |=> !write_outstanding);

    cover_combined_read_request: cover property (@(posedge clk) disable iff (rst | !formal_active)
        ls_new_request && ls_if.ready && ls_if.re && !ls_if.we);

    cover_combined_write_request: cover property (@(posedge clk) disable iff (rst | !formal_active)
        ls_new_request && ls_if.ready && ls_if.we && !ls_if.re);

    cover_combined_read_lifecycle: cover property (@(posedge clk) disable iff (rst | !formal_active)
        ls_new_request && ls_if.ready && ls_if.re && !ls_if.we ##[1:8]
        ar_accepted ##[1:8]
        r_accepted ##1
        read_completion && !read_pending && u_dut.current_state == u_dut.READY);

    cover_combined_write_lifecycle: cover property (@(posedge clk) disable iff (rst | !formal_active)
        ls_new_request && ls_if.ready && ls_if.we && !ls_if.re ##[1:8]
        aw_pending && w_pending ##[1:8]
        b_accepted ##1
        write_completion && !write_pending && u_dut.current_state == u_dut.READY);

    cover_read_then_write: cover property (@(posedge clk) disable iff (rst | !formal_active)
        read_completion && !read_pending ##[1:8]
        ls_new_request && ls_if.ready && ls_if.we && !ls_if.re ##[1:8]
        write_completion && !write_pending);

    cover_write_then_read: cover property (@(posedge clk) disable iff (rst | !formal_active)
        write_completion && !write_pending ##[1:8]
        ls_new_request && ls_if.ready && ls_if.re && !ls_if.we ##[1:8]
        read_completion && !read_pending);

endmodule

module axi_master_combined_formal_wrapper (
    input logic clk,
    input logic rst,

    input logic        ls_new_request,
    input logic        ls_re,
    input logic        ls_we,
    input logic [31:0] ls_addr,
    input logic [31:0] ls_data_in,
    input logic [3:0]  ls_be,

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

    axi_master_combined_harness #(
        .BOUND_READY_FOR_COVER(1'b0)
    ) u_harness (
        .*
    );

endmodule

module axi_master_combined_cover_wrapper (
    input logic clk,
    input logic rst,

    input logic        ls_new_request,
    input logic        ls_re,
    input logic        ls_we,
    input logic [31:0] ls_addr,
    input logic [31:0] ls_data_in,
    input logic [3:0]  ls_be,

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

    axi_master_combined_harness #(
        .BOUND_READY_FOR_COVER(1'b1)
    ) u_harness (
        .*
    );

endmodule
