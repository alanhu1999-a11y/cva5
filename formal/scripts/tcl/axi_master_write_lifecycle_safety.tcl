# Prove the local AXI write-response lifecycle safety ladder against the
# write-only AXI master harness.

set AXI_MASTER_WRITE_TOP axi_master_write_formal_wrapper

if {[info exists env(CVA5_ROOT)]} {
    set COMMON_TCL [file join $env(CVA5_ROOT) formal scripts tcl _axi_master_write_common.tcl]
} else {
    set COMMON_TCL [file join [pwd] formal scripts tcl _axi_master_write_common.tcl]
}
source $COMMON_TCL

set WRITE_LIFECYCLE_PROPERTIES {
    dut_write_request_enters_requesting_write
    dut_write_request_drives_aw_w_valid
    dut_write_only_no_read_valid
    dut_awvalid_backpressure_implies_requesting_write
    dut_requesting_write_holds_awvalid
    dut_awvalid_holds_until_ready
    dut_requesting_write_holds_awaddr
    dut_awaddr_stable_until_ready
    dut_wvalid_backpressure_implies_requesting_write
    dut_requesting_write_holds_wvalid
    dut_wvalid_holds_until_ready
    dut_requesting_write_holds_wdata
    dut_wdata_stable_until_ready
    dut_aw_accept_sets_aw_pending
    dut_w_accept_sets_w_pending
    dut_aw_w_acceptance_creates_pending_write
    dut_write_pending_holds_without_b_response
    dut_write_pending_implies_waiting_write
    dut_waiting_write_holds_until_bvalid
    dut_b_response_clears_pending_write
    dut_b_response_returns_to_ready
    dut_b_response_completes_lsu
    dut_write_completion_follows_b_response
    dut_b_response_clears_write_outstanding
}

foreach property_name $WRITE_LIFECYCLE_PROPERTIES {
    set PROPERTY_PATH ${AXI_MASTER_WRITE_HARNESS}.${property_name}
    puts "Proving write lifecycle safety property: $PROPERTY_PATH"
    prove -property $PROPERTY_PATH
}
