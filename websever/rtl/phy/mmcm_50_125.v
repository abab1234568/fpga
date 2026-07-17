//****************************************Copyright 2026[c]************************//
// File name:        mmcm_50_125.v
// Author:           huaming.huang@link-real.com.cn
// Date:             2026-06-08
// Version Number:   1.0
// Abstract:         MMCME2_BASE: 50MHz 板载晶振 → 125MHz 系统主时钟
//                   VCO=1000MHz (M=20), CLKOUT0=125MHz (D=8)
//                   Xilinx 7 系列，用于 SGMII 系统逻辑时钟。
//
//  接口信号：
//   clk_50m   — 50MHz 输入 (板载 W19)
//   clk_125m  — 125MHz 输出 (BUFG 后)
//   locked    — PLL 锁定标志
//   rst_n     — 异步复位 (低有效)
//
// Modification history:
//   2026-06-08, v1.0, haitao.zhu, 初始版本
//
// *********************************end************************************** //

module mmcm_50_125 (
    input  wire clk_50m,      // 50MHz 板载晶振输入
    output wire clk_125m,     // 125MHz BUFG 输出 (系统主时钟)
    output wire clk_200m,     // 200MHz BUFG 输出 (IDELAYCTRL 参考时钟)
    output wire clk_125m_tx,  // 125MHz BUFG 输出 (RGMII TXC, 90°移相)
    output wire clk_50m_cpu,  // 50MHz BUFG 输出 (CPU/LCPU 时钟)
    output wire locked,       // MMCM 锁定: 1=已锁定
    input  wire rst_n         // 异步复位 (低有效)
);

  //========================================================================
  // 内部连线
  //========================================================================
  wire clk_fb;  // MMCM 反馈时钟
  wire clk_125m_unbuf;  // MMCM CLKOUT0 输出 (BUFG 前)
  wire clk_200m_unbuf;  // MMCM CLKOUT1 输出 (BUFG 前)
  wire clk_125m_tx_unbuf;  // MMCM CLKOUT2 输出 (BUFG 前)
  wire clk_50m_cpu_unbuf;  // MMCM CLKOUT3 输出 (BUFG 前)

  //========================================================================
  // MMCME2_BASE — 锁相环原语
  //
  // 参数计算:
  //   f_VCO = f_CLKIN × CLKFBOUT_MULT_F / DIVCLK_DIVIDE
  //         = 50MHz × 20 / 1 = 1000MHz
  //
  //   f_CLKOUT0 = f_VCO / CLKOUT0_DIVIDE_F
  //             = 1000MHz / 8 = 125MHz
  //
  //   f_CLKOUT1 = f_VCO / CLKOUT1_DIVIDE
  //             = 1000MHz / 5 = 200MHz (IDELAYCTRL 参考)
  //
  //   f_CLKOUT2 = f_VCO / CLKOUT2_DIVIDE_F
  //             = 1000MHz / 8 = 125MHz (90°移相 RGMII TXC)
  //
  //   f_CLKOUT3 = f_VCO / CLKOUT3_DIVIDE_F
  //             = 1000MHz / 20 = 50MHz (CPU/LCPU 时钟)
  //========================================================================
  MMCME2_BASE #(
      .BANDWIDTH         ("OPTIMIZED"),
      .CLKFBOUT_MULT_F   (20.0),
      .CLKFBOUT_PHASE    (0.0),
      .CLKIN1_PERIOD     (20.0),
      .CLKOUT0_DIVIDE_F  (8.0),
      .CLKOUT0_DUTY_CYCLE(0.5),
      .CLKOUT0_PHASE     (0.0),
      .CLKOUT1_DIVIDE    (5),
      .CLKOUT1_DUTY_CYCLE(0.5),
      .CLKOUT1_PHASE     (0.0),
      .CLKOUT2_DIVIDE    (8),
      .CLKOUT2_DUTY_CYCLE(0.5),
      .CLKOUT2_PHASE     (90.0),
      .CLKOUT3_DIVIDE    (20),
      .CLKOUT3_DUTY_CYCLE(0.5),
      .CLKOUT3_PHASE     (0.0),
      .DIVCLK_DIVIDE     (1),
      .REF_JITTER1       (0.010),
      .STARTUP_WAIT      ("FALSE")
  ) u_mmcm (
      .CLKIN1  (clk_50m),
      .CLKFBIN (clk_fb),
      .CLKFBOUT(clk_fb),
      .CLKOUT0 (clk_125m_unbuf),
      .CLKOUT1 (clk_200m_unbuf),
      .CLKOUT2 (clk_125m_tx_unbuf),
      .CLKOUT3 (clk_50m_cpu_unbuf),
      .LOCKED  (locked),
      .PWRDWN  (1'b0),
      .RST     (~rst_n)
  );

  BUFG u_bufg_125 (
      .I(clk_125m_unbuf),
      .O(clk_125m)
  );

  BUFG u_bufg_200 (
      .I(clk_200m_unbuf),
      .O(clk_200m)
  );

  BUFG u_bufg_125_tx (
      .I(clk_125m_tx_unbuf),
      .O(clk_125m_tx)
  );

  BUFG u_bufg_50_cpu (
      .I(clk_50m_cpu_unbuf),
      .O(clk_50m_cpu)
  );

endmodule
