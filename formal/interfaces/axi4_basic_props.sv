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

import cva5_config::*;
import cva5_types::*;

module axi4_basic_props(
    input logic clk,
    input logic rst,
    axi_interface axi_if
    );

//------------------------------------------------------------//
//decalarations

    localparam l_max_os = 'd1;

    logic ar_trx_os;
    logic ar_accepted;
    logic r_accepted;
    logic next_ar_trx_os;
    logic [5:0] curr_trx_rid;
    logic arvalid_wait;

    logic aw_trx_os;
    logic w_trx_os;
    logic aw_accepted;
    logic w_accepted;
    logic b_accepted;
    logic next_aw_trx_os;
    logic next_w_trx_os;
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

    always @*
    begin
        case({r_accepted,ar_accepted})
            2'b00 : next_ar_trx_os = ar_trx_os;
            2'b01 : next_ar_trx_os = ar_trx_os + 'd1;
            2'b10 : next_ar_trx_os = ar_trx_os - 'd1;
            2'b11 : next_ar_trx_os = ar_trx_os;
            default : next_ar_trx_os = 1'bx;
        endcase
    end

    always @ (posedge clk)
    begin
        if(rst)
            ar_trx_os <= 1'b0;
        else
            ar_trx_os <= next_ar_trx_os;
    end

    always @ (posedge clk)
    begin
        if(ar_accepted)
            curr_trx_rid <= axi_if.arid;
    end

    env_no_rresponse_if_no_os: assume property(@(posedge clk) disable iff (rst)
        r_accepted  |-> ar_trx_os > 'd0);

    env_arid_match_rid: assume property(@(posedge clk) disable iff (rst)
        axi_if.rvalid  |-> (axi_if.rid == curr_trx_rid));

    env_no_arready_if_max_os: assume property(@(posedge clk) disable iff (rst)
        (ar_trx_os >= l_max_os) |-> !axi_if.arready);

    master_arvalid_held_until_ready: assert property(@(posedge clk) disable iff (rst)
        arvalid_wait |=> axi_if.arvalid);

    master_araddr_stable_until_ready: assert property(@(posedge clk) disable iff (rst)
        arvalid_wait |=> $stable({axi_if.araddr, axi_if.arlen, axi_if.arsize,
                                  axi_if.arburst, axi_if.arcache, axi_if.arlock,
                                  axi_if.arid}));

    master_read_outstanding_limit: assert property(@(posedge clk) disable iff (rst)
        ar_accepted |-> (ar_trx_os < l_max_os));
        
                
// write channel
// currently only supports a single write transaction outstanding
// AXI-4 so no leading write data

    assign aw_accepted = axi_if.awvalid & axi_if.awready;
    assign w_accepted = axi_if.wvalid & axi_if.wready;
    assign b_accepted = axi_if.bvalid & axi_if.bready;
    assign awvalid_wait = axi_if.awvalid & !axi_if.awready;
    assign wvalid_wait = axi_if.wvalid & !axi_if.wready;

    always @*
    begin
        case({b_accepted,aw_accepted})
            2'b00 : next_aw_trx_os = aw_trx_os;
            2'b01 : next_aw_trx_os = aw_trx_os + 'd1;
            2'b10 : next_aw_trx_os = aw_trx_os - 'd1;
            2'b11 : next_aw_trx_os = aw_trx_os;
            default : next_aw_trx_os = 1'bx;
        endcase
    end

    always @*
    begin
        case({b_accepted,w_accepted})
            2'b00 : next_w_trx_os = w_trx_os;
            2'b01 : next_w_trx_os = w_trx_os + 'd1;
            2'b10 : next_w_trx_os = w_trx_os - 'd1;
            2'b11 : next_w_trx_os = w_trx_os;
            default : next_w_trx_os = 1'bx;
        endcase
    end

    always @ (posedge clk)
    begin
        if(rst)
            aw_trx_os <= 1'b0;
        else
            aw_trx_os <= next_aw_trx_os;
    end

    always @ (posedge clk)
    begin
        if(rst)
            w_trx_os <= 1'b0;
        else
            w_trx_os <= next_w_trx_os;
    end

    always @ (posedge clk)
    begin
        if(aw_accepted)
            curr_trx_wid <= axi_if.awid;
    end

    env_no_bresponse_if_no_os: assume property(@(posedge clk) disable iff (rst)
        b_accepted  |-> (aw_trx_os > 'd0) && (w_trx_os > 'd0));

    env_awid_match_bid: assume property(@(posedge clk) disable iff (rst)
        axi_if.bvalid  |-> (axi_if.bid == curr_trx_wid));

    env_no_awready_if_max_os: assume property(@(posedge clk) disable iff (rst)
        (aw_trx_os >= l_max_os) |-> !axi_if.awready);

    env_no_wready_if_max_os: assume property(@(posedge clk) disable iff (rst)
        (w_trx_os >= l_max_os) |-> !axi_if.wready);

    master_awvalid_held_until_ready: assert property(@(posedge clk) disable iff (rst)
        awvalid_wait |=> axi_if.awvalid);

    master_awaddr_stable_until_ready: assert property(@(posedge clk) disable iff (rst)
        awvalid_wait |=> $stable({axi_if.awaddr, axi_if.awlen, axi_if.awsize,
                                  axi_if.awburst, axi_if.awcache, axi_if.awlock,
                                  axi_if.awid}));

    master_wvalid_held_until_ready: assert property(@(posedge clk) disable iff (rst)
        wvalid_wait |=> axi_if.wvalid);

    master_wdata_stable_until_ready: assert property(@(posedge clk) disable iff (rst)
        wvalid_wait |=> $stable({axi_if.wdata, axi_if.wstrb, axi_if.wlast}));

    master_write_address_outstanding_limit: assert property(@(posedge clk) disable iff (rst)
        aw_accepted |-> (aw_trx_os < l_max_os));

    master_write_data_outstanding_limit: assert property(@(posedge clk) disable iff (rst)
        w_accepted |-> (w_trx_os < l_max_os));

    // Basic read transaction can complete.
      cover_read_request:
      cover property (@(posedge clk) disable iff (rst)
          ar_accepted);

      cover_read_response:
      cover property (@(posedge clk) disable iff (rst)
          ar_accepted ##[1:8] r_accepted);

      cover_read_outstanding_lifecycle:
      cover property (@(posedge clk) disable iff (rst)
          ar_accepted ##1 ar_trx_os ##[1:8] r_accepted ##1 !ar_trx_os);

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
          aw_accepted ##[0:4] w_accepted ##1 (aw_trx_os && w_trx_os) ##[1:8] b_accepted ##1 (!aw_trx_os && !w_trx_os));
        



endmodule
