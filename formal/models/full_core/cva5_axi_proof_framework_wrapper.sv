import cva5_config::*;
import cva5_types::*;

module cva5_axi_proof_framework_wrapper (
    input logic clk,
    input logic rst,
    input logic axi_arready_choice,
    input logic axi_awready_choice,
    input logic axi_wready_choice
);

    /////////////////////////////////////////////////////////////////
    // CONFIGURATION
    /////////////////////////////////////////////////////////////////

    localparam int FULL_LS_BUS_ID = int'(EXAMPLE_CONFIG.INCLUDE_DLOCAL_MEM);
    localparam int WB_GROUP_W = $clog2(EXAMPLE_CONFIG.NUM_WB_GROUPS);
    localparam logic [4:0] ICACHE_LINE_LAST = 5'(EXAMPLE_CONFIG.ICACHE.LINE_W - 1);

    // Mirrors axi_master.state_t for white-box proof decomposition.
    localparam logic [31:0] AXI_STATE_READY           = 32'd0;
    localparam logic [31:0] AXI_STATE_REQUESTING_READ = 32'd2;
    localparam logic [31:0] AXI_STATE_WAITING_READ    = 32'd4;

    localparam logic [31:0] LUI_INSTRUCTION = 32'h600000b7;
    localparam logic [31:0] LW_INSTRUCTION = 32'h0000a103;
    localparam logic [31:0] LW_PC = EXAMPLE_CONFIG.CSRS.RESET_VEC + 32'd4;
    localparam logic [31:2] RESET_WORD_ADDR = EXAMPLE_CONFIG.CSRS.RESET_VEC[31:2];
    localparam logic [31:0] LW_DATA_ADDR = 32'h60000000;
    localparam rs_addr_t LW_ARCH_RD = rs_addr_t'(5'd2);
    localparam logic [WB_GROUP_W-1:0] LS_WB_GROUP = WB_GROUP_W'(1);

    /////////////////////////////////////////////////////////////////
    // FORMAL SIGNALS
    /////////////////////////////////////////////////////////////////

    logic [31:0] embedded_axi_state;
    logic embedded_axi_read_pending;
    logic formal_active;
    logic normal_lsu_load_request;
    logic normal_lsu_load_accept;
    logic fullcore_ar_accept;
    logic fullcore_r_accept;
    logic fullcore_lsu_load_completion;

    // White-box reachability trackers. They observe one PC-anchored LW and do
    // not constrain the DUT or its environment.
    id_t anchored_lui_id;
    id_t anchored_lw_id;
    phys_addr_t anchored_lui_phys_rd;
    phys_addr_t anchored_lw_phys_rd;
    rs_addr_t anchored_lw_arch_rd;
    logic [WB_GROUP_W-1:0] anchored_lui_wb_group;
    logic [WB_GROUP_W-1:0] anchored_lw_wb_group;
    logic [31:0] captured_lw_rdata;
    logic lw_startup_seen;
    logic lw_instruction_line_request_seen;
    logic lw_instruction_returned_seen;
    logic lw_fetch_request_seen;
    logic lw_fetch_complete_seen;
    logic lw_decode_seen;
    logic lw_issue_seen;
    logic lui_decode_seen;
    logic lui_issue_seen;
    logic lui_writeback_seen;
    logic lw_source_mapping_seen;
    logic lw_source_value_seen;
    logic lw_lsu_command_seen;
    logic lw_lsu_request_seen;
    logic lw_lsu_request_accepted_seen;
    logic lw_axi_requesting_read_seen;
    logic lw_axi_arvalid_seen;
    logic lw_axi_ar_handshake_seen;
    logic lw_axi_r_response_seen;
    logic lw_lsu_completion_seen;
    logic lw_writeback_seen;
    logic lw_retire_seen;
    logic lw_arch_x2_update_seen;
    logic lw_writeback_tracking_active;
    logic lw_response_captured;
    logic lw_retirement_pending;

    logic lw_instruction_line_request_event;
    logic lui_instruction_returned_event;
    logic lw_instruction_returned_event;
    logic lw_fetch_request_event;
    logic lw_icache_restart_event;
    logic lw_icache_lw_hit_event;
    logic lw_fetch_id_match;
    logic lw_fetch_complete_event;
    logic lui_decode_event;
    logic lui_issue_event;
    logic lui_writeback_event;
    logic lw_decode_event;
    logic lw_issue_event;
    logic lw_source_mapping_event;
    logic lw_source_value_event;
    logic lw_lsu_command_event;
    logic lw_dtlb_bus_match_event;
    logic lw_lsq_load_valid_event;
    logic lw_axi_subunit_ready_event;
    logic lw_lsu_request_event;
    logic lw_lsu_request_accepted_event;
    logic lw_axi_requesting_read_event;
    logic lw_axi_arvalid_event;
    logic lw_axi_ar_handshake_event;
    logic lw_axi_r_response_event;
    logic lw_lsu_completion_event;
    logic lw_rdata_capture_event;
    logic lw_writeback_event;
    logic lw_register_file_write_event;
    logic lw_retire_event;
    logic lw_arch_x2_update_event;
    logic [31:0] lw_writeback_data;
    phys_addr_t lw_writeback_phys_rd;
    logic [WB_GROUP_W-1:0] lw_writeback_group;
    logic lw_writeback_suppressed;
    logic [EXAMPLE_CONFIG.NUM_WB_GROUPS-1:0] lui_commit_by_group;
    logic [EXAMPLE_CONFIG.NUM_WB_GROUPS-1:0] lw_commit_by_group;

    /////////////////////////////////////////////////////////////////
    // DUT
    /////////////////////////////////////////////////////////////////

    // This framework starts the memory model immediately after reset. The
    // legacy wrapper default remains 80 cycles for historical flows.
    cva5_formal_wrapper #(
        .FBM_STARTUP_CYCLES(1),
        .FBM_ASSUME_CYCLE_RESET_SEQUENCE(1'b0)
    ) u_fullcore (
        .clk,
        .rst,
        .axi_arready_choice,
        .axi_awready_choice,
        .axi_wready_choice
    );

    /////////////////////////////////////////////////////////////////
    // formal helper signals
    /////////////////////////////////////////////////////////////////

    assign embedded_axi_state =
        u_fullcore.u_cva5_core.load_store_unit_block.gen_ls_pbus.gen_axi.axi_bus.current_state;
    assign formal_active = u_fullcore.full_smoke_active;

    assign normal_lsu_load_request =
        u_fullcore.u_cva5_core.load_store_unit_block.sub_unit[FULL_LS_BUS_ID].new_request &&
        u_fullcore.u_cva5_core.load_store_unit_block.sub_unit[FULL_LS_BUS_ID].re &&
        !u_fullcore.u_cva5_core.load_store_unit_block.sub_unit[FULL_LS_BUS_ID].we &&
        !u_fullcore.u_cva5_core.load_store_unit_block.shared_inputs.amo;

    assign normal_lsu_load_accept =
        normal_lsu_load_request &&
        u_fullcore.u_cva5_core.load_store_unit_block.sub_unit[FULL_LS_BUS_ID].ready &&
        embedded_axi_state == AXI_STATE_READY;

    assign fullcore_ar_accept =
        u_fullcore.m_axi.arvalid && u_fullcore.m_axi.arready;
    assign fullcore_r_accept =
        u_fullcore.m_axi.rvalid && u_fullcore.m_axi.rready;

    assign fullcore_lsu_load_completion =
        u_fullcore.u_cva5_core.load_store_unit_block.sub_unit[FULL_LS_BUS_ID].ready &&
        u_fullcore.u_cva5_core.load_store_unit_block.sub_unit[FULL_LS_BUS_ID].data_valid &&
        !u_fullcore.m_axi.arlock;

    assign lw_instruction_line_request_event =
        u_fullcore.mem.request &&
        u_fullcore.mem.id == 2'b01 &&
        u_fullcore.mem.addr == RESET_WORD_ADDR;

    assign lw_instruction_returned_event =
        u_fullcore.mem.rvalid &&
        u_fullcore.mem.rid == 2'b01 &&
        u_fullcore.mem.rdata == LW_INSTRUCTION;

    assign lui_instruction_returned_event =
        u_fullcore.mem.rvalid &&
        u_fullcore.mem.rid == 2'b01 &&
        u_fullcore.mem.rdata == LUI_INSTRUCTION;

    assign lw_fetch_request_event =
        u_fullcore.u_cva5_core.fetch_block.new_mem_request &&
        u_fullcore.u_cva5_core.pc_id_assigned &&
        u_fullcore.u_cva5_core.if_pc == LW_PC;

    assign lw_icache_restart_event =
        u_fullcore.u_cva5_core.fetch_block.gen_fetch_icache.i_cache.new_request &&
        u_fullcore.u_cva5_core.fetch_block.gen_fetch_icache.i_cache.new_request_addr ==
            LW_PC;

    assign lw_icache_lw_hit_event =
        u_fullcore.u_cva5_core.fetch_block.gen_fetch_icache.i_cache.second_cycle &&
        u_fullcore.u_cva5_core.fetch_block.gen_fetch_icache.i_cache.second_cycle_addr ==
            LW_PC &&
        u_fullcore.u_cva5_core.fetch_block.gen_fetch_icache.i_cache.tag_hit &&
        u_fullcore.u_cva5_core.fetch_block.gen_fetch_icache.i_cache.fetch_sub.data_valid &&
        u_fullcore.u_cva5_core.fetch_block.gen_fetch_icache.i_cache.fetch_sub.data_out ==
            LW_INSTRUCTION;

    assign lw_fetch_id_match =
        (lw_fetch_request_seen &&
            u_fullcore.u_cva5_core.fetch_id == anchored_lw_id) ||
        (lw_fetch_request_event &&
            u_fullcore.u_cva5_core.fetch_id ==
                u_fullcore.u_cva5_core.pc_id);

    assign lw_fetch_complete_event =
        u_fullcore.u_cva5_core.fetch_complete &&
        u_fullcore.u_cva5_core.fetch_block.valid_fetch_result &&
        |u_fullcore.u_cva5_core.fetch_block.unit_data_valid &&
        u_fullcore.u_cva5_core.fetch_instruction == LW_INSTRUCTION &&
        lw_fetch_id_match;

    assign lui_decode_event =
        u_fullcore.u_cva5_core.decode_advance &&
        u_fullcore.u_cva5_core.decode.valid &&
        u_fullcore.u_cva5_core.decode.pc == EXAMPLE_CONFIG.CSRS.RESET_VEC &&
        u_fullcore.u_cva5_core.decode.instruction == LUI_INSTRUCTION;

    assign lui_issue_event =
        u_fullcore.u_cva5_core.unit_issue[ALU_ID].new_request &&
        u_fullcore.u_cva5_core.unit_issue[ALU_ID].id == anchored_lui_id &&
        u_fullcore.u_cva5_core.issue.pc == EXAMPLE_CONFIG.CSRS.RESET_VEC &&
        u_fullcore.u_cva5_core.issue.instruction == LUI_INSTRUCTION &&
        u_fullcore.u_cva5_core.issue.id == anchored_lui_id;

    for (genvar wb_group = 0;
            wb_group < EXAMPLE_CONFIG.NUM_WB_GROUPS; wb_group++) begin : gen_lui_commit_observer
        assign lui_commit_by_group[wb_group] =
            u_fullcore.u_cva5_core.wb_packet[wb_group].valid &&
            u_fullcore.u_cva5_core.wb_packet[wb_group].id == anchored_lui_id &&
            u_fullcore.u_cva5_core.wb_packet[wb_group].data == LW_DATA_ADDR &&
            u_fullcore.u_cva5_core.wb_phys_addr[wb_group] == anchored_lui_phys_rd &&
            WB_GROUP_W'(wb_group) == anchored_lui_wb_group;
    end
    assign lui_writeback_event = |lui_commit_by_group;

    assign lw_decode_event =
        u_fullcore.u_cva5_core.decode_advance &&
        u_fullcore.u_cva5_core.decode.valid &&
        u_fullcore.u_cva5_core.decode.pc == LW_PC &&
        u_fullcore.u_cva5_core.decode.instruction == LW_INSTRUCTION &&
        u_fullcore.u_cva5_core.decode.id == anchored_lw_id;

    assign lw_issue_event =
        u_fullcore.u_cva5_core.unit_issue[LS_ID].new_request &&
        u_fullcore.u_cva5_core.unit_issue[LS_ID].id == anchored_lw_id &&
        u_fullcore.u_cva5_core.issue.pc == LW_PC &&
        u_fullcore.u_cva5_core.issue.instruction == LW_INSTRUCTION &&
        u_fullcore.u_cva5_core.issue.id == anchored_lw_id;

    assign lw_source_mapping_event =
        lw_decode_event &&
        lui_decode_seen &&
        u_fullcore.u_cva5_core.decode_phys_rs_addr[RS1] ==
            anchored_lui_phys_rd &&
        u_fullcore.u_cva5_core.decode_rs_wb_group[RS1] ==
            anchored_lui_wb_group;

    assign lw_source_value_event =
        lw_issue_event &&
        lw_source_mapping_seen &&
        u_fullcore.u_cva5_core.rf_issue.data[RS1] == LW_DATA_ADDR;

    assign lw_lsu_command_event =
        lw_source_value_event &&
        u_fullcore.u_cva5_core.load_store_unit_block.tlb.new_request &&
        u_fullcore.u_cva5_core.load_store_unit_block.tlb.virtual_address ==
            LW_DATA_ADDR &&
        u_fullcore.u_cva5_core.load_store_unit_block.tlb.rnw &&
        u_fullcore.u_cva5_core.load_store_unit_block.issue_attr.is_load &&
        !u_fullcore.u_cva5_core.load_store_unit_block.issue_attr.is_amo &&
        !u_fullcore.u_cva5_core.load_store_unit_block.unaligned_addr;

    assign lw_dtlb_bus_match_event =
        lw_lsu_command_seen &&
        u_fullcore.u_cva5_core.load_store_unit_block.tlb.done &&
        !u_fullcore.u_cva5_core.load_store_unit_block.tlb.is_fault &&
        u_fullcore.u_cva5_core.load_store_unit_block.tlb.physical_address ==
            LW_DATA_ADDR &&
        u_fullcore.u_cva5_core.load_store_unit_block.sub_unit_address_match[
            FULL_LS_BUS_ID];

    assign lw_lsq_load_valid_event =
        lw_lsu_command_seen &&
        u_fullcore.u_cva5_core.load_store_unit_block.lsq.load_valid &&
        u_fullcore.u_cva5_core.load_store_unit_block.shared_inputs.load &&
        !u_fullcore.u_cva5_core.load_store_unit_block.shared_inputs.store &&
        !u_fullcore.u_cva5_core.load_store_unit_block.shared_inputs.amo &&
        u_fullcore.u_cva5_core.load_store_unit_block.shared_inputs.id ==
            anchored_lw_id &&
        u_fullcore.u_cva5_core.load_store_unit_block.shared_inputs.addr ==
            LW_DATA_ADDR &&
        u_fullcore.u_cva5_core.load_store_unit_block.shared_inputs.fn3 ==
            3'b010;

    assign lw_axi_subunit_ready_event =
        lw_lsq_load_valid_event &&
        u_fullcore.u_cva5_core.load_store_unit_block.sub_unit[
            FULL_LS_BUS_ID].ready &&
        embedded_axi_state == AXI_STATE_READY;

    assign lw_lsu_request_event =
        normal_lsu_load_request &&
        u_fullcore.u_cva5_core.load_store_unit_block.shared_inputs.id == anchored_lw_id &&
        u_fullcore.u_cva5_core.load_store_unit_block.shared_inputs.addr == LW_DATA_ADDR &&
        u_fullcore.u_cva5_core.load_store_unit_block.shared_inputs.fn3 == 3'b010;

    assign lw_lsu_request_accepted_event =
        lw_lsu_request_event &&
        u_fullcore.u_cva5_core.load_store_unit_block.sub_unit[FULL_LS_BUS_ID].ready &&
        embedded_axi_state == AXI_STATE_READY;

    assign lw_axi_requesting_read_event =
        embedded_axi_state == AXI_STATE_REQUESTING_READ;

    assign lw_axi_arvalid_event =
        u_fullcore.m_axi.arvalid &&
        u_fullcore.m_axi.araddr == LW_DATA_ADDR;

    assign lw_axi_ar_handshake_event =
        lw_axi_arvalid_event && u_fullcore.m_axi.arready;

    assign lw_axi_r_response_event =
        fullcore_r_accept &&
        u_fullcore.m_axi.rresp == 2'b00 &&
        u_fullcore.m_axi.rlast;

    assign lw_lsu_completion_event =
        u_fullcore.u_cva5_core.unit_wb[LS_ID].done &&
        u_fullcore.u_cva5_core.unit_wb[LS_ID].id == anchored_lw_id;

    assign lw_rdata_capture_event =
        lw_writeback_tracking_active &&
        lw_axi_ar_handshake_seen &&
        !lw_response_captured &&
        lw_axi_r_response_event;

    for (genvar wb_group = 0;
            wb_group < EXAMPLE_CONFIG.NUM_WB_GROUPS; wb_group++) begin : gen_lw_commit_observer
        assign lw_commit_by_group[wb_group] =
            lw_writeback_tracking_active &&
            lw_response_captured &&
            u_fullcore.u_cva5_core.wb_packet[wb_group].valid &&
            u_fullcore.u_cva5_core.wb_packet[wb_group].id == anchored_lw_id;
    end

    always_comb begin
        lw_writeback_event = 1'b0;
        lw_writeback_data = '0;
        lw_writeback_phys_rd = '0;
        lw_writeback_group = '0;
        for (int wb_group = 0;
                wb_group < EXAMPLE_CONFIG.NUM_WB_GROUPS; wb_group++) begin
            if (lw_commit_by_group[wb_group]) begin
                lw_writeback_event = 1'b1;
                lw_writeback_data =
                    u_fullcore.u_cva5_core.wb_packet[wb_group].data;
                lw_writeback_phys_rd =
                    u_fullcore.u_cva5_core.wb_phys_addr[wb_group];
                lw_writeback_group = WB_GROUP_W'(wb_group);
            end
        end
    end

    assign lw_writeback_suppressed =
        u_fullcore.u_cva5_core.gc.writeback_suppress;
    assign lw_register_file_write_event =
        lw_writeback_event && !lw_writeback_suppressed;
    assign lw_retire_event =
        lw_retirement_pending &&
        u_fullcore.u_cva5_core.wb_retire.valid &&
        u_fullcore.u_cva5_core.wb_retire.id == anchored_lw_id;

    // CVA5 architectural integer state is a rename-map entry plus the selected
    // physical register-bank value. EXAMPLE_CONFIG assigns LS writes to bank 1.
    assign lw_arch_x2_update_event =
        lw_retire_event &&
        u_fullcore.u_cva5_core.renamer_block.spec_table_ram.xilinx_gen.ram[5'd2] ==
            {anchored_lw_phys_rd, anchored_lw_wb_group} &&
        u_fullcore.u_cva5_core.register_file_block.register_file_gen[1].
            register_file_bank.xilinx_gen.ram[anchored_lw_phys_rd] ==
                captured_lw_rdata;

    always_ff @(posedge clk) begin
        if (rst) begin
            anchored_lui_id <= '0;
            anchored_lw_id <= '0;
            anchored_lui_phys_rd <= '0;
            anchored_lw_phys_rd <= '0;
            anchored_lw_arch_rd <= '0;
            anchored_lui_wb_group <= '0;
            anchored_lw_wb_group <= '0;
            captured_lw_rdata <= '0;
            lw_startup_seen <= 1'b0;
            lw_instruction_line_request_seen <= 1'b0;
            lw_instruction_returned_seen <= 1'b0;
            lw_fetch_request_seen <= 1'b0;
            lw_fetch_complete_seen <= 1'b0;
            lw_decode_seen <= 1'b0;
            lw_issue_seen <= 1'b0;
            lui_decode_seen <= 1'b0;
            lui_issue_seen <= 1'b0;
            lui_writeback_seen <= 1'b0;
            lw_source_mapping_seen <= 1'b0;
            lw_source_value_seen <= 1'b0;
            lw_lsu_command_seen <= 1'b0;
            lw_lsu_request_seen <= 1'b0;
            lw_lsu_request_accepted_seen <= 1'b0;
            lw_axi_requesting_read_seen <= 1'b0;
            lw_axi_arvalid_seen <= 1'b0;
            lw_axi_ar_handshake_seen <= 1'b0;
            lw_axi_r_response_seen <= 1'b0;
            lw_lsu_completion_seen <= 1'b0;
            lw_writeback_seen <= 1'b0;
            lw_retire_seen <= 1'b0;
            lw_arch_x2_update_seen <= 1'b0;
            lw_writeback_tracking_active <= 1'b0;
            lw_response_captured <= 1'b0;
            lw_retirement_pending <= 1'b0;
        end
        else begin
            if (formal_active)
                lw_startup_seen <= 1'b1;

            if ((lw_startup_seen || formal_active) &&
                    lw_instruction_line_request_event)
                lw_instruction_line_request_seen <= 1'b1;

            // FBM mem.rvalid can only follow an accepted memory request, so
            // the response itself carries the request-ordering dependency.
            if (lw_instruction_returned_event)
                lw_instruction_returned_seen <= 1'b1;

            // The icache miss path can replay the same anchored PC with a new
            // fetch ID. Follow those pre-completion replays so the observer
            // tracks the logical LW rather than a stale allocation ID.
            if (lw_fetch_request_event && !lw_fetch_complete_seen) begin
                lw_fetch_request_seen <= 1'b1;
                anchored_lw_id <= u_fullcore.u_cva5_core.pc_id;
            end

            if ((lw_instruction_returned_seen || lw_instruction_returned_event) &&
                    (lw_fetch_request_seen || lw_fetch_request_event) &&
                    lw_fetch_complete_event)
                lw_fetch_complete_seen <= 1'b1;

            if (lui_decode_event) begin
                lui_decode_seen <= 1'b1;
                anchored_lui_id <= u_fullcore.u_cva5_core.decode.id;
                anchored_lui_phys_rd <=
                    u_fullcore.u_cva5_core.decode_phys_rd_addr;
                anchored_lui_wb_group <=
                    u_fullcore.u_cva5_core.decode_rename_interface.rd_wb_group;
            end

            if ((lui_decode_seen || lui_decode_event) && lui_issue_event)
                lui_issue_seen <= 1'b1;

            if ((lui_issue_seen || lui_issue_event) && lui_writeback_event)
                lui_writeback_seen <= 1'b1;

            if (lw_fetch_complete_seen && lw_decode_event)
                lw_decode_seen <= 1'b1;

            if (lw_fetch_complete_seen && lw_decode_event &&
                    !lw_writeback_tracking_active && !lw_retirement_pending) begin
                anchored_lw_phys_rd <=
                    u_fullcore.u_cva5_core.decode_phys_rd_addr;
                anchored_lw_arch_rd <=
                    u_fullcore.u_cva5_core.decode_rd_addr;
                anchored_lw_wb_group <=
                    u_fullcore.u_cva5_core.decode_rename_interface.rd_wb_group;
                lw_writeback_tracking_active <= 1'b1;
            end

            if (lw_source_mapping_event)
                lw_source_mapping_seen <= 1'b1;

            if (lw_decode_seen && lw_issue_event)
                lw_issue_seen <= 1'b1;

            if (lw_source_value_event)
                lw_source_value_seen <= 1'b1;

            if ((lw_issue_seen || lw_issue_event) && lw_lsu_command_event)
                lw_lsu_command_seen <= 1'b1;

            if (lw_lsu_command_seen && lw_lsu_request_event)
                lw_lsu_request_seen <= 1'b1;

            if ((lw_lsu_request_seen || lw_lsu_request_event) &&
                    lw_lsu_request_accepted_event)
                lw_lsu_request_accepted_seen <= 1'b1;

            if (lw_lsu_request_accepted_seen && lw_axi_requesting_read_event)
                lw_axi_requesting_read_seen <= 1'b1;

            if ((lw_axi_requesting_read_seen || lw_axi_requesting_read_event) &&
                    lw_axi_arvalid_event)
                lw_axi_arvalid_seen <= 1'b1;

            if ((lw_axi_arvalid_seen || lw_axi_arvalid_event) &&
                    lw_axi_ar_handshake_event)
                lw_axi_ar_handshake_seen <= 1'b1;

            if (lw_axi_ar_handshake_seen && lw_axi_r_response_event)
                lw_axi_r_response_seen <= 1'b1;

            if ((lw_axi_r_response_seen || lw_axi_r_response_event) &&
                    lw_lsu_completion_event)
                lw_lsu_completion_seen <= 1'b1;

            if (lw_rdata_capture_event) begin
                captured_lw_rdata <= u_fullcore.m_axi.rdata;
                lw_response_captured <= 1'b1;
            end

            if (lw_writeback_event) begin
                lw_writeback_seen <= 1'b1;
                lw_writeback_tracking_active <= 1'b0;
                lw_response_captured <= 1'b0;
                lw_retirement_pending <= 1'b1;
            end

            if (lw_retire_event) begin
                lw_retire_seen <= 1'b1;
                lw_retirement_pending <= 1'b0;
            end

            if (lw_arch_x2_update_event)
                lw_arch_x2_update_seen <= 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            embedded_axi_read_pending <= 1'b0;
        end
        else begin
            if (fullcore_ar_accept)
                embedded_axi_read_pending <= 1'b1;
            if (fullcore_r_accept)
                embedded_axi_read_pending <= 1'b0;
        end
    end

    /////////////////////////////////////////////////////////////////
    // ENVIRONMENT ASSUMPTIONS
    /////////////////////////////////////////////////////////////////

    // Jasper's reset command establishes the initial reset state. Formal proof
    // then runs with reset deasserted; this assumption makes that environment
    // contract explicit in the named framework tasks.
    assume_framework_no_reset_reassertion:
        assume property (@(posedge clk) !rst);

    // EXAMPLE_CONFIG generates no custom-unit instance. The corresponding
    // internal interface outputs have no RTL driver, so formal must model the
    // disabled unit's intended quiescent tieoff explicitly. This assumption
    // does not force decode, issue, LSU, or AXI progress.
    assume_disabled_custom_unit_quiet:
        assume property (@(posedge clk)
            !u_fullcore.u_cva5_core.unit_needed[CUSTOM_ID] &&
            u_fullcore.u_cva5_core.unit_uses_rs[CUSTOM_ID] == '0 &&
            !u_fullcore.u_cva5_core.unit_uses_rd[CUSTOM_ID] &&
            !u_fullcore.u_cva5_core.unit_issue[CUSTOM_ID].ready &&
            !u_fullcore.u_cva5_core.unit_wb[CUSTOM_ID].done);

    /////////////////////////////////////////////////////////////////
    // DUT PROPERTIES ASSERTIONS
    /////////////////////////////////////////////////////////////////

    // Request helpers
    helper_load_accept_enters_requesting_read:
        assert property (@(posedge clk) disable iff (rst)
            normal_lsu_load_accept
            |=> embedded_axi_state == AXI_STATE_REQUESTING_READ);

    helper_requesting_read_drives_arvalid:
        assert property (@(posedge clk) disable iff (rst)
            embedded_axi_state == AXI_STATE_REQUESTING_READ
            |-> u_fullcore.m_axi.arvalid);

    helper_requesting_read_waits_for_arready:
        assert property (@(posedge clk) disable iff (rst)
            embedded_axi_state == AXI_STATE_REQUESTING_READ &&
            !u_fullcore.m_axi.arready
            |=> embedded_axi_state == AXI_STATE_REQUESTING_READ);

    helper_arvalid_backpressure_implies_requesting_read:
        assert property (@(posedge clk) disable iff (rst)
            u_fullcore.m_axi.arvalid && !u_fullcore.m_axi.arready &&
            !u_fullcore.m_axi.arlock
            |-> embedded_axi_state == AXI_STATE_REQUESTING_READ);

    helper_load_accept_captures_address:
        assert property (@(posedge clk) disable iff (rst)
            normal_lsu_load_accept
            |=> u_fullcore.u_cva5_core.load_store_unit_block.gen_ls_pbus.gen_axi.axi_bus.addr ==
                $past(u_fullcore.u_cva5_core.load_store_unit_block.sub_unit[FULL_LS_BUS_ID].addr[31:2]));

    // AR guarantees
    fullcore_embedded_arvalid_hold:
        assert property (@(posedge clk) disable iff (rst)
            u_fullcore.m_axi.arvalid && !u_fullcore.m_axi.arready
            |=> u_fullcore.m_axi.arvalid);

    fullcore_embedded_araddr_stability:
        assert property (@(posedge clk) disable iff (rst)
            u_fullcore.m_axi.arvalid && !u_fullcore.m_axi.arready
            |=> $stable({u_fullcore.m_axi.araddr,
                         u_fullcore.m_axi.arlen,
                         u_fullcore.m_axi.arburst,
                         u_fullcore.m_axi.arlock,
                         u_fullcore.m_axi.arid}));

    fullcore_lsu_to_araddr_mapping:
        assert property (@(posedge clk) disable iff (rst)
            normal_lsu_load_accept
            |=> u_fullcore.m_axi.araddr ==
                {$past(u_fullcore.u_cva5_core.load_store_unit_block.sub_unit[FULL_LS_BUS_ID].addr[31:2]), 2'b0});

    // Response helpers
    // Read-response tracking is proof instrumentation, not a DUT state bit.
    helper_ar_accept_sets_pending:
        assert property (@(posedge clk) disable iff (rst)
            fullcore_ar_accept && !fullcore_r_accept
            |=> embedded_axi_read_pending);

    helper_pending_holds_without_r_response:
        assert property (@(posedge clk) disable iff (rst)
            embedded_axi_read_pending && !fullcore_r_accept
            |=> embedded_axi_read_pending);

    helper_pending_implies_waiting_read:
        assert property (@(posedge clk) disable iff (rst)
            embedded_axi_read_pending && !u_fullcore.m_axi.rvalid
            |-> embedded_axi_state == AXI_STATE_WAITING_READ);

    helper_waiting_read_holds_until_rvalid:
        assert property (@(posedge clk) disable iff (rst)
            embedded_axi_state == AXI_STATE_WAITING_READ &&
            !u_fullcore.m_axi.rvalid
            |=> embedded_axi_state == AXI_STATE_WAITING_READ);

    environment_rvalid_requires_pending:
        assert property (@(posedge clk) disable iff (rst)
            u_fullcore.m_axi.rvalid |-> embedded_axi_read_pending);

    // Response guarantees
    fullcore_r_response_clears_pending:
        assert property (@(posedge clk) disable iff (rst)
            fullcore_r_accept |=> !embedded_axi_read_pending);

    fullcore_r_response_returns_master_ready:
        assert property (@(posedge clk) disable iff (rst)
            fullcore_r_accept && !u_fullcore.m_axi.arlock
            |=> embedded_axi_state == AXI_STATE_READY);

    fullcore_r_response_completes_lsu:
        assert property (@(posedge clk) disable iff (rst)
            fullcore_r_accept && !u_fullcore.m_axi.arlock
            |=> fullcore_lsu_load_completion);

    fullcore_no_load_completion_before_response:
        assert property (@(posedge clk) disable iff (rst)
            fullcore_lsu_load_completion
            |-> $past(embedded_axi_read_pending && fullcore_r_accept));

    fullcore_returned_data_mapping:
        assert property (@(posedge clk) disable iff (rst)
            fullcore_lsu_load_completion
            |-> u_fullcore.u_cva5_core.load_store_unit_block.sub_unit[FULL_LS_BUS_ID].data_out ==
                $past(u_fullcore.m_axi.rdata));

    // Tracker helpers
    helper_lw_decode_destination:
        assert property (@(posedge clk) disable iff (rst)
            lw_decode_event
            |-> u_fullcore.u_cva5_core.decode_rd_addr == LW_ARCH_RD &&
                u_fullcore.u_cva5_core.decode_rename_interface.rd_wb_group ==
                    LS_WB_GROUP);

    helper_lw_writeback_tracker_created:
        assert property (@(posedge clk) disable iff (rst)
            lw_fetch_complete_seen && lw_decode_event &&
            !lw_writeback_tracking_active && !lw_retirement_pending
            |=> lw_writeback_tracking_active &&
                anchored_lw_arch_rd ==
                    $past(u_fullcore.u_cva5_core.decode_rd_addr) &&
                anchored_lw_phys_rd ==
                    $past(u_fullcore.u_cva5_core.decode_phys_rd_addr) &&
                anchored_lw_wb_group ==
                    $past(u_fullcore.u_cva5_core.decode_rename_interface.rd_wb_group));

    helper_lw_writeback_tracker_holds:
        assert property (@(posedge clk) disable iff (rst)
            lw_writeback_tracking_active && !lw_writeback_event
            |=> lw_writeback_tracking_active &&
                $stable({anchored_lw_arch_rd,
                         anchored_lw_phys_rd,
                         anchored_lw_wb_group}));

    helper_lw_id_to_phys_mapping:
        assert property (@(posedge clk) disable iff (rst)
            lw_writeback_tracking_active
            |-> u_fullcore.u_cva5_core.id_block.id_to_phys_rd_table.
                    xilinx_gen.ram[anchored_lw_id] == anchored_lw_phys_rd);

    helper_lw_writeback_tracker_clears:
        assert property (@(posedge clk) disable iff (rst)
            lw_writeback_tracking_active && lw_writeback_event
            |=> !lw_writeback_tracking_active &&
                !lw_response_captured && lw_retirement_pending);

    helper_lw_rdata_capture:
        assert property (@(posedge clk) disable iff (rst)
            lw_rdata_capture_event
            |=> lw_response_captured &&
                captured_lw_rdata == $past(u_fullcore.m_axi.rdata));

    helper_lw_rdata_holds_until_writeback:
        assert property (@(posedge clk) disable iff (rst)
            lw_response_captured && !lw_writeback_event
            |=> lw_response_captured && $stable(captured_lw_rdata));

    helper_lw_retirement_tracker_clears:
        assert property (@(posedge clk) disable iff (rst)
            lw_retirement_pending && lw_retire_event
            |=> !lw_retirement_pending);

    // LW guarantees
    fullcore_lw_rdata_matches_lsu_data:
        assert property (@(posedge clk) disable iff (rst)
            lw_writeback_tracking_active && lw_response_captured &&
            lw_lsu_completion_event
            |-> u_fullcore.u_cva5_core.unit_wb[LS_ID].rd ==
                captured_lw_rdata);

    fullcore_lw_writeback_destination:
        assert property (@(posedge clk) disable iff (rst)
            lw_writeback_event
            |-> anchored_lw_arch_rd == LW_ARCH_RD &&
                anchored_lw_wb_group == LS_WB_GROUP &&
                lw_writeback_group == anchored_lw_wb_group &&
                lw_writeback_phys_rd == anchored_lw_phys_rd);

    fullcore_lw_writeback_data:
        assert property (@(posedge clk) disable iff (rst)
            lw_writeback_event
            |-> lw_writeback_data == captured_lw_rdata);

    fullcore_lw_register_file_write_port:
        assert property (@(posedge clk) disable iff (rst)
            lw_writeback_event
            |-> lw_register_file_write_event &&
                u_fullcore.u_cva5_core.wb_packet[1].valid &&
                u_fullcore.u_cva5_core.wb_packet[1].id == anchored_lw_id &&
                u_fullcore.u_cva5_core.wb_packet[1].data == captured_lw_rdata &&
                u_fullcore.u_cva5_core.wb_phys_addr[1] == anchored_lw_phys_rd);

    fullcore_lw_register_file_update:
        assert property (@(posedge clk) disable iff (rst)
            lw_register_file_write_event
            |=> u_fullcore.u_cva5_core.register_file_block.register_file_gen[1].
                    register_file_bank.xilinx_gen.ram[$past(anchored_lw_phys_rd)] ==
                        $past(captured_lw_rdata));

    fullcore_lw_architectural_x2_update:
        assert property (@(posedge clk) disable iff (rst)
            lw_retire_event
            |-> u_fullcore.u_cva5_core.renamer_block.spec_table_ram.xilinx_gen.ram[5'd2] ==
                    {anchored_lw_phys_rd, anchored_lw_wb_group} &&
                u_fullcore.u_cva5_core.register_file_block.register_file_gen[1].
                    register_file_bank.xilinx_gen.ram[anchored_lw_phys_rd] ==
                        captured_lw_rdata);

    fullcore_lw_instruction_result:
        assert property (@(posedge clk) disable iff (rst)
            lw_retire_event
            |-> lw_writeback_seen &&
                anchored_lw_arch_rd == LW_ARCH_RD &&
                lw_arch_x2_update_event);

    /////////////////////////////////////////////////////////////////
    // COVER
    /////////////////////////////////////////////////////////////////

    // Reset startup
    // Jasper's global `reset rst` establishes the reset state of every tracker
    // before focused cover search. The reset-release stage alone observes the
    // deassertion edge explicitly.
    cover_core_reset_release:
        cover property (@(posedge clk) $fell(rst));

    cover_core_startup_complete:
        cover property (@(posedge clk) formal_active);

    // Fetch reachability
    cover_lw_instruction_request:
        cover property (@(posedge clk) lw_instruction_line_request_seen);

    cover_lw_instruction_returned:
        cover property (@(posedge clk) disable iff (rst || !formal_active)
            lui_instruction_returned_event
            ##1 lw_instruction_returned_event);

    cover_debug_lw_fetch_request_allocated:
        cover property (@(posedge clk) lw_fetch_request_seen);

    cover_debug_lw_icache_request_queued:
        cover property (@(posedge clk) disable iff (rst)
            formal_active &&
            u_fullcore.u_cva5_core.fetch_block.gen_fetch_icache.i_cache.input_fifo.valid &&
            u_fullcore.u_cva5_core.fetch_block.gen_fetch_icache.i_cache.input_fifo.data_out ==
                LW_PC);

    cover_debug_lw_icache_line_complete_queued:
        cover property (@(posedge clk) disable iff (rst)
            formal_active &&
            u_fullcore.u_cva5_core.fetch_block.gen_fetch_icache.i_cache.line_complete &&
            u_fullcore.u_cva5_core.fetch_block.gen_fetch_icache.i_cache.word_count ==
                ICACHE_LINE_LAST &&
            u_fullcore.u_cva5_core.fetch_block.gen_fetch_icache.i_cache.input_fifo.valid &&
            u_fullcore.u_cva5_core.fetch_block.gen_fetch_icache.i_cache.input_fifo.data_out ==
                LW_PC);

    cover_debug_lw_icache_restart:
        cover property (@(posedge clk) disable iff (rst)
            formal_active &&
            u_fullcore.u_cva5_core.fetch_block.gen_fetch_icache.i_cache.input_fifo.valid &&
            u_fullcore.u_cva5_core.fetch_block.gen_fetch_icache.i_cache.input_fifo.data_out ==
                LW_PC
            ##[1:8] lw_icache_restart_event);

    cover_debug_lw_icache_hit:
        cover property (@(posedge clk) disable iff (rst)
            lw_icache_restart_event
            ##[1:4] lw_icache_lw_hit_event);

    cover_debug_lw_fetch_complete_raw:
        cover property (@(posedge clk) disable iff (rst)
            lw_icache_lw_hit_event
            ##[0:1]
            u_fullcore.u_cva5_core.fetch_complete &&
            u_fullcore.u_cva5_core.fetch_block.valid_fetch_result &&
            |u_fullcore.u_cva5_core.fetch_block.unit_data_valid &&
            u_fullcore.u_cva5_core.fetch_instruction == LW_INSTRUCTION);

    cover_lw_fetch_complete:
        cover property (@(posedge clk) disable iff (rst || !formal_active)
            lw_fetch_complete_seen);

    // Decode reachability
    cover_debug_lui_decode:
        cover property (@(posedge clk) lui_decode_seen);

    cover_debug_lui_issue:
        cover property (@(posedge clk) lui_issue_seen);

    cover_debug_lui_writeback:
        cover property (@(posedge clk) lui_writeback_seen);

    cover_lw_decode_valid:
        cover property (@(posedge clk) lw_decode_seen);

    cover_debug_lw_source_mapping:
        cover property (@(posedge clk) lw_source_mapping_seen);

    cover_lw_issue_accept:
        cover property (@(posedge clk) lw_issue_seen);

    cover_debug_lw_source_value:
        cover property (@(posedge clk) lw_source_value_seen);

    // Diagnostic only: distinguishes an unexpected issued operand from a hard
    // expected-value data cone. It constrains nothing and is not a closure goal.
    cover_debug_lw_source_value_unexpected:
        cover property (@(posedge clk)
            lw_issue_event &&
            lw_source_mapping_seen &&
            u_fullcore.u_cva5_core.rf_issue.data[RS1] != LW_DATA_ADDR);

    // LSU reachability
    cover_lsu_load_command:
        cover property (@(posedge clk) lw_lsu_command_seen);

    cover_debug_lw_dtlb_bus_match:
        cover property (@(posedge clk) lw_dtlb_bus_match_event);

    cover_debug_lw_lsq_load_valid:
        cover property (@(posedge clk) lw_lsq_load_valid_event);

    cover_debug_lw_axi_subunit_ready:
        cover property (@(posedge clk) lw_axi_subunit_ready_event);

    // AXI reachability
    cover_lsu_load_request_accepted:
        cover property (@(posedge clk) lw_lsu_request_accepted_seen);

    cover_axi_master_enters_requesting_read:
        cover property (@(posedge clk) lw_axi_requesting_read_seen);

    cover_axi_arvalid_from_lw:
        cover property (@(posedge clk) lw_axi_arvalid_seen);

    cover_axi_ar_handshake_from_lw:
        cover property (@(posedge clk) lw_axi_ar_handshake_seen);

    cover_axi_r_response_for_lw:
        cover property (@(posedge clk) lw_axi_r_response_seen);

    cover_lsu_load_completion_from_lw:
        cover property (@(posedge clk) lw_lsu_completion_seen);

    cover_full_lw_to_axi_read_lifecycle:
        cover property (@(posedge clk) lw_lsu_completion_seen);

    cover_full_lw_reaches_writeback:
        cover property (@(posedge clk) lw_writeback_seen);

    cover_full_lw_reaches_retirement:
        cover property (@(posedge clk) lw_retire_seen);

    cover_full_lw_updates_x2:
        cover property (@(posedge clk) lw_arch_x2_update_seen);

    // End-to-end covers
    // Instruction-correlated reachability. These covers add no constraints.
    cover_lw_fetch_to_decode:
        cover property (@(posedge clk) disable iff (rst || !formal_active)
            u_fullcore.full_fetch_lw
            ##[0:128] u_fullcore.full_decode_lw);

    cover_lw_fetch_to_issue:
        cover property (@(posedge clk) disable iff (rst || !formal_active)
            u_fullcore.full_fetch_lw
            ##[0:128] u_fullcore.full_decode_lw
            ##[0:128] u_fullcore.full_issue_lw);

    cover_lw_to_lsu_load_request:
        cover property (@(posedge clk) disable iff (rst || !formal_active)
            u_fullcore.full_fetch_lw
            ##[0:128] u_fullcore.full_decode_lw
            ##[0:128] u_fullcore.full_issue_lw
            ##[0:64] normal_lsu_load_request);

    cover_lw_to_axi_master_accept:
        cover property (@(posedge clk) disable iff (rst || !formal_active)
            u_fullcore.full_fetch_lw
            ##[0:128] u_fullcore.full_decode_lw
            ##[0:128] u_fullcore.full_issue_lw
            ##[0:64] normal_lsu_load_accept);

    cover_lw_to_arvalid:
        cover property (@(posedge clk) disable iff (rst || !formal_active)
            u_fullcore.full_fetch_lw
            ##[0:128] u_fullcore.full_decode_lw
            ##[0:128] u_fullcore.full_issue_lw
            ##[0:64] normal_lsu_load_accept
            ##[0:4] u_fullcore.m_axi.arvalid);

    cover_lw_to_ar_handshake:
        cover property (@(posedge clk) disable iff (rst || !formal_active)
            u_fullcore.full_fetch_lw
            ##[0:128] u_fullcore.full_decode_lw
            ##[0:128] u_fullcore.full_issue_lw
            ##[0:64] normal_lsu_load_accept
            ##[0:32] fullcore_ar_accept);

    cover_lw_to_r_response:
        cover property (@(posedge clk) disable iff (rst || !formal_active)
            u_fullcore.full_fetch_lw
            ##[0:128] u_fullcore.full_decode_lw
            ##[0:128] u_fullcore.full_issue_lw
            ##[0:64] normal_lsu_load_accept
            ##[0:32] fullcore_ar_accept
            ##[1:16] fullcore_r_accept);

    cover_lw_to_load_completion:
        cover property (@(posedge clk) disable iff (rst || !formal_active)
            u_fullcore.full_fetch_lw
            ##[0:128] u_fullcore.full_decode_lw
            ##[0:128] u_fullcore.full_issue_lw
            ##[0:64] normal_lsu_load_accept
            ##[0:32] fullcore_ar_accept
            ##[1:16] fullcore_r_accept
            ##[1:4] fullcore_lsu_load_completion);

    // Embedded activity
    cover_axi_master_accepts_normal_load:
        cover property (@(posedge clk) disable iff (rst || !formal_active)
            normal_lsu_load_accept);

    cover_axi_master_requesting_read:
        cover property (@(posedge clk) disable iff (rst || !formal_active)
            embedded_axi_state == AXI_STATE_REQUESTING_READ);

    cover_embedded_r_response:
        cover property (@(posedge clk) disable iff (rst || !formal_active)
            fullcore_r_accept);

    cover_embedded_load_completion:
        cover property (@(posedge clk) disable iff (rst || !formal_active)
            fullcore_lsu_load_completion);

endmodule
