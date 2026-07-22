//****************************************Copyright 2026[c]************************//
// File name:        gmii_to_rgmii.v
// Author:           huaming.huang@link-real.com.cn
// Date:             2026-06-05
// Version Number:   1.0
// Abstract:         GMII → RGMII 发送方向转换 (MAC → PHY)
//                   GMII 8bit SDR @125MHz → RGMII 4bit DDR @125MHz
//                   Xilinx 7 系列，使用 ODDR 硬核原语
//
// Modification history:[time, version, author, abstract]
//
// *********************************end************************************** //

module gmii_to_rgmii (
    // GMII TX (from MAC)
    input  wire       gmii_tx_clk,   // 125MHz clock from MAC
    input  wire [7:0] gmii_txd,      // TX data (SDR)
    input  wire       gmii_tx_en,    // TX enable
    input  wire       gmii_tx_er,    // TX error
    // RGMII TX (to PHY)
    output wire       rgmii_txc,     // TX clock to PHY (125MHz)
    output wire [3:0] rgmii_txd,     // TX data (DDR)
    output wire       rgmii_tx_ctl,  // TX control (DDR)
    // Control
    input  wire       rst_n          // Async reset, active low
);

  // ============================================================
  // RGMII TX 时序:
  //   TXC rising  → TXD[3:0] = gmii_txd[3:0],  TX_CTL = gmii_tx_en
  //   TXC falling → TXD[3:0] = gmii_txd[7:4],  TX_CTL = gmii_tx_en ^ gmii_tx_er
  // ============================================================

  // TXC: 125MHz clock via ODDR (D1=1, D2=0 → toggles at 125MHz)
  ODDR #(
      .DDR_CLK_EDGE("OPPOSITE_EDGE"),
      .INIT(1'b0),
      .SRTYPE("ASYNC")
  ) u_txc_oddr (
      .Q (rgmii_txc),
      .C (gmii_tx_clk),
      .CE(1'b1),
      .D1(1'b1),
      .D2(1'b0),
      .R (~rst_n),
      .S (1'b0)
  );

  // TX_CTL: D1 = TX_EN, D2 = TX_EN xor TX_ER
  wire tx_ctl_d1;
  wire tx_ctl_d2;
  assign tx_ctl_d1 = gmii_tx_en;
  assign tx_ctl_d2 = gmii_tx_en ^ gmii_tx_er;

  ODDR #(
      .DDR_CLK_EDGE("OPPOSITE_EDGE"),
      .INIT(1'b0),
      .SRTYPE("ASYNC")
  ) u_tx_ctl_oddr (
      .Q (rgmii_tx_ctl),
      .C (gmii_tx_clk),
      .CE(1'b1),
      .D1(tx_ctl_d1),
      .D2(tx_ctl_d2),
      .R (~rst_n),
      .S (1'b0)
  );

  // TXD[3:0]: D1 = gmii_txd[3:0], D2 = gmii_txd[7:4]
  genvar i;
  generate
    for (i = 0; i < 4; i = i + 1) begin : gen_txd_oddr
      ODDR #(
          .DDR_CLK_EDGE("OPPOSITE_EDGE"),
          .INIT(1'b0),
          .SRTYPE("ASYNC")
      ) u_txd_oddr (
          .Q (rgmii_txd[i]),
          .C (gmii_tx_clk),
          .CE(1'b1),
          .D1(gmii_txd[i]),
          .D2(gmii_txd[i+4]),
          .R (~rst_n),
          .S (1'b0)
      );
    end
  endgenerate

endmodule
