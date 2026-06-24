# Prove one AXI property against the unit-level AXI master harness.

if {[info exists env(CVA5_ROOT)]} {
    set COMMON_TCL [file join $env(CVA5_ROOT) formal scripts tcl _axi_master_common.tcl]
} else {
    set COMMON_TCL [file join [pwd] formal scripts tcl _axi_master_common.tcl]
}
source $COMMON_TCL

if {![info exists env(JG_PROPERTY)] || $env(JG_PROPERTY) eq ""} {
    error "JG_PROPERTY is required. Example: make formal-axi-master-property PROPERTY=master_arvalid_held_until_ready"
}

if {[string match "helper_*" $env(JG_PROPERTY)]} {
    error "helper_* properties are checker self-tests; use formal-axi-checker-property instead."
}

if {[string match "dut_*" $env(JG_PROPERTY)]} {
    set PROPERTY_PATH ${AXI_MASTER_HARNESS}.$env(JG_PROPERTY)
} else {
    set PROPERTY_PATH ${AXI_MASTER_PROPS}.$env(JG_PROPERTY)
}

puts "Proving unit-level AXI master property: $PROPERTY_PATH"
prove -property $PROPERTY_PATH
