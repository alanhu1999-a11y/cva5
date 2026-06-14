//
// Copyright © 2020  Stuart Hoad, Lesley Shannon
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
// CVA5 Formal Behavioural Model

//****************************************************************************
//****************************************************************************


import cva5_config::*;
import riscv_types::*;
import cva5_types::*;

module cva5_fbm (
        input logic clk,
        input logic rst,

        local_memory_interface instruction_bram,
        local_memory_interface data_bram,

        axi_interface m_axi,
        avalon_interface m_avalon,
        wishbone_interface dwishbone,
        wishbone_interface iwishbone,
        mem_interface mem,

        output logic [63:0] mtime,
        output interrupt_t s_interrupt,
        output interrupt_t m_interrupt
        );

//****************************************************************************
// Interface properties
//****************************************************************************

    // AXI constraints.
    // CVA5 does not deal with bad AXI responses, so need to constrain to avoid them
    // REVISIT add AXI protocol properties
    axi4_basic_props
    u_ppb_axi (
        .clk 		        (clk),
        .rst 		        (rst),
        .axi_if		        (m_axi)
    );

//****************************************************************************
// Simple smoke-test environment
//****************************************************************************

    assign mtime = 64'b0;
    assign s_interrupt = '0;
    assign m_interrupt = '0;

    assign instruction_bram.data_out = 32'b0;
    assign data_bram.data_out = 32'b0;

    assign m_axi.arready = 1'b0;
    assign m_axi.rvalid = 1'b0;
    assign m_axi.rdata = 32'b0;
    assign m_axi.rresp = 2'b0;
    assign m_axi.rlast = 1'b0;
    assign m_axi.rid = 6'b0;
    assign m_axi.awready = 1'b0;
    assign m_axi.wready = 1'b0;
    assign m_axi.bvalid = 1'b0;
    assign m_axi.bresp = 2'b0;
    assign m_axi.bid = 6'b0;

    assign m_avalon.readdata = 32'b0;
    assign m_avalon.waitrequest = 1'b1;
    assign m_avalon.readdatavalid = 1'b0;
    assign m_avalon.writeresponsevalid = 1'b0;

    assign dwishbone.dat_r = 32'b0;
    assign dwishbone.ack = 1'b0;
    assign dwishbone.err = 1'b0;

    assign iwishbone.dat_r = 32'b0;
    assign iwishbone.ack = 1'b0;
    assign iwishbone.err = 1'b0;

    assign mem.ack = 1'b0;
    assign mem.rvalid = 1'b0;
    assign mem.rdata = 32'b0;
    assign mem.rid = 2'b0;
    assign mem.inv = 1'b0;
    assign mem.inv_addr = 30'b0;
    assign mem.write_outstanding = 1'b0;

endmodule
