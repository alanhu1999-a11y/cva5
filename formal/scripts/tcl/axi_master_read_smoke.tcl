# Read-only AXI master AR-channel reachability smoke test.

set AXI_MASTER_READ_TOP axi_master_read_cover_wrapper

if {[info exists env(CVA5_ROOT)]} {
    set COMMON_TCL [file join $env(CVA5_ROOT) formal scripts tcl _axi_master_read_common.tcl]
} else {
    set COMMON_TCL [file join [pwd] formal scripts tcl _axi_master_read_common.tcl]
}
source $COMMON_TCL

prove -property ${AXI_MASTER_READ_HARNESS}.cover_read_request
prove -property ${AXI_MASTER_READ_HARNESS}.cover_read_backpressure
prove -property ${AXI_MASTER_READ_HARNESS}.cover_read_response
prove -property ${AXI_MASTER_READ_HARNESS}.cover_read_response_lifecycle
