# RGMII → GMII 回环 + cpu_channel + LCPU JTAG 读包

> **版本:** v1.3 | **日期:** 2026-07-09 | **作者:** huaming.huang@link-real.com.cn

---

## 1. 架构总览

```
 RGMII PHY ──▶ Bridge ──▶ gmii2mac ──▶ cpu_channel ──▶ gmii2mac ──▶ Bridge ──▶ PHY
  (RTL8211)   (DDR↔SDR)   (CDC+前导码  (过滤+FIFO+    (CRC+前导码  (SDR↔DDR)
                           +CRC RX/TX)  透传回环)      插入)

                              │                              │
                         cpu_channel_reg ◀── LCPU bus ── jtag_cpu_amd_core ◀── JTAG ── PC
```

**6 个顶层模块:**

| # | 模块 | 文件 | 功能 |
|---|------|------|------|
| 1 | `mmcm_50_125` | `rtl/rgmii2gmii/mmcm_50_125.v` | 50MHz→125MHz/200MHz/125MHz_tx |
| 2 | `rgmii_gmii_bridge` | `rtl/rgmii2gmii/*.v` | RGMII DDR ↔ GMII SDR |
| 3 | `gmii2mac` | `rtl/mac/gmii2mac.v` | CDC + 前导码剥离/插入 + CRC校验/插入 |
| 4 | `cpu_channel` | `rtl/cpu/cpu_channel.v` | 全帧缓存 + 多字节过滤 + FIFO + 透传回环 |
| 5 | `jtag_cpu_amd_core` | `rtl/AMD/RTL/*.v` | JTAG→AXI4-Lite→LCPU bus |
| 6 | `cpu_channel_reg` | `rtl/cpu/cpu_channel_reg.v` | LCPU bus → 寄存器桥 |

---

## 2. 数据通路

### RX 方向

```
RGMII PHY (DDR, 125MHz)
  │ rgmii_rxc/rxd[3:0]/rx_ctl
  ▼
rgmii_gmii_bridge  ── IDELAYE2+IDDR ──▶ GMII (SDR, 8bit)
  │ gmii_rx_dv, gmii_rxd[7:0], gmii_rx_er  (gmii_rx_clk 域)
  ▼
gmii2mac:
  u_rx_asyncfifo   ── CDC gmii_rx_clk→clk_125m (10bit {ER,DV,DATA})
  u_eth_presemble  ── 剥离前导码 (7×0x55 + 0xD5)
  u_mac_top/u_mac_rx ── CRC32 校验, 输出 sop/eop
  │ mac_rx_sop/en/data[7:0]/eop/err  (clk_125m 域)
  ▼
cpu_channel:
  frame_buf       ── Block RAM 全帧缓存
  多字节窗口过滤  ── filter_data[15]=en, [14:8]=match, [7:0]=mask
                    filter_offset[15:8]=start, [7:0]=count
  extract SM      ── EOP+frame_hit→逐字节搬入 ram2pktfifo_int
  ram2pktfifo_int ── 打拍计算 wpkt_len
  package_fifo_v2 ── RX: clk_125m→cpu_clk (双时钟 CDC)
  │ cpu_rd_empty/rpkt_len/rdata[...]  (cpu_clk 域)
  ▼
cpu_channel_reg ── lcpu_rdata[31:0]/lcpu_ack
  │ lcpu_req/rh_wl/address[31:0]
  ▼
jtag_cpu_amd_core ── JTAG ──▶ PC (Vivado HW Manager)
```

### TX 方向 (回环)

```
cpu_channel 内部:
  mac_rx_en/data/err ──▶ 透传延迟线(4拍) ──▶ MUX(CPU优先) ──▶ sop_eop_gen
  cpu_wr_*           ──▶ package_fifo_v2 ──▶ pktfifo2ram_int_v2 ──┘
  │ cpu_tx_sop/en/data[7:0]/eop/err  (clk_125m 域)
  ▼
gmii2mac:
  u_mac_top/u_mac_tx   ── CRC32 插入
  u_eth_presemble      ── 插入前导码
  │ gmii_tx_en, gmii_txd[7:0]  (clk_125m 域)
  ▼
rgmii_gmii_bridge  ── ODDR ──▶ RGMII PHY
```

---

## 3. 时钟域

| 时钟 | 频率 | 来源 | 使用者 |
|------|------|------|--------|
| `clk_50m` | 50MHz | 板载晶振 | `mmcm_50_125` 输入 |
| `clk_125m` | 125MHz | MMCM CLKOUT0 | `gmii2mac`, `cpu_channel` 数据面, ILA |
| `clk_200m` | 200MHz | MMCM CLKOUT1 | IDELAYCTRL 参考 |
| `clk_125m_tx` | 125MHz (90°) | MMCM CLKOUT2 | GMII TX 时钟 |
| `gmii_rx_clk` | 125MHz | RGMII RXC→BUFG | gmii2mac 内部 CDC 写侧 |
| `cpu_clk` | 50MHz | 外部 | `jtag_cpu_amd_core`, `cpu_channel_reg`, `cpu_channel.cpu_rd_*` |

---

## 4. LCPU 寄存器映射

| 地址 | 名称 | R/W | 位段 | 说明 |
|------|------|-----|------|------|
| `0x00` | STATUS | R | `[7:0]` drop_cnt | 丢包计数 |
| `0x04` | PKT_LEN | R | `[11:0]` rpkt_len | 当前包长度 (pop后有效) |
| `0x08` | RD_DATA | R | `[7:0]` rdata | 读1字节 (raddr自动++) |
| `0x0C` | CONTROL | R/W | `[0]` pop, `[1]` bypass | 弹出包 / 旁路过滤 |
| `0x10` | FILTER_CFG | R/W | `[15]` en, `[14:8]` match, `[7:0]` mask | 多字节窗口掩码过滤 |
| `0x14` | FILTER_OFS | R/W | `[15:8]` start, `[7:0]` count | 过滤窗口位置+长度 |
| `0x18` | EXTRACT_OFS | R/W | `[10:0]` offset | 提取偏移 (预留) |

---

## 5. ILA 观测 (7 Probe / 122 bits)

| Probe | 位宽 | 信号 | 位置 |
|-------|------|------|------|
| 0 | 10 | `{gmii_rx_dv, gmii_rx_er, gmii_rxd[7:0]}` | **GMII 接口处** — bridge 输出, 含前导码 |
| 1 | 12 | `{mac_rx_sop, mac_rx_en, mac_rx_data[7:0], mac_rx_eop, mac_rx_err}` | **FIFO入口** — CRC校验后 sop/eop, 去前导码 |
| 2 | 12 | `{cpu_tx_sop, cpu_tx_en, cpu_tx_data[7:0], cpu_tx_eop, cpu_tx_err}` | **回环出口** — 透传/CPU注入后 |
| 3 | 9 | `{gmii_tx_en, gmii_txd[7:0]}` | **GMII 出口** — 即将进 bridge, 含新CRC+前导码 |
| 4 | 32 | `rx_stat_good_pkt[31:0]` | **统计** — CRC正确包累加 |
| 5 | 23 | `{cpu_rd_empty, cpu_rd_rpkt_len[11:0], frame_hit, reg_bypass_mode, pkt_drop_cnt[7:0]}` | **CPU状态** — FIFO空/包长/命中/bypass/丢包 |
| 6 | 24 | `{dbg_extract_active, dbg_fifo_full, dbg_fifo_wen, dbg_fifo_wdata[7:0], dbg_fifo_wpkt_push, dbg_fifo_wpkt_len[11:0]}` | **FIFO写入** — extract SM逐字节写入 package_fifo_v2 |

### ILA 波形解读

```
probe0: dv ──‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾______  每帧含前导码 55 55 55 55 55 55 55 D5
probe1: sop ──‾\__________________________  帧起始 (DA 首字节)
        en  ──‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\__  帧数据有效 (已去前导码, 含 FCS)
        eop ──________________________‾\__  帧结束 (FCS 末字节)
        err ──__________________________/‾\  CRC 错误 (eop 时有效)
probe2: 与 probe1 对齐但延迟约4拍 (透传回环)
probe3: 比 probe2 多 8B 前导码 + 4B 新 CRC
probe4: 每个 probe1.eop 且 err=0 后 +1
probe5: empty=0 → FIFO 有包可读; frame_hit↗ → 过滤命中
probe6: extract_active=1 时 wen 脉冲 N 次 (N=帧长), wdata 逐字节写入
```

---

## 6. 文件清单

```
rtl/
├── rgmii_gmii_loopback_top.v     ← 顶层
├── dual_clock_fifo.v
│
├── rgmii2gmii/                   ← 物理层
│   ├── mmcm_50_125.v
│   ├── gmii_rgmii_bridge.v
│   ├── gmii_to_rgmii.v
│   ├── rgmii_to_gmii.v
│   └── simple_dual_port_ram.v
│
├── mac/                          ← MAC 层
│   ├── gmii2mac.v
│   ├── eth_presemble.v
│   ├── mac_top.v
│   ├── mac_rx.v
│   ├── mac_tx.v
│   ├── crc.v
│   ├── sop_eop_gen.v
│   └── fix_delay.v
│
├── cpu/                          ← CPU 通道层
│   ├── cpu_channel.v             (v3.2)
│   ├── cpu_channel_reg.v
│   ├── ram2pktfifo_int.v
│   ├── package_fifo.v
│   ├── pktfifo2ram_int_v2.v
│   ├── single_clock_fifo.v
│   └── pulse_clock_region_pass.v
│
└── AMD/RTL/                      ← JTAG 调试层
    ├── jtag_cpu_amd_core.v
    ├── axi2lcpu.v
    └── jtag_axi_0.xci
```

---

## 7. 构建步骤

```
1. 打开 Vivado 项目 lcpu_rgmii.xpr

2. 生成 ILA IP (TCL Console):
      source create_ila.tcl

3. Run Synthesis

4. Run Implementation → Generate Bitstream

5. Program Device → 下载到 FPGA

6. 连接 JTAG (Vivado HW Manager):
      source AMD/TCL/lcpu_start.tcl
      lcpu_quick_test
```

---

## 8. TCL 抓包操作

```tcl
# 打开 Hardware Manager 后
source LCPU_AMD_Driver.tcl
source lcpu_capture.tcl

lcpu_status              # 查看寄存器状态
filter_pass_all           # 全放行
lcpu_capture_once        # 单次抓包
lcpu_monitor             # 持续监控
lcpu_help                # 帮助
```

---

## 9. cpu_channel 过滤配置

**位域定义:**

| 寄存器 | 位 | 含义 |
|--------|-----|------|
| `FILTER_CFG` | `[15]` | 过滤使能 (0=全放行) |
| | `[14:8]` | 匹配值 (7-bit) |
| | `[7:0]` | 掩码 (bit=1 检查, bit=0 忽略) |
| `FILTER_OFS` | `[15:8]` | 起始字节偏移 |
| | `[7:0]` | 检查字节数 |

**匹配逻辑:** 窗口 `[start, start+count)` 内所有字节 `(data & mask) == (match & mask)` 同时成立

**配置示例:**

```tcl
# IPv4 (EtherType=0x0800, 检查 byte13=0x00)
reg_write 0x10 0x80FF   # FILTER_CFG: en=1, match=0x00, mask=0xFF
reg_write 0x14 0x0D01   # FILTER_OFS: start=13, count=1

# 放行所有
reg_write 0x0C 0x02     # CONTROL: bypass=1

# ARP (EtherType=0x0806)
reg_write 0x10 0x8006   # FILTER_CFG: en=1, match=0x00, mask=0x06
reg_write 0x14 0x0D02   # FILTER_OFS: start=13, count=2
```

---

## 10. 顶层端口

| 端口 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `rgmii_txc/txd/tx_ctl` | out | 1+4+1 | RGMII TX |
| `rgmii_rxc/rxd/rx_ctl` | in | 1+4+1 | RGMII RX |
| `clk_50m` | in | 1 | 板载晶振 |
| `cpu_clk` | in | 1 | LCPU 时钟 |
| `rst_n` | in | 1 | 异步复位 |
| `phy_rst_n` | out | 1 | PHY 复位 (MMCM锁定后~16ms释放) |
| `mmcm_locked` | out | 1 | PLL 锁定 |
| `led[1:0]` | out | 2 | LED[0]=锁定, LED[1]=FIFO有包 |
