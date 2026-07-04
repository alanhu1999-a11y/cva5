# Prove one combined read/write AXI master property under the unit-level harness.

set AXI_MASTER_COMBINED_TOP axi_master_combined_formal_wrapper

if {[info exists env(CVA5_ROOT)]} {
    set COMMON_TCL [file join $env(CVA5_ROOT) formal scripts tcl _axi_master_combined_common.tcl]
} else {
    set COMMON_TCL [file join [pwd] formal scripts tcl _axi_master_combined_common.tcl]
}
source $COMMON_TCL

if {![info exists env(JG_PROPERTY)] || $env(JG_PROPERTY) eq ""} {
    error "JG_PROPERTY is required. Example: make formal-axi-master-combined-property PROPERTY=dut_no_simultaneous_read_write_handshake"
}

if {[string match "dut_*" $env(JG_PROPERTY)]
    || [string match "cover_combined_*" $env(JG_PROPERTY)]
    || $env(JG_PROPERTY) eq "cover_read_then_write"
    || $env(JG_PROPERTY) eq "cover_write_then_read"} {
    set PROPERTY_PATH ${AXI_MASTER_COMBINED_HARNESS}.$env(JG_PROPERTY)
} else {
    set PROPERTY_PATH ${AXI_MASTER_COMBINED_PROPS}.$env(JG_PROPERTY)
}

puts "Proving combined AXI master property: $PROPERTY_PATH"
prove -property $PROPERTY_PATH
