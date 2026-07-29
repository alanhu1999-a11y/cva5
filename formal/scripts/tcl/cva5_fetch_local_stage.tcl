# Prove one focused fetch-local CVA5 reachability/debug property.

clear -all

if {[info exists env(JG_ENGINE_MODE)] && $env(JG_ENGINE_MODE) ne ""} {
    set CVA5_FETCH_LOCAL_ENGINE_MODE $env(JG_ENGINE_MODE)
} else {
    set CVA5_FETCH_LOCAL_ENGINE_MODE auto
}
puts "CVA5 fetch-local engine mode: $CVA5_FETCH_LOCAL_ENGINE_MODE"
set_engine_mode $CVA5_FETCH_LOCAL_ENGINE_MODE

if {[info exists env(CVA5_ROOT)]} {
    set CVA5_ROOT [file normalize $env(CVA5_ROOT)]
} elseif {[info exists env(JG_CVA5_RTL_PATH)]} {
    set CVA5_ROOT [file normalize $env(JG_CVA5_RTL_PATH)]
} else {
    set SCRIPT_DIR [file dirname [file normalize [info script]]]
    set CVA5_ROOT [file normalize [file join $SCRIPT_DIR ../../..]]
}

set env(JG_CVA5_RTL_PATH) $CVA5_ROOT
set JG_CVA5_RTL_PATH $CVA5_ROOT
set FILELIST_PATH [file join $CVA5_ROOT formal filelists cva5_rtl.vfile]

source [file join $CVA5_ROOT formal scripts tcl _proof_limits.tcl]

if {![file exists $FILELIST_PATH]} {
    error "RTL filelist not found: $FILELIST_PATH. Run make formal-filelist first."
}

analyze -sv -f $FILELIST_PATH
analyze -sv [file join $CVA5_ROOT formal models full_core cva5_fetch_local_wrapper.sv]

elaborate -top cva5_fetch_local_wrapper \
    -bbox_a 17000 \
    -bbox_mul 67 \
    -bbox_m sixinput_pop_count

clock clk
reset rst

set FETCH_LOCAL <embedded>::cva5_fetch_local_wrapper

if {![info exists env(JG_STAGE)] || $env(JG_STAGE) eq ""} {
    error "JG_STAGE is required. Example: make formal-cva5-fetch-local-stage STAGE=fetch_complete_lui"
}

array set CVA5_FETCH_LOCAL_STAGE {
    request_alloc                   cover_fetch_request_alloc
    attr_push                       cover_attr_fifo_push
    attr_valid_after_push           cover_attr_fifo_valid_after_push
    attr_valid_waiting_for_data     cover_attr_fifo_valid_waiting_for_data
    mem_request_reset_vec           cover_instruction_mem_request_reset_vec
    mem_ack_reset_vec               cover_instruction_mem_ack_reset_vec
    instruction_response_lui        cover_instruction_response_lui
    miss_data_lui                   cover_miss_data_lui
    attr_valid_and_miss_data        cover_attr_valid_and_miss_data
    attr_and_unit_data_same_cycle   cover_attr_and_unit_data_same_cycle
    attr_valid_then_lui_data_next   cover_attr_valid_then_lui_data_next
    lui_data_then_attr_valid_next   cover_lui_data_then_attr_valid_next
    attr_pop_without_unit_data      cover_attr_pop_without_unit_data
    internal_fetch_complete_lui     cover_internal_fetch_complete_lui
    fetch_complete_lui              cover_fetch_complete_lui
    assert_attr_push_creates_valid  assert_attr_push_creates_valid
    assert_attr_valid_holds_without_data assert_attr_valid_holds_without_data
    assert_unit_data_implies_matching_attr assert_unit_data_implies_matching_attr
    assert_miss_data_implies_attr_icache assert_miss_data_implies_attr_icache
    assert_miss_data_implies_internal_complete assert_miss_data_implies_internal_complete
    assert_miss_data_implies_fetch_complete_lui assert_miss_data_implies_fetch_complete_lui
}

set STAGE_NAME $env(JG_STAGE)
if {![info exists CVA5_FETCH_LOCAL_STAGE($STAGE_NAME)]} {
    error "Unknown JG_STAGE '$STAGE_NAME'. Valid stages: [lsort [array names CVA5_FETCH_LOCAL_STAGE]]"
}

set PROPERTY_NAME $CVA5_FETCH_LOCAL_STAGE($STAGE_NAME)
set PROPERTY_PATH ${FETCH_LOCAL}.${PROPERTY_NAME}

puts "Running CVA5 fetch-local stage '$STAGE_NAME': $PROPERTY_PATH"
prove -property $PROPERTY_PATH
