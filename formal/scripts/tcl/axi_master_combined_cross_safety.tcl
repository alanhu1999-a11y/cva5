# Prove combined read/write cross-mode safety against the unit-level AXI master harness.

set AXI_MASTER_COMBINED_TOP axi_master_combined_formal_wrapper

if {[info exists env(CVA5_ROOT)]} {
    set COMMON_TCL [file join $env(CVA5_ROOT) formal scripts tcl _axi_master_combined_common.tcl]
} else {
    set COMMON_TCL [file join [pwd] formal scripts tcl _axi_master_combined_common.tcl]
}
source $COMMON_TCL

set COMBINED_CROSS_PROPERTIES {
    dut_legal_read_request_enters_requesting_read
    dut_legal_write_request_enters_requesting_write
    dut_request_accepted_only_from_ready_state
    dut_no_simultaneous_read_write_valid
    dut_no_simultaneous_read_write_handshake
    dut_no_read_write_pending_overlap
    dut_busy_states_hold_ready_low
    dut_read_request_drives_only_arvalid
    dut_write_request_drives_only_aw_wvalid
    dut_ar_accept_creates_read_pending
    dut_read_pending_holds_without_r_response
    dut_read_pending_implies_waiting_read
    dut_r_response_clears_read_pending
    dut_r_response_returns_to_ready
    dut_read_completion_follows_r_response
    dut_no_read_completion_from_b_response
    dut_rdata_maps_to_ls_data_out
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
}

foreach property_name $COMBINED_CROSS_PROPERTIES {
    set PROPERTY_PATH ${AXI_MASTER_COMBINED_HARNESS}.${property_name}
    puts "Proving combined AXI master cross-safety property: $PROPERTY_PATH"
    prove -property $PROPERTY_PATH
}
