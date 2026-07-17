//******************************************************************************
// File name:        rgmii_gmii_loopback_top.v
// Author:           huaming.huang@link-real.com.cn
// Date:             2026-07-15
// Version Number:   2.0
// Abstract:
//   RGMII → GMII + cpu_channel + LCPU JTAG 顶层
//
//   数据通路:
//     RGMII PHY → rgmii_gmii_bridge (DDR↔SDR)
//              → gmii2mac (CDC + 前导码 + CRC)
//              → cpu_channel (流式过滤 + CPU FIFO + CPU 注入 TX)
//              → gmii2mac (CRC + 前导码)
//              → rgmii_gmii_bridge (SDR→DDR) → RGMII PHY
//
//   cpu_channel: 收到帧通过过滤器后进 CPU 读 FIFO, TX 仅来自 CPU 写 FIFO
//
//   LCPU 寄存器映射 (JTAG):
//     0x00: STATUS   [7:0]=drop_cnt
//     0x04: PKT_LEN  [11:0]=包长度
//     0x08: RD_DATA  [7:0]=读数据
//     0x0C: CONTROL  [0]=rpkt_pop
//
//   时钟域:
//     gmii_rx_clk: RGMII RXC (gmii2mac CDC 写侧)
//     clk_125m:    MMCM 系统时钟 (gmii2mac + cpu_channel 数据面)
//     cpu_clk:     LCPU 时钟 (jtag + cpu_channel_reg + cpu_channel.cpu_rd)
//******************************************************************************
module rgmii_gmii_loopback_top #(
    parameter AW = 11,  // 地址位宽
    parameter DW = 8,   // 数据位宽
    parameter PW = 3    // 参数位宽
) (
    // RGMII
    output wire       rgmii_txc,
    output wire [3:0] rgmii_txd,
    output wire       rgmii_tx_ctl,
    input  wire       rgmii_rxc,
    input  wire [3:0] rgmii_rxd,
    input  wire       rgmii_rx_ctl,

    // 时钟与复位
    input wire clk_50m,
    input wire rst_n,

    // PHY 控制
    output wire phy_rst_n,

    // 状态
    output wire       mmcm_locked,
    output wire [1:0] led
);

  //============================================================================
  // MMCM 时钟
  //============================================================================
  wire clk_125m, clk_200m, clk_125m_tx, cpu_clk, mmcm_locked_i;

  mmcm_50_125 u_mmcm (
      .clk_50m(clk_50m),
      .rst_n(rst_n),
      .clk_125m(clk_125m),
      .clk_200m(clk_200m),
      .clk_125m_tx(clk_125m_tx),
      .clk_50m_cpu(cpu_clk),
      .locked(mmcm_locked_i)
  );

  assign mmcm_locked = mmcm_locked_i;
  wire        rst_n_int = rst_n & mmcm_locked_i;

  //============================================================================
  // PHY 复位 (~16ms 延时释放)
  //============================================================================
  reg  [20:0] phy_rst_cnt;
  reg         phy_rst_n_r;

  always @(posedge clk_125m or negedge rst_n_int)
    if (!rst_n_int) {phy_rst_cnt, phy_rst_n_r} <= 0;
    else if (!phy_rst_n_r) begin
      phy_rst_cnt <= phy_rst_cnt + 1;
      if (phy_rst_cnt == 21'h1FF_FFF) phy_rst_n_r <= 1'b1;
    end

  assign phy_rst_n = phy_rst_n_r;

  //============================================================================
  // RGMII ↔ GMII 信号
  //============================================================================
  wire gmii_rx_clk, gmii_rx_dv, gmii_rx_er, gmii_tx_en, gmii_tx_er;
  wire [7:0] gmii_rxd, gmii_txd;

  //============================================================================
  // gmii2mac ↔ cpu_channel 信号
  //============================================================================
  wire mac_rx_sop, mac_rx_en, mac_rx_eop, mac_rx_err;
  wire [7:0] mac_rx_data;

  wire cpu_tx_sop, cpu_tx_en, cpu_tx_eop, cpu_tx_err;
  wire [7:0] cpu_tx_data;

  //============================================================================
  // cpu_channel ↔ cpu_channel_reg 信号 (cpu_clk 域)
  //============================================================================
  wire cpu_rd_empty, cpu_rd_rpkt_pop, cpu_rd_rpkt_pop_ind;
  wire [  AW:0] cpu_rd_rpkt_len;
  wire [PW-1:0] cpu_rd_rpkt_para;
  wire cpu_rd_ren, cpu_rd_reop_pre;
  wire [AW-1:0] cpu_rd_raddr;
  wire [DW-1:0] cpu_rd_rdata;

  wire cpu_wr_full, cpu_wr_wen, cpu_wr_wen_ind;
  wire [AW-1:0] cpu_wr_waddr;
  wire [DW-1:0] cpu_wr_wdata;
  wire [  AW:0] cpu_wr_wpkt_len;
  wire cpu_wr_wpkt_push, cpu_wr_wpkt_push_ind;

  wire [7:0] pkt_drop_cnt;

  // cpu_channel_reg 32-bit → 截断
  wire [31:0] reg_rd_raddr_32, reg_wr_waddr_32, reg_wr_wdata_32, reg_wr_wpkt_len_32;
  assign cpu_rd_raddr = reg_rd_raddr_32[AW-1:0];
  assign cpu_wr_waddr = reg_wr_waddr_32[AW-1:0];
  assign cpu_wr_wdata = reg_wr_wdata_32[DW-1:0];
  assign cpu_wr_wpkt_len = reg_wr_wpkt_len_32[AW:0];

  //============================================================================
  // LCPU 总线
  //============================================================================
  wire lcpu_req, lcpu_rh_wl, lcpu_ack;
  wire [31:0] lcpu_address, lcpu_wdata, lcpu_rdata;

  //============================================================================
  // 1. RGMII ↔ GMII 桥
  //============================================================================
  rgmii_gmii_bridge u_bridge (
      .gmii_tx_clk(clk_125m_tx),
      .gmii_txd(gmii_txd),
      .gmii_tx_en(gmii_tx_en),
      .gmii_tx_er(gmii_tx_er),
      .gmii_rx_clk(gmii_rx_clk),
      .gmii_rxd(gmii_rxd),
      .gmii_rx_dv(gmii_rx_dv),
      .gmii_rx_er(gmii_rx_er),
      .rgmii_txc(rgmii_txc),
      .rgmii_txd(rgmii_txd),
      .rgmii_tx_ctl(rgmii_tx_ctl),
      .rgmii_rxc(rgmii_rxc),
      .rgmii_rxd(rgmii_rxd),
      .rgmii_rx_ctl(rgmii_rx_ctl),
      .idelay_refclk(clk_200m),
      .rst_n(rst_n_int)
  );

  //============================================================================
  // 2. gmii2mac: CDC + 前导码 + MAC
  //============================================================================
  gmii2mac u_gmii2mac (
      .clk(clk_125m),
      .reset_l(rst_n_int),
      .Eth_RXC(gmii_rx_clk),
      .Eth_RXDV(gmii_rx_dv),
      .Eth_RXER(gmii_rx_er),
      .Eth_RXD(gmii_rxd),
      .Eth_TXD(gmii_txd),
      .Eth_TXEN(gmii_tx_en),
      .Eth_TXER(gmii_tx_er),
      .mac_rx_sop(mac_rx_sop),
      .mac_rx_en(mac_rx_en),
      .mac_rx_data(mac_rx_data),
      .mac_rx_eop(mac_rx_eop),
      .mac_rx_err(mac_rx_err),
      .mac_tx_sop(cpu_tx_sop),
      .mac_tx_en(cpu_tx_en),
      .mac_tx_data(cpu_tx_data),
      .mac_tx_eop(cpu_tx_eop),
      .mac_tx_err(cpu_tx_err),
      .rx_afifo_full_cnt(),
      .rx_afifo_empty_cnt(),
      .rx_data_err_line(),
      .rx_correct_pkt_cnt(),
      .rx_crc_err_pkt_cnt(),
      .tx_correct_pkt_cnt(),
      .tx_error_pkt_cnt()
  );

  //============================================================================
  // 3. cpu_channel: 流式过滤 + CPU 读 FIFO + CPU 注入 TX
  //============================================================================
  cpu_channel #(
      .ADDR_WIDTH(AW),
      .DATA_WIDTH(DW),
      .PARA_WIDTH(PW)
  ) u_cpu_channel (
      .clk(clk_125m),
      .reset_l(rst_n_int),
      .cpu_clk(cpu_clk),
      .mac_rx_sop(mac_rx_sop),
      .mac_rx_en(mac_rx_en),
      .mac_rx_data(mac_rx_data),
      .mac_rx_eop(mac_rx_eop),
      .mac_tx_sop(cpu_tx_sop),
      .mac_tx_en(cpu_tx_en),
      .mac_tx_data(cpu_tx_data),
      .mac_tx_eop(cpu_tx_eop),
      .mac_tx_err(cpu_tx_err),
      .recv_pkt_drop_cnt(pkt_drop_cnt),
      .cpu_rd_empty(cpu_rd_empty),
      .cpu_rd_rpkt_pop(cpu_rd_rpkt_pop),
      .cpu_rd_rpkt_len(cpu_rd_rpkt_len),
      .cpu_rd_rpkt_para(cpu_rd_rpkt_para),
      .cpu_rd_ren(cpu_rd_ren),
      .cpu_rd_raddr(cpu_rd_raddr),
      .cpu_rd_rdata(cpu_rd_rdata),
      .cpu_rd_reop_pre(cpu_rd_reop_pre),
      .cpu_wr_full(cpu_wr_full),
      .cpu_wr_wen(cpu_wr_wen),
      .cpu_wr_waddr(cpu_wr_waddr),
      .cpu_wr_wdata(cpu_wr_wdata),
      .cpu_wr_wpkt_push(cpu_wr_wpkt_push),
      .cpu_wr_wpkt_len(cpu_wr_wpkt_len),
      .cpu_wr_wpkt_para({PW{1'b0}})
  );

  //============================================================================
  // 4. JTAG → LCPU bus
  //============================================================================
  jtag_cpu_amd_core #(
      .data_width(32),
      .addr_width(32)
  ) u_jtag_cpu (
      .clk(cpu_clk),
      .rst_n(rst_n),
      .lcpu_rh_wl(lcpu_rh_wl),
      .lcpu_req(lcpu_req),
      .lcpu_ack(lcpu_ack),
      .lcpu_address(lcpu_address),
      .lcpu_wdata(lcpu_wdata),
      .lcpu_rdata(lcpu_rdata)
  );

  //============================================================================
  // 5. LCPU bus → 寄存器桥
  //============================================================================
  cpu_channel_reg u_cpu_channel_reg (
      .clk(cpu_clk),
      .rst_n(rst_n),
      .req(lcpu_req),
      .rhwl(lcpu_rh_wl),
      .wdata(lcpu_wdata),
      .address(lcpu_address[15:0]),
      .rdata(lcpu_rdata),
      .ack(lcpu_ack),
      .cpu_rd_empty(cpu_rd_empty),
      .cpu_rd_rpkt_pop(cpu_rd_rpkt_pop),
      .cpu_rd_rpkt_pop_ind(cpu_rd_rpkt_pop_ind),
      .cpu_rd_rpkt_len({20'd0, cpu_rd_rpkt_len}),
      .cpu_rd_ren(cpu_rd_ren),
      .cpu_rd_raddr(reg_rd_raddr_32),
      .cpu_rd_rdata({24'd0, cpu_rd_rdata}),
      .cpu_wr_full(cpu_wr_full),
      .cpu_wr_wen(cpu_wr_wen),
      .cpu_wr_wen_ind(cpu_wr_wen_ind),
      .cpu_wr_waddr(reg_wr_waddr_32),
      .cpu_wr_wdata(reg_wr_wdata_32),
      .cpu_wr_wpkt_len(reg_wr_wpkt_len_32),
      .cpu_wr_wpkt_push(cpu_wr_wpkt_push),
      .cpu_wr_wpkt_push_ind(cpu_wr_wpkt_push_ind)
  );

  //============================================================================
  // 6. ILA — RGMII进入 (GMII格式: 8bit SDR, gmii_rx_clk域)
  //    ⚠️ ILA时钟用clk_125m, 跨时钟域采样仅参考
  //============================================================================
  ila_0 u_ila_0 (
      .clk    (clk_125m),
      .probe0 ({gmii_rx_dv, gmii_rx_er, gmii_rxd})
  );

  //============================================================================
  // 7. 状态 LED
  //============================================================================
  assign led[0] = mmcm_locked_i;
  assign led[1] = ~cpu_rd_empty;

endmodule
