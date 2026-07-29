# Combined AXI master read/write lifecycle reachability smoke test.

set AXI_MASTER_COMBINED_TOP axi_master_combined_formal_wrapper

if {[info exists env(CVA5_ROOT)]} {
    set COMMON_TCL [file join $env(CVA5_ROOT) formal scripts tcl _axi_master_combined_common.tcl]
} else {
    set COMMON_TCL [file join [pwd] formal scripts tcl _axi_master_combined_common.tcl]
}
source $COMMON_TCL

prove -property ${AXI_MASTER_COMBINED_HARNESS}.cover_combined_read_request
prove -property ${AXI_MASTER_COMBINED_HARNESS}.cover_combined_write_request
prove -property ${AXI_MASTER_COMBINED_HARNESS}.cover_combined_read_lifecycle
prove -property ${AXI_MASTER_COMBINED_HARNESS}.cover_combined_write_lifecycle
prove -property ${AXI_MASTER_COMBINED_HARNESS}.cover_read_then_write
prove -property ${AXI_MASTER_COMBINED_HARNESS}.cover_write_then_read
