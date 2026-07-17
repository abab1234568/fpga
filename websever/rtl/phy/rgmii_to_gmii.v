//****************************************Copyright 2026[c]************************//
// File name:        rgmii_to_gmii.v
// Author:           huaming.huang@link-real.com.cn
// Date:             2026-06-05
// Version Number:   1.2
// Abstract:         RGMII → GMII 接收方向转换 (PHY → MAC)
//                   RGMII 4bit DDR @125MHz → GMII 8bit SDR @125MHz
//                   Xilinx 7 系列，使用 IDELAYE2 + IDDR/BUFG 硬核原语
//                   解决 RGMII RX 时钟数据对齐导致的保持时间违例
//
//   IDELAY: ~1.5ns 固定延迟补偿, 将数据移到时钟窗口中央
//
// Modification history:[time, version, author, abstract]
//   2026-06-11, v1.1, huaming.huang, 添加嵌入式 Testbench
//   2026-06-12, v1.2, huaming.huang, IDELAYE2 修复 RGMII RX hold 违例
//
// *********************************end************************************** //

module rgmii_to_gmii (
    // RGMII RX (from PHY)
    input  wire       rgmii_rxc,      // RX clock from PHY (125MHz)
    input  wire [3:0] rgmii_rxd,      // RX data (DDR)
    input  wire       rgmii_rx_ctl,   // RX control (DDR)
    // GMII RX (to MAC)
    output wire       gmii_rx_clk,    // RX clock to MAC (125MHz)
    output wire [7:0] gmii_rxd,       // RX data (SDR)
    output wire       gmii_rx_dv,     // RX data valid
    output wire       gmii_rx_er,     // RX error
    // IDELAY 参考时钟 (200MHz)
    input  wire       idelay_refclk,  // 200MHz IDELAYCTRL 参考时钟
    // Control
    input  wire       rst_n           // Async reset, active low
);

  // ============================================================
  // IDELAYCTRL: 必须例化, 否则 IDELAYE2 不工作
  // ============================================================
  (* IODELAY_GROUP = "rgmii_rx_group" *)
  IDELAYCTRL u_idelayctrl (
      .REFCLK(idelay_refclk),  // 200MHz
      .RST   (~rst_n),
      .RDY   ()                // 可忽略
  );

  // ============================================================
  // RXC → BUFG → global clock
  // ============================================================
  wire rgmii_rxc_bufg;
  BUFG u_rxc_bufg (
      .I(rgmii_rxc),
      .O(rgmii_rxc_bufg)
  );
  assign gmii_rx_clk = rgmii_rxc_bufg;

  // ============================================================
  // IDELAYE2: RXD[3:0] + RX_CTL 各延迟 ~1.5ns (20 tap × 78ps)
  //   将数据边沿移到时钟采样窗口中央, 消除 hold 违例
  // ============================================================
  wire [3:0] rxd_delayed;
  wire       rx_ctl_delayed;

  genvar i;
  generate
    for (i = 0; i < 4; i = i + 1) begin : gen_rxd_idelay
      (* IODELAY_GROUP = "rgmii_rx_group" *)
      IDELAYE2 #(
          .IDELAY_TYPE          ("FIXED"),
          .IDELAY_VALUE         (20),         // 20 × 78ps ≈ 1.56ns
          .DELAY_SRC            ("IDATAIN"),
          .HIGH_PERFORMANCE_MODE("TRUE"),
          .SIGNAL_PATTERN       ("DATA"),
          .REFCLK_FREQUENCY     (200.0)
      ) u_rxd_idelay (
          .DATAOUT    (rxd_delayed[i]),
          .DATAIN     (1'b0),
          .C          (1'b0),
          .CE         (1'b0),
          .INC        (1'b0),
          .IDATAIN    (rgmii_rxd[i]),
          .CNTVALUEIN (5'd0),
          .CNTVALUEOUT(),
          .LD         (1'b0),
          .LDPIPEEN   (1'b0),
          .REGRST     (1'b0),
          .CINVCTRL   (1'b0)
      );
    end
  endgenerate

  (* IODELAY_GROUP = "rgmii_rx_group" *)
  IDELAYE2 #(
      .IDELAY_TYPE          ("FIXED"),
      .IDELAY_VALUE         (20),
      .DELAY_SRC            ("IDATAIN"),
      .HIGH_PERFORMANCE_MODE("TRUE"),
      .SIGNAL_PATTERN       ("DATA"),
      .REFCLK_FREQUENCY     (200.0)
  ) u_rx_ctl_idelay (
      .DATAOUT    (rx_ctl_delayed),
      .DATAIN     (1'b0),
      .C          (1'b0),
      .CE         (1'b0),
      .INC        (1'b0),
      .IDATAIN    (rgmii_rx_ctl),
      .CNTVALUEIN (5'd0),
      .CNTVALUEOUT(),
      .LD         (1'b0),
      .LDPIPEEN   (1'b0),
      .REGRST     (1'b0),
      .CINVCTRL   (1'b0)
  );

  // ============================================================
  // RGMII RX 时序 (PHY 行为):
  //   RXC rising  → RXD[3:0] = lower nibble,  RX_CTL = DV
  //   RXC falling → RXD[3:0] = upper nibble,  RX_CTL = DV ^ ER
  //
  // SAME_EDGE_PIPELINED IDDR (Xilinx UG471):
  //   Q1 = D at posedge of C → lower nibble (data[3:0])
  //   Q2 = D at negedge of C → upper nibble (data[7:4])
  //   Both Q1 and Q2 are presented simultaneously at the next posedge.
  //
  //   IDELAY 将数据延迟 ~1.56ns 后, RXC posedge/negedge 采样点落在
  //   数据眼图中央, Q1/Q2 的对应关系不变:
  //   因此: gmii_rxd[3:0] = Q1 (posedge → lower), gmii_rxd[7:4] = Q2 (negedge → upper)
  //
  //   RX_CTL: Q1(posedge) = DV, Q2(negedge) = DV ^ ER
  //   因此: gmii_rx_dv = Q1, gmii_rx_er = Q1 ^ Q2
  // ============================================================

  // RXD[3:0] IDDR (延迟后的数据)
  wire [3:0] rxd_q1;  // posedge → lower nibble (data[3:0])
  wire [3:0] rxd_q2;  // negedge → upper nibble (data[7:4])

  generate
    for (i = 0; i < 4; i = i + 1) begin : gen_rxd_iddr
      IDDR #(
          .DDR_CLK_EDGE("SAME_EDGE_PIPELINED"),
          .INIT_Q1(1'b0),
          .INIT_Q2(1'b0),
          .SRTYPE("ASYNC")
      ) u_rxd_iddr (
          .Q1(rxd_q1[i]),
          .Q2(rxd_q2[i]),
          .C (rgmii_rxc_bufg),
          .CE(1'b1),
          .D (rxd_delayed[i]),
          .R (~rst_n),
          .S (1'b0)
      );
    end
  endgenerate

  // RX_CTL IDDR (延迟后的信号)
  wire rx_ctl_q1;  // posedge → DV
  wire rx_ctl_q2;  // negedge → DV ^ ER

  IDDR #(
      .DDR_CLK_EDGE("SAME_EDGE_PIPELINED"),
      .INIT_Q1(1'b0),
      .INIT_Q2(1'b0),
      .SRTYPE("ASYNC")
  ) u_rx_ctl_iddr (
      .Q1(rx_ctl_q1),
      .Q2(rx_ctl_q2),
      .C (rgmii_rxc_bufg),
      .CE(1'b1),
      .D (rx_ctl_delayed),
      .R (~rst_n),
      .S (1'b0)
  );

  // Reconstruct GMII RX
  assign gmii_rxd[3:0] = rxd_q1;
  assign gmii_rxd[7:4] = rxd_q2;
  assign gmii_rx_dv    = rx_ctl_q1;
  assign gmii_rx_er    = rx_ctl_q1 ^ rx_ctl_q2;

endmodule
