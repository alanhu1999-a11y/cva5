 //
 // Copyright © 2020 Stuart Hoad,  Lesley Shannon
 //
 // Licensed under the Apache License, Version 2.0 (the "License");
 // you may not use this file except in compliance with the License.
 // You may obtain a copy of the License at
 //
 // http://www.apache.org/licenses/LICENSE-2.0
 //
 // Unless required by applicable law or agreed to in writing, software
 // distributed under the License is distributed on an "AS IS" BASIS,
 // WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 // See the License for the specific language governing permissions and
 // limitations under the License.
 //
 // Initial code developed under the supervision of Dr. Lesley Shannon,
 // Reconfigurable Computing Lab, Simon Fraser University.
 //
 // Author(s):
 //             Stuart Hoad <shoad@sfu.ca>
 //

module axi4_basic_props(
    input logic clk,
    input logic rst,
    axi_interface axi_if
    );

//------------------------------------------------------------//
// Declarations

    localparam logic [1:0] MAX_OUTSTANDING = 2'd1;

    logic [1:0] ar_outstanding;
    logic ar_accepted;
    logic r_accepted;
    logic [1:0] ar_outstanding_next;
    logic [5:0] curr_trx_rid;
    logic arvalid_wait;

    logic [1:0] aw_outstanding;
    logic [1:0] w_outstanding;
    logic aw_accepted;
    logic w_accepted;
    logic b_accepted;
    logic [1:0] aw_outstanding_next;
    logic [1:0] w_outstanding_next;
    logic [5:0] curr_trx_wid;
    logic awvalid_wait;
    logic wvalid_wait;

   
//------------------------------------------------------------//
//properties

// read channel
// currently only supports a single read transaction outstanding

    assign ar_accepted = axi_if.arvalid & axi_if.arready;
    assign r_accepted = axi_if.rvalid & axi_if.rready;
    assign arvalid_wait = axi_if.arvalid & !axi_if.arready;

    always_comb begin
        case({r_accepted,ar_accepted})
            2'b00 : ar_outstanding_next = ar_outstanding;
            2'b01 : ar_outstanding_next = ar_outstanding + 1'b1;
            2'b10 : ar_outstanding_next = ar_outstanding - 1'b1;
            2'b11 : ar_outstanding_next = ar_outstanding;
            default : ar_outstanding_next = 'x;
        endcase
    end

    always_ff @(posedge clk) begin
        if(rst)
            ar_outstanding <= '0;
        else
            ar_outstanding <= ar_outstanding_next;
    end

    always @ (posedge clk)
    begin
        if(ar_accepted)
            curr_trx_rid <= axi_if.arid;
    end

    env_no_rresponse_if_no_os: assume property(@(posedge clk) disable iff (rst)
        r_accepted |-> ar_outstanding != '0);

    env_arid_match_rid: assume property(@(posedge clk) disable iff (rst)
        axi_if.rvalid  |-> (axi_if.rid == curr_trx_rid));

    master_arvalid_held_until_ready: assert property(@(posedge clk) disable iff (rst)
        arvalid_wait |=> axi_if.arvalid);

    master_araddr_stable_until_ready: assert property(@(posedge clk) disable iff (rst)
        // ARSIZE and ARCACHE are pending design-owner review because the
        // current RTL does not drive them.
        arvalid_wait |=> $stable({axi_if.araddr, axi_if.arlen,
                                  axi_if.arburst, axi_if.arlock, axi_if.arid}));

    master_read_outstanding_limit: assert property(@(posedge clk) disable iff (rst)
        ar_outstanding <= MAX_OUTSTANDING);

    master_no_second_read_accept: assert property(@(posedge clk) disable iff (rst)
        ar_outstanding == MAX_OUTSTANDING && !r_accepted |-> !ar_accepted);

    helper_read_count_increment: assert property(@(posedge clk) disable iff (rst)
        ar_accepted && !r_accepted
        |=> ar_outstanding == $past(ar_outstanding) + 1'b1);

    helper_read_count_decrement: assert property(@(posedge clk) disable iff (rst)
        !ar_accepted && r_accepted
        |=> ar_outstanding == $past(ar_outstanding) - 1'b1);

    helper_read_count_stable: assert property(@(posedge clk) disable iff (rst)
        ar_accepted == r_accepted
        |=> ar_outstanding == $past(ar_outstanding));
        
                
// write channel
// currently only supports a single write transaction outstanding
// AXI-4 so no leading write data

    assign aw_accepted = axi_if.awvalid & axi_if.awready;
    assign w_accepted = axi_if.wvalid & axi_if.wready;
    assign b_accepted = axi_if.bvalid & axi_if.bready;
    assign awvalid_wait = axi_if.awvalid & !axi_if.awready;
    assign wvalid_wait = axi_if.wvalid & !axi_if.wready;

    always_comb begin
        case({b_accepted,aw_accepted})
            2'b00 : aw_outstanding_next = aw_outstanding;
            2'b01 : aw_outstanding_next = aw_outstanding + 1'b1;
            2'b10 : aw_outstanding_next = aw_outstanding - 1'b1;
            2'b11 : aw_outstanding_next = aw_outstanding;
            default : aw_outstanding_next = 'x;
        endcase
    end

    always_comb begin
        case({b_accepted,w_accepted})
            2'b00 : w_outstanding_next = w_outstanding;
            2'b01 : w_outstanding_next = w_outstanding + 1'b1;
            2'b10 : w_outstanding_next = w_outstanding - 1'b1;
            2'b11 : w_outstanding_next = w_outstanding;
            default : w_outstanding_next = 'x;
        endcase
    end

    always_ff @(posedge clk) begin
        if(rst)
            aw_outstanding <= '0;
        else
            aw_outstanding <= aw_outstanding_next;
    end

    always_ff @(posedge clk) begin
        if(rst)
            w_outstanding <= '0;
        else
            w_outstanding <= w_outstanding_next;
    end

    always @ (posedge clk)
    begin
        if(aw_accepted)
            curr_trx_wid <= axi_if.awid;
    end

    env_no_bresponse_if_no_os: assume property(@(posedge clk) disable iff (rst)
        b_accepted |-> (aw_outstanding != '0) && (w_outstanding != '0));

    env_awid_match_bid: assume property(@(posedge clk) disable iff (rst)
        axi_if.bvalid  |-> (axi_if.bid == curr_trx_wid));

    master_awvalid_held_until_ready: assert property(@(posedge clk) disable iff (rst)
        awvalid_wait |=> axi_if.awvalid);

    master_awaddr_stable_until_ready: assert property(@(posedge clk) disable iff (rst)
        // AWSIZE and AWCACHE are pending design-owner review because the
        // current RTL does not drive them.
        awvalid_wait |=> $stable({axi_if.awaddr, axi_if.awlen,
                                  axi_if.awburst, axi_if.awlock, axi_if.awid}));

    master_wvalid_held_until_ready: assert property(@(posedge clk) disable iff (rst)
        wvalid_wait |=> axi_if.wvalid);

    master_wdata_stable_until_ready: assert property(@(posedge clk) disable iff (rst)
        // WLAST is pending design-owner review because the current RTL does
        // not drive it.
        wvalid_wait |=> $stable({axi_if.wdata, axi_if.wstrb}));

    master_write_address_outstanding_limit: assert property(@(posedge clk) disable iff (rst)
        aw_outstanding <= MAX_OUTSTANDING);

    master_write_data_outstanding_limit: assert property(@(posedge clk) disable iff (rst)
        w_outstanding <= MAX_OUTSTANDING);

    master_no_second_write_address_accept: assert property(@(posedge clk) disable iff (rst)
        aw_outstanding == MAX_OUTSTANDING && !b_accepted |-> !aw_accepted);

    master_no_second_write_data_accept: assert property(@(posedge clk) disable iff (rst)
        w_outstanding == MAX_OUTSTANDING && !b_accepted |-> !w_accepted);

    helper_write_address_count_increment: assert property(@(posedge clk) disable iff (rst)
        aw_accepted && !b_accepted
        |=> aw_outstanding == $past(aw_outstanding) + 1'b1);

    helper_write_address_count_decrement: assert property(@(posedge clk) disable iff (rst)
        !aw_accepted && b_accepted
        |=> aw_outstanding == $past(aw_outstanding) - 1'b1);

    helper_write_address_count_stable: assert property(@(posedge clk) disable iff (rst)
        aw_accepted == b_accepted
        |=> aw_outstanding == $past(aw_outstanding));

    helper_write_data_count_increment: assert property(@(posedge clk) disable iff (rst)
        w_accepted && !b_accepted
        |=> w_outstanding == $past(w_outstanding) + 1'b1);

    helper_write_data_count_decrement: assert property(@(posedge clk) disable iff (rst)
        !w_accepted && b_accepted
        |=> w_outstanding == $past(w_outstanding) - 1'b1);

    helper_write_data_count_stable: assert property(@(posedge clk) disable iff (rst)
        w_accepted == b_accepted
        |=> w_outstanding == $past(w_outstanding));

    // Basic read transaction can complete.
      cover_read_request:
      cover property (@(posedge clk) disable iff (rst)
          ar_accepted);

      cover_read_response:
      cover property (@(posedge clk) disable iff (rst)
          ar_accepted ##[1:8] r_accepted);

      cover_read_outstanding_lifecycle:
      cover property (@(posedge clk) disable iff (rst)
          ar_accepted ##1 (ar_outstanding == 1) ##[1:8] r_accepted
          ##1 (ar_outstanding == 0));

      // Basic write transaction can complete.
      cover_write_address:
      cover property (@(posedge clk) disable iff (rst)
          aw_accepted);

      cover_write_data:
      cover property (@(posedge clk) disable iff (rst)
          w_accepted);

      cover_write_response:
      cover property (@(posedge clk) disable iff (rst)
          aw_accepted ##[0:4] w_accepted ##[1:8] b_accepted);

      cover_write_outstanding_lifecycle:
      cover property (@(posedge clk) disable iff (rst)
          aw_accepted ##[0:4] w_accepted
          ##1 ((aw_outstanding == 1) && (w_outstanding == 1))
          ##[1:8] b_accepted
          ##1 ((aw_outstanding == 0) && (w_outstanding == 0)));
        



endmodule
