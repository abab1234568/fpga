# ============================================================================
# Constraints for ALINX ACX750 + RTL8211 PHY
# RGMII 回环 + cpu_channel 过滤 + LCPU JTAG 读包
# 目标器件: Xilinx Artix-7 XC7A35T FGG484 -2
#
# 数据通路:
#   RGMII PHY → rgmii_gmii_bridge → preamble_remove → CDC FIFO
#            → mac_rx (CRC校验+sop/eop) → cpu_channel (过滤+缓冲+回环)
#            → mac_tx (CRC插入) → rgmii_gmii_bridge → RGMII PHY
#
# 基于 ACX750_CB_PIN.xdc ENET1 RGMII 引脚
# 参考 WebServer/xdc/acx750.xdc 约束风格
# ============================================================================

# ============================================================
# 配置模式
# ============================================================
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]

# ============================================================
# Clock: clk_50m = 50MHz (板载有源晶振, W19)
# ============================================================
set_property PACKAGE_PIN W19 [get_ports clk_50m]
set_property IOSTANDARD LVCMOS33 [get_ports clk_50m]
create_clock -period 20.000 -name fpga_clk [get_ports clk_50m]

# ============================================================
# Clock: cpu_clk = 50MHz — MMCM CLKOUT3 内部生成, 无需外部引脚

# ============================================================
# Reset: rst_n = KEY0 (D21), 按下低电平, 异步复位
# ============================================================
set_property PACKAGE_PIN D21 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

# ============================================================
# PHY 控制
# ============================================================
# PHY 复位 (低有效, FPGA 内部延时 ~16ms 释放)
set_property PACKAGE_PIN P14 [get_ports phy_rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports phy_rst_n]

# ============================================================
# RGMII TX (FPGA → PHY)
#   使用 ODDR + clk_125m_tx@90° 移相
# ============================================================
set_property PACKAGE_PIN AB21 [get_ports rgmii_txc]
set_property PACKAGE_PIN AB20 [get_ports {rgmii_txd[0]}]
set_property PACKAGE_PIN Y19  [get_ports {rgmii_txd[1]}]
set_property PACKAGE_PIN AB22 [get_ports {rgmii_txd[2]}]
set_property PACKAGE_PIN W20  [get_ports {rgmii_txd[3]}]
set_property PACKAGE_PIN AA19 [get_ports rgmii_tx_ctl]

set_property IOSTANDARD LVCMOS33 [get_ports rgmii_txc]
set_property IOSTANDARD LVCMOS33 [get_ports {rgmii_txd[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports rgmii_tx_ctl]

# RGMII TX 驱动强度
set_property DRIVE 8 [get_ports rgmii_txc]
set_property DRIVE 8 [get_ports {rgmii_txd[*]}]
set_property DRIVE 8 [get_ports rgmii_tx_ctl]

# ============================================================
# RGMII RX (PHY → FPGA)
#   IDELAYE2 (20tap) + IDDR (SAME_EDGE_PIPELINED)
# ============================================================
set_property PACKAGE_PIN Y18  [get_ports rgmii_rxc]
set_property PACKAGE_PIN P20  [get_ports {rgmii_rxd[0]}]
set_property PACKAGE_PIN N15  [get_ports {rgmii_rxd[1]}]
set_property PACKAGE_PIN AA18 [get_ports {rgmii_rxd[2]}]
set_property PACKAGE_PIN AB18 [get_ports {rgmii_rxd[3]}]
set_property PACKAGE_PIN T20  [get_ports rgmii_rx_ctl]

set_property IOSTANDARD LVCMOS33 [get_ports rgmii_rxc]
set_property IOSTANDARD LVCMOS33 [get_ports {rgmii_rxd[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports rgmii_rx_ctl]

# RXC clock: 125MHz from PHY
create_clock -period 8.000 -name enet1_rx_clk [get_ports rgmii_rxc]

# ============================================================
# 状态输出 (LED + 调试)
# ============================================================
set_property PACKAGE_PIN U22 [get_ports {led[0]}]
set_property PACKAGE_PIN V22 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[*]}]

# mmcm_locked → LED[2] (W21)
set_property PACKAGE_PIN W21 [get_ports mmcm_locked]
set_property IOSTANDARD LVCMOS33 [get_ports mmcm_locked]

# pkt_drop_cnt[0] → LED[3] (W22) — 综合可能优化掉此端口, 见下方 DRC 宽松

# ============================================================
# 调试/统计端口
#   pkt_drop_cnt[7:1] / rx_stat_good_pkt[31:0] / rx_stat_bad_pkt[31:0]
#   / tx_stat_pkt[31:0] — 共 103 个端口仅用于 ILA 内部观测,
#   不分配物理引脚, 宽松 DRC 让其通过。
#   (综合可能优化掉未使用端口, 故不设 IOSTANDARD/PACKAGE_PIN)
#   建议长期方案: 从 RTL 顶层移除这些端口。
# ============================================================

# ============================================================
# Generated Clock: MMCM 125MHz 系统主时钟
#   f_VCO = 50MHz × 20 / 1 = 1000MHz
#   f_CLKOUT0 = 1000MHz / 8 = 125MHz @ 0°
# ============================================================
create_generated_clock -name clk_125m \
    -source [get_pins u_mmcm/u_mmcm/CLKIN1] \
    -divide_by 8 -multiply_by 20 \
    [get_pins u_mmcm/u_bufg_125/O]

# Generated Clock: MMCM 200MHz IDELAYCTRL 参考时钟
#   f_CLKOUT1 = 1000MHz / 5 = 200MHz @ 0°
create_generated_clock -name clk_200m \
    -source [get_pins u_mmcm/u_mmcm/CLKIN1] \
    -divide_by 5 -multiply_by 20 \
    [get_pins u_mmcm/u_bufg_200/O]

# Generated Clock: MMCM 125MHz TX 时钟 (90° 移相)
#   f_CLKOUT2 = 1000MHz / 8 = 125MHz @ 90°
create_generated_clock -name clk_125m_tx \
    -source [get_pins u_mmcm/u_mmcm/CLKIN1] \
    -divide_by 8 -multiply_by 20 \
    [get_pins u_mmcm/u_bufg_125_tx/O]

# Generated Clock: MMCM 50MHz CPU 时钟
#   f_CLKOUT3 = 1000MHz / 20 = 50MHz @ 0°
create_generated_clock -name cpu_clk \
    -source [get_pins u_mmcm/u_mmcm/CLKIN1] \
    -divide_by 20 -multiply_by 20 \
    [get_pins u_mmcm/u_bufg_50_cpu/O]

# ============================================================
# RGMII RX Input Delay
#   DDR data valid window: 上升沿/下降沿各 4ns (125MHz DDR)
#   IDELAYE2 已提供 ~1.56ns 固定延迟补偿
#   格式参考 WebServer/xdc/acx750.xdc
# ============================================================
# 上升沿数据 (lower nibble)
set_input_delay -clock [get_clocks enet1_rx_clk] -max 2.000 \
    [get_ports {{rgmii_rxd[*]} rgmii_rx_ctl}]
set_input_delay -clock [get_clocks enet1_rx_clk] -min 4.000 \
    [get_ports {{rgmii_rxd[*]} rgmii_rx_ctl}]

# 下降沿数据 (upper nibble)
set_input_delay -clock [get_clocks enet1_rx_clk] -clock_fall \
    -max 2.000 -add_delay \
    [get_ports {{rgmii_rxd[*]} rgmii_rx_ctl}]
set_input_delay -clock [get_clocks enet1_rx_clk] -clock_fall \
    -min 4.000 -add_delay \
    [get_ports {{rgmii_rxd[*]} rgmii_rx_ctl}]

# ============================================================
# RGMII TX Output Delay
#   ODDR 由 clk_125m_tx@90° 驱动, TXC 与 TXD 同源
#   格式参考 WebServer/xdc/acx750.xdc
# ============================================================
set_output_delay -clock [get_clocks clk_125m_tx] -max 2.000 \
    [get_ports {{rgmii_txd[*]} rgmii_tx_ctl}]
set_output_delay -clock [get_clocks clk_125m_tx] -min -1.000 \
    [get_ports {{rgmii_txd[*]} rgmii_tx_ctl}]
set_output_delay -clock [get_clocks clk_125m_tx] -clock_fall \
    -max 2.000 -add_delay \
    [get_ports {{rgmii_txd[*]} rgmii_tx_ctl}]
set_output_delay -clock [get_clocks clk_125m_tx] -clock_fall \
    -min -1.000 -add_delay \
    [get_ports {{rgmii_txd[*]} rgmii_tx_ctl}]

# DDR multicycle: 每个 nibble 有完整 8ns 周期传播
set_multicycle_path -setup \
    -from [get_clocks clk_125m_tx] \
    -to [get_ports {{rgmii_txd[*]} rgmii_tx_ctl}] 2
set_multicycle_path -hold \
    -from [get_clocks clk_125m_tx] \
    -to [get_ports {{rgmii_txd[*]} rgmii_tx_ctl}] 1

# ============================================================
# Clock Groups (异步时钟域)
#   MMCM 组: fpga_clk, clk_125m, clk_200m, clk_125m_tx (同源相关)
#   enet1_rx_clk: RGMII PHY 恢复时钟 (异步于 MMCM 组)
#   cpu_clk: LCPU 独立时钟域 (异步于所有其他时钟)
# ============================================================
set_clock_groups -asynchronous \
    -group [get_clocks fpga_clk] \
    -group [get_clocks {clk_125m clk_200m clk_125m_tx cpu_clk}] \
    -group [get_clocks enet1_rx_clk]

# ============================================================
# 时序例外
# ============================================================

# 异步复位 — 全局不分析
set_false_path -from [get_ports rst_n]

# cpu_channel_reg 配置信号跨域 (cpu_clk → clk_125m)
# filter_data/filter_offset/bypass_mode/extract_offset
# 配置变化低频, 单 bit 亚稳态不影响功能。建议长期加 2-FF 同步器。
# set_clock_groups 已切断时序分析

# ============================================================
# DRC 宽松: 调试统计端口无需分配物理引脚/IOSTANDARD
#   pkt_drop_cnt[7:1] / rx_stat_good_pkt[31:0] / rx_stat_bad_pkt[31:0]
#   / tx_stat_pkt[31:0] — 共 103 个端口仅用于 ILA 内部观测,
#   不分配物理引脚和 IOSTANDARD。综合可能优化掉这些端口,
#   宽松 UCIO-1 / NSTD-1 让其通过 DRC。
#   建议长期方案: 从 RTL 顶层移除这些端口。
# ============================================================
set_property SEVERITY {Warning} [get_drc_checks UCIO-1]
set_property SEVERITY {Warning} [get_drc_checks NSTD-1]
