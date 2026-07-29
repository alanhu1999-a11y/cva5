// Abstract AXI stimulus for validating checker bookkeeping independently.

module axi_checker_formal_wrapper (
    input logic clk,
    input logic rst,

    input logic        arready,
    input logic        arvalid,
    input logic [31:0] araddr,
    input logic [7:0]  arlen,
    input logic [2:0]  arsize,
    input logic [1:0]  arburst,
    input logic [3:0]  arcache,
    input logic [5:0]  arid,
    input logic        arlock,
    input logic        rready,
    input logic        rvalid,
    input logic [31:0] rdata,
    input logic [1:0]  rresp,
    input logic        rlast,
    input logic [5:0]  rid,

    input logic        awready,
    input logic        awvalid,
    input logic [31:0] awaddr,
    input logic [7:0]  awlen,
    input logic [2:0]  awsize,
    input logic [1:0]  awburst,
    input logic [3:0]  awcache,
    input logic [5:0]  awid,
    input logic        awlock,
    input logic        wready,
    input logic        wvalid,
    input logic [31:0] wdata,
    input logic [3:0]  wstrb,
    input logic        wlast,
    input logic        bready,
    input logic        bvalid,
    input logic [1:0]  bresp,
    input logic [5:0]  bid
);

    axi_interface axi_if();

    assign axi_if.arready = arready;
    assign axi_if.arvalid = arvalid;
    assign axi_if.araddr = araddr;
    assign axi_if.arlen = arlen;
    assign axi_if.arsize = arsize;
    assign axi_if.arburst = arburst;
    assign axi_if.arcache = arcache;
    assign axi_if.arid = arid;
    assign axi_if.arlock = arlock;
    assign axi_if.rready = rready;
    assign axi_if.rvalid = rvalid;
    assign axi_if.rdata = rdata;
    assign axi_if.rresp = rresp;
    assign axi_if.rlast = rlast;
    assign axi_if.rid = rid;

    assign axi_if.awready = awready;
    assign axi_if.awvalid = awvalid;
    assign axi_if.awaddr = awaddr;
    assign axi_if.awlen = awlen;
    assign axi_if.awsize = awsize;
    assign axi_if.awburst = awburst;
    assign axi_if.awcache = awcache;
    assign axi_if.awid = awid;
    assign axi_if.awlock = awlock;
    assign axi_if.wready = wready;
    assign axi_if.wvalid = wvalid;
    assign axi_if.wdata = wdata;
    assign axi_if.wstrb = wstrb;
    assign axi_if.wlast = wlast;
    assign axi_if.bready = bready;
    assign axi_if.bvalid = bvalid;
    assign axi_if.bresp = bresp;
    assign axi_if.bid = bid;

    axi4_basic_props u_axi_props (
        .clk,
        .rst,
        .axi_if
    );

endmodule
