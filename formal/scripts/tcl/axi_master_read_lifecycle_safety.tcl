# Prove the local AXI read-response lifecycle safety ladder against the
# read-only AXI master harness.

set AXI_MASTER_READ_TOP axi_master_read_formal_wrapper

if {[info exists env(CVA5_ROOT)]} {
    set COMMON_TCL [file join $env(CVA5_ROOT) formal scripts tcl _axi_master_read_common.tcl]
} else {
    set COMMON_TCL [file join [pwd] formal scripts tcl _axi_master_read_common.tcl]
}
source $COMMON_TCL

set READ_LIFECYCLE_PROPERTIES {
    dut_ar_accept_creates_pending_read
    dut_read_pending_holds_without_r_response
    dut_read_pending_implies_waiting_read
    dut_waiting_read_holds_until_rvalid
    dut_r_response_clears_pending_read
    dut_r_response_returns_to_ready
    dut_r_response_completes_lsu
    dut_read_completion_follows_r_response
    dut_rdata_maps_to_ls_data_out
    dut_rvalid_drives_ls_data_valid
    dut_rvalid_drives_ls_ready
}

foreach property_name $READ_LIFECYCLE_PROPERTIES {
    set PROPERTY_PATH ${AXI_MASTER_READ_HARNESS}.${property_name}
    puts "Proving read lifecycle safety property: $PROPERTY_PATH"
    prove -property $PROPERTY_PATH
}
