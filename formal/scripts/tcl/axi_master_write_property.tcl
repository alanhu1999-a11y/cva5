# Prove one write-only AXI master property under the unit-level harness.

set AXI_MASTER_WRITE_TOP axi_master_write_formal_wrapper

if {[info exists env(CVA5_ROOT)]} {
    set COMMON_TCL [file join $env(CVA5_ROOT) formal scripts tcl _axi_master_write_common.tcl]
} else {
    set COMMON_TCL [file join [pwd] formal scripts tcl _axi_master_write_common.tcl]
}
source $COMMON_TCL

if {![info exists env(JG_PROPERTY)] || $env(JG_PROPERTY) eq ""} {
    error "JG_PROPERTY is required. Example: make formal-axi-master-write-property PROPERTY=dut_write_request_drives_aw_w_valid"
}

if {[string match "dut_*" $env(JG_PROPERTY)]
    || [string match "cover_*" $env(JG_PROPERTY)]} {
    set PROPERTY_PATH ${AXI_MASTER_WRITE_HARNESS}.$env(JG_PROPERTY)
} else {
    set PROPERTY_PATH ${AXI_MASTER_WRITE_PROPS}.$env(JG_PROPERTY)
}

puts "Proving write-only AXI master property: $PROPERTY_PATH"
prove -property $PROPERTY_PATH
