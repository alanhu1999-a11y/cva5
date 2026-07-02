# Prove one AR-channel property against the read-only AXI master harness.

set AXI_MASTER_READ_TOP axi_master_read_formal_wrapper

if {[info exists env(CVA5_ROOT)]} {
    set COMMON_TCL [file join $env(CVA5_ROOT) formal scripts tcl _axi_master_read_common.tcl]
} else {
    set COMMON_TCL [file join [pwd] formal scripts tcl _axi_master_read_common.tcl]
}
source $COMMON_TCL

if {![info exists env(JG_PROPERTY)] || $env(JG_PROPERTY) eq ""} {
    error "JG_PROPERTY is required. Example: make formal-axi-master-read-property PROPERTY=master_arvalid_held_until_ready"
}

if {[string match "helper_*" $env(JG_PROPERTY)]} {
    error "helper_* properties are checker self-tests; use formal-axi-checker-property instead."
}

if {[string match "dut_*" $env(JG_PROPERTY)]
    || [string match "cover_*" $env(JG_PROPERTY)]
    || [string match "cut_*" $env(JG_PROPERTY)]
    || [string match "debug_*" $env(JG_PROPERTY)]} {
    set PROPERTY_PATH ${AXI_MASTER_READ_HARNESS}.$env(JG_PROPERTY)
} else {
    set PROPERTY_PATH ${AXI_MASTER_READ_PROPS}.$env(JG_PROPERTY)
}

puts "Proving read-only AXI master property: $PROPERTY_PATH"
prove -property $PROPERTY_PATH
