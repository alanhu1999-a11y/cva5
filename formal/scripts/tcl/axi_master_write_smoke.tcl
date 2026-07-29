# Write-only AXI master AW/W/B lifecycle reachability smoke test.

set AXI_MASTER_WRITE_TOP axi_master_write_formal_wrapper

if {[info exists env(CVA5_ROOT)]} {
    set COMMON_TCL [file join $env(CVA5_ROOT) formal scripts tcl _axi_master_write_common.tcl]
} else {
    set COMMON_TCL [file join [pwd] formal scripts tcl _axi_master_write_common.tcl]
}
source $COMMON_TCL

prove -property ${AXI_MASTER_WRITE_HARNESS}.cover_write_request
prove -property ${AXI_MASTER_WRITE_HARNESS}.cover_aw_backpressure
prove -property ${AXI_MASTER_WRITE_HARNESS}.cover_aw_ready_already_high
prove -property ${AXI_MASTER_WRITE_HARNESS}.cover_aw_ready_same_cycle_as_valid
prove -property ${AXI_MASTER_WRITE_HARNESS}.cover_aw_wait_1_cycle
prove -property ${AXI_MASTER_WRITE_HARNESS}.cover_aw_wait_2_cycles
prove -property ${AXI_MASTER_WRITE_HARNESS}.cover_aw_wait_3_cycles
prove -property ${AXI_MASTER_WRITE_HARNESS}.cover_aw_wait_16_cycles
prove -property ${AXI_MASTER_WRITE_HARNESS}.cover_aw_wait_19_cycles
prove -property ${AXI_MASTER_WRITE_HARNESS}.cover_w_backpressure
prove -property ${AXI_MASTER_WRITE_HARNESS}.cover_w_ready_already_high
prove -property ${AXI_MASTER_WRITE_HARNESS}.cover_w_ready_same_cycle_as_valid
prove -property ${AXI_MASTER_WRITE_HARNESS}.cover_w_wait_1_cycle
prove -property ${AXI_MASTER_WRITE_HARNESS}.cover_w_wait_2_cycles
prove -property ${AXI_MASTER_WRITE_HARNESS}.cover_w_wait_3_cycles
prove -property ${AXI_MASTER_WRITE_HARNESS}.cover_w_wait_16_cycles
prove -property ${AXI_MASTER_WRITE_HARNESS}.cover_w_wait_19_cycles
prove -property ${AXI_MASTER_WRITE_HARNESS}.cover_write_address_data_accept
prove -property ${AXI_MASTER_WRITE_HARNESS}.cover_write_response_lifecycle
