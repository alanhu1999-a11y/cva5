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
// Smoke-test control
//****************************************************************************

    localparam int RESET_CYCLES = 2;
    localparam int STARTUP_CYCLES = 80;
    localparam int AXI_RESPONSE_DELAY = 2;
    localparam logic [7:0] STARTUP_CYCLES_W = STARTUP_CYCLES;
    localparam logic [1:0] AXI_RESPONSE_DELAY_W = AXI_RESPONSE_DELAY;

    localparam logic [31:0] INSN_LUI_X1_60000 = 32'h600000b7;
    localparam logic [31:0] INSN_LW_X2_0_X1   = 32'h0000a103;
    localparam logic [31:0] INSN_SW_X2_4_X1   = 32'h0020a223;
    localparam logic [31:0] INSN_JAL_X0_0     = 32'h0000006f;
    localparam logic [31:0] INSN_NOP          = 32'h00000013;

    logic [7:0] formal_cycle;
    logic [7:0] startup_count;
    logic smoke_initialized;

    initial assume(formal_cycle == '0);

    always_ff @(posedge clk) begin
        if (formal_cycle != 8'hff)
            formal_cycle <= formal_cycle + 1'b1;
    end

    assume_reset_asserted_at_start:
        assume property (@(posedge clk) formal_cycle < RESET_CYCLES |-> rst);

    assume_reset_released_after_start:
        assume property (@(posedge clk) formal_cycle >= RESET_CYCLES |-> !rst);

    always_ff @(posedge clk) begin
        if (rst)
            startup_count <= '0;
        else if (!smoke_initialized)
            startup_count <= startup_count + 1'b1;
    end

    assign smoke_initialized = startup_count >= STARTUP_CYCLES_W;

    cover_reset_released:
        cover property (@(posedge clk) $fell(rst));

    cover_startup_complete:
        cover property (@(posedge clk) smoke_initialized);

    function automatic logic [31:0] smoke_instruction_rom(input logic [31:2] word_addr);
        case (word_addr)
            30'h20000000: smoke_instruction_rom = INSN_LUI_X1_60000;
            30'h20000001: smoke_instruction_rom = INSN_LW_X2_0_X1;
            30'h20000002: smoke_instruction_rom = INSN_SW_X2_4_X1;
            30'h20000003: smoke_instruction_rom = INSN_JAL_X0_0;
            default:      smoke_instruction_rom = INSN_NOP;
        endcase
    endfunction

//****************************************************************************
// Interface properties
//****************************************************************************

    axi4_basic_props
    u_ppb_axi (
	        .clk 		        (clk),
	        .rst 		        (rst | !smoke_initialized),
	        .axi_if		        (m_axi)
	    );

//****************************************************************************
// Simple smoke-test environment
//****************************************************************************

    logic mem_pending;
    logic [1:0] mem_rid_q;
    logic [31:2] mem_addr_q;
    logic [31:2] mem_word_addr;
    logic [4:0] mem_len_q;
    logic [4:0] mem_beat_q;

    logic axi_ready_phase;
    logic axi_read_pending;
    logic [1:0] axi_read_delay;
    logic [5:0] axi_read_id;
    logic axi_aw_seen;
    logic axi_w_seen;
    logic axi_write_pending;
    logic [1:0] axi_write_delay;
    logic [5:0] axi_write_id;

    logic axi_ar_accepted;
    logic axi_aw_accepted;
    logic axi_w_accepted;
    logic axi_r_accepted;
    logic axi_b_accepted;

    assign axi_ar_accepted = m_axi.arvalid & m_axi.arready;
    assign axi_aw_accepted = m_axi.awvalid & m_axi.awready;
    assign axi_w_accepted = m_axi.wvalid & m_axi.wready;
    assign axi_r_accepted = m_axi.rvalid & m_axi.rready;
    assign axi_b_accepted = m_axi.bvalid & m_axi.bready;

    assign mtime = 64'b0;
    assign s_interrupt = '0;
    assign m_interrupt = '0;

    assign instruction_bram.data_out = smoke_instruction_rom(instruction_bram.addr);
    assign data_bram.data_out = 32'b0;

    assign m_axi.arready = smoke_initialized & axi_ready_phase & !axi_read_pending;
    assign m_axi.rvalid = smoke_initialized & axi_read_pending & (axi_read_delay == '0);
    assign m_axi.rdata = 32'hc0de_0001;
    assign m_axi.rresp = 2'b0;
    assign m_axi.rlast = m_axi.rvalid;
    assign m_axi.rid = axi_read_id;
    assign m_axi.awready = smoke_initialized & axi_ready_phase & !axi_aw_seen & !axi_write_pending;
    assign m_axi.wready = smoke_initialized & !axi_ready_phase & !axi_w_seen & !axi_write_pending;
    assign m_axi.bvalid = smoke_initialized & axi_write_pending & (axi_write_delay == '0);
    assign m_axi.bresp = 2'b0;
    assign m_axi.bid = axi_write_id;

    always_ff @(posedge clk) begin
        if (rst | !smoke_initialized) begin
            axi_ready_phase <= 1'b0;
            axi_read_pending <= 1'b0;
            axi_read_delay <= '0;
            axi_read_id <= '0;
            axi_aw_seen <= 1'b0;
            axi_w_seen <= 1'b0;
            axi_write_pending <= 1'b0;
            axi_write_delay <= '0;
            axi_write_id <= '0;
        end
        else begin
            axi_ready_phase <= ~axi_ready_phase;

            if (axi_ar_accepted) begin
                axi_read_pending <= 1'b1;
                axi_read_delay <= AXI_RESPONSE_DELAY_W;
                axi_read_id <= m_axi.arid;
            end
            else if (axi_read_pending & (axi_read_delay != '0)) begin
                axi_read_delay <= axi_read_delay - 1'b1;
            end
            else if (axi_r_accepted) begin
                axi_read_pending <= 1'b0;
            end

            if (axi_aw_accepted) begin
                axi_aw_seen <= 1'b1;
                axi_write_id <= m_axi.awid;
            end
            if (axi_w_accepted)
                axi_w_seen <= 1'b1;

            if (!axi_write_pending && ((axi_aw_seen | axi_aw_accepted) && (axi_w_seen | axi_w_accepted))) begin
                axi_write_pending <= 1'b1;
                axi_write_delay <= AXI_RESPONSE_DELAY_W;
                axi_aw_seen <= 1'b0;
                axi_w_seen <= 1'b0;
            end
            else if (axi_write_pending & (axi_write_delay != '0)) begin
                axi_write_delay <= axi_write_delay - 1'b1;
            end
            else if (axi_b_accepted) begin
                axi_write_pending <= 1'b0;
            end
        end
    end

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

    assign mem_word_addr = mem_addr_q + {{25{1'b0}}, mem_beat_q};
    assign mem.ack = smoke_initialized & mem.request & !mem_pending;
    assign mem.rvalid = smoke_initialized & mem_pending;
    assign mem.rdata = smoke_instruction_rom(mem_word_addr);
    assign mem.rid = mem_rid_q;
    assign mem.inv = 1'b0;
    assign mem.inv_addr = 30'b0;
    assign mem.write_outstanding = 1'b0;

    always_ff @(posedge clk) begin
        if (rst | !smoke_initialized) begin
            mem_pending <= 1'b0;
            mem_rid_q <= '0;
            mem_addr_q <= '0;
            mem_len_q <= '0;
            mem_beat_q <= '0;
        end
        else if (mem.ack) begin
            mem_pending <= 1'b1;
            mem_rid_q <= mem.id;
            mem_addr_q <= mem.addr;
            mem_len_q <= mem.rlen;
            mem_beat_q <= '0;
        end
        else if (mem.rvalid) begin
            if (mem_beat_q == mem_len_q)
                mem_pending <= 1'b0;
            else
                mem_beat_q <= mem_beat_q + 1'b1;
        end
    end

    cover_instruction_fetch:
        cover property (@(posedge clk) disable iff (rst)
            smoke_initialized ##[1:32] (mem.ack && mem.id == 2'b01));

endmodule
