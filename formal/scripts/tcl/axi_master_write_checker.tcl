# Prove write-side checker properties in the unit-level AXI master write
# harness.

set AXI_MASTER_WRITE_TOP axi_master_write_formal_wrapper

if {[info exists env(CVA5_ROOT)]} {
    set COMMON_TCL [file join $env(CVA5_ROOT) formal scripts tcl _axi_master_write_common.tcl]
} else {
    set COMMON_TCL [file join [pwd] formal scripts tcl _axi_master_write_common.tcl]
}
source $COMMON_TCL

set WRITE_CHECKER_ASSERTIONS {
    master_awvalid_held_until_ready
    master_awaddr_stable_until_ready
    master_wvalid_held_until_ready
    master_wdata_stable_until_ready
    helper_write_address_count_increment
    helper_write_address_count_decrement
    helper_write_address_count_stable
    helper_write_data_count_increment
    helper_write_data_count_decrement
    helper_write_data_count_stable
    master_write_address_outstanding_limit
    master_write_data_outstanding_limit
    master_no_second_write_address_accept
    master_no_second_write_data_accept
}

foreach property_name $WRITE_CHECKER_ASSERTIONS {
    set PROPERTY_PATH ${AXI_MASTER_WRITE_PROPS}.${property_name}
    puts "Proving write checker property: $PROPERTY_PATH"
    prove -property $PROPERTY_PATH
}

set WRITE_CHECKER_COVERS {
    cover_write_address
    cover_write_data
    cover_write_response
    cover_write_outstanding_lifecycle
}

foreach property_name $WRITE_CHECKER_COVERS {
    set PROPERTY_PATH ${AXI_MASTER_WRITE_PROPS}.${property_name}
    puts "Covering write checker property: $PROPERTY_PATH"
    prove -property $PROPERTY_PATH
}
