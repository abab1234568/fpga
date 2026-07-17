module jtag_cpu_amd_core #(
    parameter data_width = 32,
    parameter addr_width = 32
) (
    input clk,
    input rst_n,

    output lcpu_rh_wl,
    output lcpu_req,
    input lcpu_ack,
    output [addr_width-1:0] lcpu_address,
    output [data_width-1:0] lcpu_wdata,
    input [data_width-1:0] lcpu_rdata
);

  wire [31:0] m_axi_awaddr;
  wire [2:0] m_axi_awprot;
  wire m_axi_awvalid;
  wire m_axi_awready;
  wire [31:0] m_axi_wdata;
  wire [3:0] m_axi_wstrb;
  wire m_axi_wvalid;
  wire m_axi_wready;
  wire [1:0] m_axi_bresp;
  wire m_axi_bvalid;
  wire m_axi_bready;
  wire [31:0] m_axi_araddr;
  wire [2:0] m_axi_arprot;
  wire m_axi_arvalid;
  wire m_axi_arready;
  wire [31:0] m_axi_rdata;
  wire [1:0] m_axi_rresp;
  wire m_axi_rvalid;
  wire m_axi_rready;

  jtag_axi_0 u_jtag_axi_0 (
      .aclk   (clk),
      .aresetn  (rst_n),
      .m_axi_awaddr (m_axi_awaddr[addr_width-1:0]),
      .m_axi_awprot (m_axi_awprot),
      .m_axi_awvalid (m_axi_awvalid),
      .m_axi_awready (m_axi_awready),
      .m_axi_wdata (m_axi_wdata[data_width-1:0]),
      .m_axi_wstrb (m_axi_wstrb),
      .m_axi_wvalid (m_axi_wvalid),
      .m_axi_wready (m_axi_wready),
      .m_axi_bresp (m_axi_bresp),
      .m_axi_bvalid (m_axi_bvalid),
      .m_axi_bready (m_axi_bready),
      .m_axi_araddr (m_axi_araddr[addr_width-1:0]),
      .m_axi_arprot (m_axi_arprot),
      .m_axi_arvalid (m_axi_arvalid),
      .m_axi_arready (m_axi_arready),
      .m_axi_rdata (m_axi_rdata[data_width-1:0]),
      .m_axi_rresp (m_axi_rresp),
      .m_axi_rvalid (m_axi_rvalid),
      .m_axi_rready (m_axi_rready)
  );

  axi2lcpu #(
      .data_width(data_width),
      .addr_width(addr_width)
  ) u_axi2lcpu (
      .resetl   (rst_n),
      .clk   (clk),
      .m_axi_awaddr (m_axi_awaddr),
      .m_axi_awvalid (m_axi_awvalid),
      .m_axi_awready (m_axi_awready),
      .m_axi_wdata (m_axi_wdata),
      .m_axi_wstrb (m_axi_wstrb),
      .m_axi_wvalid (m_axi_wvalid),
      .m_axi_wready (m_axi_wready),
      .m_axi_bresp (m_axi_bresp),
      .m_axi_bvalid (m_axi_bvalid),
      .m_axi_bready (m_axi_bready),
      .m_axi_araddr (m_axi_araddr),
      .m_axi_arvalid (m_axi_arvalid),
      .m_axi_arready (m_axi_arready),
      .m_axi_rdata (m_axi_rdata),
      .m_axi_rresp (m_axi_rresp),
      .m_axi_rvalid (m_axi_rvalid),
      .m_axi_rready (m_axi_rready),

      .lcpu_rh_wl  (lcpu_rh_wl),
      .lcpu_req   (lcpu_req),
      .lcpu_ack   (lcpu_ack),
      .lcpu_address (lcpu_address),
      .lcpu_wdata  (lcpu_wdata),
      .lcpu_rdata  (lcpu_rdata)
  );

endmodule


