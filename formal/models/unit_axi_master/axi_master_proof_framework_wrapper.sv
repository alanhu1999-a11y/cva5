// Review-only top that keeps the read, write, and combined proof contexts
// structurally independent inside one Jasper project.

module axi_master_proof_framework_wrapper (
    input logic clk,
    input logic rst,

    input logic        read_ls_new_request,
    input logic [31:0] read_ls_addr,
    input logic        read_axi_arready,
    input logic        read_axi_rvalid,
    input logic [31:0] read_axi_rdata,
    input logic [1:0]  read_axi_rresp,
    input logic        read_axi_rlast,
    input logic [5:0]  read_axi_rid,

    input logic        write_ls_new_request,
    input logic [31:0] write_ls_addr,
    input logic [31:0] write_ls_data_in,
    input logic [3:0]  write_ls_be,
    input logic        write_axi_awready,
    input logic        write_axi_wready,
    input logic        write_axi_bvalid,
    input logic [1:0]  write_axi_bresp,
    input logic [5:0]  write_axi_bid,

    input logic        combined_ls_new_request,
    input logic        combined_ls_re,
    input logic        combined_ls_we,
    input logic [31:0] combined_ls_addr,
    input logic [31:0] combined_ls_data_in,
    input logic [3:0]  combined_ls_be,
    input logic        combined_axi_arready,
    input logic        combined_axi_rvalid,
    input logic [31:0] combined_axi_rdata,
    input logic [1:0]  combined_axi_rresp,
    input logic        combined_axi_rlast,
    input logic [5:0]  combined_axi_rid,
    input logic        combined_axi_awready,
    input logic        combined_axi_wready,
    input logic        combined_axi_bvalid,
    input logic [1:0]  combined_axi_bresp,
    input logic [5:0]  combined_axi_bid
);

    axi_master_read_harness #(
        .BOUND_ARREADY_FOR_COVER(1'b0)
    ) u_read (
        .clk,
        .rst,
        .ls_new_request (read_ls_new_request),
        .ls_addr        (read_ls_addr),
        .axi_arready    (read_axi_arready),
        .axi_rvalid     (read_axi_rvalid),
        .axi_rdata      (read_axi_rdata),
        .axi_rresp      (read_axi_rresp),
        .axi_rlast      (read_axi_rlast),
        .axi_rid        (read_axi_rid)
    );

    axi_master_write_harness #(
        .BOUND_WRITE_READY_FOR_COVER(1'b0)
    ) u_write (
        .clk,
        .rst,
        .ls_new_request (write_ls_new_request),
        .ls_addr        (write_ls_addr),
        .ls_data_in     (write_ls_data_in),
        .ls_be          (write_ls_be),
        .axi_awready    (write_axi_awready),
        .axi_wready     (write_axi_wready),
        .axi_bvalid     (write_axi_bvalid),
        .axi_bresp      (write_axi_bresp),
        .axi_bid        (write_axi_bid)
    );

    axi_master_combined_harness #(
        .BOUND_READY_FOR_COVER(1'b0)
    ) u_combined (
        .clk,
        .rst,
        .ls_new_request (combined_ls_new_request),
        .ls_re          (combined_ls_re),
        .ls_we          (combined_ls_we),
        .ls_addr        (combined_ls_addr),
        .ls_data_in     (combined_ls_data_in),
        .ls_be          (combined_ls_be),
        .axi_arready    (combined_axi_arready),
        .axi_rvalid     (combined_axi_rvalid),
        .axi_rdata      (combined_axi_rdata),
        .axi_rresp      (combined_axi_rresp),
        .axi_rlast      (combined_axi_rlast),
        .axi_rid        (combined_axi_rid),
        .axi_awready    (combined_axi_awready),
        .axi_wready     (combined_axi_wready),
        .axi_bvalid     (combined_axi_bvalid),
        .axi_bresp      (combined_axi_bresp),
        .axi_bid        (combined_axi_bid)
    );

endmodule
