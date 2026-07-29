//
// Copyright © 2020  Stuart Hoad,  Lesley Shannon
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

module cva5_formal_wrapper #(
        parameter int FBM_STARTUP_CYCLES = 80,
        parameter bit FBM_ASSUME_CYCLE_RESET_SEQUENCE = 1'b1
    ) (

        input logic clk,
        input logic rst,
        input logic axi_arready_choice,
        input logic axi_awready_choice,
        input logic axi_wready_choice
        );

// top level signals

        local_memory_interface 	instruction_bram();
        local_memory_interface 	data_bram();

        axi_interface 		    m_axi();
        avalon_interface 	    m_avalon();
        wishbone_interface 	    dwishbone();
        wishbone_interface 	    iwishbone();
        mem_interface            mem();

        logic [63:0]             mtime;
        interrupt_t              s_interrupt;
        interrupt_t              m_interrupt;

// Instance of CVA5 core
        cva5
        u_cva5_core (
        .clk 		        (clk),
        .rst 		        (rst),
        .instruction_bram   (instruction_bram.master),
        .data_bram	        (data_bram.master),
        .m_axi		        (m_axi.master),
        .m_avalon	        (m_avalon.master),
        .dwishbone          (dwishbone.master),
        .iwishbone          (iwishbone.master),
        .mem                (mem.mem_master),
        .mtime              (mtime),
        .s_interrupt        (s_interrupt),
        .m_interrupt        (m_interrupt)
	);

// Instance of CVA5 FBM
        cva5_fbm #(
        .STARTUP_CYCLES    (FBM_STARTUP_CYCLES),
        .ASSUME_CYCLE_RESET_SEQUENCE (FBM_ASSUME_CYCLE_RESET_SEQUENCE)
        )
        u_cva5_fbm (
        .clk 		        (clk),
        .rst 		        (rst),
        .axi_arready_choice (axi_arready_choice),
        .axi_awready_choice (axi_awready_choice),
        .axi_wready_choice  (axi_wready_choice),
        .instruction_bram   (instruction_bram),
        .data_bram	        (data_bram),
        .m_axi		        (m_axi),
        .m_avalon	        (m_avalon),
        .dwishbone          (dwishbone),
        .iwishbone          (iwishbone),
        .mem                (mem),
        .mtime              (mtime),
        .s_interrupt        (s_interrupt),
        .m_interrupt        (m_interrupt)
	);

//****************************************************************************
// Full-core reachability debug covers
//****************************************************************************

        localparam logic [31:0] FULL_INSN_LUI_X1_60000 = 32'h600000b7;
        localparam logic [31:0] FULL_INSN_LW_X2_0_X1   = 32'h0000a103;
        localparam logic [31:0] FULL_INSN_SW_X2_4_X1   = 32'h0020a223;
        localparam logic [31:0] FULL_RESET_VEC          = EXAMPLE_CONFIG.CSRS.RESET_VEC;
        localparam logic [31:2] FULL_RESET_WORD_ADDR    = EXAMPLE_CONFIG.CSRS.RESET_VEC[31:2];
        localparam logic [4:0]  FULL_ICACHE_LINE_LAST   = 5'(EXAMPLE_CONFIG.ICACHE.LINE_W - 1);
        localparam logic [1:0]  FULL_ICACHE_MEM_ID      = 2'b01;
        localparam int          FULL_LS_BUS_ID          = int'(EXAMPLE_CONFIG.INCLUDE_DLOCAL_MEM);
        localparam int          FULL_FETCH_ICACHE_ID    = int'(EXAMPLE_CONFIG.INCLUDE_ILOCAL_MEM);

        logic full_smoke_active;
        logic full_fetch_ready;
        logic full_fetch_tlb_ready;
        logic full_fetch_pc_id_available;
        logic full_fetch_attr_fifo_not_full;
        logic full_fetch_no_exception_pending;
        logic full_fetch_no_fetch_hold;
        logic full_fetch_tlb_request_enable;
        logic full_fetch_tlb_request_any;
        logic full_fetch_tlb_request_at_reset_pc;
        logic full_fetch_tlb_request;
        logic full_fetch_tlb_done;
        logic full_fetch_icache_subrequest;
        logic full_fetch_icache_mem_request;
        logic full_fetch_icache_mem_ack;
        logic full_fetch_icache_mem_rvalid;
        logic full_core_mem_request_icache_reset_vec;
        logic full_fbm_mem_ack_icache_reset_vec;
        logic full_fbm_response_lui_reset_vec;
        logic full_core_icache_rvalid_lui_reset_vec;
        logic full_fetch_icache_miss_data_valid;
        logic full_fetch_icache_port_valid;
        logic full_fetch_icache_port_lui;
        logic full_fetch_subunit_valid;
        logic full_fetch_subunit_lui;
        logic full_fetch_unit_data_valid_any;
        logic full_fetch_unit_data_valid_icache;
        logic full_fetch_unit_data_lui;
        logic full_fetch_attr_fifo_valid;
        logic full_fetch_attr_icache;
        logic full_fetch_attr_and_unit_data;
        logic full_fetch_attr_icache_and_lui_data;
        logic full_fetch_internal_complete;
        logic full_fetch_internal_complete_lui;
        logic full_fetch_complete_ready;
        logic full_fetch_instruction_lui_raw;
        logic full_fetch_lui;
        logic full_fetch_lw;
        logic full_fetch_sw;
        logic full_decode_lw;
        logic full_decode_sw;
        logic full_issue_lw;
        logic full_issue_sw;
        logic full_lsu_issue;
        logic full_lsu_read_request;
        logic full_lsu_write_request;

        assign full_smoke_active = u_cva5_fbm.smoke_initialized;
        assign full_fetch_ready = full_smoke_active &&
            !u_cva5_core.gc.init_clear &&
            !u_cva5_core.gc.fetch_hold &&
            u_cva5_core.pc_id_available;
        assign full_fetch_tlb_ready =
            u_cva5_core.itlb.ready;
        assign full_fetch_pc_id_available =
            u_cva5_core.pc_id_available;
        assign full_fetch_attr_fifo_not_full =
            !u_cva5_core.fetch_block.fetch_attr_fifo.full;
        assign full_fetch_no_exception_pending =
            !u_cva5_core.fetch_block.exception_pending;
        assign full_fetch_no_fetch_hold =
            !u_cva5_core.gc.fetch_hold;
        assign full_fetch_tlb_request_enable =
            u_cva5_core.itlb.ready &&
            u_cva5_core.pc_id_available &&
            !u_cva5_core.fetch_block.fetch_attr_fifo.full &&
            !u_cva5_core.fetch_block.exception_pending &&
            !u_cva5_core.gc.fetch_hold;
        assign full_fetch_tlb_request_any =
            u_cva5_core.itlb.new_request;
        assign full_fetch_tlb_request_at_reset_pc =
            full_fetch_tlb_request_any &&
            (u_cva5_core.fetch_block.pc == FULL_RESET_VEC);
        assign full_fetch_tlb_request = u_cva5_core.itlb.new_request &&
            (u_cva5_core.itlb.virtual_address == FULL_RESET_VEC);
        assign full_fetch_tlb_done = u_cva5_core.itlb.done &&
            (u_cva5_core.itlb.physical_address == FULL_RESET_VEC) &&
            !u_cva5_core.itlb.is_fault;
        assign full_fetch_icache_subrequest =
            u_cva5_core.fetch_block.sub_unit[FULL_FETCH_ICACHE_ID].new_request &&
            (u_cva5_core.fetch_block.sub_unit[FULL_FETCH_ICACHE_ID].addr == FULL_RESET_VEC);
        assign full_fetch_icache_mem_request = u_cva5_core.icache_mem.request &&
            (u_cva5_core.icache_mem.addr == FULL_RESET_WORD_ADDR);
        assign full_fetch_icache_mem_ack = u_cva5_core.icache_mem.ack &&
            (u_cva5_core.icache_mem.addr == FULL_RESET_WORD_ADDR);
        assign full_fetch_icache_mem_rvalid = u_cva5_core.icache_mem.rvalid &&
            (u_cva5_core.icache_mem.rdata == FULL_INSN_LUI_X1_60000);
        assign full_core_mem_request_icache_reset_vec = mem.request &&
            (mem.id == FULL_ICACHE_MEM_ID) &&
            (mem.addr == FULL_RESET_WORD_ADDR);
        assign full_fbm_mem_ack_icache_reset_vec = mem.ack &&
            (mem.id == FULL_ICACHE_MEM_ID) &&
            (mem.addr == FULL_RESET_WORD_ADDR);
        assign full_fbm_response_lui_reset_vec = mem.rvalid &&
            (mem.rid == FULL_ICACHE_MEM_ID) &&
            (u_cva5_fbm.mem_word_addr == FULL_RESET_WORD_ADDR) &&
            (mem.rdata == FULL_INSN_LUI_X1_60000);
        assign full_core_icache_rvalid_lui_reset_vec =
            u_cva5_core.icache_mem.rvalid &&
            (u_cva5_core.icache_mem.rdata == FULL_INSN_LUI_X1_60000) &&
            (u_cva5_core.fetch_block.gen_fetch_icache.i_cache.second_cycle_addr[31:2] == FULL_RESET_WORD_ADDR);
        assign full_fetch_icache_miss_data_valid =
            u_cva5_core.fetch_block.gen_fetch_icache.i_cache.miss_data_valid &&
            (u_cva5_core.fetch_block.gen_fetch_icache.i_cache.fetch_sub.data_out == FULL_INSN_LUI_X1_60000);
        assign full_fetch_icache_port_valid =
            u_cva5_core.fetch_block.gen_fetch_icache.i_cache.fetch_sub.data_valid;
        assign full_fetch_icache_port_lui =
            full_fetch_icache_port_valid &&
            (u_cva5_core.fetch_block.gen_fetch_icache.i_cache.fetch_sub.data_out == FULL_INSN_LUI_X1_60000);
        assign full_fetch_subunit_valid =
            u_cva5_core.fetch_block.sub_unit[FULL_FETCH_ICACHE_ID].data_valid;
        assign full_fetch_subunit_lui =
            full_fetch_subunit_valid &&
            (u_cva5_core.fetch_block.sub_unit[FULL_FETCH_ICACHE_ID].data_out == FULL_INSN_LUI_X1_60000);
        assign full_fetch_unit_data_valid_any =
            |u_cva5_core.fetch_block.unit_data_valid;
        assign full_fetch_unit_data_valid_icache =
            u_cva5_core.fetch_block.unit_data_valid[FULL_FETCH_ICACHE_ID];
        assign full_fetch_unit_data_lui =
            full_fetch_unit_data_valid_icache &&
            (u_cva5_core.fetch_block.unit_data_array[FULL_FETCH_ICACHE_ID] == FULL_INSN_LUI_X1_60000);
        assign full_fetch_attr_fifo_valid =
            u_cva5_core.fetch_block.fetch_attr_fifo.valid;
        assign full_fetch_attr_icache =
            full_fetch_attr_fifo_valid &&
            (u_cva5_core.fetch_block.fetch_attr.subunit_id == FULL_FETCH_ICACHE_ID);
        assign full_fetch_attr_and_unit_data =
            full_smoke_active &&
            full_fetch_attr_fifo_valid &&
            full_fetch_unit_data_valid_any;
        assign full_fetch_attr_icache_and_lui_data =
            full_smoke_active &&
            full_fetch_attr_icache &&
            full_fetch_unit_data_lui;
        assign full_fetch_internal_complete =
            u_cva5_core.fetch_block.internal_fetch_complete;
        assign full_fetch_internal_complete_lui =
            full_fetch_internal_complete &&
            (u_cva5_core.fetch_instruction == FULL_INSN_LUI_X1_60000);
        assign full_fetch_complete_ready =
            full_fetch_internal_complete &&
            !|u_cva5_core.fetch_block.flush_count;

        assign full_fetch_instruction_lui_raw =
            u_cva5_core.fetch_instruction == FULL_INSN_LUI_X1_60000;
        assign full_fetch_lui = u_cva5_core.fetch_complete &&
            (u_cva5_core.fetch_instruction == FULL_INSN_LUI_X1_60000);
        assign full_fetch_lw = u_cva5_core.fetch_complete &&
            (u_cva5_core.fetch_instruction == FULL_INSN_LW_X2_0_X1);
        assign full_fetch_sw = u_cva5_core.fetch_complete &&
            (u_cva5_core.fetch_instruction == FULL_INSN_SW_X2_4_X1);

        assign full_decode_lw = u_cva5_core.decode_advance &&
            (u_cva5_core.decode.instruction == FULL_INSN_LW_X2_0_X1);
        assign full_decode_sw = u_cva5_core.decode_advance &&
            (u_cva5_core.decode.instruction == FULL_INSN_SW_X2_4_X1);

        assign full_issue_lw = u_cva5_core.unit_issue[LS_ID].new_request &&
            (u_cva5_core.issue.instruction == FULL_INSN_LW_X2_0_X1);
        assign full_issue_sw = u_cva5_core.unit_issue[LS_ID].new_request &&
            (u_cva5_core.issue.instruction == FULL_INSN_SW_X2_4_X1);

        assign full_lsu_issue = u_cva5_core.load_store_unit_block.sub_unit[FULL_LS_BUS_ID].new_request;
        assign full_lsu_read_request = full_lsu_issue &&
            u_cva5_core.load_store_unit_block.sub_unit[FULL_LS_BUS_ID].re;
        assign full_lsu_write_request = full_lsu_issue &&
            u_cva5_core.load_store_unit_block.sub_unit[FULL_LS_BUS_ID].we;

        cover_full_fetch_complete:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && u_cva5_core.fetch_complete);

        cover_full_fetch_ready:
            cover property (@(posedge clk) disable iff (rst)
                full_fetch_ready);

        cover_full_fetch_pc_reset_vec:
            cover property (@(posedge clk) disable iff (rst)
                u_cva5_core.gc.init_clear &&
                (u_cva5_core.fetch_block.pc == FULL_RESET_VEC));

        cover_full_fetch_tlb_ready:
            cover property (@(posedge clk) disable iff (rst)
                full_fetch_tlb_ready);

        cover_full_fetch_pc_id_available:
            cover property (@(posedge clk) disable iff (rst)
                full_fetch_pc_id_available);

        cover_full_fetch_attr_fifo_not_full:
            cover property (@(posedge clk) disable iff (rst)
                full_fetch_attr_fifo_not_full);

        cover_full_fetch_no_exception_pending:
            cover property (@(posedge clk) disable iff (rst)
                full_fetch_no_exception_pending);

        cover_full_fetch_no_fetch_hold:
            cover property (@(posedge clk) disable iff (rst)
                full_fetch_no_fetch_hold);

        cover_full_fetch_tlb_request_enable:
            cover property (@(posedge clk) disable iff (rst)
                full_fetch_tlb_request_enable);

        cover_full_fetch_tlb_request_any:
            cover property (@(posedge clk) disable iff (rst)
                full_fetch_tlb_request_any);

        cover_full_fetch_tlb_request_at_reset_pc:
            cover property (@(posedge clk) disable iff (rst)
                full_fetch_tlb_request_at_reset_pc);

        cover_full_fetch_tlb_request:
            cover property (@(posedge clk) disable iff (rst)
                full_fetch_tlb_request);

        cover_full_fetch_tlb_done:
            cover property (@(posedge clk) disable iff (rst)
                full_fetch_tlb_done);

        cover_full_fetch_icache_subrequest:
            cover property (@(posedge clk) disable iff (rst)
                full_fetch_icache_subrequest);

        cover_full_fetch_icache_mem_request:
            cover property (@(posedge clk) disable iff (rst)
                full_fetch_icache_mem_request);

        cover_full_fetch_icache_mem_ack:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && full_fetch_icache_mem_ack);

        cover_full_fetch_icache_mem_rvalid:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && full_fetch_icache_mem_rvalid);

        cover_full_core_mem_request_icache_reset_vec:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && full_core_mem_request_icache_reset_vec);

        cover_full_fbm_mem_ack_icache_reset_vec:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && full_fbm_mem_ack_icache_reset_vec);

        cover_full_fbm_response_lui_reset_vec:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && full_fbm_response_lui_reset_vec);

        cover_full_core_icache_rvalid_lui_reset_vec:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && full_core_icache_rvalid_lui_reset_vec);

        cover_full_fetch_icache_line_complete:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active &&
                u_cva5_core.fetch_block.gen_fetch_icache.i_cache.line_complete &&
                (u_cva5_core.fetch_block.gen_fetch_icache.i_cache.word_count == FULL_ICACHE_LINE_LAST));

        cover_full_fetch_icache_miss_data_valid:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && full_fetch_icache_miss_data_valid);

        cover_full_fetch_icache_port_valid:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && full_fetch_icache_port_valid);

        cover_full_fetch_icache_port_lui:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && full_fetch_icache_port_lui);

        cover_full_fetch_icache_port_lui_raw:
            cover property (@(posedge clk) disable iff (rst)
                full_fetch_icache_port_lui);

        cover_full_fetch_subunit_valid:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && full_fetch_subunit_valid);

        cover_full_fetch_subunit_lui:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && full_fetch_subunit_lui);

        cover_full_fetch_unit_data_valid_any:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && full_fetch_unit_data_valid_any);

        cover_full_fetch_unit_data_valid_icache:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && full_fetch_unit_data_valid_icache);

        cover_full_fetch_unit_data_lui:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && full_fetch_unit_data_lui);

        cover_full_fetch_unit_data_lui_raw:
            cover property (@(posedge clk) disable iff (rst)
                full_fetch_unit_data_lui);

        cover_full_fetch_instruction_lui_raw:
            cover property (@(posedge clk) disable iff (rst)
                full_fetch_instruction_lui_raw);

        cover_full_fetch_attr_fifo_valid:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && full_fetch_attr_fifo_valid);

        cover_full_fetch_attr_icache:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && full_fetch_attr_icache);

        cover_full_fetch_attr_and_unit_data:
            cover property (@(posedge clk) disable iff (rst)
                full_fetch_attr_and_unit_data);

        cover_full_fetch_attr_icache_and_lui_data:
            cover property (@(posedge clk) disable iff (rst)
                full_fetch_attr_icache_and_lui_data);

        cover_full_fetch_attr_to_miss_data:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && full_fetch_attr_icache
                ##[0:32] full_fetch_icache_miss_data_valid);

        cover_full_fetch_attr_to_lui_data:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && full_fetch_attr_icache
                ##[0:32] full_fetch_unit_data_lui);

        cover_full_fetch_internal_complete:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && full_fetch_internal_complete);

        cover_full_fetch_internal_complete_lui:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && full_fetch_internal_complete_lui);

        cover_full_fetch_internal_complete_lui_raw:
            cover property (@(posedge clk) disable iff (rst)
                full_fetch_internal_complete_lui);

        cover_full_fetch_lui_data_to_internal_complete:
            cover property (@(posedge clk) disable iff (rst)
                full_fetch_attr_icache_and_lui_data &&
                full_fetch_internal_complete);

        cover_full_response_to_icache_port_lui:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && full_fbm_response_lui_reset_vec
                ##[0:4] full_fetch_icache_port_lui);

        cover_full_response_to_unit_data_lui:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && full_fbm_response_lui_reset_vec
                ##[0:4] full_fetch_unit_data_lui);

        cover_full_response_to_internal_complete_lui:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && full_fbm_response_lui_reset_vec
                ##[0:4] full_fetch_internal_complete_lui);

        cover_full_response_to_fetch_lui:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && full_fbm_response_lui_reset_vec
                ##[0:4] full_fetch_lui);

        assert_full_fetch_miss_implies_icache_port_valid:
            assert property (@(posedge clk) disable iff (rst)
                full_fetch_icache_miss_data_valid |-> full_fetch_icache_port_valid);

        assert_full_fetch_icache_port_implies_subunit_valid:
            assert property (@(posedge clk) disable iff (rst)
                full_fetch_icache_port_valid |-> full_fetch_subunit_valid);

        assert_full_fetch_subunit_implies_unit_data_valid:
            assert property (@(posedge clk) disable iff (rst)
                full_fetch_subunit_valid |-> full_fetch_unit_data_valid_icache);

        assert_full_fetch_attr_and_unit_valid_imply_internal_complete:
            assert property (@(posedge clk) disable iff (rst)
                full_fetch_attr_fifo_valid && full_fetch_unit_data_valid_any
                |-> full_fetch_internal_complete);

        assert_full_fetch_miss_implies_attr_icache:
            assert property (@(posedge clk) disable iff (rst)
                full_fetch_icache_miss_data_valid |-> full_fetch_attr_icache);

        assert_full_fetch_miss_implies_internal_complete:
            assert property (@(posedge clk) disable iff (rst)
                full_fetch_icache_miss_data_valid |-> full_fetch_internal_complete);

        assert_full_fetch_miss_implies_fetch_lui:
            assert property (@(posedge clk) disable iff (rst)
                full_fetch_icache_miss_data_valid |-> full_fetch_lui);

        cover_full_fetch_no_flush_pending:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && full_fetch_complete_ready);

        cover_full_fetch_lui:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && full_fetch_lui);

        cover_full_fetch_lui_raw:
            cover property (@(posedge clk) disable iff (rst)
                full_fetch_lui);

        cover_full_fetch_lw:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && full_fetch_lw);

        cover_full_fetch_sw:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && full_fetch_sw);

        cover_full_decode_lw:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && full_decode_lw);

        cover_full_decode_sw:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && full_decode_sw);

        cover_full_decode_ls_needed:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && u_cva5_core.decode_advance &&
                u_cva5_core.unit_needed[LS_ID]);

        cover_full_issue_lw:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && full_issue_lw);

        cover_full_issue_sw:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && full_issue_sw);

        cover_full_issue_ls:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && u_cva5_core.unit_issue[LS_ID].new_request);

        cover_full_lsu_tlb_request:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && u_cva5_core.load_store_unit_block.tlb.new_request);

        cover_full_lsu_tlb_done:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && u_cva5_core.load_store_unit_block.tlb.done);

        cover_full_lsu_bus_match:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active &&
                u_cva5_core.load_store_unit_block.sub_unit_address_match[FULL_LS_BUS_ID]);

        cover_full_axi_master_read_request:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && full_lsu_read_request);

        cover_full_axi_master_write_request:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && full_lsu_write_request);

        cover_full_axi_arvalid:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && m_axi.arvalid);

        cover_full_axi_awvalid:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && m_axi.awvalid);

        cover_full_axi_wvalid:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && m_axi.wvalid);

        cover_full_read_lifecycle_to_arvalid:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && full_fetch_lw ##[0:128]
                full_decode_lw ##[0:128]
                full_issue_lw ##[0:128]
                full_lsu_read_request ##[0:32]
                m_axi.arvalid);

        cover_full_store_lifecycle_to_awvalid:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && full_fetch_sw ##[0:128]
                full_decode_sw ##[0:128]
                full_issue_sw ##[0:128]
                full_lsu_write_request ##[0:32]
                (m_axi.awvalid || m_axi.wvalid));

        cover_full_axi_ar_handshake:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && m_axi.arvalid && m_axi.arready);

        cover_full_axi_aw_handshake:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && m_axi.awvalid && m_axi.awready);

        cover_full_axi_w_handshake:
            cover property (@(posedge clk) disable iff (rst)
                full_smoke_active && m_axi.wvalid && m_axi.wready);

endmodule
