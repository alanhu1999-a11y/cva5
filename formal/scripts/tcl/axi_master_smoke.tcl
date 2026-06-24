# Unit-level AXI master reachability smoke test.

if {[info exists env(CVA5_ROOT)]} {
    set COMMON_TCL [file join $env(CVA5_ROOT) formal scripts tcl _axi_master_common.tcl]
} else {
    set COMMON_TCL [file join [pwd] formal scripts tcl _axi_master_common.tcl]
}
source $COMMON_TCL

prove -property ${AXI_MASTER_HARNESS}.cover_*
prove -property ${AXI_MASTER_PROPS}.cover_*
