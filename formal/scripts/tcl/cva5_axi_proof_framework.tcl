# Jasper-native review project for one full CVA5 core and its embedded AXI
# master. Existing focused stage targets remain the debug/regression interface.

clear -all

if {[info exists env(JG_ENGINE_MODE)] && $env(JG_ENGINE_MODE) ne ""} {
    set CORE_ENGINE_MODE $env(JG_ENGINE_MODE)
} else {
    set CORE_ENGINE_MODE auto
}
puts "CVA5 core/AXI framework engine mode: $CORE_ENGINE_MODE"
set_engine_mode $CORE_ENGINE_MODE

if {[info exists env(CVA5_ROOT)]} {
    set CVA5_ROOT [file normalize $env(CVA5_ROOT)]
} else {
    set SCRIPT_DIR [file dirname [file normalize [info script]]]
    set CVA5_ROOT [file normalize [file join $SCRIPT_DIR ../../..]]
}
set FILELIST_PATH [file join $CVA5_ROOT formal filelists cva5_rtl.vfile]
source [file join $CVA5_ROOT formal scripts tcl _proof_limits.tcl]

if {![file exists $FILELIST_PATH]} {
    error "RTL filelist not found: $FILELIST_PATH. Run make formal-filelist first."
}

# Load-path coverage is intentionally scoped. No whole-core coverage percentage
# is claimed by this project.
set CORE_COVERAGE_INSTANCES [list \
    u_fullcore.u_cva5_core.load_store_unit_block \
    u_fullcore.u_cva5_core.load_store_unit_block.gen_ls_pbus.gen_axi.axi_bus]
check_cov -init -model {branch statement} -type coi \
    -exclude_instance {*} \
    -include_instance $CORE_COVERAGE_INSTANCES

analyze -sv -f $FILELIST_PATH
analyze -sv [file join $CVA5_ROOT formal interfaces axi4_basic_props.sv]
analyze -sv [file join $CVA5_ROOT formal models full_core cva5_fbm.sv]
analyze -sv [file join $CVA5_ROOT formal models full_core cva5_formal_wrapper.sv]
analyze -sv [file join $CVA5_ROOT formal models full_core cva5_axi_proof_framework_wrapper.sv]

set CORE_ELABORATE_OPTIONS [list \
    -top cva5_axi_proof_framework_wrapper \
    -bbox_a 17000 \
    -keep_array_for_module sdp_ram \
    -bbox_mul 67 \
    -bbox_m sixinput_pop_count]

# The anchored load maps to the disjoint peripheral-bus range. Preserve the
# data-cache control logic, but remove its unrelated large data RAM from
# focused reachability and focused LW safety runs so keeping the
# instruction-cache RAM concrete does not dominate memory. This is a
# documented abstraction, not an assumption and not part of the default
# review framework.
if {([info exists env(JG_CVA5_FRAMEWORK_LOAD_STAGE)] &&
         $env(JG_CVA5_FRAMEWORK_LOAD_STAGE) ne "") ||
        ([info exists env(JG_CVA5_FRAMEWORK_SAFETY_STAGE)] &&
         $env(JG_CVA5_FRAMEWORK_SAFETY_STAGE) ne "")} {
    set CORE_FOCUSED_DCACHE_DATABANK \
        u_fullcore.u_cva5_core.load_store_unit_block.gen_ls_dcache.gen_small_dcache.data_cache.databank
    puts "CVA5 core/AXI framework: black-boxing unrelated peripheral-load data-cache bank $CORE_FOCUSED_DCACHE_DATABANK"
    lappend CORE_ELABORATE_OPTIONS -bbox_i $CORE_FOCUSED_DCACHE_DATABANK
}

elaborate {*}$CORE_ELABORATE_OPTIONS

clock clk
reset rst -non_resettable_regs 0

proc core_paths {base labels} {
    set result {}
    foreach label $labels {
        lappend result ${base}.${label}
    }
    return $result
}

set CORE_EMBEDDED_PROPERTIES [get_property_list -task <embedded> -no_task_prefix]

proc core_require_properties {section properties} {
    foreach property_name $properties {
        if {[lsearch -exact $::CORE_EMBEDDED_PROPERTIES $property_name] < 0} {
            error "Full-core framework manifest entry is missing: section=$section property=$property_name"
        }
    }
}

proc core_annotate {task_name properties annotation} {
    foreach property_name $properties {
        set_annotation -property ${task_name}::${property_name} $annotation
    }
}

proc core_create_assumption_task {task_name assumptions classification} {
    core_require_properties $task_name $assumptions
    task -create $task_name -copy $assumptions -copy_related_covers \
        -source_task <embedded>
    core_annotate $task_name $assumptions \
        "ROLE=environment assumption; CLASS=$classification; not a DUT guarantee"
    set related_covers [get_property_list -task $task_name \
        -include {type cover} -no_task_prefix]
    core_annotate $task_name $related_covers \
        "ROLE=Jasper-generated assumption precondition cover; CLASS=$classification; not an explicit reachability result"
}

proc core_add_review_marker {task_name property_name label annotation} {
    task -set $task_name
    assert -name $property_name {1'b0} -label $label -annotation $annotation
    assert -disable $property_name
}

proc core_print_task_summary {task_name} {
    puts [format "  %-46s assume=%2d assert=%2d cover=%2d" \
        $task_name [task -num_assumes $task_name] \
        [task -num_asserts $task_name] [task -num_covers $task_name]]
}

set CORE_TOP cva5_axi_proof_framework_wrapper
set FULL_H ${CORE_TOP}.u_fullcore
set FBM_H ${FULL_H}.u_cva5_fbm
set AXI_P ${FBM_H}.u_ppb_axi

# Environment contract. Deterministic FBM behavior is documented separately
# from explicit assumptions.
set RESET_STARTUP_ASSUMPTIONS [core_paths $CORE_TOP {
    assume_framework_no_reset_reassertion
}]
set DESIGN_INTENT_ASSUMPTIONS [core_paths $CORE_TOP {
    assume_disabled_custom_unit_quiet
}]
set AXI_SECONDARY_ASSUMPTIONS [core_paths $AXI_P {
    env_no_rresponse_if_no_os
    env_arid_match_rid
}]
set CORE_ASSUMPTIONS [concat \
    $RESET_STARTUP_ASSUMPTIONS \
    $DESIGN_INTENT_ASSUMPTIONS \
    $AXI_SECONDARY_ASSUMPTIONS]

core_create_assumption_task CORE__00_ENV_RESET_STARTUP \
    $RESET_STARTUP_ASSUMPTIONS {reset/startup}
core_create_assumption_task CORE__00_DESIGN_INTENT_DISABLED_UNIT \
    $DESIGN_INTENT_ASSUMPTIONS {design-intent tieoff for generated-off custom unit}
core_create_assumption_task CORE__00_ENV_AXI_SECONDARY \
    $AXI_SECONDARY_ASSUMPTIONS {AXI secondary/slave environment}
core_create_assumption_task CORE__00_ENV_ASSUMPTION_REVIEW \
    $CORE_ASSUMPTIONS {complete active full-core contract}

foreach task_name {
    CORE__01_ENV_INSTRUCTION_MEMORY_MODEL
    CORE__02_ENV_DATA_AXI_MODEL
    CORE__03_ENV_PROGRESS
    CORE__04_ENV_ABSTRACTIONS
    CORE__90_NOT_IMPLEMENTED
    CORE__91_NOT_RUN
    CORE__92_INCONCLUSIVE
    CORE__93_REVIEW_ONLY
    CORE__94_OUTSIDE_BOUNDARY
    CORE__95_COUNTEREXAMPLE_STATUS
} {
    task -create $task_name
}

core_add_review_marker CORE__01_ENV_INSTRUCTION_MEMORY_MODEL \
    deterministic_lui_lw_sw_program \
    {MODEL: deterministic LUI/LW/SW instruction memory} \
    {ROLE=environment review marker; STATUS=model behavior, not assumption; cva5_fbm returns an anchored LUI/LW/SW/JAL smoke program}
core_add_review_marker CORE__02_ENV_DATA_AXI_MODEL \
    deterministic_single_beat_read_response \
    {MODEL: legal delayed single-beat AXI read response} \
    {ROLE=environment review marker; STATUS=model behavior, not assumption; RVALID follows an accepted AR and RRESP is OKAY}
core_add_review_marker CORE__03_ENV_PROGRESS \
    no_safety_fairness_assumption \
    {PROGRESS: no bounded READY fairness in safety context} \
    {ROLE=environment review marker; STATUS=no safety assumption; READY timing remains formal input behavior and progress is checked only by covers}
core_add_review_marker CORE__04_ENV_ABSTRACTIONS \
    arithmetic_and_memory_blackboxes \
    {ABSTRACTION: configured full-core arithmetic and initialized RAM models} \
    {ROLE=debug/design-intent abstraction marker; STATUS=review required; elaborate uses bbox_a, bbox_mul, and sixinput_pop_count, keeps sdp_ram arrays concrete for instruction-cache data integrity, and focused load stages black-box only the unrelated data-cache databank; reset analysis initializes otherwise undefined non-resettable state to zero because Jasper ignores RTL initial blocks}
core_add_review_marker CORE__04_ENV_ABSTRACTIONS \
    ignored_initial_formal_cycle_assume \
    {WARNING: legacy initial assume is ignored by Jasper} \
    {ROLE=assumption audit marker; STATUS=known limitation; the FBM formal_cycle initial assume is not trusted as an active property}

# Reused reachability properties.
set RESET_STARTUP_REACHABILITY [core_paths $FBM_H {
    cover_reset_released
    cover_startup_complete
}]

set FETCH_BASE_REACHABILITY [concat \
    [core_paths $FBM_H {
        cover_instruction_mem_request_reset_vec
        cover_instruction_mem_ack_reset_vec
        cover_instruction_mem_rvalid
        cover_instruction_lui_returned_from_reset_vec
        cover_instruction_lw_returned
        cover_instruction_program_returned
    }] \
    [core_paths $FULL_H {
        cover_full_fbm_response_lui_reset_vec
        cover_full_response_to_fetch_lui
    }]]

set FETCH_LW_REACHABILITY [core_paths $FULL_H {
    cover_full_fetch_lw
}]

set FETCH_HELPERS [core_paths $FULL_H {
    assert_full_fetch_miss_implies_icache_port_valid
    assert_full_fetch_icache_port_implies_subunit_valid
    assert_full_fetch_subunit_implies_unit_data_valid
    assert_full_fetch_attr_and_unit_valid_imply_internal_complete
}]

set DECODE_REACHABILITY [concat \
    [core_paths $FULL_H {cover_full_decode_lw}] \
    [core_paths $CORE_TOP {cover_lw_fetch_to_decode}]]
set ISSUE_REACHABILITY [concat \
    [core_paths $FULL_H {cover_full_issue_lw cover_full_issue_ls}] \
    [core_paths $CORE_TOP {cover_lw_fetch_to_issue}]]

set LSU_BRIDGE_REACHABILITY [concat \
    [core_paths $FULL_H {
        cover_full_lsu_tlb_request
        cover_full_lsu_tlb_done
        cover_full_lsu_bus_match
        cover_full_axi_master_read_request
    }] \
    [core_paths $CORE_TOP {
        cover_axi_master_accepts_normal_load
        cover_axi_master_requesting_read
        cover_lw_to_lsu_load_request
    }]]

set AXI_READ_REQUEST_REACHABILITY [concat \
    [core_paths $FULL_H {
        cover_full_axi_arvalid
        cover_full_axi_ar_handshake
    }] \
    [core_paths $FBM_H {
        cover_axi_ar_ready_already_high
        cover_axi_ar_ready_same_cycle_as_valid
        cover_axi_ar_wait_1_cycle
        cover_axi_ar_wait_2_cycles
        cover_axi_ar_wait_3_cycles
        cover_axi_ar_wait_16_cycles
        cover_axi_ar_wait_19_cycles
    }] \
    [core_paths $CORE_TOP {cover_lw_to_arvalid cover_lw_to_ar_handshake}]]

set AXI_READ_RESPONSE_REACHABILITY [concat \
    [core_paths $FBM_H {
        cover_axi_r_accepted
        cover_axi_read_lifecycle
    }] \
    [core_paths $CORE_TOP {
        cover_embedded_r_response
        cover_embedded_load_completion
    }]]

set END_TO_END_LOAD_REACHABILITY [core_paths $CORE_TOP {
    cover_lw_to_axi_master_accept
    cover_lw_to_r_response
    cover_lw_to_load_completion
}]

# PC/ID-anchored normal-LW ladder. Each child task contains exactly one cover;
# the formal-only trackers in the framework wrapper provide correlation without
# constraining DUT behavior.
set LOAD_RESET_RELEASE [core_paths $CORE_TOP {cover_core_reset_release}]
set LOAD_STARTUP_COMPLETE [core_paths $CORE_TOP {cover_core_startup_complete}]
set LOAD_INSTRUCTION_REQUEST [core_paths $CORE_TOP {cover_lw_instruction_request}]
set LOAD_INSTRUCTION_RETURN [core_paths $CORE_TOP {cover_lw_instruction_returned}]
set LOAD_DEBUG_FETCH_REQUEST [core_paths $CORE_TOP {cover_debug_lw_fetch_request_allocated}]
set LOAD_DEBUG_ICACHE_LINE_COMPLETE [core_paths $CORE_TOP {cover_debug_lw_icache_line_complete_queued}]
set LOAD_DEBUG_ICACHE_QUEUED [core_paths $CORE_TOP {cover_debug_lw_icache_request_queued}]
set LOAD_DEBUG_ICACHE_RESTART [core_paths $CORE_TOP {cover_debug_lw_icache_restart}]
set LOAD_DEBUG_ICACHE_HIT [core_paths $CORE_TOP {cover_debug_lw_icache_hit}]
set LOAD_DEBUG_FETCH_RAW [core_paths $CORE_TOP {cover_debug_lw_fetch_complete_raw}]
set LOAD_FETCH_COMPLETE [core_paths $CORE_TOP {cover_lw_fetch_complete}]
set LOAD_DEBUG_LUI_DECODE [core_paths $CORE_TOP {cover_debug_lui_decode}]
set LOAD_DEBUG_LUI_ISSUE [core_paths $CORE_TOP {cover_debug_lui_issue}]
set LOAD_DEBUG_LUI_WRITEBACK [core_paths $CORE_TOP {cover_debug_lui_writeback}]
set LOAD_DECODE [core_paths $CORE_TOP {cover_lw_decode_valid}]
set LOAD_DEBUG_LW_SOURCE_MAPPING [core_paths $CORE_TOP {cover_debug_lw_source_mapping}]
set LOAD_ISSUE [core_paths $CORE_TOP {cover_lw_issue_accept}]
set LOAD_DEBUG_LW_SOURCE_VALUE [core_paths $CORE_TOP {cover_debug_lw_source_value}]
set LOAD_DEBUG_LW_SOURCE_MISMATCH [core_paths $CORE_TOP {cover_debug_lw_source_value_unexpected}]
set LOAD_LSU_COMMAND [core_paths $CORE_TOP {cover_lsu_load_command}]
set LOAD_DEBUG_DTLB_BUS_MATCH [core_paths $CORE_TOP {cover_debug_lw_dtlb_bus_match}]
set LOAD_DEBUG_LSQ_LOAD_VALID [core_paths $CORE_TOP {cover_debug_lw_lsq_load_valid}]
set LOAD_DEBUG_AXI_SUBUNIT_READY [core_paths $CORE_TOP {cover_debug_lw_axi_subunit_ready}]
set LOAD_LSU_REQUEST_ACCEPT [core_paths $CORE_TOP {cover_lsu_load_request_accepted}]
set LOAD_AXI_MASTER_ENTRY [core_paths $CORE_TOP {cover_axi_master_enters_requesting_read}]
set LOAD_AXI_ARVALID [core_paths $CORE_TOP {cover_axi_arvalid_from_lw}]
set LOAD_AXI_AR_HANDSHAKE [core_paths $CORE_TOP {cover_axi_ar_handshake_from_lw}]
set LOAD_AXI_R_RESPONSE [core_paths $CORE_TOP {cover_axi_r_response_for_lw}]
set LOAD_LSU_COMPLETION [core_paths $CORE_TOP {cover_lsu_load_completion_from_lw}]
set LOAD_FULL_LIFECYCLE [core_paths $CORE_TOP {cover_full_lw_to_axi_read_lifecycle}]
set LOAD_WRITEBACK [core_paths $CORE_TOP {cover_full_lw_reaches_writeback}]
set LOAD_RETIREMENT [core_paths $CORE_TOP {cover_full_lw_reaches_retirement}]
set LOAD_X2_UPDATE [core_paths $CORE_TOP {cover_full_lw_updates_x2}]

set FULL_CORE_LOAD_STAGE_TASKS {
    LOAD__00_RESET_RELEASE
    LOAD__01_STARTUP_COMPLETE
    LOAD__02_INSTRUCTION_REQUEST
    LOAD__03_INSTRUCTION_RETURN
    LOAD_DBG__04A_FETCH_REQUEST_ALLOC
    LOAD_DBG__04B_ICACHE_LINE_COMPLETE
    LOAD_DBG__04C_ICACHE_REQUEST_QUEUED
    LOAD_DBG__04D_ICACHE_RESTART
    LOAD_DBG__04E_ICACHE_LW_HIT
    LOAD_DBG__04F_FETCH_LW_RAW
    LOAD__04_FETCH_COMPLETE
    LOAD_DBG__04G_LUI_DECODE
    LOAD_DBG__04H_LUI_ISSUE
    LOAD_DBG__04I_LUI_WRITEBACK
    LOAD__05_DECODE
    LOAD_DBG__05A_LW_SOURCE_MAPPING
    LOAD__06_ISSUE
    LOAD_DBG__06A_LW_SOURCE_VALUE
    LOAD_DBG__06B_LW_SOURCE_MISMATCH
    LOAD__07_LSU_COMMAND
    LOAD_DBG__07A_DTLB_BUS_MATCH
    LOAD_DBG__07B_LSQ_LOAD_VALID
    LOAD_DBG__07C_AXI_SUBUNIT_READY
    LOAD__08_LSU_REQUEST_ACCEPT
    LOAD__09_AXI_MASTER_ENTRY
    LOAD__10_AXI_ARVALID
    LOAD__11_AXI_AR_HANDSHAKE
    LOAD__12_AXI_R_RESPONSE
    LOAD__13_LSU_COMPLETION
    LOAD__14_FULL_LIFECYCLE
    LOAD__15_WRITEBACK
    LOAD__16_RETIREMENT
    LOAD__17_X2_UPDATE
}
set FULL_CORE_LOAD_STAGE_PROPERTIES [list \
    $LOAD_RESET_RELEASE \
    $LOAD_STARTUP_COMPLETE \
    $LOAD_INSTRUCTION_REQUEST \
    $LOAD_INSTRUCTION_RETURN \
    $LOAD_DEBUG_FETCH_REQUEST \
    $LOAD_DEBUG_ICACHE_LINE_COMPLETE \
    $LOAD_DEBUG_ICACHE_QUEUED \
    $LOAD_DEBUG_ICACHE_RESTART \
    $LOAD_DEBUG_ICACHE_HIT \
    $LOAD_DEBUG_FETCH_RAW \
    $LOAD_FETCH_COMPLETE \
    $LOAD_DEBUG_LUI_DECODE \
    $LOAD_DEBUG_LUI_ISSUE \
    $LOAD_DEBUG_LUI_WRITEBACK \
    $LOAD_DECODE \
    $LOAD_DEBUG_LW_SOURCE_MAPPING \
    $LOAD_ISSUE \
    $LOAD_DEBUG_LW_SOURCE_VALUE \
    $LOAD_DEBUG_LW_SOURCE_MISMATCH \
    $LOAD_LSU_COMMAND \
    $LOAD_DEBUG_DTLB_BUS_MATCH \
    $LOAD_DEBUG_LSQ_LOAD_VALID \
    $LOAD_DEBUG_AXI_SUBUNIT_READY \
    $LOAD_LSU_REQUEST_ACCEPT \
    $LOAD_AXI_MASTER_ENTRY \
    $LOAD_AXI_ARVALID \
    $LOAD_AXI_AR_HANDSHAKE \
    $LOAD_AXI_R_RESPONSE \
    $LOAD_LSU_COMPLETION \
    $LOAD_FULL_LIFECYCLE \
    $LOAD_WRITEBACK \
    $LOAD_RETIREMENT \
    $LOAD_X2_UPDATE]
set FULL_CORE_LOAD_REACHABILITY [concat \
    $LOAD_RESET_RELEASE \
    $LOAD_STARTUP_COMPLETE \
    $LOAD_INSTRUCTION_REQUEST \
    $LOAD_INSTRUCTION_RETURN \
    $LOAD_DEBUG_FETCH_REQUEST \
    $LOAD_DEBUG_ICACHE_LINE_COMPLETE \
    $LOAD_DEBUG_ICACHE_QUEUED \
    $LOAD_DEBUG_ICACHE_RESTART \
    $LOAD_DEBUG_ICACHE_HIT \
    $LOAD_DEBUG_FETCH_RAW \
    $LOAD_FETCH_COMPLETE \
    $LOAD_DEBUG_LUI_DECODE \
    $LOAD_DEBUG_LUI_ISSUE \
    $LOAD_DEBUG_LUI_WRITEBACK \
    $LOAD_DECODE \
    $LOAD_DEBUG_LW_SOURCE_MAPPING \
    $LOAD_ISSUE \
    $LOAD_DEBUG_LW_SOURCE_VALUE \
    $LOAD_DEBUG_LW_SOURCE_MISMATCH \
    $LOAD_LSU_COMMAND \
    $LOAD_DEBUG_DTLB_BUS_MATCH \
    $LOAD_DEBUG_LSQ_LOAD_VALID \
    $LOAD_DEBUG_AXI_SUBUNIT_READY \
    $LOAD_LSU_REQUEST_ACCEPT \
    $LOAD_AXI_MASTER_ENTRY \
    $LOAD_AXI_ARVALID \
    $LOAD_AXI_AR_HANDSHAKE \
    $LOAD_AXI_R_RESPONSE \
    $LOAD_LSU_COMPLETION \
    $LOAD_FULL_LIFECYCLE \
    $LOAD_WRITEBACK \
    $LOAD_RETIREMENT \
    $LOAD_X2_UPDATE]

array set FULL_CORE_LOAD_STAGE_MAP {
    reset_release               LOAD__00_RESET_RELEASE
    startup_complete            LOAD__01_STARTUP_COMPLETE
    instruction_request         LOAD__02_INSTRUCTION_REQUEST
    instruction_return          LOAD__03_INSTRUCTION_RETURN
    debug_fetch_request_alloc   LOAD_DBG__04A_FETCH_REQUEST_ALLOC
    debug_icache_line_complete  LOAD_DBG__04B_ICACHE_LINE_COMPLETE
    debug_icache_request_queued LOAD_DBG__04C_ICACHE_REQUEST_QUEUED
    debug_icache_restart        LOAD_DBG__04D_ICACHE_RESTART
    debug_icache_lw_hit         LOAD_DBG__04E_ICACHE_LW_HIT
    debug_fetch_lw_raw          LOAD_DBG__04F_FETCH_LW_RAW
    fetch_complete              LOAD__04_FETCH_COMPLETE
    debug_lui_decode            LOAD_DBG__04G_LUI_DECODE
    debug_lui_issue             LOAD_DBG__04H_LUI_ISSUE
    debug_lui_writeback         LOAD_DBG__04I_LUI_WRITEBACK
    decode                      LOAD__05_DECODE
    debug_lw_source_mapping     LOAD_DBG__05A_LW_SOURCE_MAPPING
    issue                       LOAD__06_ISSUE
    debug_lw_source_value       LOAD_DBG__06A_LW_SOURCE_VALUE
    debug_lw_source_mismatch    LOAD_DBG__06B_LW_SOURCE_MISMATCH
    lsu_command                 LOAD__07_LSU_COMMAND
    debug_dtlb_bus_match        LOAD_DBG__07A_DTLB_BUS_MATCH
    debug_lsq_load_valid        LOAD_DBG__07B_LSQ_LOAD_VALID
    debug_axi_subunit_ready     LOAD_DBG__07C_AXI_SUBUNIT_READY
    lsu_request_accept          LOAD__08_LSU_REQUEST_ACCEPT
    axi_master_requesting_read  LOAD__09_AXI_MASTER_ENTRY
    axi_arvalid                 LOAD__10_AXI_ARVALID
    axi_ar_handshake            LOAD__11_AXI_AR_HANDSHAKE
    axi_r_response              LOAD__12_AXI_R_RESPONSE
    lsu_completion              LOAD__13_LSU_COMPLETION
    full_lifecycle              LOAD__14_FULL_LIFECYCLE
    writeback                   LOAD__15_WRITEBACK
    retirement                  LOAD__16_RETIREMENT
    x2_update                   LOAD__17_X2_UPDATE
}

# Deep load reachability is built as one reset-originating witness. `prove
# -from` extends an already covered trace; it is a reachability/debug feature,
# not an assumption and cannot establish unreachability. The source-value
# source-mapping event includes the exact LW decode, and the source-value event
# includes the exact LW issue. The canonical trace therefore uses these strong
# events directly; weaker decode/issue-only witnesses remain separate review
# covers because they can freeze arbitrary details needed by the next stage.
# The LW source mapping is observed in decode. CVA5 may issue the dependent LW
# from the single-cycle ALU bypass path before the later wb_packet commit is
# observed, so actual LUI commit remains an independent diagnostic cover rather
# than a predecessor of the issued source-value event.
array set FULL_CORE_LOAD_TRACE_PREDECESSOR {
    LOAD_DBG__04B_ICACHE_LINE_COMPLETE LOAD__03_INSTRUCTION_RETURN
    LOAD_DBG__04D_ICACHE_RESTART       LOAD_DBG__04B_ICACHE_LINE_COMPLETE
    LOAD_DBG__04E_ICACHE_LW_HIT        LOAD_DBG__04D_ICACHE_RESTART
    LOAD_DBG__04F_FETCH_LW_RAW         LOAD_DBG__04E_ICACHE_LW_HIT
    LOAD__04_FETCH_COMPLETE            LOAD_DBG__04F_FETCH_LW_RAW
    LOAD_DBG__04G_LUI_DECODE           LOAD__04_FETCH_COMPLETE
    LOAD_DBG__04H_LUI_ISSUE            LOAD_DBG__04G_LUI_DECODE
    LOAD__05_DECODE                    LOAD_DBG__04H_LUI_ISSUE
    LOAD_DBG__05A_LW_SOURCE_MAPPING    LOAD_DBG__04H_LUI_ISSUE
    LOAD_DBG__04I_LUI_WRITEBACK        LOAD_DBG__05A_LW_SOURCE_MAPPING
    LOAD__06_ISSUE                     LOAD_DBG__05A_LW_SOURCE_MAPPING
    LOAD_DBG__06A_LW_SOURCE_VALUE      LOAD_DBG__05A_LW_SOURCE_MAPPING
    LOAD_DBG__06B_LW_SOURCE_MISMATCH   LOAD_DBG__05A_LW_SOURCE_MAPPING
    LOAD__07_LSU_COMMAND               LOAD_DBG__06A_LW_SOURCE_VALUE
    LOAD_DBG__07A_DTLB_BUS_MATCH       LOAD__07_LSU_COMMAND
    LOAD_DBG__07B_LSQ_LOAD_VALID       LOAD_DBG__07A_DTLB_BUS_MATCH
    LOAD_DBG__07C_AXI_SUBUNIT_READY    LOAD_DBG__07B_LSQ_LOAD_VALID
    LOAD__08_LSU_REQUEST_ACCEPT        LOAD_DBG__07C_AXI_SUBUNIT_READY
    LOAD__09_AXI_MASTER_ENTRY          LOAD__08_LSU_REQUEST_ACCEPT
    LOAD__10_AXI_ARVALID               LOAD__09_AXI_MASTER_ENTRY
    LOAD__11_AXI_AR_HANDSHAKE          LOAD__10_AXI_ARVALID
    LOAD__12_AXI_R_RESPONSE            LOAD__11_AXI_AR_HANDSHAKE
    LOAD__13_LSU_COMPLETION            LOAD__12_AXI_R_RESPONSE
    LOAD__14_FULL_LIFECYCLE            LOAD__13_LSU_COMPLETION
    LOAD__15_WRITEBACK                 LOAD__14_FULL_LIFECYCLE
    LOAD__16_RETIREMENT                LOAD__15_WRITEBACK
    LOAD__17_X2_UPDATE                 LOAD__16_RETIREMENT
}

proc core_load_single_cover {task_name} {
    set covers [get_property_list -task $task_name \
        -include {type cover} -no_task_prefix]
    if {[llength $covers] != 1} {
        error "Expected one cover in $task_name, found [llength $covers]"
    }
    return [lindex $covers 0]
}

proc core_load_trace_chain {target_task} {
    set chain [list $target_task]
    set cursor $target_task
    while {[info exists ::FULL_CORE_LOAD_TRACE_PREDECESSOR($cursor)]} {
        set cursor $::FULL_CORE_LOAD_TRACE_PREDECESSOR($cursor)
        set chain [linsert $chain 0 $cursor]
    }
    return $chain
}

proc core_load_cover_is_covered {task_name cover_name} {
    set covered [get_property_list -task $task_name \
        -include {type cover status covered} -no_task_prefix]
    return [expr {[lsearch -exact $covered $cover_name] >= 0}]
}

proc core_prove_load_trace_chain {target_task} {
    set previous_property ""
    foreach load_task [core_load_trace_chain $target_task] {
        set load_cover [core_load_single_cover $load_task]
        puts "CVA5 core/AXI framework: covering anchored load stage $load_task"
        if {$previous_property eq ""} {
            prove -task $load_task
        } else {
            puts "CVA5 core/AXI framework: extending covered trace from $previous_property"
            prove -task $load_task -from $previous_property -cycle -1
        }
        if {![core_load_cover_is_covered $load_task $load_cover]} {
            puts "CVA5 core/AXI framework: stopping trace extension; ${load_task}::${load_cover} is not covered."
            return ""
        }
        set previous_property ${load_task}::${load_cover}
    }
    return $previous_property
}

# Reused and new assertion ladders. Unit-framework results are not imported;
# checker properties here observe the full-core m_axi interface and are rerun.
set LSU_BRIDGE_HELPERS [core_paths $CORE_TOP {
    helper_load_accept_enters_requesting_read
    helper_load_accept_captures_address
}]
set LSU_BRIDGE_GUARANTEES [core_paths $CORE_TOP {
    fullcore_lsu_to_araddr_mapping
}]

set AXI_READ_REQUEST_HELPERS [core_paths $CORE_TOP {
    helper_requesting_read_drives_arvalid
    helper_requesting_read_waits_for_arready
    helper_arvalid_backpressure_implies_requesting_read
}]
set AXI_READ_REQUEST_GUARANTEES [concat \
    [core_paths $CORE_TOP {
        fullcore_embedded_arvalid_hold
        fullcore_embedded_araddr_stability
    }] \
    [core_paths $AXI_P {
        master_arvalid_held_until_ready
        master_araddr_stable_until_ready
    }]]

set AXI_READ_RESPONSE_HELPERS [concat \
    [core_paths $CORE_TOP {
        helper_ar_accept_sets_pending
        helper_pending_holds_without_r_response
        helper_pending_implies_waiting_read
        helper_waiting_read_holds_until_rvalid
    }] \
    [core_paths $AXI_P {
        helper_read_count_increment
        helper_read_count_decrement
        helper_read_count_stable
    }]]
set AXI_READ_RESPONSE_ENVIRONMENT_CHECK [core_paths $CORE_TOP {
    environment_rvalid_requires_pending
}]
set AXI_READ_RESPONSE_QUICK_GUARANTEES [concat \
    [core_paths $CORE_TOP {
        fullcore_r_response_clears_pending
        fullcore_r_response_returns_master_ready
    }] \
    [core_paths $AXI_P {
        master_read_outstanding_limit
        master_no_second_read_accept
    }]]
set AXI_READ_RESPONSE_DEEP_GUARANTEES [core_paths $CORE_TOP {
    fullcore_r_response_completes_lsu
    fullcore_no_load_completion_before_response
    fullcore_returned_data_mapping
}]
set AXI_READ_RESPONSE_GUARANTEES [concat \
    $AXI_READ_RESPONSE_QUICK_GUARANTEES \
    $AXI_READ_RESPONSE_DEEP_GUARANTEES]

set LW_WRITEBACK_HELPERS [core_paths $CORE_TOP {
    helper_lw_decode_destination
    helper_lw_writeback_tracker_created
    helper_lw_writeback_tracker_holds
    helper_lw_id_to_phys_mapping
    helper_lw_writeback_tracker_clears
    helper_lw_rdata_capture
    helper_lw_rdata_holds_until_writeback
    helper_lw_retirement_tracker_clears
}]
set LW_WRITEBACK_GUARANTEES [core_paths $CORE_TOP {
    fullcore_lw_rdata_matches_lsu_data
    fullcore_lw_writeback_destination
    fullcore_lw_writeback_data
    fullcore_lw_register_file_write_port
    fullcore_lw_register_file_update
    fullcore_lw_architectural_x2_update
    fullcore_lw_instruction_result
}]
set LW_WRITEBACK_SAFETY [concat \
    $LW_WRITEBACK_HELPERS \
    $LW_WRITEBACK_GUARANTEES]

set LSU_BRIDGE_SAFETY [concat $LSU_BRIDGE_HELPERS $LSU_BRIDGE_GUARANTEES]
set AXI_READ_REQUEST_SAFETY [concat $AXI_READ_REQUEST_HELPERS $AXI_READ_REQUEST_GUARANTEES]
set AXI_READ_RESPONSE_SAFETY [concat \
    $AXI_READ_RESPONSE_HELPERS \
    $AXI_READ_RESPONSE_ENVIRONMENT_CHECK \
    $AXI_READ_RESPONSE_GUARANTEES]

set CORE_ACTIVE_PROPERTIES [concat \
    $RESET_STARTUP_REACHABILITY \
    $FETCH_BASE_REACHABILITY \
    $FETCH_LW_REACHABILITY \
    $FETCH_HELPERS \
    $DECODE_REACHABILITY \
    $ISSUE_REACHABILITY \
    $LSU_BRIDGE_REACHABILITY \
    $LSU_BRIDGE_SAFETY \
    $AXI_READ_REQUEST_REACHABILITY \
    $AXI_READ_REQUEST_SAFETY \
    $AXI_READ_RESPONSE_REACHABILITY \
    $AXI_READ_RESPONSE_SAFETY \
    $LW_WRITEBACK_SAFETY \
    $END_TO_END_LOAD_REACHABILITY \
    $FULL_CORE_LOAD_REACHABILITY]
core_require_properties CVA5_CORE_AXI_FRAMEWORK [concat $CORE_ASSUMPTIONS $CORE_ACTIVE_PROPERTIES]

# One root and one full-core proof context. Partitioning is structural only and
# adds no assumptions or cover dependencies.
task -create CORE_FRAMEWORK_SOURCE -copy $CORE_ASSUMPTIONS \
    -copy_related_covers -source_task <embedded>
task -edit CORE_FRAMEWORK_SOURCE -copy $CORE_ACTIVE_PROPERTIES \
    -copy_related_covers -source_task <embedded>
proof_structure -init CVA5_CORE_AXI_FRAMEWORK -from CORE_FRAMEWORK_SOURCE \
    -copy_assumes -copy $CORE_ACTIVE_PROPERTIES
task -remove CORE_FRAMEWORK_SOURCE

set CORE_BRANCH_NAMES {
    RESET_AND_STARTUP_REACHABILITY
    INSTRUCTION_FETCH_BASE_REACHABILITY
    INSTRUCTION_FETCH_LW_REACHABILITY
    INSTRUCTION_FETCH_SAFETY
    DECODE_REACHABILITY
    ISSUE_REACHABILITY
    LSU_TO_AXI_MASTER_REACHABILITY
    LSU_TO_AXI_MASTER_SAFETY
    AXI_READ_REQUEST_REACHABILITY
    AXI_READ_REQUEST_SAFETY
    AXI_READ_RESPONSE_REACHABILITY
    AXI_READ_RESPONSE_SAFETY
    LW_WRITEBACK_SAFETY
    END_TO_END_LOAD_REACHABILITY
    FULL_CORE_LOAD_REACHABILITY
}
set CORE_BRANCH_PROPERTIES [list \
    $RESET_STARTUP_REACHABILITY \
    $FETCH_BASE_REACHABILITY \
    $FETCH_LW_REACHABILITY \
    $FETCH_HELPERS \
    $DECODE_REACHABILITY \
    $ISSUE_REACHABILITY \
    $LSU_BRIDGE_REACHABILITY \
    $LSU_BRIDGE_SAFETY \
    $AXI_READ_REQUEST_REACHABILITY \
    $AXI_READ_REQUEST_SAFETY \
    $AXI_READ_RESPONSE_REACHABILITY \
    $AXI_READ_RESPONSE_SAFETY \
    $LW_WRITEBACK_SAFETY \
    $END_TO_END_LOAD_REACHABILITY \
    $FULL_CORE_LOAD_REACHABILITY]

proof_structure -create partition -from CVA5_CORE_AXI_FRAMEWORK \
    -op_name CORE_SCOPE_PARTITION \
    -imp_name $CORE_BRANCH_NAMES \
    -copy $CORE_BRANCH_PROPERTIES \
    -fail_if missing_property {assert} \
    -fail_if duplicated_property {assert}

proof_structure -create partition -from FULL_CORE_LOAD_REACHABILITY \
    -op_name FULL_CORE_LOAD_STAGE_PARTITION \
    -imp_name $FULL_CORE_LOAD_STAGE_TASKS \
    -copy $FULL_CORE_LOAD_STAGE_PROPERTIES

proof_structure -create assume_guarantee -from LSU_TO_AXI_MASTER_SAFETY \
    -op_name LSU_BRIDGE_ASSUME_GUARANTEE \
    -imp_name {LSU_BRIDGE_HELPERS LSU_BRIDGE_GUARANTEES} \
    -property [list $LSU_BRIDGE_HELPERS $LSU_BRIDGE_GUARANTEES] \
    -fail_if missing_property {assert}

proof_structure -create assume_guarantee -from AXI_READ_REQUEST_SAFETY \
    -op_name AXI_READ_REQUEST_ASSUME_GUARANTEE \
    -imp_name {AXI_READ_REQUEST_HELPERS AXI_READ_REQUEST_GUARANTEES} \
    -property [list $AXI_READ_REQUEST_HELPERS $AXI_READ_REQUEST_GUARANTEES] \
    -fail_if missing_property {assert}

proof_structure -create assume_guarantee -from AXI_READ_RESPONSE_SAFETY \
    -op_name AXI_READ_RESPONSE_ASSUME_GUARANTEE \
    -imp_name {
        AXI_READ_RESPONSE_HELPERS
        AXI_READ_RESPONSE_ENVIRONMENT_CHECK
        AXI_READ_RESPONSE_QUICK_GUARANTEES
        AXI_READ_RESPONSE_DEEP_GUARANTEES
    } \
    -property [list \
        $AXI_READ_RESPONSE_HELPERS \
        $AXI_READ_RESPONSE_ENVIRONMENT_CHECK \
        $AXI_READ_RESPONSE_QUICK_GUARANTEES \
        $AXI_READ_RESPONSE_DEEP_GUARANTEES] \
    -fail_if missing_property {assert}

proof_structure -create assume_guarantee -from LW_WRITEBACK_SAFETY \
    -op_name LW_WRITEBACK_ASSUME_GUARANTEE \
    -imp_name {LW_WRITEBACK_HELPERS LW_WRITEBACK_GUARANTEES} \
    -property [list $LW_WRITEBACK_HELPERS $LW_WRITEBACK_GUARANTEES] \
    -fail_if missing_property {assert}

# Property roles and expected default status.
foreach task_name {
    RESET_AND_STARTUP_REACHABILITY
    INSTRUCTION_FETCH_BASE_REACHABILITY
} {
    set properties [get_property_list -task $task_name -include {type cover} -no_task_prefix]
    core_annotate $task_name $properties \
        {ROLE=cover/reachability; STATUS=not run by default because broad full-core cover search is resource intensive; focused stage evidence exists; never a proof dependency}
}

foreach task_name {
    INSTRUCTION_FETCH_LW_REACHABILITY
    DECODE_REACHABILITY
    ISSUE_REACHABILITY
    LSU_TO_AXI_MASTER_REACHABILITY
    AXI_READ_REQUEST_REACHABILITY
    AXI_READ_RESPONSE_REACHABILITY
    END_TO_END_LOAD_REACHABILITY
} {
    set properties [get_property_list -task $task_name -include {type cover} -no_task_prefix]
    core_annotate $task_name $properties \
        {ROLE=cover/reachability; STATUS=not run by default; explicit next-stage obligation; never a proof dependency}
}

foreach task_name $FULL_CORE_LOAD_STAGE_TASKS {
    set properties [get_property_list -task $task_name -include {type cover} -no_task_prefix]
    core_annotate $task_name $properties \
        {ROLE=anchored cover/reachability; ANCHOR=LW PC 0x80000004 and CVA5 instruction ID; STATUS=run only by the focused load-stage command; never a proof dependency}
}

core_annotate INSTRUCTION_FETCH_SAFETY $FETCH_HELPERS \
    {ROLE=white-box helper lemma; SCOPE=fetch response wiring; not architectural instruction correctness}
core_annotate LSU_BRIDGE_HELPERS $LSU_BRIDGE_HELPERS \
    {ROLE=white-box helper lemma; SCOPE=LSU request to embedded axi_master}
core_annotate LSU_BRIDGE_GUARANTEES $LSU_BRIDGE_GUARANTEES \
    {ROLE=local guarantee; SCOPE=normal load address mapping at direct axi_master boundary}
core_annotate AXI_READ_REQUEST_HELPERS $AXI_READ_REQUEST_HELPERS \
    {ROLE=white-box helper lemma; SCOPE=embedded axi_master read-request FSM}
core_annotate AXI_READ_REQUEST_GUARANTEES $AXI_READ_REQUEST_GUARANTEES \
    {ROLE=final assertion; SCOPE=embedded axi_master ARVALID/ARADDR safety; strict adapter fields excluded}
core_annotate AXI_READ_RESPONSE_HELPERS $AXI_READ_RESPONSE_HELPERS \
    {ROLE=helper lemma; SCOPE=embedded read outstanding/FSM lifecycle}
core_annotate AXI_READ_RESPONSE_ENVIRONMENT_CHECK $AXI_READ_RESPONSE_ENVIRONMENT_CHECK \
    {ROLE=environment-model assertion; SCOPE=FBM emits no impossible early RVALID; not a DUT obligation}
core_annotate AXI_READ_RESPONSE_QUICK_GUARANTEES $AXI_READ_RESPONSE_QUICK_GUARANTEES \
    {ROLE=final assertion; SCOPE=embedded read pending/FSM lifecycle and checker outstanding limits; run by default}
core_annotate AXI_READ_RESPONSE_DEEP_GUARANTEES $AXI_READ_RESPONSE_DEEP_GUARANTEES \
    {ROLE=final assertion; SCOPE=LSU completion ordering and returned data; STATUS=resource-intensive, not run by default}
core_annotate LW_WRITEBACK_HELPERS $LW_WRITEBACK_HELPERS \
    {ROLE=white-box helper lemma; SCOPE=anchored LW response/writeback/retirement tracker integrity; no DUT constraint}
core_annotate LW_WRITEBACK_GUARANTEES $LW_WRITEBACK_GUARANTEES \
    {ROLE=conditional safety assertion; SCOPE=anchored LW RDATA through LSU, physical writeback, rename map, and architectural x2 state; no eventual-completion claim}

# Historical hard properties remain visible without rerunning them.
task -create CORE__85_HISTORICAL_FETCH_DEBUG -copy [core_paths $FULL_H {
    cover_full_fetch_complete
    cover_full_fetch_attr_and_unit_data
    assert_full_fetch_miss_implies_attr_icache
}] -copy_related_covers -source_task <embedded>
set historical_properties [get_property_list -task CORE__85_HISTORICAL_FETCH_DEBUG -no_task_prefix]
core_annotate CORE__85_HISTORICAL_FETCH_DEBUG $historical_properties \
    {ROLE=historical debug property; STATUS=previously inconclusive/time-limit in full-core runs; not rerun by framework}

# Visible incomplete-obligation manifest. Markers are disabled and false so no
# reviewer can mistake them for proven assertions.
core_add_review_marker CORE__91_NOT_RUN architectural_register_writeback \
    {NOT RUN BY DEFAULT: anchored LW architectural writeback} \
    {ROLE=review manifest; STATUS=implemented as focused covers and conditional safety assertions; run writeback, retirement, x2_update, and lw_* safety stages}
core_add_review_marker CORE__90_NOT_IMPLEMENTED sign_zero_extension \
    {NOT IMPLEMENTED: load sign/zero extension semantics} \
    {ROLE=review manifest; STATUS=not implemented; byte/halfword/word result semantics remain open}
core_add_review_marker CORE__90_NOT_IMPLEMENTED misalignment_and_exceptions \
    {NOT IMPLEMENTED: misalignment and exception behavior} \
    {ROLE=review manifest; STATUS=not implemented}
core_add_review_marker CORE__90_NOT_IMPLEMENTED axi_error_responses \
    {NOT IMPLEMENTED: AXI error-response behavior} \
    {ROLE=review manifest; STATUS=not implemented; FBM currently returns OKAY}

core_add_review_marker CORE__91_NOT_RUN decode_issue_lsu_default \
    {NOT RUN: anchored LW decode/issue/LSU ladder} \
    {ROLE=review manifest; STATUS=not run by default; use the focused reachability tasks after reviewing base fetch results}
core_add_review_marker CORE__91_NOT_RUN load_end_to_end_default \
    {NOT RUN: LW to AR/R/LSU completion covers} \
    {ROLE=review manifest; STATUS=not run by default; no end-to-end load claim}
core_add_review_marker CORE__91_NOT_RUN broad_base_reachability_default \
    {NOT RUN BY DEFAULT: broad reset/startup/fetch cover groups} \
    {ROLE=review manifest; STATUS=focused historical covers exist; set CVA5_FRAMEWORK_RUN_REACHABILITY=1 only on a machine with sufficient memory}
core_add_review_marker CORE__91_NOT_RUN deep_read_response_default \
    {NOT RUN BY DEFAULT: deep LSU completion/data guarantees} \
    {ROLE=review manifest; STATUS=resource-intensive diagnostic obligations; set CVA5_FRAMEWORK_RUN_DEEP_RESPONSE=1 explicitly}

core_add_review_marker CORE__92_INCONCLUSIVE fullcore_lw_fetch_correlation \
    {HISTORICAL INCONCLUSIVE: anchored LW return to valid fetch completion} \
    {ROLE=review manifest; STATUS=historical 2-minute Ht time-limit after depth 87; subsequently covered by the focused anchored load ladder; retained as debug history, not a current open obligation}

core_add_review_marker CORE__93_REVIEW_ONLY store_path \
    {REVIEW ONLY: store/AW/W/B path} \
    {ROLE=review manifest; STATUS=outside current load-only scope; existing write reachability stages remain available}
core_add_review_marker CORE__93_REVIEW_ONLY amo_path \
    {REVIEW ONLY: AMO/LR/SC path} \
    {ROLE=review manifest; STATUS=outside current normal-load scope}
core_add_review_marker CORE__93_REVIEW_ONLY unit_axi_proof_reference \
    {REFERENCE ONLY: separate unit-level axi_master closure} \
    {ROLE=review manifest; STATUS=separate evidence; unit results are not imported as proof of the embedded instance}

core_add_review_marker CORE__94_OUTSIDE_BOUNDARY strict_external_axi_adapter_fields \
    {OUTSIDE BOUNDARY: post-axi_adapter ARSIZE/ARCACHE/AWSIZE/AWCACHE/WLAST} \
    {ROLE=review manifest; STATUS=outside current proof boundary; final external fields belong at axi_adapter or higher}

core_add_review_marker CORE__95_COUNTEREXAMPLE_STATUS no_current_framework_cex \
    {COUNTEREXAMPLE STATUS: none recorded before this framework run} \
    {ROLE=review manifest; STATUS=no recorded current counterexample; disabled marker, not a proof result}

set CORE_DEFAULT_REACHABILITY_TASKS {
    RESET_AND_STARTUP_REACHABILITY
    INSTRUCTION_FETCH_BASE_REACHABILITY
}
set CORE_DEFAULT_SAFETY_ROOTS {
    INSTRUCTION_FETCH_SAFETY
    LSU_TO_AXI_MASTER_SAFETY
    AXI_READ_REQUEST_SAFETY
}
set CORE_DEFAULT_RESPONSE_TASKS {
    AXI_READ_RESPONSE_ENVIRONMENT_CHECK
    AXI_READ_RESPONSE_HELPERS
    AXI_READ_RESPONSE_QUICK_GUARANTEES
}
set CORE_COVERAGE_TASKS {
    INSTRUCTION_FETCH_SAFETY
    LSU_BRIDGE_HELPERS
    LSU_BRIDGE_GUARANTEES
    AXI_READ_REQUEST_HELPERS
    AXI_READ_REQUEST_GUARANTEES
    AXI_READ_RESPONSE_HELPERS
    AXI_READ_RESPONSE_ENVIRONMENT_CHECK
    AXI_READ_RESPONSE_QUICK_GUARANTEES
    LW_WRITEBACK_HELPERS
    LW_WRITEBACK_GUARANTEES
}

# Focused reruns select existing assertions from the named framework tasks.
# They preserve explicit assumptions but may use the documented peripheral-load
# dcache abstraction and scheduling controls.
array set CORE_SAFETY_STAGE_TASK {
    load_accept_enters_requesting_read LSU_BRIDGE_HELPERS
    requesting_read_drives_arvalid     AXI_READ_REQUEST_HELPERS
    embedded_arvalid_hold              AXI_READ_REQUEST_GUARANTEES
    embedded_araddr_stability          AXI_READ_REQUEST_GUARANTEES
    lw_tracker_created                 LW_WRITEBACK_HELPERS
    lw_decode_destination              LW_WRITEBACK_HELPERS
    lw_tracker_holds                   LW_WRITEBACK_HELPERS
    lw_id_to_phys_mapping              LW_WRITEBACK_HELPERS
    lw_tracker_clears                  LW_WRITEBACK_HELPERS
    lw_rdata_capture                   LW_WRITEBACK_HELPERS
    lw_rdata_holds                     LW_WRITEBACK_HELPERS
    lw_retirement_tracker_clears       LW_WRITEBACK_HELPERS
    lw_rdata_matches_lsu_data          LW_WRITEBACK_GUARANTEES
    lw_writeback_destination           LW_WRITEBACK_GUARANTEES
    lw_writeback_data                  LW_WRITEBACK_GUARANTEES
    lw_register_file_write_port        LW_WRITEBACK_GUARANTEES
    lw_register_file_update            LW_WRITEBACK_GUARANTEES
    lw_architectural_x2_update         LW_WRITEBACK_GUARANTEES
    lw_instruction_result              LW_WRITEBACK_GUARANTEES
}
array set CORE_SAFETY_STAGE_PROPERTY {
    load_accept_enters_requesting_read cva5_axi_proof_framework_wrapper.helper_load_accept_enters_requesting_read
    requesting_read_drives_arvalid     cva5_axi_proof_framework_wrapper.helper_requesting_read_drives_arvalid
    embedded_arvalid_hold              cva5_axi_proof_framework_wrapper.fullcore_embedded_arvalid_hold
    embedded_araddr_stability          cva5_axi_proof_framework_wrapper.fullcore_embedded_araddr_stability
    lw_tracker_created                 cva5_axi_proof_framework_wrapper.helper_lw_writeback_tracker_created
    lw_decode_destination              cva5_axi_proof_framework_wrapper.helper_lw_decode_destination
    lw_tracker_holds                   cva5_axi_proof_framework_wrapper.helper_lw_writeback_tracker_holds
    lw_id_to_phys_mapping              cva5_axi_proof_framework_wrapper.helper_lw_id_to_phys_mapping
    lw_tracker_clears                  cva5_axi_proof_framework_wrapper.helper_lw_writeback_tracker_clears
    lw_rdata_capture                   cva5_axi_proof_framework_wrapper.helper_lw_rdata_capture
    lw_rdata_holds                     cva5_axi_proof_framework_wrapper.helper_lw_rdata_holds_until_writeback
    lw_retirement_tracker_clears       cva5_axi_proof_framework_wrapper.helper_lw_retirement_tracker_clears
    lw_rdata_matches_lsu_data          cva5_axi_proof_framework_wrapper.fullcore_lw_rdata_matches_lsu_data
    lw_writeback_destination           cva5_axi_proof_framework_wrapper.fullcore_lw_writeback_destination
    lw_writeback_data                  cva5_axi_proof_framework_wrapper.fullcore_lw_writeback_data
    lw_register_file_write_port        cva5_axi_proof_framework_wrapper.fullcore_lw_register_file_write_port
    lw_register_file_update            cva5_axi_proof_framework_wrapper.fullcore_lw_register_file_update
    lw_architectural_x2_update         cva5_axi_proof_framework_wrapper.fullcore_lw_architectural_x2_update
    lw_instruction_result              cva5_axi_proof_framework_wrapper.fullcore_lw_instruction_result
}

puts "CVA5 core/AXI framework named tasks:"
puts [task -list -silent]
puts "CVA5 core/AXI Proof Structure nodes:"
puts [proof_structure -get_node_list]

if {[info exists env(JG_CVA5_FRAMEWORK_RUN_PROOFS)] && $env(JG_CVA5_FRAMEWORK_RUN_PROOFS) ne ""} {
    set CORE_RUN_PROOFS $env(JG_CVA5_FRAMEWORK_RUN_PROOFS)
} else {
    set CORE_RUN_PROOFS 1
}
if {[info exists env(JG_CVA5_FRAMEWORK_RUN_REACHABILITY)] && $env(JG_CVA5_FRAMEWORK_RUN_REACHABILITY) ne ""} {
    set CORE_RUN_REACHABILITY $env(JG_CVA5_FRAMEWORK_RUN_REACHABILITY)
} else {
    set CORE_RUN_REACHABILITY 0
}
if {[info exists env(JG_CVA5_FRAMEWORK_RUN_DEEP_RESPONSE)] && $env(JG_CVA5_FRAMEWORK_RUN_DEEP_RESPONSE) ne ""} {
    set CORE_RUN_DEEP_RESPONSE $env(JG_CVA5_FRAMEWORK_RUN_DEEP_RESPONSE)
} else {
    set CORE_RUN_DEEP_RESPONSE 0
}

if {[info exists env(JG_CVA5_FRAMEWORK_LOAD_STAGE)] && $env(JG_CVA5_FRAMEWORK_LOAD_STAGE) ne ""} {
    set CORE_LOAD_STAGE $env(JG_CVA5_FRAMEWORK_LOAD_STAGE)
} else {
    set CORE_LOAD_STAGE ""
}
if {[info exists env(JG_CVA5_FRAMEWORK_SAFETY_STAGE)] && $env(JG_CVA5_FRAMEWORK_SAFETY_STAGE) ne ""} {
    set CORE_SAFETY_STAGE $env(JG_CVA5_FRAMEWORK_SAFETY_STAGE)
} else {
    set CORE_SAFETY_STAGE ""
}

if {$CORE_LOAD_STAGE ne "" && $CORE_SAFETY_STAGE ne ""} {
    error "Select either a load reachability stage or a safety stage, not both"
}

if {$CORE_LOAD_STAGE ne "" && $CORE_LOAD_STAGE ne "all" &&
        ![info exists FULL_CORE_LOAD_STAGE_MAP($CORE_LOAD_STAGE)]} {
    error "Unknown full-core load stage '$CORE_LOAD_STAGE'. Valid stages: all [lsort [array names FULL_CORE_LOAD_STAGE_MAP]]"
}
if {$CORE_SAFETY_STAGE ne "" &&
        ![info exists CORE_SAFETY_STAGE_PROPERTY($CORE_SAFETY_STAGE)]} {
    error "Unknown full-core safety stage '$CORE_SAFETY_STAGE'. Valid stages: [lsort [array names CORE_SAFETY_STAGE_PROPERTY]]"
}

if {$CORE_LOAD_STAGE ne "" && [info exists env(JG_CVA5_LOAD_MAX_JOBS)] &&
        $env(JG_CVA5_LOAD_MAX_JOBS) ne ""} {
    puts "CVA5 core/AXI framework: limiting focused load ProofGrid scheduling to $env(JG_CVA5_LOAD_MAX_JOBS) local jobs"
    set_proofgrid_max_jobs $env(JG_CVA5_LOAD_MAX_JOBS)
}

if {$CORE_LOAD_STAGE ne "" &&
        [info exists env(JG_CVA5_LOAD_ORCHESTRATION)] &&
        $env(JG_CVA5_LOAD_ORCHESTRATION) ne ""} {
    puts "CVA5 core/AXI framework: focused load orchestration $env(JG_CVA5_LOAD_ORCHESTRATION)"
    set_prove_orchestration $env(JG_CVA5_LOAD_ORCHESTRATION)
}

if {$CORE_SAFETY_STAGE ne "" &&
        [info exists env(JG_CVA5_SAFETY_MAX_JOBS)] &&
        $env(JG_CVA5_SAFETY_MAX_JOBS) ne ""} {
    puts "CVA5 core/AXI framework: limiting focused safety ProofGrid scheduling to $env(JG_CVA5_SAFETY_MAX_JOBS) local jobs"
    set_proofgrid_max_jobs $env(JG_CVA5_SAFETY_MAX_JOBS)
}

if {$CORE_SAFETY_STAGE ne "" &&
        [info exists env(JG_CVA5_SAFETY_ORCHESTRATION)] &&
        $env(JG_CVA5_SAFETY_ORCHESTRATION) ne ""} {
    puts "CVA5 core/AXI framework: focused safety orchestration $env(JG_CVA5_SAFETY_ORCHESTRATION)"
    set_prove_orchestration $env(JG_CVA5_SAFETY_ORCHESTRATION)
}

if {$CORE_RUN_PROOFS eq "1"} {
    if {$CORE_SAFETY_STAGE ne ""} {
        set safety_task $CORE_SAFETY_STAGE_TASK($CORE_SAFETY_STAGE)
        set safety_property ${safety_task}::$CORE_SAFETY_STAGE_PROPERTY($CORE_SAFETY_STAGE)

        if {[info exists env(JG_CVA5_USE_PROVEN_LW_LEMMAS)] &&
                $env(JG_CVA5_USE_PROVEN_LW_LEMMAS) eq "1" &&
                $safety_task eq "LW_WRITEBACK_GUARANTEES"} {
            task -set $safety_task
            foreach source_lemma {
                helper_lw_decode_destination
                helper_lw_writeback_tracker_created
                helper_lw_writeback_tracker_holds
                helper_lw_writeback_tracker_clears
                helper_lw_rdata_capture
                helper_lw_rdata_holds_until_writeback
                helper_lw_retirement_tracker_clears
            } {
                set source_assert <embedded>::${CORE_TOP}.${source_lemma}
                set cut_property [assume -from_assert $source_assert]
                puts "CVA5 core/AXI framework: assume-guarantee cut $cut_property from independently proven $source_assert"
            }
        }

        puts "CVA5 core/AXI framework: proving focused embedded safety stage $CORE_SAFETY_STAGE"
        puts "CVA5 core/AXI framework: selected property $safety_property"
        prove -property $safety_property
    } elseif {$CORE_LOAD_STAGE ne ""} {
        if {$CORE_LOAD_STAGE eq "all"} {
            foreach standalone_task {
                LOAD__00_RESET_RELEASE
                LOAD__01_STARTUP_COMPLETE
                LOAD__02_INSTRUCTION_REQUEST
                LOAD_DBG__04A_FETCH_REQUEST_ALLOC
                LOAD_DBG__04C_ICACHE_REQUEST_QUEUED
                LOAD__05_DECODE
                LOAD_DBG__05A_LW_SOURCE_MAPPING
                LOAD__06_ISSUE
            } {
                puts "CVA5 core/AXI framework: covering standalone load stage $standalone_task"
                prove -task $standalone_task
            }
            set selected_load_tasks {LOAD__14_FULL_LIFECYCLE}
        } else {
            set selected_load_tasks [list $FULL_CORE_LOAD_STAGE_MAP($CORE_LOAD_STAGE)]
        }
        foreach load_task $selected_load_tasks {
            set load_cover_qualified [core_prove_load_trace_chain $load_task]
            if {$load_cover_qualified ne "" &&
                    [info exists env(JG_CVA5_LOAD_DUMP_TRACE)] &&
                    $env(JG_CVA5_LOAD_DUMP_TRACE) eq "1"} {
                set trace_vcd [file join $env(JG_RUN_DIR) \
                    ${CORE_LOAD_STAGE}.vcd]
                puts "CVA5 core/AXI framework: exporting $load_cover_qualified to $trace_vcd"
                visualize -cover -property $load_cover_qualified \
                    -batch -silent
                visualize -save -vcd $trace_vcd -force -visible_only
            } elseif {$load_cover_qualified eq ""} {
                puts "CVA5 core/AXI framework: no covered target trace is available for export."
            }
        }
        puts "CVA5 core/AXI framework: focused load reachability mode does not run safety roots; embedded safety remains available in separate branches."
    } elseif {$CORE_RUN_REACHABILITY eq "1"} {
        foreach reachability_task $CORE_DEFAULT_REACHABILITY_TASKS {
            puts "CVA5 core/AXI framework: running opt-in reachability task $reachability_task"
            prove -task $reachability_task
        }
    } else {
        puts "JG_CVA5_FRAMEWORK_RUN_REACHABILITY=$CORE_RUN_REACHABILITY: broad full-core covers remain visible but unrun; use focused stage targets for normal regression."
    }

    if {$CORE_LOAD_STAGE eq "" && $CORE_SAFETY_STAGE eq ""} {
        source [file join [get_install_dir] etc res tcl_library jasper_tcl_library.tcl]
        foreach safety_root $CORE_DEFAULT_SAFETY_ROOTS {
            puts "CVA5 core/AXI framework: proving safety root $safety_root"
            ::jasper::psu::prove_all_serial $safety_root
        }

        foreach response_task $CORE_DEFAULT_RESPONSE_TASKS {
            puts "CVA5 core/AXI framework: proving independent response task $response_task"
            prove -task $response_task
        }

        if {$CORE_RUN_DEEP_RESPONSE eq "1"} {
            puts "CVA5 core/AXI framework: proving opt-in deep response task AXI_READ_RESPONSE_DEEP_GUARANTEES"
            prove -task AXI_READ_RESPONSE_DEEP_GUARANTEES
        } else {
            puts "JG_CVA5_FRAMEWORK_RUN_DEEP_RESPONSE=$CORE_RUN_DEEP_RESPONSE: deep LSU completion/data guarantees remain visible but unrun."
        }

        puts "CVA5 core/AXI framework: collecting scoped branch/statement COI Checker Coverage"
        check_cov -configure -checker_mode coi
        foreach coverage_task $CORE_COVERAGE_TASKS {
            check_cov -measure -type coi -task $coverage_task
        }
        foreach coverage_instance $CORE_COVERAGE_INSTANCES {
            puts "CVA5 core/AXI framework: COI Checker Coverage for $coverage_instance"
            check_cov -report -task $CORE_COVERAGE_TASKS \
                -type checker -checker_mode coi \
                -include_instance [list $coverage_instance] -no_return
        }
    }
} else {
    puts "JG_CVA5_FRAMEWORK_RUN_PROOFS=$CORE_RUN_PROOFS: setup-only project; all proof and cover results remain unrun."
}

check_cov -configure -checker_mode coi
if {[info exists env(JG_GUI)] && $env(JG_GUI) eq "1"} {
    # FPV displays measured coverage directly; stay in FPV for Proof Structure.
    proof_structure -set_visible_results proof_structure
    if {$CORE_SAFETY_STAGE ne ""} {
        task -set $CORE_SAFETY_STAGE_TASK($CORE_SAFETY_STAGE) -update_gui
    } elseif {$CORE_LOAD_STAGE ne "" && $CORE_LOAD_STAGE ne "all"} {
        task -set $FULL_CORE_LOAD_STAGE_MAP($CORE_LOAD_STAGE) -update_gui
    } elseif {$CORE_LOAD_STAGE eq "all"} {
        task -set LOAD__00_RESET_RELEASE -update_gui
    } else {
        task -set RESET_AND_STARTUP_REACHABILITY -update_gui
    }
} else {
    if {$CORE_SAFETY_STAGE ne ""} {
        task -set $CORE_SAFETY_STAGE_TASK($CORE_SAFETY_STAGE)
    } elseif {$CORE_LOAD_STAGE ne "" && $CORE_LOAD_STAGE ne "all"} {
        task -set $FULL_CORE_LOAD_STAGE_MAP($CORE_LOAD_STAGE)
    } elseif {$CORE_LOAD_STAGE eq "all"} {
        task -set LOAD__00_RESET_RELEASE
    } else {
        task -set RESET_AND_STARTUP_REACHABILITY
    }
}

puts "CVA5 core/AXI framework task status summary:"
foreach task_name [concat \
    $CORE_BRANCH_NAMES \
    $FULL_CORE_LOAD_STAGE_TASKS \
    {
        CORE__00_ENV_RESET_STARTUP
        CORE__00_DESIGN_INTENT_DISABLED_UNIT
        CORE__00_ENV_AXI_SECONDARY
        CORE__00_ENV_ASSUMPTION_REVIEW
        CORE__01_ENV_INSTRUCTION_MEMORY_MODEL
        CORE__02_ENV_DATA_AXI_MODEL
        CORE__03_ENV_PROGRESS
        CORE__04_ENV_ABSTRACTIONS
        CORE__85_HISTORICAL_FETCH_DEBUG
        CORE__90_NOT_IMPLEMENTED
        CORE__91_NOT_RUN
        CORE__92_INCONCLUSIVE
        CORE__93_REVIEW_ONLY
        CORE__94_OUTSIDE_BOUNDARY
        CORE__95_COUNTEREXAMPLE_STATUS
    }] {
    core_print_task_summary $task_name
}
