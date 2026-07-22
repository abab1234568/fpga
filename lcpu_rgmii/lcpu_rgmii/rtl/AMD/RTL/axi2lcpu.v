//******************************************************************************
// File name:        axi2lcpu.v
// Abstract:         AXI4-Lite Slave → LCPU 寄存器总线 桥接
//                   将 jtag_axi_0 的 AXI 读写转换为 lcpu_req/rh_wl/address/wdata/rdata/ack
//******************************************************************************
module axi2lcpu #(
    parameter data_width = 32,
    parameter addr_width = 32
) (
    input resetl,
    input clk,

    // ---- AXI4-Lite Write Address ----
    input  [addr_width-1:0] m_axi_awaddr,
    input                   m_axi_awvalid,
    output                  m_axi_awready,

    // ---- AXI4-Lite Write Data ----
    input  [data_width-1:0] m_axi_wdata,
    input  [           3:0] m_axi_wstrb,
    input                   m_axi_wvalid,
    output                  m_axi_wready,

    // ---- AXI4-Lite Write Response ----
    output [1:0] m_axi_bresp,
    output       m_axi_bvalid,
    input        m_axi_bready,

    // ---- AXI4-Lite Read Address ----
    input  [addr_width-1:0] m_axi_araddr,
    input                   m_axi_arvalid,
    output                  m_axi_arready,

    // ---- AXI4-Lite Read Data ----
    output [data_width-1:0] m_axi_rdata,
    output [           1:0] m_axi_rresp,
    output                  m_axi_rvalid,
    input                   m_axi_rready,

    // ---- LCPU 总线 ----
    output                  lcpu_rh_wl,
    output                  lcpu_req,
    input                   lcpu_ack,
    output [addr_width-1:0] lcpu_address,
    output [data_width-1:0] lcpu_wdata,
    input  [data_width-1:0] lcpu_rdata
);

  //============================================================================
  // 状态机
  //============================================================================
  localparam S_IDLE = 2'd0;
  localparam S_WAIT = 2'd1;
  localparam S_DONE = 2'd2;

  reg [1:0] state, next_state;

  reg                   is_write;
  reg  [addr_width-1:0] addr_r;
  reg  [data_width-1:0] wdata_r;
  reg  [data_width-1:0] rdata_r;

  // AXI ready 信号
  wire                  aw_hs = m_axi_awvalid && m_axi_awready;
  wire                  w_hs = m_axi_wvalid && m_axi_wready;
  wire                  ar_hs = m_axi_arvalid && m_axi_arready;
  wire                  r_hs = m_axi_rvalid && m_axi_rready;

  // 接受写地址/数据
  assign m_axi_awready = (state == S_IDLE) && m_axi_awvalid;
  assign m_axi_wready  = (state == S_IDLE) && m_axi_wvalid;

  // 接受读地址
  assign m_axi_arready = (state == S_IDLE) && m_axi_arvalid && !m_axi_awvalid;

  // 写响应
  reg [1:0] bresp_r;
  reg       bvalid_r;
  assign m_axi_bresp  = bresp_r;
  assign m_axi_bvalid = bvalid_r;

  // 读数据响应
  reg [data_width-1:0] rdata_out;
  reg [           1:0] rresp_out;
  reg                  rvalid_r;
  assign m_axi_rdata  = rdata_out;
  assign m_axi_rresp  = rresp_out;
  assign m_axi_rvalid = rvalid_r;

  //============================================================================
  // LCPU 接口
  //============================================================================
  reg lcpu_req_r;
  assign lcpu_req     = lcpu_req_r;
  assign lcpu_rh_wl   = is_write ? 1'b0 : 1'b1;  // 0=write, 1=read
  assign lcpu_address = addr_r;
  assign lcpu_wdata   = wdata_r;

  //============================================================================
  // 主状态机
  //============================================================================
  always @(posedge clk or negedge resetl)
    if (!resetl) state <= S_IDLE;
    else state <= next_state;

  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (aw_hs || ar_hs) next_state = S_WAIT;
      end
      S_WAIT: begin
        if (lcpu_ack) next_state = S_DONE;
      end
      S_DONE: begin
        if ((is_write && m_axi_bready) || (!is_write && r_hs)) next_state = S_IDLE;
      end
    endcase
  end

  // 数据锁存
  always @(posedge clk or negedge resetl)
    if (!resetl) begin
      is_write <= 1'b0;
      addr_r   <= 0;
      wdata_r  <= 0;
    end else if (state == S_IDLE) begin
      if (aw_hs) begin
        is_write <= 1'b1;
        addr_r   <= m_axi_awaddr;
        wdata_r  <= m_axi_wdata;
      end else if (ar_hs) begin
        is_write <= 1'b0;
        addr_r   <= m_axi_araddr;
      end
    end

  // LCPU 请求
  always @(posedge clk or negedge resetl)
    if (!resetl) lcpu_req_r <= 1'b0;
    else lcpu_req_r <= (state == S_IDLE) && (aw_hs || ar_hs);

  // 写响应
  always @(posedge clk or negedge resetl)
    if (!resetl) begin
      bvalid_r <= 1'b0;
      bresp_r  <= 2'b00;
    end else if (state == S_DONE && is_write && !bvalid_r) begin
      bvalid_r <= 1'b1;
      bresp_r  <= 2'b00;  // OKAY
    end else if (m_axi_bready && bvalid_r) begin
      bvalid_r <= 1'b0;
    end

  // 读数据
  always @(posedge clk or negedge resetl)
    if (!resetl) begin
      rdata_out <= 0;
    end else if (lcpu_ack && !is_write) begin
      rdata_out <= lcpu_rdata;
    end

  // 读响应
  always @(posedge clk or negedge resetl)
    if (!resetl) begin
      rvalid_r  <= 1'b0;
      rresp_out <= 2'b00;
    end else if (state == S_DONE && !is_write && !r_hs) begin
      rvalid_r <= 1'b1;
    end else if (r_hs) begin
      rvalid_r <= 1'b0;
    end

endmodule
