# lcpu_rgmii 修改总结

> 日期: 2026-07-13

---

## cpu_channel.v — 解决帧首字节丢失 (核心修复)

**问题**：SOP 同拍若 EN 有效，`rx_byte_cnt` 的 NBA 复位未生效就被 EN 分支用作写入地址，导致 byte0 写入错误地
址、帧长少 1。

**修复**：`if-else-if` 结构，SOP 分支内检查是否同时有 EN：

```verilog
if (mac_rx_sop) begin
    if (mac_rx_en) begin
        frame_buf[0] <= mac_rx_data;   // 直写地址0
        rx_byte_cnt <= 1'b1;           // 下一拍写到frame_buf[1]
    end else begin
        rx_byte_cnt <= 0;              // 纯SOP, 只复位
    end
end else if (mac_rx_en) begin
    frame_buf[rx_byte_cnt] <= mac_rx_data;
    rx_byte_cnt <= rx_byte_cnt + 1;
end
```

---

## cpu_channel.v — 其他修复

| 修复 | 说明 |
|------|------|
| `(* ram_style = "block" *)` | 强制 Block RAM, 防资源超限 |
| `(* DONT_TOUCH = "TRUE" *)` extract_rd_ptr | 防止 Vivado 优化 |
| `synthesis DONT_TOUCH = 1` rx_byte_cnt | 防止 Vivado 优化 |
| 双窗口过滤 | +filter_data2/filter_offset2 端口 |
| debug 输出端口 | dbg_extract_wen/wdata, dbg_mac_in_wen/wdata, dbg_rx_cnt_out |

---

## axi2lcpu.v — 解决 jwrite 失败

| 修复 | 说明 |
|------|------|
| `!m_axi_bready` → `!bvalid_r` | BVALID 竞态导致 AXI 写超时 |
| `m_axi_bready && bvalid_r` | BVALID 握手正确 |

---

## mmcm_50_125.v — cpu_clk 内部生成

+CLKOUT3=50MHz (1000MHz/20) + BUFG，顶层不再需要外部 cpu_clk 引脚。

---

## rgmii_gmii_loopback_top.v — 顶层适配

| 改动 | 说明 |
|------|------|
| 过滤常量 | `F7FF/3D01/0000/0000` 双窗口 |
| cpu_clk 内部线 | 删外部端口 |
| +phy_rst_n | PHY 复位 ~16ms |
| debug wire | extract/mac_in/rx_cnt 引出接 ILA |
| cpu_channel_reg 例化 | 去 LCPU_TYPE, 32-bit wire 截断 |

---

## lcpu_rgmii.xdc

| 改动 | 说明 |
|------|------|
| +phy_rst_n (P14) | PHY 复位引脚 |
| cpu_clk generated_clock | MMCM CLKOUT3 BUFG |
| 时钟组 cpu_clk 归入 MMCM | |
| get_ports 双花括号 | 语法修复 |
| DRC UCIO-1/NSTD-1 抑制 | |

---

## 最终 ILA 配置

| probe | 信号 | 宽度 |
|-------|------|------|
| 0 | mac_rx_sop/en/eop/err/data[7:0] | 12 |
| 1 | dbg_frame_hit, dbg_extract_active, dbg_extract_wen, dbg_extract_wdata[7:0] | 11 |
| 2 | dbg_mac_in_wen, dbg_mac_in_wpkt_push, dbg_mac_in_wdata[7:0] | 10 |
| 3 | cpu_tx_sop/en/eop/err/data[7:0] | 12 |
| 4 | gmii_tx_en, gmii_txd[7:0] | 9 |
| 5 | cpu_rd_empty_sync, dbg_rx_cnt_out[10:0] | 12 |

触发: probe0[11] = mac_rx_sop = R, Pre-trigger 64

---

## 已验证功能

| 功能 | 验证方式 | 状态 |
|------|---------|------|
| RGMII→GMII 接收 + 前导码剥离 | ILA probe0/6 | ✅ |
| CRC32 校验 (mac_rx) | ILA mac_rx_err=0 | ✅ |
| 双窗口硬件过滤 (byte61=0x77) | LED1 亮 / ILA frame_hit | ✅ |
| 帧缓冲写入 (frame_buf) | 仿真 byte[0]=0x30 | ✅ |
| 提取搬运 → RX FIFO | ILA mac_in_wpkt_push 脉冲 | ✅ |
| LCPU 读 FIFO (jread 0x05) | PKT_LEN=68, byte[0]=0x30 | ✅ |
| LCPU 写 FIFO → mac_tx | ILA probe3 cpu_tx_sop | 待测 |
| RGMII 直接回环 | probe3 cpu_tx_en=0 时 probe4 有数据 | ✅ |
| PHY 复位 | LED0/LED2 亮 | ✅ |
| axi2lcpu jwrite 修复 | AXI 写不再超时 | ✅ |
| cpu_clk 内部生成 (MMCM CLKOUT3) | 不依赖外部引脚 | ✅ |

**不验证 / 无需验证**：短帧过滤 (window1_visited)、BRAM→寄存器→BRAM 改动历史、仿真与硬件差异（已知 iverilog 不模拟 BRAM 读延迟）。
