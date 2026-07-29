import cva5_config::*;
import riscv_types::*;
import cva5_types::*;
import csr_types::*;

module cva5_fetch_local_wrapper (
        input logic clk,
        input logic rst
    );

//****************************************************************************
// Fetch-local CVA5 reachability harness
//****************************************************************************

    localparam cpu_config_t FETCH_CONFIG = EXAMPLE_CONFIG;
    localparam int INIT_CLEAR_CYCLES = 4;
    localparam logic [31:0] INSN_LUI_X1_60000 = 32'h600000b7;
    localparam logic [31:0] INSN_LW_X2_0_X1   = 32'h0000a103;
    localparam logic [31:0] INSN_SW_X2_4_X1   = 32'h0020a223;
    localparam logic [31:0] INSN_JAL_X0_0     = 32'h0000006f;
    localparam logic [31:0] INSN_NOP          = 32'h00000013;
    localparam logic [31:0] RESET_VEC         = FETCH_CONFIG.CSRS.RESET_VEC;
    localparam logic [31:2] RESET_WORD_ADDR   = FETCH_CONFIG.CSRS.RESET_VEC[31:2];
    localparam int FETCH_ICACHE_ID            = int'(FETCH_CONFIG.INCLUDE_ILOCAL_MEM);
    localparam int INIT_CLEAR_COUNT_WIDTH     = $clog2(INIT_CLEAR_CYCLES+1);
    localparam logic [INIT_CLEAR_COUNT_WIDTH-1:0] INIT_CLEAR_LIMIT = INIT_CLEAR_COUNT_WIDTH'(INIT_CLEAR_CYCLES);

    branch_predictor_interface bp();
    ras_interface ras();
    tlb_interface itlb_if();
    mmu_interface immu_if();
    local_memory_interface instruction_bram();
    wishbone_interface iwishbone();
    mem_interface dcache_mem();
    mem_interface icache_mem();
    mem_interface dmmu_mem();
    mem_interface immu_mem();
    mem_interface mem();

    gc_outputs_t gc;
    tlb_packet_t sfence;
    id_t pc_id;
    logic pc_id_available;
    logic pc_id_assigned;
    logic fetch_complete;
    logic [31:0] fetch_instruction;
    logic early_branch_flush;
    logic early_branch_flush_ras_adjust;
    logic [31:0] if_pc;
    fetch_metadata_t fetch_metadata;

    logic [INIT_CLEAR_COUNT_WIDTH-1:0] init_clear_count;
    logic init_clear_done;
    logic local_init_clear;

    logic mem_pending;
    logic [1:0] mem_rid_q;
    logic [31:2] mem_addr_q;
    logic [31:2] mem_word_addr;
    logic [4:0] mem_len_q;
    logic [4:0] mem_beat_q;

    logic fetch_attr_push;
    logic fetch_attr_pop;
    logic fetch_attr_valid;
    logic fetch_attr_icache;
    logic fetch_unit_data_any;
    logic fetch_unit_data_icache;
    logic fetch_unit_data_lui;
    logic fetch_internal_complete;
    logic icache_miss_data_lui;
    logic icache_port_valid;
    logic icache_port_lui;

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
// Reset and benign front-end environment
//****************************************************************************

    assume_reset_not_reasserted_after_release:
        assume property (@(posedge clk) !rst |=> !rst);

    always_ff @(posedge clk) begin
        if (rst)
            init_clear_count <= '0;
        else if (!init_clear_done)
            init_clear_count <= init_clear_count + 1'b1;
    end

    assign init_clear_done = init_clear_count == INIT_CLEAR_LIMIT;
    assign local_init_clear = !rst && !init_clear_done;

    always_comb begin
        gc = '0;
        gc.init_clear = rst || local_init_clear;
        gc.fetch_hold = local_init_clear;
    end

    assign sfence = '0;
    assign pc_id = '0;
    assign pc_id_available = !rst && !local_init_clear;

    assign bp.branch_flush_pc = '0;
    assign bp.predicted_pc = '0;
    assign bp.use_prediction = 1'b0;
    assign bp.is_return = 1'b0;
    assign bp.is_call = 1'b0;
    assign bp.is_branch = 1'b0;
    assign ras.addr = '0;

    assign immu_if.write_entry = 1'b0;
    assign immu_if.superpage = 1'b0;
    assign immu_if.perms = '0;
    assign immu_if.upper_physical_address = '0;
    assign immu_if.is_fault = 1'b0;
    assign immu_if.satp_ppn = '0;
    assign immu_if.mxr = 1'b0;
    assign immu_if.sum = 1'b0;
    assign immu_if.privilege = MACHINE_PRIVILEGE;

    assign instruction_bram.data_out = smoke_instruction_rom(instruction_bram.addr);
    assign iwishbone.dat_r = '0;
    assign iwishbone.ack = 1'b0;
    assign iwishbone.err = 1'b0;

    assign dcache_mem.request = 1'b0;
    assign dcache_mem.addr = '0;
    assign dcache_mem.rlen = '0;
    assign dcache_mem.rnw = 1'b1;
    assign dcache_mem.rmw = 1'b0;
    assign dcache_mem.wbe = '0;
    assign dcache_mem.wdata = '0;
    assign dmmu_mem.request = 1'b0;
    assign dmmu_mem.addr = '0;
    assign dmmu_mem.rlen = '0;
    assign immu_mem.request = 1'b0;
    assign immu_mem.addr = '0;
    assign immu_mem.rlen = '0;

//****************************************************************************
// Live fetch path under debug
//****************************************************************************

    fetch #(.CONFIG(FETCH_CONFIG))
    u_fetch (
        .clk (clk),
        .rst (rst),
        .branch_flush (1'b0),
        .gc (gc),
        .pc_id (pc_id),
        .pc_id_available (pc_id_available),
        .pc_id_assigned (pc_id_assigned),
        .fetch_complete (fetch_complete),
        .fetch_metadata (fetch_metadata),
        .bp (bp),
        .ras (ras),
        .early_branch_flush (early_branch_flush),
        .early_branch_flush_ras_adjust (early_branch_flush_ras_adjust),
        .if_pc (if_pc),
        .fetch_instruction (fetch_instruction),
        .instruction_bram (instruction_bram),
        .iwishbone (iwishbone),
        .icache_on (1'b1),
        .tlb (itlb_if),
        .mem (icache_mem)
    );

    itlb #(.WAYS(FETCH_CONFIG.ITLB.WAYS), .DEPTH(FETCH_CONFIG.ITLB.DEPTH))
    u_itlb (
        .clk (clk),
        .rst (rst),
        .translation_on (1'b0),
        .sfence (sfence),
        .abort_request (1'b0),
        .asid ('0),
        .mmu (immu_if),
        .tlb (itlb_if)
    );

    core_arbiter #(
        .INCLUDE_DCACHE (1'b0),
        .INCLUDE_ICACHE (1'b1),
        .INCLUDE_MMUS (1'b0)
    ) u_core_arbiter (
        .clk (clk),
        .rst (rst),
        .dcache (dcache_mem),
        .icache (icache_mem),
        .dmmu (dmmu_mem),
        .immu (immu_mem),
        .mem (mem)
    );

//****************************************************************************
// Fetch-only memory model
//****************************************************************************

    assign mem_word_addr = mem_addr_q + {{25{1'b0}}, mem_beat_q};
    assign mem.ack = mem.request && !mem_pending;
    assign mem.rvalid = mem_pending;
    assign mem.rdata = smoke_instruction_rom(mem_word_addr);
    assign mem.rid = mem_rid_q;
    assign mem.inv = 1'b0;
    assign mem.inv_addr = '0;
    assign mem.write_outstanding = 1'b0;

    always_ff @(posedge clk) begin
        if (rst) begin
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

//****************************************************************************
// Fetch-local debug probes
//****************************************************************************

    assign fetch_attr_push = u_fetch.fetch_attr_fifo.push;
    assign fetch_attr_pop = u_fetch.fetch_attr_fifo.pop;
    assign fetch_attr_valid = u_fetch.fetch_attr_fifo.valid;
    assign fetch_attr_icache =
        fetch_attr_valid &&
        (u_fetch.fetch_attr.subunit_id == FETCH_ICACHE_ID);
    assign fetch_unit_data_any = |u_fetch.unit_data_valid;
    assign fetch_unit_data_icache = u_fetch.unit_data_valid[FETCH_ICACHE_ID];
    assign fetch_unit_data_lui =
        fetch_unit_data_icache &&
        (u_fetch.unit_data_array[FETCH_ICACHE_ID] == INSN_LUI_X1_60000);
    assign fetch_internal_complete = u_fetch.internal_fetch_complete;
    assign icache_miss_data_lui =
        u_fetch.gen_fetch_icache.i_cache.miss_data_valid &&
        (u_fetch.gen_fetch_icache.i_cache.fetch_sub.data_out == INSN_LUI_X1_60000);
    assign icache_port_valid = u_fetch.gen_fetch_icache.i_cache.fetch_sub.data_valid;
    assign icache_port_lui =
        icache_port_valid &&
        (u_fetch.gen_fetch_icache.i_cache.fetch_sub.data_out == INSN_LUI_X1_60000);

    cover_fetch_request_alloc:
        cover property (@(posedge clk) disable iff (rst)
            pc_id_assigned && u_fetch.new_mem_request &&
            (u_fetch.pc == RESET_VEC));

    cover_attr_fifo_push:
        cover property (@(posedge clk) disable iff (rst)
            fetch_attr_push &&
            u_fetch.sub_unit_address_match[FETCH_ICACHE_ID] &&
            (itlb_if.physical_address == RESET_VEC));

    cover_attr_fifo_valid_after_push:
        cover property (@(posedge clk) disable iff (rst)
            fetch_attr_push ##1 fetch_attr_icache);

    cover_attr_fifo_valid_waiting_for_data:
        cover property (@(posedge clk) disable iff (rst)
            fetch_attr_icache && !fetch_unit_data_any);

    cover_instruction_mem_request_reset_vec:
        cover property (@(posedge clk) disable iff (rst)
            mem.request && mem.id == 2'b01 &&
            mem.addr == RESET_WORD_ADDR);

    cover_instruction_mem_ack_reset_vec:
        cover property (@(posedge clk) disable iff (rst)
            mem.ack && mem.id == 2'b01 &&
            mem.addr == RESET_WORD_ADDR);

    cover_instruction_response_lui:
        cover property (@(posedge clk) disable iff (rst)
            mem.rvalid && mem.rid == 2'b01 &&
            mem_word_addr == RESET_WORD_ADDR &&
            mem.rdata == INSN_LUI_X1_60000);

    cover_miss_data_lui:
        cover property (@(posedge clk) disable iff (rst)
            icache_miss_data_lui);

    cover_attr_valid_and_miss_data:
        cover property (@(posedge clk) disable iff (rst)
            fetch_attr_icache && icache_miss_data_lui);

    cover_attr_and_unit_data_same_cycle:
        cover property (@(posedge clk) disable iff (rst)
            fetch_attr_icache && fetch_unit_data_lui);

    cover_attr_valid_then_lui_data_next:
        cover property (@(posedge clk) disable iff (rst)
            fetch_attr_icache && !fetch_unit_data_any ##1 fetch_unit_data_lui);

    cover_lui_data_then_attr_valid_next:
        cover property (@(posedge clk) disable iff (rst)
            fetch_unit_data_lui && !fetch_attr_valid ##1 fetch_attr_icache);

    cover_attr_pop_without_unit_data:
        cover property (@(posedge clk) disable iff (rst)
            fetch_attr_pop && !fetch_unit_data_any);

    cover_internal_fetch_complete_lui:
        cover property (@(posedge clk) disable iff (rst)
            fetch_internal_complete &&
            fetch_instruction == INSN_LUI_X1_60000);

    cover_fetch_complete_lui:
        cover property (@(posedge clk) disable iff (rst)
            fetch_complete &&
            fetch_instruction == INSN_LUI_X1_60000);

    assert_attr_push_creates_valid:
        assert property (@(posedge clk) disable iff (rst)
            fetch_attr_push && !fetch_attr_pop |=> fetch_attr_valid);

    assert_attr_valid_holds_without_data:
        assert property (@(posedge clk) disable iff (rst)
            fetch_attr_valid && !fetch_unit_data_any |=> fetch_attr_valid);

    assert_unit_data_implies_matching_attr:
        assert property (@(posedge clk) disable iff (rst)
            fetch_unit_data_any |-> fetch_attr_valid &&
            u_fetch.unit_data_valid[u_fetch.fetch_attr.subunit_id]);

    assert_miss_data_implies_attr_icache:
        assert property (@(posedge clk) disable iff (rst)
            icache_miss_data_lui |-> fetch_attr_icache);

    assert_miss_data_implies_internal_complete:
        assert property (@(posedge clk) disable iff (rst)
            icache_miss_data_lui |-> fetch_internal_complete);

    assert_miss_data_implies_fetch_complete_lui:
        assert property (@(posedge clk) disable iff (rst)
            icache_miss_data_lui |-> fetch_complete &&
            fetch_instruction == INSN_LUI_X1_60000);

endmodule
