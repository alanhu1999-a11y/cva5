# Prove one focused full-core CVA5 reachability cover.

if {[info exists env(CVA5_ROOT)]} {
    set COMMON_TCL [file join $env(CVA5_ROOT) formal scripts tcl _axi_common.tcl]
} else {
    set COMMON_TCL [file join [pwd] formal scripts tcl _axi_common.tcl]
}
source $COMMON_TCL

if {![info exists env(JG_STAGE)] || $env(JG_STAGE) eq ""} {
    error "JG_STAGE is required. Example: make formal-cva5-reachability-stage STAGE=instruction_fetch"
}

array set CVA5_REACHABILITY_STAGE {
    reset                                   cover_reset_released
    startup                                 cover_startup_complete
    mem_request                             cover_any_mem_request
    instruction_mem_request                 cover_instruction_mem_request
    instruction_mem_ack                     cover_instruction_mem_ack
    instruction_mem_request_reset_vec       cover_instruction_mem_request_reset_vec
    instruction_mem_ack_reset_vec           cover_instruction_mem_ack_reset_vec
    instruction_mem_rvalid                  cover_instruction_mem_rvalid
    instruction_lui_returned_from_reset_vec cover_instruction_lui_returned_from_reset_vec
    instruction_lui_returned                cover_instruction_lui_returned
    instruction_lw_returned                 cover_instruction_lw_returned
    instruction_sw_returned                 cover_instruction_sw_returned
    instruction_program_returned            cover_instruction_program_returned
    instruction_mem_read                    cover_instruction_mem_lifecycle
    instruction_fetch                       cover_instruction_fetch
    fetch_complete                          cover_full_fetch_complete
    fetch_ready                             cover_full_fetch_ready
    fetch_pc_reset_vec                      cover_full_fetch_pc_reset_vec
    fetch_tlb_ready                         cover_full_fetch_tlb_ready
    fetch_pc_id_available                   cover_full_fetch_pc_id_available
    fetch_attr_fifo_not_full                cover_full_fetch_attr_fifo_not_full
    fetch_no_exception_pending              cover_full_fetch_no_exception_pending
    fetch_no_fetch_hold                     cover_full_fetch_no_fetch_hold
    fetch_tlb_request_enable                cover_full_fetch_tlb_request_enable
    fetch_tlb_request_any                   cover_full_fetch_tlb_request_any
    fetch_tlb_request_at_reset_pc           cover_full_fetch_tlb_request_at_reset_pc
    fetch_tlb_request                       cover_full_fetch_tlb_request
    fetch_tlb_done                          cover_full_fetch_tlb_done
    fetch_icache_subrequest                 cover_full_fetch_icache_subrequest
    fetch_icache_mem_request                cover_full_fetch_icache_mem_request
    fetch_icache_mem_ack                    cover_full_fetch_icache_mem_ack
    fetch_icache_mem_rvalid                 cover_full_fetch_icache_mem_rvalid
    core_mem_request_icache_reset_vec       cover_full_core_mem_request_icache_reset_vec
    fbm_mem_ack_icache_reset_vec            cover_full_fbm_mem_ack_icache_reset_vec
    fbm_response_lui_reset_vec              cover_full_fbm_response_lui_reset_vec
    core_icache_rvalid_lui_reset_vec        cover_full_core_icache_rvalid_lui_reset_vec
    fetch_icache_line_complete              cover_full_fetch_icache_line_complete
    fetch_icache_miss_data_valid            cover_full_fetch_icache_miss_data_valid
    fetch_icache_port_valid                 cover_full_fetch_icache_port_valid
    fetch_icache_port_lui                   cover_full_fetch_icache_port_lui
    fetch_icache_port_lui_raw               cover_full_fetch_icache_port_lui_raw
    fetch_subunit_valid                     cover_full_fetch_subunit_valid
    fetch_subunit_lui                       cover_full_fetch_subunit_lui
    fetch_unit_data_valid_any               cover_full_fetch_unit_data_valid_any
    fetch_unit_data_valid_icache            cover_full_fetch_unit_data_valid_icache
    fetch_unit_data_lui                     cover_full_fetch_unit_data_lui
    fetch_unit_data_lui_raw                 cover_full_fetch_unit_data_lui_raw
    fetch_instruction_lui_raw               cover_full_fetch_instruction_lui_raw
    fetch_attr_fifo_valid                   cover_full_fetch_attr_fifo_valid
    fetch_attr_icache                       cover_full_fetch_attr_icache
    fetch_attr_and_unit_data                cover_full_fetch_attr_and_unit_data
    fetch_attr_icache_and_lui_data          cover_full_fetch_attr_icache_and_lui_data
    fetch_attr_to_miss_data                 cover_full_fetch_attr_to_miss_data
    fetch_attr_to_lui_data                  cover_full_fetch_attr_to_lui_data
    fetch_internal_complete                 cover_full_fetch_internal_complete
    fetch_internal_complete_lui             cover_full_fetch_internal_complete_lui
    fetch_internal_complete_lui_raw         cover_full_fetch_internal_complete_lui_raw
    fetch_lui_data_to_internal_complete     cover_full_fetch_lui_data_to_internal_complete
    response_to_icache_port_lui             cover_full_response_to_icache_port_lui
    response_to_unit_data_lui               cover_full_response_to_unit_data_lui
    response_to_internal_complete_lui       cover_full_response_to_internal_complete_lui
    response_to_fetch_lui                   cover_full_response_to_fetch_lui
    fetch_assert_miss_implies_icache_port_valid assert_full_fetch_miss_implies_icache_port_valid
    fetch_assert_icache_port_implies_subunit_valid assert_full_fetch_icache_port_implies_subunit_valid
    fetch_assert_subunit_implies_unit_data_valid assert_full_fetch_subunit_implies_unit_data_valid
    fetch_assert_attr_and_unit_valid_imply_internal_complete assert_full_fetch_attr_and_unit_valid_imply_internal_complete
    fetch_assert_miss_implies_attr_icache assert_full_fetch_miss_implies_attr_icache
    fetch_assert_miss_implies_internal_complete assert_full_fetch_miss_implies_internal_complete
    fetch_assert_miss_implies_fetch_lui assert_full_fetch_miss_implies_fetch_lui
    fetch_no_flush_pending                  cover_full_fetch_no_flush_pending
    fetch_lui                               cover_full_fetch_lui
    fetch_lui_raw                           cover_full_fetch_lui_raw
    fetch_lw                                cover_full_fetch_lw
    fetch_sw                                cover_full_fetch_sw
    decode_lw                               cover_full_decode_lw
    decode_sw                               cover_full_decode_sw
    decode_ls_needed                        cover_full_decode_ls_needed
    issue_lw                                cover_full_issue_lw
    issue_sw                                cover_full_issue_sw
    issue_ls                                cover_full_issue_ls
    lsu_tlb_request                         cover_full_lsu_tlb_request
    lsu_tlb_done                            cover_full_lsu_tlb_done
    lsu_bus_match                           cover_full_lsu_bus_match
    axi_master_read_request                 cover_full_axi_master_read_request
    axi_master_write_request                cover_full_axi_master_write_request
    axi_arvalid_core                        cover_full_axi_arvalid
    axi_awvalid_core                        cover_full_axi_awvalid
    axi_wvalid_core                         cover_full_axi_wvalid
    full_read_to_arvalid                    cover_full_read_lifecycle_to_arvalid
    full_store_to_awvalid                   cover_full_store_lifecycle_to_awvalid
    axi_ar_handshake_core                   cover_full_axi_ar_handshake
    axi_aw_handshake_core                   cover_full_axi_aw_handshake
    axi_w_handshake_core                    cover_full_axi_w_handshake
    axi_arvalid                             cover_axi_arvalid
    axi_ar                                  cover_axi_ar_accepted
    axi_r                                   cover_axi_r_accepted
    axi_read                                cover_axi_read_lifecycle
    axi_ar_ready_high                       cover_axi_ar_ready_already_high
    axi_ar_ready_same                       cover_axi_ar_ready_same_cycle_as_valid
    axi_ar_wait_1                           cover_axi_ar_wait_1_cycle
    axi_ar_wait_2                           cover_axi_ar_wait_2_cycles
    axi_ar_wait_3                           cover_axi_ar_wait_3_cycles
    axi_ar_wait_16                          cover_axi_ar_wait_16_cycles
    axi_ar_wait_19                          cover_axi_ar_wait_19_cycles
    axi_aw                                  cover_axi_aw_accepted
    axi_w                                   cover_axi_w_accepted
    axi_b                                   cover_axi_b_accepted
    axi_write                               cover_axi_write_lifecycle
    axi_aw_ready_high                       cover_axi_aw_ready_already_high
    axi_aw_ready_same                       cover_axi_aw_ready_same_cycle_as_valid
    axi_aw_wait_1                           cover_axi_aw_wait_1_cycle
    axi_aw_wait_2                           cover_axi_aw_wait_2_cycles
    axi_aw_wait_3                           cover_axi_aw_wait_3_cycles
    axi_aw_wait_16                          cover_axi_aw_wait_16_cycles
    axi_aw_wait_19                          cover_axi_aw_wait_19_cycles
    axi_w_ready_high                        cover_axi_w_ready_already_high
    axi_w_ready_same                        cover_axi_w_ready_same_cycle_as_valid
    axi_w_wait_1                            cover_axi_w_wait_1_cycle
    axi_w_wait_2                            cover_axi_w_wait_2_cycles
    axi_w_wait_3                            cover_axi_w_wait_3_cycles
    axi_w_wait_16                           cover_axi_w_wait_16_cycles
    axi_w_wait_19                           cover_axi_w_wait_19_cycles
}

set STAGE_NAME $env(JG_STAGE)
if {![info exists CVA5_REACHABILITY_STAGE($STAGE_NAME)]} {
    error "Unknown JG_STAGE '$STAGE_NAME'. Valid stages: [lsort [array names CVA5_REACHABILITY_STAGE]]"
}

set PROPERTY_NAME $CVA5_REACHABILITY_STAGE($STAGE_NAME)
if {[string match "cover_full_*" $PROPERTY_NAME] || [string match "assert_full_*" $PROPERTY_NAME]} {
    set PROPERTY_PATH ${WRAPPER}.$PROPERTY_NAME
} else {
    set PROPERTY_PATH ${FBM}.$PROPERTY_NAME
}
puts "Covering full-core CVA5 reachability stage '$STAGE_NAME': $PROPERTY_PATH"
prove -property $PROPERTY_PATH
