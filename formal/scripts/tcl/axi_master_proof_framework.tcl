# Jasper-native review project for the unit-level CVA5 AXI master proof.
#
# The read, write, and combined roots copy only their own assumptions and
# properties from the embedded super-top. Proof Structure roots are therefore
# independent proof contexts; results never propagate between them.

if {[info exists env(CVA5_ROOT)]} {
    set COMMON_TCL [file join $env(CVA5_ROOT) formal scripts tcl _axi_master_proof_framework_common.tcl]
} else {
    set COMMON_TCL [file join [pwd] formal scripts tcl _axi_master_proof_framework_common.tcl]
}
source $COMMON_TCL

proc fw_paths {base labels} {
    set result {}
    foreach label $labels {
        lappend result ${base}.${label}
    }
    return $result
}

set FW_EMBEDDED_PROPERTIES [get_property_list -task <embedded> -no_task_prefix]

proc fw_require_properties {section properties} {
    foreach property_name $properties {
        if {[lsearch -exact $::FW_EMBEDDED_PROPERTIES $property_name] < 0} {
            error "Proof-framework manifest entry is missing from elaboration: section=$section property=$property_name"
        }
    }
}

proc fw_annotate {task_name properties annotation} {
    foreach property_name $properties {
        set_annotation -property ${task_name}::${property_name} $annotation
    }
}

proc fw_create_assumption_task {task_name assumptions} {
    fw_require_properties $task_name $assumptions
    task -create $task_name -copy $assumptions -copy_related_covers \
        -source_task <embedded>
    fw_annotate $task_name $assumptions \
        "ROLE=environment assumption; CONTEXT=$task_name; not a DUT guarantee"
    set related_covers [get_property_list -task $task_name \
        -include {type cover} -no_task_prefix]
    fw_annotate $task_name $related_covers \
        "ROLE=Jasper-generated assumption precondition cover; CONTEXT=$task_name; not an explicit project reachability cover"
}

proc fw_init_root {root_name assumption_task assumptions properties} {
    fw_require_properties $root_name [concat $assumptions $properties]
    set source_task FW_SOURCE__$root_name
    task -create $source_task -copy_assumes -copy_related_covers \
        -source_task $assumption_task
    task -edit $source_task -copy $properties -copy_related_covers \
        -source_task <embedded>
    proof_structure -init $root_name -from $source_task \
        -copy_assumes -copy $properties
    task -remove $source_task
}

proc fw_add_review_marker {task_name property_name label annotation} {
    task -set $task_name
    assert -name $property_name {1'b0} -label $label -annotation $annotation
    assert -disable $property_name
}

proc fw_print_task_summary {task_name} {
    set assertions [task -num_asserts $task_name]
    set covers [task -num_covers $task_name]
    set assumptions [task -num_assumes $task_name]
    puts [format "  %-38s assume=%2d assert=%2d cover=%2d" \
        $task_name $assumptions $assertions $covers]
}

set FW_TOP axi_master_proof_framework_wrapper
set READ_H ${FW_TOP}.u_read
set READ_P ${READ_H}.u_axi_props
set WRITE_H ${FW_TOP}.u_write
set WRITE_P ${WRITE_H}.u_axi_props
set COMBINED_H ${FW_TOP}.u_combined
set COMBINED_P ${COMBINED_H}.u_axi_props

# Read context
set READ_LSU_ASSUMPTIONS [fw_paths $READ_H {
    env_legal_read_request
    env_read_request_is_a_pulse
    env_quiet_during_warmup
}]
set READ_AXI_ASSUMPTIONS [concat \
    [fw_paths $READ_H {
        env_no_early_read_response
        env_single_beat_read_response
    }] \
    [fw_paths $READ_P {
        env_no_rresponse_if_no_os
        env_arid_match_rid
    }]]
set READ_ASSUMPTIONS [concat $READ_LSU_ASSUMPTIONS $READ_AXI_ASSUMPTIONS]

set READ_HARNESS_COVERS [fw_paths $READ_H {
    cover_read_request
    cover_read_backpressure
    cover_ar_ready_already_high
    cover_ar_ready_same_cycle_as_valid
    cover_ar_wait_1_cycle
    cover_ar_wait_2_cycles
    cover_ar_wait_3_cycles
    cover_ar_wait_16_cycles
    cover_ar_wait_19_cycles
    cover_read_response
    cover_read_response_lifecycle
}]
set READ_CHECKER_COVERS [fw_paths $READ_P {
    cover_read_request
    cover_read_response
    cover_read_outstanding_lifecycle
}]
set READ_REACHABILITY [concat $READ_HARNESS_COVERS $READ_CHECKER_COVERS]

set READ_AR_HELPERS [fw_paths $READ_H {
    dut_read_request_enters_requesting_read
    dut_requesting_read_waits_for_arready
    dut_requesting_read_exits_on_arready
    dut_requesting_read_drives_arvalid
    dut_requesting_read_holds_arvalid
    dut_arvalid_backpressure_implies_requesting_read
    dut_requesting_read_holds_araddr
    dut_requesting_read_holds_araddr_only
    dut_araddr_matches_addr_reg
    dut_no_lsu_accept_in_requesting_read
    dut_requesting_read_holds_ready_low
    dut_requesting_read_holds_addr_reg
    dut_requesting_read_holds_addr_reg_explicit
    dut_requesting_read_holds_arlen
    dut_requesting_read_holds_arburst
    dut_requesting_read_holds_arlock
    dut_requesting_read_holds_arid
    dut_read_request_drives_arvalid
}]
set READ_AR_LOCAL_GUARANTEES [fw_paths $READ_H {
    dut_arvalid_holds_until_ready
    dut_araddr_stable_until_ready
}]
set READ_AR_CHECKER_GUARANTEES [fw_paths $READ_P {
    master_arvalid_held_until_ready
    master_araddr_stable_until_ready
}]
set READ_MODE_SAFETY [fw_paths $READ_H {dut_read_only_no_write_valid}]

set READ_LIFECYCLE_HELPERS [fw_paths $READ_H {
    dut_ar_accept_creates_pending_read
    dut_read_pending_holds_without_r_response
    dut_read_pending_implies_waiting_read
    dut_waiting_read_holds_until_rvalid
    dut_r_response_clears_pending_read
    dut_r_response_returns_to_ready
}]
set READ_LIFECYCLE_GUARANTEES [fw_paths $READ_H {
    dut_r_response_completes_lsu
    dut_read_completion_follows_r_response
    dut_rdata_maps_to_ls_data_out
    dut_rvalid_drives_ls_data_valid
    dut_rvalid_drives_ls_ready
}]

set READ_CHECKER_HELPERS [fw_paths $READ_P {
    helper_read_count_increment
    helper_read_count_decrement
    helper_read_count_stable
}]
set READ_CHECKER_GUARANTEES [fw_paths $READ_P {
    master_read_outstanding_limit
    master_no_second_read_accept
}]
set READ_DEBUG_PROPERTIES [concat \
    [fw_paths $READ_H {
        debug_arvalid_holds_when_requesting_read
        debug_tracked_arvalid_hold
    }] \
    [fw_paths $READ_H {
        cover_addr_changes_during_requesting_read_wait
        cover_cut_violation_arvalid_drop
        cover_tracked_arvalid_drop
    }]]

# Write context
set WRITE_LSU_ASSUMPTIONS [fw_paths $WRITE_H {
    env_legal_write_request
    env_write_request_is_a_pulse
    env_quiet_during_warmup
}]
set WRITE_AXI_ASSUMPTIONS [concat \
    [fw_paths $WRITE_H {env_no_early_write_response}] \
    [fw_paths $WRITE_P {
        env_no_bresponse_if_no_os
        env_awid_match_bid
    }]]
set WRITE_ASSUMPTIONS [concat $WRITE_LSU_ASSUMPTIONS $WRITE_AXI_ASSUMPTIONS]

set WRITE_HARNESS_COVERS [fw_paths $WRITE_H {
    cover_write_request
    cover_aw_backpressure
    cover_aw_ready_already_high
    cover_aw_ready_same_cycle_as_valid
    cover_aw_wait_1_cycle
    cover_aw_wait_2_cycles
    cover_aw_wait_3_cycles
    cover_aw_wait_16_cycles
    cover_aw_wait_19_cycles
    cover_w_backpressure
    cover_w_ready_already_high
    cover_w_ready_same_cycle_as_valid
    cover_w_wait_1_cycle
    cover_w_wait_2_cycles
    cover_w_wait_3_cycles
    cover_w_wait_16_cycles
    cover_w_wait_19_cycles
    cover_write_address_data_accept
    cover_write_response_lifecycle
}]
set WRITE_CHECKER_COVERS [fw_paths $WRITE_P {
    cover_write_address
    cover_write_data
    cover_write_response
    cover_write_outstanding_lifecycle
}]
set WRITE_REACHABILITY [concat $WRITE_HARNESS_COVERS $WRITE_CHECKER_COVERS]

set WRITE_CHANNEL_HELPERS [fw_paths $WRITE_H {
    dut_write_request_enters_requesting_write
    dut_write_request_drives_aw_w_valid
    dut_awvalid_backpressure_implies_requesting_write
    dut_requesting_write_holds_awvalid
    dut_requesting_write_holds_awaddr
    dut_wvalid_backpressure_implies_requesting_write
    dut_requesting_write_holds_wvalid
    dut_requesting_write_holds_wdata
}]
set WRITE_CHANNEL_LOCAL_GUARANTEES [fw_paths $WRITE_H {
    dut_awvalid_holds_until_ready
    dut_awaddr_stable_until_ready
    dut_wvalid_holds_until_ready
    dut_wdata_stable_until_ready
}]
set WRITE_CHANNEL_CHECKER_GUARANTEES [fw_paths $WRITE_P {
    master_awvalid_held_until_ready
    master_awaddr_stable_until_ready
    master_wvalid_held_until_ready
    master_wdata_stable_until_ready
}]
set WRITE_MODE_SAFETY [fw_paths $WRITE_H {dut_write_only_no_read_valid}]

set WRITE_LIFECYCLE_HELPERS [fw_paths $WRITE_H {
    dut_aw_accept_sets_aw_pending
    dut_w_accept_sets_w_pending
    dut_aw_w_acceptance_creates_pending_write
    dut_write_pending_holds_without_b_response
    dut_write_pending_implies_waiting_write
    dut_waiting_write_holds_until_bvalid
}]
set WRITE_LIFECYCLE_GUARANTEES [fw_paths $WRITE_H {
    dut_b_response_clears_pending_write
    dut_b_response_returns_to_ready
    dut_b_response_completes_lsu
    dut_write_completion_follows_b_response
    dut_b_response_clears_write_outstanding
}]
set WRITE_CHECKER_HELPERS [fw_paths $WRITE_P {
    helper_write_address_count_increment
    helper_write_address_count_decrement
    helper_write_address_count_stable
    helper_write_data_count_increment
    helper_write_data_count_decrement
    helper_write_data_count_stable
}]
set WRITE_CHECKER_GUARANTEES [fw_paths $WRITE_P {
    master_write_address_outstanding_limit
    master_write_data_outstanding_limit
    master_no_second_write_address_accept
    master_no_second_write_data_accept
}]

# Combined context
set COMBINED_LSU_ASSUMPTIONS [fw_paths $COMBINED_H {
    env_legal_lsu_request_type
    env_lsu_request_only_when_ready
    env_lsu_request_is_a_pulse
    env_quiet_during_warmup
}]
set COMBINED_AXI_ASSUMPTIONS [concat \
    [fw_paths $COMBINED_H {
        env_no_early_read_response
        env_single_beat_read_response
        env_no_early_write_response
    }] \
    [fw_paths $COMBINED_P {
        env_no_rresponse_if_no_os
        env_arid_match_rid
        env_no_bresponse_if_no_os
        env_awid_match_bid
    }]]
set COMBINED_ASSUMPTIONS [concat $COMBINED_LSU_ASSUMPTIONS $COMBINED_AXI_ASSUMPTIONS]

set COMBINED_HARNESS_COVERS [fw_paths $COMBINED_H {
    cover_combined_read_request
    cover_combined_write_request
    cover_combined_read_lifecycle
    cover_combined_write_lifecycle
    cover_read_then_write
    cover_write_then_read
}]
set COMBINED_CHECKER_COVERS [fw_paths $COMBINED_P {
    cover_read_request
    cover_read_response
    cover_read_outstanding_lifecycle
    cover_write_address
    cover_write_data
    cover_write_response
    cover_write_outstanding_lifecycle
}]
set COMBINED_REACHABILITY [concat $COMBINED_HARNESS_COVERS $COMBINED_CHECKER_COVERS]

set COMBINED_CROSS_SAFETY [fw_paths $COMBINED_H {
    dut_legal_read_request_enters_requesting_read
    dut_legal_write_request_enters_requesting_write
    dut_request_accepted_only_from_ready_state
    dut_no_simultaneous_read_write_valid
    dut_no_simultaneous_read_write_handshake
    dut_no_read_write_pending_overlap
    dut_busy_states_hold_ready_low
    dut_read_request_drives_only_arvalid
    dut_write_request_drives_only_aw_wvalid
}]
set COMBINED_READ_LIFECYCLE [fw_paths $COMBINED_H {
    dut_ar_accept_creates_read_pending
    dut_read_pending_holds_without_r_response
    dut_read_pending_implies_waiting_read
    dut_r_response_clears_read_pending
    dut_r_response_returns_to_ready
    dut_read_completion_follows_r_response
    dut_no_read_completion_from_b_response
    dut_rdata_maps_to_ls_data_out
}]
set COMBINED_WRITE_LIFECYCLE [fw_paths $COMBINED_H {
    dut_aw_accept_sets_aw_pending
    dut_w_accept_sets_w_pending
    dut_aw_w_acceptance_creates_write_pending
    dut_write_pending_holds_without_b_response
    dut_write_pending_implies_waiting_write
    dut_b_response_clears_write_pending
    dut_b_response_returns_to_ready
    dut_write_completion_follows_b_response
    dut_no_write_completion_from_r_response
    dut_b_response_clears_write_outstanding
}]
set COMBINED_CHECKER_HELPERS [concat \
    [fw_paths $COMBINED_P {
        helper_read_count_increment
        helper_read_count_decrement
        helper_read_count_stable
    }] \
    [fw_paths $COMBINED_P {
        helper_write_address_count_increment
        helper_write_address_count_decrement
        helper_write_address_count_stable
        helper_write_data_count_increment
        helper_write_data_count_decrement
        helper_write_data_count_stable
    }]]
set COMBINED_CHECKER_GUARANTEES [fw_paths $COMBINED_P {
    master_arvalid_held_until_ready
    master_araddr_stable_until_ready
    master_read_outstanding_limit
    master_no_second_read_accept
    master_awvalid_held_until_ready
    master_awaddr_stable_until_ready
    master_wvalid_held_until_ready
    master_wdata_stable_until_ready
    master_write_address_outstanding_limit
    master_write_data_outstanding_limit
    master_no_second_write_address_accept
    master_no_second_write_data_accept
}]

# Named assumption tasks are audit views and the source of each root's exact
# environment. Temporary source tasks are removed after root initialization.
fw_create_assumption_task READ__00_ASSUMPTIONS $READ_ASSUMPTIONS
fw_create_assumption_task WRITE__00_ASSUMPTIONS $WRITE_ASSUMPTIONS
fw_create_assumption_task COMBINED__00_ASSUMPTIONS $COMBINED_ASSUMPTIONS

fw_annotate READ__00_ASSUMPTIONS $READ_LSU_ASSUMPTIONS \
    {ROLE=environment assumption; CLASS=reset/warmup or LSU requester protocol; CONTEXT=read-only}
fw_annotate READ__00_ASSUMPTIONS $READ_AXI_ASSUMPTIONS \
    {ROLE=environment assumption; CLASS=AXI slave and single-beat response model; CONTEXT=read-only}
fw_annotate WRITE__00_ASSUMPTIONS $WRITE_LSU_ASSUMPTIONS \
    {ROLE=environment assumption; CLASS=reset/warmup or LSU requester protocol; CONTEXT=write-only}
fw_annotate WRITE__00_ASSUMPTIONS $WRITE_AXI_ASSUMPTIONS \
    {ROLE=environment assumption; CLASS=AXI slave response model; CONTEXT=write-only}
fw_annotate COMBINED__00_ASSUMPTIONS $COMBINED_LSU_ASSUMPTIONS \
    {ROLE=environment assumption; CLASS=reset/warmup or LSU requester protocol; CONTEXT=combined}
fw_annotate COMBINED__00_ASSUMPTIONS $COMBINED_AXI_ASSUMPTIONS \
    {ROLE=environment assumption; CLASS=AXI slave and single-beat response model; CONTEXT=combined}

# Covers are independent reachability roots and never become proof dependencies.
fw_init_root READ__10_REACHABILITY READ__00_ASSUMPTIONS $READ_ASSUMPTIONS $READ_REACHABILITY
fw_init_root WRITE__10_REACHABILITY WRITE__00_ASSUMPTIONS $WRITE_ASSUMPTIONS $WRITE_REACHABILITY
fw_init_root COMBINED__10_REACHABILITY COMBINED__00_ASSUMPTIONS $COMBINED_ASSUMPTIONS $COMBINED_REACHABILITY
fw_annotate READ__10_REACHABILITY $READ_REACHABILITY \
    {ROLE=cover; PURPOSE=reachability/non-vacuity only; not a safety guarantee}
fw_annotate WRITE__10_REACHABILITY $WRITE_REACHABILITY \
    {ROLE=cover; PURPOSE=reachability/non-vacuity only; not a safety guarantee}
fw_annotate COMBINED__10_REACHABILITY $COMBINED_REACHABILITY \
    {ROLE=cover; PURPOSE=reachability/non-vacuity only; not a safety guarantee}

# Read proof ladders.
set READ_AR_ALL [concat $READ_AR_HELPERS $READ_AR_LOCAL_GUARANTEES $READ_AR_CHECKER_GUARANTEES]
fw_init_root READ__20_AR_SAFETY READ__00_ASSUMPTIONS $READ_ASSUMPTIONS $READ_AR_ALL
proof_structure -create assume_guarantee -from READ__20_AR_SAFETY \
    -op_name READ_AR_ASSUME_GUARANTEE \
    -imp_name {READ_AR_HELPERS READ_AR_LOCAL_GUARANTEES READ_AR_CHECKER_GUARANTEES} \
    -property [list $READ_AR_HELPERS $READ_AR_LOCAL_GUARANTEES $READ_AR_CHECKER_GUARANTEES] \
    -fail_if missing_property {assert}
fw_annotate READ__20_AR_SAFETY $READ_AR_HELPERS \
    {ROLE=helper lemma; SCOPE=white-box AR proof decomposition; proven before use downstream}
fw_annotate READ_AR_HELPERS $READ_AR_HELPERS \
    {ROLE=helper lemma; SCOPE=white-box AR proof decomposition; proven before use downstream}
fw_annotate READ__20_AR_SAFETY $READ_AR_LOCAL_GUARANTEES \
    {ROLE=final assertion; SCOPE=local DUT AR guarantee}
fw_annotate READ_AR_LOCAL_GUARANTEES $READ_AR_LOCAL_GUARANTEES \
    {ROLE=final assertion; SCOPE=local DUT AR guarantee}
fw_annotate READ__20_AR_SAFETY $READ_AR_CHECKER_GUARANTEES \
    {ROLE=final assertion; SCOPE=checker-level AR guarantee}
fw_annotate READ_AR_CHECKER_GUARANTEES $READ_AR_CHECKER_GUARANTEES \
    {ROLE=final assertion; SCOPE=checker-level AR guarantee}

fw_init_root READ__21_MODE_SAFETY READ__00_ASSUMPTIONS $READ_ASSUMPTIONS $READ_MODE_SAFETY
fw_annotate READ__21_MODE_SAFETY $READ_MODE_SAFETY \
    {ROLE=final assertion; SCOPE=read-only harness mode exclusion}

set READ_LIFECYCLE_ALL [concat $READ_LIFECYCLE_HELPERS $READ_LIFECYCLE_GUARANTEES]
fw_init_root READ__30_R_LIFECYCLE READ__00_ASSUMPTIONS $READ_ASSUMPTIONS $READ_LIFECYCLE_ALL
proof_structure -create assume_guarantee -from READ__30_R_LIFECYCLE \
    -op_name READ_R_LIFECYCLE_ASSUME_GUARANTEE \
    -imp_name {READ_R_LIFECYCLE_HELPERS READ_R_LIFECYCLE_GUARANTEES} \
    -property [list $READ_LIFECYCLE_HELPERS $READ_LIFECYCLE_GUARANTEES] \
    -fail_if missing_property {assert}
fw_annotate READ__30_R_LIFECYCLE $READ_LIFECYCLE_HELPERS \
    {ROLE=helper lemma; SCOPE=read pending/FSM lifecycle}
fw_annotate READ_R_LIFECYCLE_HELPERS $READ_LIFECYCLE_HELPERS \
    {ROLE=helper lemma; SCOPE=read pending/FSM lifecycle}
fw_annotate READ__30_R_LIFECYCLE $READ_LIFECYCLE_GUARANTEES \
    {ROLE=final assertion; SCOPE=R response to LSU completion/data mapping}
fw_annotate READ_R_LIFECYCLE_GUARANTEES $READ_LIFECYCLE_GUARANTEES \
    {ROLE=final assertion; SCOPE=R response to LSU completion/data mapping}

set READ_CHECKER_ALL [concat $READ_CHECKER_HELPERS $READ_CHECKER_GUARANTEES]
fw_init_root READ__40_CHECKER READ__00_ASSUMPTIONS $READ_ASSUMPTIONS $READ_CHECKER_ALL
proof_structure -create assume_guarantee -from READ__40_CHECKER \
    -op_name READ_CHECKER_ASSUME_GUARANTEE \
    -imp_name {READ_CHECKER_COUNT_HELPERS READ_CHECKER_GUARANTEES} \
    -property [list $READ_CHECKER_HELPERS $READ_CHECKER_GUARANTEES] \
    -fail_if missing_property {assert}
fw_annotate READ__40_CHECKER $READ_CHECKER_HELPERS \
    {ROLE=helper lemma; SCOPE=checker outstanding-count model}
fw_annotate READ_CHECKER_COUNT_HELPERS $READ_CHECKER_HELPERS \
    {ROLE=helper lemma; SCOPE=checker outstanding-count model}
fw_annotate READ__40_CHECKER $READ_CHECKER_GUARANTEES \
    {ROLE=final assertion; SCOPE=checker read outstanding policy}
fw_annotate READ_CHECKER_GUARANTEES $READ_CHECKER_GUARANTEES \
    {ROLE=final assertion; SCOPE=checker read outstanding policy}

# Write proof ladders.
set WRITE_CHANNEL_ALL [concat $WRITE_CHANNEL_HELPERS $WRITE_CHANNEL_LOCAL_GUARANTEES $WRITE_CHANNEL_CHECKER_GUARANTEES]
fw_init_root WRITE__20_CHANNEL_SAFETY WRITE__00_ASSUMPTIONS $WRITE_ASSUMPTIONS $WRITE_CHANNEL_ALL
proof_structure -create assume_guarantee -from WRITE__20_CHANNEL_SAFETY \
    -op_name WRITE_CHANNEL_ASSUME_GUARANTEE \
    -imp_name {WRITE_CHANNEL_HELPERS WRITE_LOCAL_GUARANTEES WRITE_CHECKER_CHANNEL_GUARANTEES} \
    -property [list $WRITE_CHANNEL_HELPERS $WRITE_CHANNEL_LOCAL_GUARANTEES $WRITE_CHANNEL_CHECKER_GUARANTEES] \
    -fail_if missing_property {assert}
fw_annotate WRITE__20_CHANNEL_SAFETY $WRITE_CHANNEL_HELPERS \
    {ROLE=helper lemma; SCOPE=white-box AW/W proof decomposition; proven before use downstream}
fw_annotate WRITE_CHANNEL_HELPERS $WRITE_CHANNEL_HELPERS \
    {ROLE=helper lemma; SCOPE=white-box AW/W proof decomposition; proven before use downstream}
fw_annotate WRITE__20_CHANNEL_SAFETY $WRITE_CHANNEL_LOCAL_GUARANTEES \
    {ROLE=final assertion; SCOPE=local DUT AW/W guarantee}
fw_annotate WRITE_LOCAL_GUARANTEES $WRITE_CHANNEL_LOCAL_GUARANTEES \
    {ROLE=final assertion; SCOPE=local DUT AW/W guarantee}
fw_annotate WRITE__20_CHANNEL_SAFETY $WRITE_CHANNEL_CHECKER_GUARANTEES \
    {ROLE=final assertion; SCOPE=checker-level AW/W guarantee}
fw_annotate WRITE_CHECKER_CHANNEL_GUARANTEES $WRITE_CHANNEL_CHECKER_GUARANTEES \
    {ROLE=final assertion; SCOPE=checker-level AW/W guarantee}

fw_init_root WRITE__21_MODE_SAFETY WRITE__00_ASSUMPTIONS $WRITE_ASSUMPTIONS $WRITE_MODE_SAFETY
fw_annotate WRITE__21_MODE_SAFETY $WRITE_MODE_SAFETY \
    {ROLE=final assertion; SCOPE=write-only harness mode exclusion}

set WRITE_LIFECYCLE_ALL [concat $WRITE_LIFECYCLE_HELPERS $WRITE_LIFECYCLE_GUARANTEES]
fw_init_root WRITE__30_B_LIFECYCLE WRITE__00_ASSUMPTIONS $WRITE_ASSUMPTIONS $WRITE_LIFECYCLE_ALL
proof_structure -create assume_guarantee -from WRITE__30_B_LIFECYCLE \
    -op_name WRITE_B_LIFECYCLE_ASSUME_GUARANTEE \
    -imp_name {WRITE_B_LIFECYCLE_HELPERS WRITE_B_LIFECYCLE_GUARANTEES} \
    -property [list $WRITE_LIFECYCLE_HELPERS $WRITE_LIFECYCLE_GUARANTEES] \
    -fail_if missing_property {assert}
fw_annotate WRITE__30_B_LIFECYCLE $WRITE_LIFECYCLE_HELPERS \
    {ROLE=helper lemma; SCOPE=write pending/FSM lifecycle}
fw_annotate WRITE_B_LIFECYCLE_HELPERS $WRITE_LIFECYCLE_HELPERS \
    {ROLE=helper lemma; SCOPE=write pending/FSM lifecycle}
fw_annotate WRITE__30_B_LIFECYCLE $WRITE_LIFECYCLE_GUARANTEES \
    {ROLE=final assertion; SCOPE=B response to LSU completion}
fw_annotate WRITE_B_LIFECYCLE_GUARANTEES $WRITE_LIFECYCLE_GUARANTEES \
    {ROLE=final assertion; SCOPE=B response to LSU completion}

set WRITE_CHECKER_ALL [concat $WRITE_CHECKER_HELPERS $WRITE_CHECKER_GUARANTEES]
fw_init_root WRITE__40_CHECKER WRITE__00_ASSUMPTIONS $WRITE_ASSUMPTIONS $WRITE_CHECKER_ALL
proof_structure -create assume_guarantee -from WRITE__40_CHECKER \
    -op_name WRITE_CHECKER_ASSUME_GUARANTEE \
    -imp_name {WRITE_CHECKER_COUNT_HELPERS WRITE_CHECKER_GUARANTEES} \
    -property [list $WRITE_CHECKER_HELPERS $WRITE_CHECKER_GUARANTEES] \
    -fail_if missing_property {assert}
fw_annotate WRITE__40_CHECKER $WRITE_CHECKER_HELPERS \
    {ROLE=helper lemma; SCOPE=checker outstanding-count model}
fw_annotate WRITE_CHECKER_COUNT_HELPERS $WRITE_CHECKER_HELPERS \
    {ROLE=helper lemma; SCOPE=checker outstanding-count model}
fw_annotate WRITE__40_CHECKER $WRITE_CHECKER_GUARANTEES \
    {ROLE=final assertion; SCOPE=checker write outstanding policy}
fw_annotate WRITE_CHECKER_GUARANTEES $WRITE_CHECKER_GUARANTEES \
    {ROLE=final assertion; SCOPE=checker write outstanding policy}

# Combined proof branches. Partition is structural only; it adds no assumptions.
fw_init_root COMBINED__20_CROSS_SAFETY COMBINED__00_ASSUMPTIONS $COMBINED_ASSUMPTIONS $COMBINED_CROSS_SAFETY
fw_annotate COMBINED__20_CROSS_SAFETY $COMBINED_CROSS_SAFETY \
    {ROLE=final assertion; SCOPE=CVA5 single-request LSU bridge read/write interaction}

set COMBINED_LIFECYCLE_ALL [concat $COMBINED_READ_LIFECYCLE $COMBINED_WRITE_LIFECYCLE]
fw_init_root COMBINED__30_LIFECYCLE COMBINED__00_ASSUMPTIONS $COMBINED_ASSUMPTIONS $COMBINED_LIFECYCLE_ALL
proof_structure -create partition -from COMBINED__30_LIFECYCLE \
    -op_name COMBINED_LIFECYCLE_PARTITION \
    -imp_name {COMBINED_READ_LIFECYCLE COMBINED_WRITE_LIFECYCLE} \
    -copy [list $COMBINED_READ_LIFECYCLE $COMBINED_WRITE_LIFECYCLE] \
    -fail_if missing_property {assert} -fail_if duplicated_property {assert}
fw_annotate COMBINED__30_LIFECYCLE $COMBINED_READ_LIFECYCLE \
    {ROLE=helper/final assertion; SCOPE=combined-harness read lifecycle}
fw_annotate COMBINED_READ_LIFECYCLE $COMBINED_READ_LIFECYCLE \
    {ROLE=helper/final assertion; SCOPE=combined-harness read lifecycle}
fw_annotate COMBINED__30_LIFECYCLE $COMBINED_WRITE_LIFECYCLE \
    {ROLE=helper/final assertion; SCOPE=combined-harness write lifecycle}
fw_annotate COMBINED_WRITE_LIFECYCLE $COMBINED_WRITE_LIFECYCLE \
    {ROLE=helper/final assertion; SCOPE=combined-harness write lifecycle}

set COMBINED_CHECKER_ALL [concat $COMBINED_CHECKER_HELPERS $COMBINED_CHECKER_GUARANTEES]
fw_init_root COMBINED__40_CHECKER COMBINED__00_ASSUMPTIONS $COMBINED_ASSUMPTIONS $COMBINED_CHECKER_ALL
proof_structure -create assume_guarantee -from COMBINED__40_CHECKER \
    -op_name COMBINED_CHECKER_ASSUME_GUARANTEE \
    -imp_name {COMBINED_CHECKER_COUNT_HELPERS COMBINED_CHECKER_GUARANTEES} \
    -property [list $COMBINED_CHECKER_HELPERS $COMBINED_CHECKER_GUARANTEES] \
    -fail_if missing_property {assert}
fw_annotate COMBINED__40_CHECKER $COMBINED_CHECKER_HELPERS \
    {ROLE=helper lemma; SCOPE=combined checker outstanding-count model}
fw_annotate COMBINED_CHECKER_COUNT_HELPERS $COMBINED_CHECKER_HELPERS \
    {ROLE=helper lemma; SCOPE=combined checker outstanding-count model}
fw_annotate COMBINED__40_CHECKER $COMBINED_CHECKER_GUARANTEES \
    {ROLE=final assertion; SCOPE=combined checker protocol guarantees}
fw_annotate COMBINED_CHECKER_GUARANTEES $COMBINED_CHECKER_GUARANTEES \
    {ROLE=final assertion; SCOPE=combined checker protocol guarantees}

# Historical/debug properties remain visible but are neither proof targets nor
# proof dependencies in this review project.
task -create READ__80_DEBUG_ONLY -copy $READ_DEBUG_PROPERTIES \
    -copy_related_covers -source_task <embedded>
fw_annotate READ__80_DEBUG_ONLY $READ_DEBUG_PROPERTIES \
    {ROLE=debug-only property; STATUS=unrun by framework; not a closure obligation}

# GUI-visible expected-obligation manifest. These assertions are deliberately
# disabled and semantically false so they can never be mistaken for proofs.
foreach review_task {
    REVIEW__90_UNIMPLEMENTED
    REVIEW__91_UNRUN
    REVIEW__92_INCONCLUSIVE
    REVIEW__93_DISABLED
    REVIEW__94_BOUNDARY_INAPPLICABLE
} {
    task -create $review_task
}

fw_add_review_marker REVIEW__90_UNIMPLEMENTED \
    post_axi_adapter_external_field_proof \
    {UNIMPLEMENTED: post-axi_adapter external AXI proof} \
    {ROLE=review manifest; STATUS=unimplemented; strict external ARSIZE/ARCACHE/AWSIZE/AWCACHE/WLAST closure belongs at axi_adapter or a higher boundary}
fw_add_review_marker REVIEW__90_UNIMPLEMENTED \
    detailed_load_store_data_semantics \
    {UNIMPLEMENTED: detailed load/store data semantics} \
    {ROLE=review manifest; STATUS=unimplemented; byte enables, width, extension, alignment, and error response semantics are outside current handshake/lifecycle closure}

fw_add_review_marker REVIEW__91_UNRUN \
    external_axi_control_field_closure \
    {UNRUN: external AXI control-field closure} \
    {ROLE=review manifest; STATUS=unrun; no post-adapter strict-field proof target has been executed}

fw_add_review_marker REVIEW__92_INCONCLUSIVE \
    no_current_auto_engine_unit_obligation \
    {INCONCLUSIVE: none in current auto-engine unit closure} \
    {ROLE=review manifest; STATUS=none recorded; historical B-only timeouts are debug history and not current ENGINE_MODE=auto closure results}

fw_add_review_marker REVIEW__93_DISABLED \
    direct_boundary_strict_field_review_mode \
    {DISABLED: direct-boundary strict-field review mode} \
    {ROLE=review manifest; STATUS=disabled by default; INCLUDE_UNDRIVEN_FIELDS=1 is optional review mode and is excluded from unit closure}
fw_add_review_marker REVIEW__93_DISABLED \
    read_proven_lemma_cut_mode \
    {DISABLED: read proven-lemma cut mode} \
    {ROLE=review manifest; STATUS=disabled by default; USE_PROVEN_LEMMAS=1 remains a focused debug/convergence mode, not default closure}

fw_add_review_marker REVIEW__94_BOUNDARY_INAPPLICABLE \
    direct_axi_master_read_control_fields \
    {BOUNDARY-INAPPLICABLE: direct axi_master ARSIZE/ARCACHE} \
    {ROLE=review manifest; STATUS=boundary-inapplicable; these fields are not driven at the direct axi_master unit proof boundary}
fw_add_review_marker REVIEW__94_BOUNDARY_INAPPLICABLE \
    direct_axi_master_write_control_fields \
    {BOUNDARY-INAPPLICABLE: direct axi_master AWSIZE/AWCACHE/WLAST} \
    {ROLE=review manifest; STATUS=boundary-inapplicable; these fields are not driven at the direct axi_master unit proof boundary}

set FW_PROOF_ROOTS {
    READ__10_REACHABILITY
    READ__20_AR_SAFETY
    READ__21_MODE_SAFETY
    READ__30_R_LIFECYCLE
    READ__40_CHECKER
    WRITE__10_REACHABILITY
    WRITE__20_CHANNEL_SAFETY
    WRITE__21_MODE_SAFETY
    WRITE__30_B_LIFECYCLE
    WRITE__40_CHECKER
    COMBINED__10_REACHABILITY
    COMBINED__20_CROSS_SAFETY
    COMBINED__30_LIFECYCLE
    COMBINED__40_CHECKER
}

set FW_AUDIT_TASKS {
    READ__00_ASSUMPTIONS
    WRITE__00_ASSUMPTIONS
    COMBINED__00_ASSUMPTIONS
    READ__80_DEBUG_ONLY
    REVIEW__90_UNIMPLEMENTED
    REVIEW__91_UNRUN
    REVIEW__92_INCONCLUSIVE
    REVIEW__93_DISABLED
    REVIEW__94_BOUNDARY_INAPPLICABLE
}

# Coverage uses the Proof Structure implementation tasks because those tasks
# contain the actual FPV proof results. Parent-node propagated results are a
# Proof Structure view and are not normal Property Table results.
set FW_COVERAGE_TASKS {
    READ_AR_HELPERS
    READ_AR_LOCAL_GUARANTEES
    READ_AR_CHECKER_GUARANTEES
    READ__21_MODE_SAFETY
    READ_R_LIFECYCLE_HELPERS
    READ_R_LIFECYCLE_GUARANTEES
    READ_CHECKER_COUNT_HELPERS
    READ_CHECKER_GUARANTEES
    WRITE_CHANNEL_HELPERS
    WRITE_LOCAL_GUARANTEES
    WRITE_CHECKER_CHANNEL_GUARANTEES
    WRITE__21_MODE_SAFETY
    WRITE_B_LIFECYCLE_HELPERS
    WRITE_B_LIFECYCLE_GUARANTEES
    WRITE_CHECKER_COUNT_HELPERS
    WRITE_CHECKER_GUARANTEES
    COMBINED__20_CROSS_SAFETY
    COMBINED_READ_LIFECYCLE
    COMBINED_WRITE_LIFECYCLE
    COMBINED_CHECKER_COUNT_HELPERS
    COMBINED_CHECKER_GUARANTEES
}

puts "AXI proof-framework named tasks and Proof Structure roots:"
puts [task -list -silent]
puts "AXI proof-framework Proof Structure nodes:"
puts [proof_structure -get_node_list]

if {[info exists env(JG_FRAMEWORK_RUN_PROOFS)] && $env(JG_FRAMEWORK_RUN_PROOFS) ne ""} {
    set FW_RUN_PROOFS $env(JG_FRAMEWORK_RUN_PROOFS)
} else {
    set FW_RUN_PROOFS 1
}

if {$FW_RUN_PROOFS eq "1"} {
    source [file join [get_install_dir] etc res tcl_library jasper_tcl_library.tcl]
    foreach root_name $FW_PROOF_ROOTS {
        puts "AXI proof framework: proving Proof Structure root $root_name"
        ::jasper::psu::prove_all_serial $root_name
    }

    puts "AXI proof framework: collecting branch/statement COI Checker Coverage"
    check_cov -configure -checker_mode coi
    foreach coverage_task $FW_COVERAGE_TASKS {
        puts "AXI proof framework: measuring COI for $coverage_task"
        check_cov -measure -type coi -task $coverage_task
    }

    foreach coverage_instance $AXI_MASTER_FRAMEWORK_COVERAGE_INSTANCES {
        puts "AXI proof framework: COI Checker Coverage for $coverage_instance"
        check_cov -report -task $FW_COVERAGE_TASKS \
            -type checker -checker_mode coi \
            -include_instance [list $coverage_instance] -no_return
        puts "AXI proof framework: COI-undetectable items for $coverage_instance"
        check_cov -list -task $FW_COVERAGE_TASKS \
            -status undetectable -checker_mode coi \
            -include_instance [list $coverage_instance] -no_return
    }
} else {
    puts "JG_FRAMEWORK_RUN_PROOFS=$FW_RUN_PROOFS: setup-only review project; proof roots and Checker Coverage remain unrun."
}

check_cov -configure -checker_mode coi
if {[info exists env(JG_GUI)] && $env(JG_GUI) eq "1"} {
    check_cov -configure_gui -task $FW_COVERAGE_TASKS
}

if {[info exists env(JG_GUI)] && $env(JG_GUI) eq "1"} {
    proof_structure -set_visible_results proof_structure
    task -set READ__10_REACHABILITY -update_gui
} else {
    task -set READ__10_REACHABILITY
}

puts "AXI proof-framework task status summary:"
foreach task_name [concat $FW_PROOF_ROOTS $FW_AUDIT_TASKS] {
    fw_print_task_summary $task_name
}
