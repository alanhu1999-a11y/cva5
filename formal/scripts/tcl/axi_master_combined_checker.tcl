# Prove shared AXI checker properties in the combined unit-level AXI master harness.

set AXI_MASTER_COMBINED_TOP axi_master_combined_formal_wrapper

if {[info exists env(CVA5_ROOT)]} {
    set COMMON_TCL [file join $env(CVA5_ROOT) formal scripts tcl _axi_master_combined_common.tcl]
} else {
    set COMMON_TCL [file join [pwd] formal scripts tcl _axi_master_combined_common.tcl]
}
source $COMMON_TCL

set COMBINED_CHECKER_ASSERTIONS {
    master_arvalid_held_until_ready
    master_araddr_stable_until_ready
    helper_read_count_increment
    helper_read_count_decrement
    helper_read_count_stable
    master_read_outstanding_limit
    master_no_second_read_accept
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

foreach property_name $COMBINED_CHECKER_ASSERTIONS {
    set PROPERTY_PATH ${AXI_MASTER_COMBINED_PROPS}.${property_name}
    puts "Proving combined AXI checker property: $PROPERTY_PATH"
    prove -property $PROPERTY_PATH
}

set COMBINED_CHECKER_COVERS {
    cover_read_request
    cover_read_response
    cover_read_outstanding_lifecycle
    cover_write_address
    cover_write_data
    cover_write_response
    cover_write_outstanding_lifecycle
}

foreach property_name $COMBINED_CHECKER_COVERS {
    set PROPERTY_PATH ${AXI_MASTER_COMBINED_PROPS}.${property_name}
    puts "Covering combined AXI checker property: $PROPERTY_PATH"
    prove -property $PROPERTY_PATH
}
