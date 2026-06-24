# Prove one AXI property or an explicitly selected property group.
# Set JG_PROPERTY to a label relative to u_ppb_axi, for example:
#   JG_PROPERTY=master_arvalid_held_until_ready

if {[info exists env(CVA5_ROOT)]} {
    set COMMON_TCL [file join $env(CVA5_ROOT) formal scripts tcl _axi_common.tcl]
} else {
    set COMMON_TCL [file join [pwd] formal scripts tcl _axi_common.tcl]
}
source $COMMON_TCL
source [file join $CVA5_ROOT formal scripts tcl _proof_limits.tcl]

if {![info exists env(JG_PROPERTY)] || $env(JG_PROPERTY) eq ""} {
    error "JG_PROPERTY is required. Example: make formal-axi-property PROPERTY=master_arvalid_held_until_ready"
}

if {[string match "helper_*" $env(JG_PROPERTY)]} {
    error "helper_* properties are checker self-tests; use formal-axi-checker-property instead."
}

set PROPERTY_PATH ${AXI_PROPS}.$env(JG_PROPERTY)
puts "Proving AXI property selection: $PROPERTY_PATH"
prove -property $PROPERTY_PATH
