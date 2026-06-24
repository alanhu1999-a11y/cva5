# Prove one checker bookkeeping helper with abstract AXI handshakes.

if {[info exists env(CVA5_ROOT)]} {
    set COMMON_TCL [file join $env(CVA5_ROOT) formal scripts tcl _axi_checker_common.tcl]
} else {
    set COMMON_TCL [file join [pwd] formal scripts tcl _axi_checker_common.tcl]
}
source $COMMON_TCL

if {![info exists env(JG_PROPERTY)] || $env(JG_PROPERTY) eq ""} {
    error "JG_PROPERTY is required. Example: make formal-axi-checker-property PROPERTY=helper_read_count_increment"
}

if {![string match "helper_*" $env(JG_PROPERTY)]} {
    error "The checker target accepts only helper_* properties; use formal-axi-master-property for DUT properties."
}

set PROPERTY_PATH ${AXI_CHECKER_PROPS}.$env(JG_PROPERTY)
puts "Proving AXI checker property: $PROPERTY_PATH"
prove -property $PROPERTY_PATH
