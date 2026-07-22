//****************************************Copyright 2026[c]************************//
// File name:        rgmii_gmii_bridge.v
// Author:           huaming.huang@link-real.com.cn
// Date:             2026-06-05
// Version Number:   2.0
// Abstract:         RGMII ↔ GMII 双向桥接顶层模块
//                   实例化 gmii_to_rgmii (TX) + rgmii_to_gmii (RX)
//                   GMII 侧 (8bit SDR @125MHz) → 内部 MAC / 用户逻辑
//                   RGMII 侧 (4bit DDR @125MHz) → 外部 PHY 芯片
//                   Xilinx 7 系列
//
// Sub-modules:
//   gmii_to_rgmii.v  — GMII → RGMII (TX path)
//   rgmii_to_gmii.v  — RGMII → GMII (RX path)
//
// Modification history:
//   2026-06-04, v1.0, huaming.huang, 初始版本（单文件全功能）
//   2026-06-05, v2.0, huaming.huang, 拆分为子模块+顶层
//
// *********************************end************************************** //

module rgmii_gmii_bridge (
    // ============================================================
    // GMII TX — from MAC to PHY (SDR, 8bit @125MHz)
    // ============================================================
    input wire       gmii_tx_clk,  // 125MHz TX clock (from MAC)
    input wire [7:0] gmii_txd,     // TX data
    input wire       gmii_tx_en,   // TX enable
    input wire       gmii_tx_er,   // TX error

    // ============================================================
    // GMII RX — from PHY to MAC (SDR, 8bit @125MHz)
    // ============================================================
    output wire       gmii_rx_clk,  // 125MHz RX clock (to MAC)
    output wire [7:0] gmii_rxd,     // RX data
    output wire       gmii_rx_dv,   // RX data valid
    output wire       gmii_rx_er,   // RX error

    // ============================================================
    // RGMII — to/from external PHY (DDR, 4bit @125MHz)
    // ============================================================
    output wire       rgmii_txc,     // TX clock to PHY
    output wire [3:0] rgmii_txd,     // TX data (DDR)
    output wire       rgmii_tx_ctl,  // TX control (DDR)
    input  wire       rgmii_rxc,     // RX clock from PHY
    input  wire [3:0] rgmii_rxd,     // RX data (DDR)
    input  wire       rgmii_rx_ctl,  // RX control (DDR)

    // ============================================================
    // Control
    // ============================================================
    input wire idelay_refclk,  // 200MHz IDELAY 参考时钟
    input wire rst_n           // Async reset, active low
);

  // ============================================================
  // TX Path: GMII → RGMII
  // ============================================================
  gmii_to_rgmii u_tx (
      .gmii_tx_clk (gmii_tx_clk),
      .gmii_txd    (gmii_txd),
      .gmii_tx_en  (gmii_tx_en),
      .gmii_tx_er  (gmii_tx_er),
      .rgmii_txc   (rgmii_txc),
      .rgmii_txd   (rgmii_txd),
      .rgmii_tx_ctl(rgmii_tx_ctl),
      .rst_n       (rst_n)
  );

  // ============================================================
  // RX Path: RGMII → GMII (含 IDELAY)
  // ============================================================
  rgmii_to_gmii u_rx (
      .rgmii_rxc    (rgmii_rxc),
      .rgmii_rxd    (rgmii_rxd),
      .rgmii_rx_ctl (rgmii_rx_ctl),
      .gmii_rx_clk  (gmii_rx_clk),
      .gmii_rxd     (gmii_rxd),
      .gmii_rx_dv   (gmii_rx_dv),
      .gmii_rx_er   (gmii_rx_er),
      .idelay_refclk(idelay_refclk),
      .rst_n        (rst_n)
  );

endmodule
