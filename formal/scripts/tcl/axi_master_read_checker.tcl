# Prove read-side checker properties in the unit-level AXI master read harness.

set AXI_MASTER_READ_TOP axi_master_read_formal_wrapper

if {[info exists env(CVA5_ROOT)]} {
    set COMMON_TCL [file join $env(CVA5_ROOT) formal scripts tcl _axi_master_read_common.tcl]
} else {
    set COMMON_TCL [file join [pwd] formal scripts tcl _axi_master_read_common.tcl]
}
source $COMMON_TCL

set READ_CHECKER_ASSERTIONS {
    helper_read_count_increment
    helper_read_count_decrement
    helper_read_count_stable
    master_read_outstanding_limit
    master_no_second_read_accept
}

foreach property_name $READ_CHECKER_ASSERTIONS {
    set PROPERTY_PATH ${AXI_MASTER_READ_PROPS}.${property_name}
    puts "Proving read checker property: $PROPERTY_PATH"
    prove -property $PROPERTY_PATH
}

set READ_CHECKER_COVERS {
    cover_read_request
    cover_read_response
    cover_read_outstanding_lifecycle
}

foreach property_name $READ_CHECKER_COVERS {
    set PROPERTY_PATH ${AXI_MASTER_READ_PROPS}.${property_name}
    puts "Covering read checker property: $PROPERTY_PATH"
    prove -property $PROPERTY_PATH
}
