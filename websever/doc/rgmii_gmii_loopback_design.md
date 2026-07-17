# RGMII → GMII 回环 + 前导码去除 + CRC 校验 + cpu_channel 数据通道 + LCPU 读包 设计文档

> **作者:** huaming.huang@link-real.com.cn
> **日期:** 2026-07-08 (更新: 2026-07-15, cpu_channel v3.3 硬接线过滤器)
> **参考代码:**
> - `/home/huamingh/work/FPGA_Prj/rtl/` (RTL 源码库: mac/, cpu_channel/, rgmii2gmii/)
> - `/home/huamingh/work/FPGA_Prj/test/` (测试工程: sgmii_sgmii/, cpu_channel1/, vivado_rgmi_gmi/)
> - `/home/huamingh/work/FPGA_Prj/test/lcpu_rgmii/rtl/cpu/cpu_channel.v` (v3.3, 过滤器已改为硬接线单字节匹配)

---

## 目录

1. [总体架构](#1-总体架构)
2. [模块划分与接口定义](#2-模块划分与接口定义)
3. [模块详细设计](#3-模块详细设计)
   - [3.1 rgmii_gmii_loopback_top — 顶层](#31-rgmii_gmii_loopback_top--顶层)
   - [3.2 rgmii_gmii_bridge — RGMII↔GMII 桥接](#32-rgmii_gmii_bridge--rgmiigmii-桥接)
   - [3.3 preamble_remove — 前导码去除](#33-preamble_remove--前导码去除)
   - [3.4 mac_rx — CRC 校验](#34-mac_rx--crc校验)
   - [3.5 cpu_channel — CPU 数据通道 (LCPU 读包 + RAM 拦截计长)](#35-cpu_channel--cpu-数据通道-lcpu-读包--ram-拦截计长)
   - [3.6 TX 通路 — cpu_channel 内部透传回环 + CPU 注入](#36-tx-通路--cpu_channel-内部透传回环--cpu-注入)
   - [3.737-mac_tx--crc-插入) mac_tx — CRC 插入](#
4. [LCPU 读 FIFO 包接口设计](#4-lcpu-读-fifo-包接口设计)
5. [数据流与波形时序](#5-数据流与波形时序)
6. [参数配置建议](#6-参数配置建议)
7. [文件清单](#7-文件清单)
8. [仿真验证方案](#8-仿真验证方案)
9. [LCPU JTAG 读包通路](#9-lcpu-jtag-读包通路)

---

## 1. 总体架构

### 1.1 数据通路框图

```
                              ┌──────────────────────────────────────────────────────────────────────┐
                              │                         rgmii_gmii_loopback_top                       │
                              │                                                                        │
  ┌──────────┐    RGMII       │  ┌──────────────┐    GMII RX    ┌──────────────┐    ┌──────────────┐  │
  │          │ RXC/RXD[3:0]   │  │               │ dv/er/d[7:0] │               │    │              │  │
  │  Ethernet │───────────────│─▶│ rgmii_gmii    │─────────────▶│  preamble     │    │  dual_clock  │  │
  │   PHY    │  RX_CTL        │  │ _bridge        │              │  _remove      │    │  _fifo       │  │
  │          │                │  │               │              │  (去前导码)    │───▶│  (CDC)       │  │
  │  (RTL8211│                │  │ (IDELAY+IDDR   │              │               │    │              │  │
  │   等)    │                │  │  +ODDR)        │              └──────────────┘    │ gmii_rx_clk  │  │
  │          │    RGMII       │  │               │   GMII TX                        │   → clk_125m │  │
  │          │ TXC/TXD[3:0]  │  │               │◀──────────────────────────────────│              │  │
  │          │◀───────────────│──│               │                                   └──────┬───────┘  │
  └──────────┘  TX_CTL        │  └──────────────┘                                          │          │
                              │                                                             │ rx_en    │
                              │                                                             │ rx_data  │
                              │                                                             ▼          │
                              │                                                      ┌──────────────┐  │
                              │                                                      │   mac_rx     │  │
                              │                                                      │  (CRC32校验) │  │
                              │                                                      │              │  │
                              │                                                      │ 输出:         │  │
                              │                                                      │ sop/en/data   │  │
                              │                                                      │ /eop/err     │  │
                              │                                                      └──────┬───────┘  │
                              │                                                             │          │
                              │                                              mac_rx_sop/en/data/eop/err │
                              │                                                             │          │
                              │                                                      ┌──────┴───────┐  │
                              │                                                      │  cpu_channel │  │
                              │                                                      │   (v3.3)     │  │
                              │                                                      │              │  │
                              │                                                      │ ┌──────────┐ │  │
                              │                                                      │ │frame_buf │ │  │
                              │                                                      │ │全帧缓存  │ │  │
                              │                                                      │ │+硬接线过滤 │ │  │
                              │                                                      │ └────┬─────┘ │  │
                              │                                                      │      │       │  │
                              │                                                      │      ▼       │  │
                              │                                                      │ ┌──────────┐ │  │
                              │                                                      │ │extract   │ │  │
                              │                                                      │ │SM+ram2pkt│ │  │
                              │                                                      │ │fifo_int  │ │  │
                              │                                                      │ └────┬─────┘ │  │
                              │                                                      │      │       │  │
                              │                                                      │      ▼       │  │
                              │                                                      │ ┌──────────┐ │  │
                              │                                                      │ │package   │ │  │
                              │                                                      │ │_fifo_v2  │ │  │
                              │                                                      │ │(RX,双时钟)│ │  │
                              │                                                      │ │clk→cpu_clk│ │  │
                              │                                                      │ └────┬─────┘ │  │
                              │                                                      │      │       │  │
                              │                                                      │      ▼       │  │
                              │                                                      │  cpu_rd_*    │  │
                              │                                                      │  ────────▶   │  │
                              │                                                      │   LCPU 读包  │  │
                              │                                                      │              │  │
                              │                                                      │ ┌ RX→TX ───┐ │  │
                              │                                                      │ │透传延迟线 │ │  │
                              │                                                      │ │(4拍)     │ │  │
                              │                                                      │ └────┬─────┘ │  │
                              │                                                      │      │       │  │
                              │                                                      │ ┌────┴─────┐ │  │
                              │                                                      │ │ CPU注入  │ │  │
                              │                                                      │ │ (cpu_wr) │ │  │
                              │                                                      │ └────┬─────┘ │  │
                              │                                                      │      │       │  │
                              │                                                      │   MUX(CPU优 │  │
                              │                                                      │   先)       │  │
                              │                                                      │      │       │  │
                              │                                                      │      ▼       │  │
                              │                                                      │ sop_eop_gen  │  │
                              │                                                      │      │       │  │
                              │                                                      └──────┼───────┘  │
                              │                                                             │          │
                              │                                                cpu_tx_sop/en/data/eop/err │
                              │                                                             │          │
                              │                                                          ▼          │    │
                              │                                                   ┌──────────────┐  │    │
                              │                                                   │   mac_tx     │  │    │
                              │                                                   │  (CRC32插入) │  │    │
                              │                                                   │              │  │    │
                              │                                                   │ 输出:         │  │    │
                              │                                                   │ tx_en/tx_data│──│────┘
                              │                                                   └──────────────┘  │
                              └──────────────────────────────────────────────────────────────────────┘
```

### 1.2 关键设计要点

| 步骤 | 模块 | 功能 | 时钟域 | 来源 |
|------|------|------|--------|------|
| 1 | `rgmii_gmii_bridge` | RGMII DDR ↔ GMII SDR 转换 (IDELAYE2+IDDR/BUFG / ODDR) | RGMII_RXC → gmii_rx_clk | 复用 `rtl/cpu_channel/rgmii2gmii/` |
| 2 | `preamble_remove` | 检测并去除 7B 前导码(0x55) + 1B SFD(0xD5) | gmii_rx_clk | **新增** `mac/preamble_remove.v` |
| 3 | `dual_clock_fifo` (CDC) | 跨时钟域: gmii_rx_clk → clk_125m, 仅传输 pr_data (8bit) | gmii_rx_clk → clk_125m | 复用 `rtl/cpu_channel/RTL/` |
| 4 | `mac_rx` | CRC32 FCS 校验, 输出 sop/eop/en/data/err | clk_125m | 复用 `rtl/mac/` |
| 5 | **`cpu_channel`** (v3.3) | **LCPU 读包通道: frame_buf 全帧缓存 → 硬接线单字节过滤(match) → extract SM → ram2pktfifo_int → package_fifo_v2 → cpu_rd_\*** | clk_125m / cpu_clk | 复用 `cpu/cpu_channel.v`, **RX_PREAMBLE_STRIP=0**, **过滤器硬接线: cnt=61, data=0x77** |
| 6 | **cpu_channel TX 通路** | **透传回环: 内部透传延迟线(4拍) → MUX → sop_eop_gen**; CPU 注入: package_fifo_v2 → pktfifo2ram_int_v2 → MUX | clk_125m | cpu_channel 内部实现 |
| 7 | `mac_tx` | CRC32 FCS 插入, 输出 tx_en/tx_data → rgmii_gmii_bridge (GMII TX) | clk_125m | 复用 `rtl/mac/` |

**架构核心思路:**
- **前导码处理策略**: `preamble_remove` 在 gmii_rx_clk 域剥离前导码, `cpu_channel` 设 `RX_PREAMBLE_STRIP=0` 避免重复跳过。两者明确分工, 消除双重处理。
- **`cpu_channel` (v3.3)** 作为 LCPU 读包的数据通道，内部 `frame_buf` Block RAM 缓存全帧。过滤器采用**硬接线单字节匹配**: `localparam CNT=61, DATA=8'h77`，在字节偏移 61 处检查数据是否为 `0x77`（'w'），`match` 信号默认为 1，不匹配时清零。EOP 后若命中则 extract 状态机将帧数据逐字节搬入 `ram2pktfifo_int` → `package_fifo_v2` (双时钟) → `cpu_rd_*` 接口。
- **TX 通路**也由 `cpu_channel` 内部统一处理: RX 数据经 4 拍透传延迟线回环到 TX; LCPU 可通过 `cpu_wr_*` 接口注入包, CPU 注入优先级高于透传回环。

---

## 2. 模块划分与接口定义

### 2.1 顶层模块接口 `rgmii_gmii_loopback_top`

```verilog
module rgmii_gmii_loopback_top #(
    // ── cpu_channel 参数 ──
    parameter CPU_BUF_ADDR_WIDTH       = 11,     // CPU 包缓冲地址宽度 (max 2048B)
    parameter CPU_BUF_BLOCK_MODE       = "false",// 包 FIFO 模式 ("true"/"false")
    parameter CPU_BUF_BLOCK_ADDR_WIDTH = 3,
    parameter CPU_BUF_DATA_WIDTH       = 8,
    parameter CPU_BUF_PARA_WIDTH       = 3,
    parameter CPU_BUF_DATA_RAM_TYPE    = "M9K",
    parameter CPU_BUF_PARA_RAM_TYPE    = "registers"
) (
    // ============================================================
    // RGMII — 到外部 PHY
    // ============================================================
    output wire       rgmii_txc,
    output wire [3:0] rgmii_txd,
    output wire       rgmii_tx_ctl,
    input  wire       rgmii_rxc,
    input  wire [3:0] rgmii_rxd,
    input  wire       rgmii_rx_ctl,

    // ============================================================
    // 系统时钟与复位
    // ============================================================
    input  wire       clk_50m,          // 板载 50MHz 晶振 → MMCM → 125MHz/200MHz
    input  wire       cpu_clk,          // LCPU 时钟 (典型 50MHz, jtag_axi_0 + cpu_channel_reg)
    input  wire       rst_n,            // 异步复位, 低有效

    // ============================================================
    // 状态输出
    // ============================================================
    output wire [31:0] rx_stat_good_pkt,   // CRC 正确包计数
    output wire [31:0] rx_stat_bad_pkt,    // CRC 错误包计数
    output wire [31:0] tx_stat_pkt,        // TX 发送包计数
    output wire [ 7:0] pkt_drop_cnt,       // 丢包计数 (来自 cpu_channel)
    output wire        mmcm_locked,        // MMCM 锁定指示
    output wire [ 1:0] led                 // 状态 LED
);
```
**注:** 过滤器已**硬接线**为单字节匹配 (`localparam CNT=61, DATA=8'h77`)，不再需要外部配置端口。旁路模式 (`bypass_mode`) 内部拉低。LCPU 读包 (`cpu_rd_*`/`cpu_wr_*`) 通过 JTAG 访问 `cpu_channel_reg` 寄存器桥。

---

## 3. 模块详细设计

### 3.1 `rgmii_gmii_loopback_top` — 顶层 (v1.2)

**功能:** 将所有子模块连接起来, 形成完整的 RGMII→GMII 回环 + LCPU JTAG 读包 通路。

**内部信号声明与子模块例化 (精简版, 完整代码见 `rgmii_gmii_loopback_top.v`):**

```verilog
// ============================================================
// MMCM 时钟管理 (50M → 125M / 200M / 125M_tx)
// ============================================================
mmcm_50_125 u_mmcm (
    .clk_50m(clk_50m), .clk_125m(clk_125m), .clk_200m(clk_200m),
    .clk_125m_tx(clk_125m_tx), .locked(mmcm_locked_i), .rst_n(rst_n)
);
wire rst_n_int = rst_n & mmcm_locked_i;

// ── 1. RGMII↔GMII 桥 (GMII TX→clk_125m_tx 90°移相) ──
rgmii_gmii_bridge u_bridge (
    .gmii_tx_clk(clk_125m_tx), .gmii_txd(gmii_txd), ...
    .gmii_rx_clk(gmii_rx_clk), .gmii_rxd(gmii_rxd), ...
    .idelay_refclk(clk_200m), .rst_n(rst_n_int)
);

// ── 2. 前导码去除 (gmii_rx_clk 域) ──
preamble_remove u_preamble_remove (
    .clk(gmii_rx_clk), .reset_l(rst_n_int),
    .rx_dv(gmii_rx_dv), .rx_data(gmii_rxd), .rx_er(gmii_rx_er),
    .pr_dv(pr_dv), .pr_data(pr_data), .pr_er(pr_er)
);

// ── 3. CDC FIFO (gmii_rx_clk → clk_125m, 16深, 8bit) ──
dual_clock_fifo #(.addr_width(4), .data_width(8)) u_rx_cdc_fifo (
    .wclk(gmii_rx_clk), .write_en(pr_dv), .write_data(pr_data),
    .rclk(clk_125m), .read_en(~cdc_empty), .read_data(cdc_rx_data), .empty(cdc_empty)
);
// cdc_rx_en = ~cdc_empty (延迟1拍对齐 rdata)

// ── 4. MAC RX: CRC32 校验 ──
mac_rx #(.rx_fcs_check_en(1)) u_mac_rx (...);

// ── 5. cpu_channel (v3.3, RX_PREAMBLE_STRIP=0, 过滤器硬接线) ──
//     过滤器: localparam CNT=61, DATA=8'h77 (单字节匹配, 不可动态配置)
cpu_channel #(.RX_PREAMBLE_STRIP(0)) u_cpu_channel (
    .clk(clk_125m), .cpu_clk(cpu_clk),
    .mac_rx_sop/en/data/eop/err (...),
    .mac_tx_sop/en/data/eop/err (cpu_tx_*),     // → mac_tx
    .bypass_mode(1'b0),                          // 内部拉低
    .cpu_rd_empty/len/rdata/... (cpu_rd_*),     // ↔ cpu_channel_reg
    .cpu_wr_* (tied off)
);

// ── 6. MAC TX: CRC32 插入 ──
mac_tx #(.tx_fcs_insert_en(1)) u_mac_tx (
    .mac_tx_sop/en/data/eop/err (cpu_tx_*),     // ← cpu_channel
    .tx_en/tx_data (gmii_tx_en/gmii_txd)        // → rgmii_gmii_bridge
);

// ════════════════════════════════════════════════════════════
// LCPU 读包通路 (cpu_clk 域)
// ════════════════════════════════════════════════════════════

// ── 7. JTAG → AXI → LCPU bus ──
jtag_cpu_amd_core #(.data_width(32), .addr_width(32)) u_jtag_cpu (
    .clk(cpu_clk), .rst_n(rst_n),
    .lcpu_req/rh_wl/address/wdata (lcpu_*),     // → cpu_channel_reg
    .lcpu_ack/rdata (lcpu_*)                    // ← cpu_channel_reg
);

// ── 8. LCPU bus → cpu_channel 寄存器桥 ──
cpu_channel_reg #(.LCPU_TYPE("AMD")) u_cpu_channel_reg (
    .clk(cpu_clk), .rst_n(rst_n),
    .lcpu_req/rh_wl/address/wdata/ack/rdata (lcpu_*),
    // 过滤器已硬接线, cpu_channel_reg 不再输出 filter_data/filter_offset
    .cpu_rd_empty/len/ren/raddr/rdata/... (cpu_rd_*)  // ↔ cpu_channel
);
```

---

### 3.2 `rgmii_gmii_bridge` — RGMII↔GMII 桥接

**源代码:** `/home/huamingh/work/FPGA_Prj/rtl/cpu_channel/rgmii2gmii/rgmii_gmii_bridge.v`

直接复用现有代码, 无需修改。例化 `gmii_to_rgmii` (TX) + `rgmii_to_gmii` (RX)。

**数据方向:**
- TX: GMII (8b SDR @125MHz) → ODDR → RGMII (4b DDR @125MHz)
- RX: RGMII (4b DDR @125MHz) → IDELAYE2 + IDDR + BUFG → GMII (8b SDR @125MHz)

**关键原语 (Xilinx 7 系列):**
- `IDELAYCTRL` — 200MHz 参考时钟校准
- `IDELAYE2` (×5, FIXED, 20tap=~1.56ns) — RXD[3:0]+RX_CTL 延迟补偿
- `IDDR` (×5, SAME_EDGE_PIPELINED) — DDR→SDR 转换
- `BUFG` — RXC 全局时钟缓冲
- `ODDR` (×6, OPPOSITE_EDGE) — TXC/TXD[3:0]/TX_CTL SDR→DDR

---

### 3.3 `preamble_remove` — 前导码去除

**新增模块。** 功能: 检测并去除以太网帧的 7 字节前导码(0x55) + 1 字节 SFD(0xD5)。

```verilog
//****************************************Copyright 2026[c]************************//
// File name:        preamble_remove.v
// Author:           huaming.huang@link-real.com.cn
// Date:             2026-07-08
// Version Number:   1.0
// Abstract:
//   检测并去除 RGMII/GMII 以太网帧的前导码 (7 × 0x55) + SFD (0xD5)
//   标准前导码: 55 55 55 55 55 55 55 D5
//
//   FSM: IDLE → PREAMBLE → FRAME → IDLE
// *********************************end************************************** //

module preamble_remove (
    input  wire       clk,
    input  wire       reset_l,
    // GMII RX input (含前导码)
    input  wire       rx_dv,
    input  wire [7:0] rx_data,
    input  wire       rx_er,
    // Output (去前导码后的帧数据: DA + SA + Type/Len + Payload + FCS)
    output reg        pr_dv,
    output reg  [7:0] pr_data,
    output reg        pr_er
);

  localparam S_IDLE     = 2'd0;
  localparam S_PREAMBLE = 2'd1;
  localparam S_FRAME    = 2'd2;

  reg [1:0] state, next_state;
  reg [2:0] preamble_cnt;   // 0-7

  wire is_preamble_byte = (rx_data == 8'h55);
  wire is_sfd_byte      = (rx_data == 8'hD5);

  always @(posedge clk or negedge reset_l) begin
    if (reset_l == 1'b0) begin
      state        <= S_IDLE;
      preamble_cnt <= 3'd0;
    end else begin
      state <= next_state;
      case (state)
        S_PREAMBLE: begin
          if (rx_dv)
            preamble_cnt <= preamble_cnt + 3'd1;
          else
            preamble_cnt <= 3'd0;
        end
        default: preamble_cnt <= 3'd0;
      endcase
    end
  end

  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE:     if (rx_dv)                 next_state = S_PREAMBLE;
      S_PREAMBLE: if (!rx_dv)                next_state = S_IDLE;
                  else if (preamble_cnt == 3'd7 && is_sfd_byte)
                                             next_state = S_FRAME;
      S_FRAME:    if (!rx_dv)                next_state = S_IDLE;
      default:                               next_state = S_IDLE;
    endcase
  end

  always @(posedge clk or negedge reset_l) begin
    if (reset_l == 1'b0) begin
      pr_dv   <= 1'b0;
      pr_data <= 8'd0;
      pr_er   <= 1'b0;
    end else begin
      if (state == S_FRAME && rx_dv) begin
        pr_dv   <= 1'b1;
        pr_data <= rx_data;
        pr_er   <= rx_er;
      end else begin
        pr_dv   <= 1'b0;
        pr_data <= 8'd0;
        pr_er   <= 1'b0;
      end
    end
  end

endmodule
```

**时序波形:**

```
         _   _   _   _   _   _   _   _   _   _   _   _   _   _   _
clk    _| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_
       ┌──────────────────────────────────────────────────┐
rx_dv  │  前导码 + SFD + 帧数据 (DA ~ FCS)                 │
       └──────────────────────────────────────────────────┘
        55  55  55  55  55  55  55  D5  DA  SA  ...
rx_data ──┬───┬───┬───┬───┬───┬───┬───┬───┬───┬──────────────
                                      ┌──────────────────────┐
pr_dv                                 │  帧数据 (无前导码)    │
                                      └──────────────────────┘
pr_data  ────────────────────────────── DA X SA X ...
```

---

### 3.4 `mac_rx` — CRC 校验

**源代码:** `/home/huamingh/work/FPGA_Prj/rtl/mac/mac_rx.v`

直接复用现有代码。功能:
1. 使用 `crc` 模块 (CRC-32, `crc_type=0`) 对输入帧进行 CRC 计算
2. 通过 `sop_eop_gen` 将 `rx_en` 转换为 `sop/eop` 信号
3. CRC 错误检测: `crc_out == 32'h1cdf4421` 为正确 (Magic Number)
4. 统计: `stat_cnt_0` = CRC 正确包数, `stat_cnt_1` = CRC 错误包数

**注意:** 输入 `rx_en/rx_data` 已经是去除前导码后的纯帧数据 (从 DA 到 FCS)。

**输出信号流向两个模块:**
- `mac_rx_sop/en/data/eop/err` → `cpu_channel` (用于 LCPU 读包 + TX 回环)

---

### 3.5 `cpu_channel` — CPU 数据通道 (LCPU 读包 + 帧缓冲 + 包过滤)

**源代码:** `/home/huamingh/work/FPGA_Prj/test/lcpu_rgmii/cpu/cpu_channel.v` (v3.3)

**核心模块，直接复用。** `cpu_channel` 是本设计的关键模块，承担以下功能:

#### 3.5.1 内部子模块链 (v3.3 实际架构)

```
mac_rx_sop/en/data/eop/err
       │
       ├──▶ [preamble 跳过/RX_PREAMBLE_STRIP 参数控制]
       │     RX_PREAMBLE_STRIP=0: 已剥离前导码, 直接逐字节计数 rx_byte_cnt
       │     RX_PREAMBLE_STRIP=1: 内部跳过前 8 字节 (默认, 向后兼容)
       │
       ├──▶ [frame_buf Block RAM] — 全帧缓存
       │     始终写入 mac_rx_data @ rx_byte_cnt 地址
       │     mac_rx_eop 时锁存 frame_len = rx_byte_cnt + 1
       │
       ├──▶ [硬接线单字节过滤] — localparam CNT=61, DATA=8'h77 (见 §3.5.3)
       │     match 默认为 1, rx_byte_cnt==61 时若 data≠0x77 则 match=0
       │     EOP 时 match=1 → frame_hit=1
       │
       ├──▶ [extract 状态机] — EOP + frame_hit 后搬全帧到 FIFO
       │     extract_active=1: 从 frame_buf 逐字节读出
       │     → extract_ram_wen/extract_ram_waddr/extract_ram_wdata
       │     extract_rd_ptr == extract_len-1 → extract_active=0
       │
       ▼
  ram2pktfifo_int (拦截 RAM 写时序 + 打拍计 wpkt_len)
       │
       ▼
  package_fifo_v2 (RX, dual_clock=1)
       │  wclk  = clk (125MHz)
       │  rclk  = cpu_clk (50MHz)
       │
       ▼
  cpu_rd_* 接口 (LCPU 在 cpu_clk 域读包)
```

#### 3.5.2 帧缓冲 + 提取机制

`cpu_channel` v3.0 使用 Block RAM 帧缓冲 + extract 状态机实现"先缓存、后判断、再搬移":

```
工作原理:
  ┌─────────────────────────────────────────────────┐
  │ 1. mac_rx_en 有效时: frame_buf[rx_byte_cnt] <= mac_rx_data │
  │ 2. mac_rx_eop 时: frame_len <= rx_byte_cnt + 1           │
  │ 3. EOP 后若 frame_hit: extract 状态机启动                  │
  │ 4. extract 逐字节从 frame_buf 读出 → ram2pktfifo_int       │
  │ 5. ram2pktfifo_int 打拍计算 wpkt_len (extract_ram_wen 计数)│
  │ 6. extract_ram_wen 下降沿 → wpkt_push (包完成)             │
  └─────────────────────────────────────────────────┘
```

**关键时序:**

```
mac_rx_en:  ┌──────────────────────────┐
            │ DA  SA  ...  Payload FCS │
            └──────────────────────────┘
frame_buf:  帧数据逐字节写入 (地址 = rx_byte_cnt)
frame_hit:  ──────────────────────────────┐└──  (EOP 后判断)
extract_active: ──────────────────────────┐████└── (搬移中)
extract_ram_wen: ─────────────────────────┐┌────┐└ (逐字节输出)
wpkt_push:  ──────────────────────────────────────┘└── (搬完)
wpkt_len:   ──────────────────────────────────────┤ N├─ (N 字节)
```

#### 3.5.3 包过滤机制 (v3.3: 硬接线单字节匹配)

`cpu_channel` v3.3 将过滤器**硬接线**为单字节位置匹配, 不再需要外部配置端口:

```verilog
// 硬接线过滤器 — 单字节匹配 (v3.3)
//   cnt==61 && data==0x77('w') → match=1
//   EOP 时 match=1 → frame_hit=1 → extract SM 搬帧进 FIFO
localparam CNT  = 61;       // 检查字节偏移
localparam DATA = 8'h77;    // 期望值 'w'

reg  match;  // 默认为 1, 不匹配时清零

always @(negedge reset_l or posedge clk)
  if (!reset_l) begin
    match  <= 1'b1;
  end else if (mac_rx_sop && mac_rx_en) begin
    match  <= 1'b1;                     // 新帧开始, 重置匹配
  end else begin
    if (!mac_rx_eop && mac_rx_en) begin
      // cnt==61 时检查 data==0x77
      if ((rx_byte_cnt == CNT) && (mac_rx_data != DATA)) begin
        match  <= 1'b0;                 // 不匹配, 清零
      end
    end
  end
```

**过滤逻辑要点:**
- `match` 默认为 `1'b1`, 每帧 SOP 时复位为 `1'b1`
- 当 `rx_byte_cnt == 61` 且 `mac_rx_data != 8'h77` 时, `match` 清零
- 其他字节位置不影响 `match` 状态
- EOP 时若 `match == 1'b1` → `frame_hit = 1`, 触发 extract 搬移全帧到 FIFO
- EOP 时若 `match == 1'b0` → 帧被丢弃 (不进入 FIFO)

**与旧版 (v3.2) 的区别:**

| 项目 | v3.2 (旧) | v3.3 (新) |
|------|-----------|-----------|
| 匹配方式 | 多字节窗口掩码匹配 | 单字节精确匹配 |
| 配置方式 | `filter_data`/`filter_offset` 外部端口 | 硬接线 `localparam CNT/DATA` |
| 可配置性 | 运行时通过寄存器动态配置 | 编译时固定, 需修改 RTL 重综合 |
| 端口数 | 2 个 16-bit 输入端口 | 0 个外部端口 |
| 匹配逻辑 | `(data & mask) == (match_val & mask)` 逐字节 | `data == DATA` 单字节判断 |
| 窗口范围 | `[start_offset, start_offset+check_count)` | 固定单字节偏移 61 |

- `filter_data`/`filter_offset` 端口已**移除**, 不再需要 LCPU 寄存器配置过滤参数
- **匹配条件**: 帧的第 61 字节 (0-indexed) 必须等于 `0x77` ('w' 字符)
- **不匹配**: 帧被丢弃, **不会**进入 `package_fifo_v2`
- **满丢弃**: 若 FIFO 满但仍有包要推入 → `recv_pkt_drop_cnt` 递增 (带饱和保护, 停在 0xFF)
- **修改过滤条件**: 需要修改 `localparam CNT` 和 `localparam DATA` 的值, 重新综合

#### 3.5.4 LCPU 读包接口 (cpu_rd_*)

`cpu_channel` 将 RX `package_fifo_v2` 的读侧暴露为 LCPU 接口:

| 信号 | 方向 | 时钟域 | 描述 |
|------|------|--------|------|
| `cpu_rd_empty` | output | cpu_clk | 无包可读 |
| `cpu_rd_rpkt_pop` | input | cpu_clk | LCPU 通知读完, 弹出下一包 |
| `cpu_rd_rpkt_len` | output | cpu_clk | 当前包长度 (字节数) |
| `cpu_rd_rpkt_para` | output | cpu_clk | 当前包参数 |
| `cpu_rd_ren` | input | cpu_clk | LCPU 读使能 |
| `cpu_rd_raddr` | input | cpu_clk | 包内偏移地址 |
| `cpu_rd_rdata` | output | cpu_clk | 读数据 |
| `cpu_rd_reop_pre` | output | cpu_clk | 包尾预指示 |

#### 3.5.5 LCPU 写包接口 (cpu_wr_*)

`cpu_channel` 同时提供了 CPU 写包接口，用于 LCPU 主动发送数据包 (如回应包、配置包等):

```
cpu_wr_* → package_fifo_v2 (TX, cpu_clk→clk) → pktfifo2ram_int_v2 → sop_eop_gen → mac_tx_*
```

| 信号 | 方向 | 时钟域 | 描述 |
|------|------|--------|------|
| `cpu_wr_full` | output | cpu_clk | TX FIFO 满 |
| `cpu_wr_wen` | input | cpu_clk | CPU 写使能 |
| `cpu_wr_waddr` | input | cpu_clk | 写地址 |
| `cpu_wr_wdata` | input | cpu_clk | 写数据 |
| `cpu_wr_wpkt_push` | input | cpu_clk | 包写完, 推入 FIFO |
| `cpu_wr_wpkt_len` | input | cpu_clk | 包数据长度 |
| `cpu_wr_wpkt_para` | input | cpu_clk | 包参数 |

---

### 3.6 TX 通路 — cpu_channel 内部透传回环 + CPU 注入

**回环 TX 通路内置于 `cpu_channel` v3.3**, 不需要独立模块:

```
                    cpu_channel 内部 TX 通路
                    ═══════════════════════════════════════════

  mac_rx_en ──▶ [透传延迟线 4拍] ──▶ pt_en/pt_data
                                       │
  cpu_wr_* ──▶ [package_fifo_v2 TX] ──▶ [pktfifo2ram_int_v2] ──▶ cpu_tx_en/cpu_tx_data
                                       │
                                       ▼
                                   [MUX: CPU 优先]
                                       │
                                       ▼
                                  final_tx_en / final_tx_data
                                       │
                                       ▼
                                  sop_eop_gen ──▶ mac_tx_sop/en/data/eop/err
```

**透传回环 (Pass-through):**
```verilog
// PASS_THROUGH_DELAY = 4 拍延迟线
pt_en_dly  <= {pt_en_dly[2:0], mac_rx_en};
pt_data_dly[0] <= mac_rx_data;
// ... 流水线延迟 ...
assign pt_en   = pt_en_dly[3];
assign pt_data = pt_data_dly[3];
```

**CPU 注入 (CPU Injection):**
```verilog
// CPU 通过 cpu_wr_* 写包 → package_fifo_v2 (cpu_clk→clk)
// → pktfifo2ram_int_v2 (自动读包, IPG=8)
// → cpu_tx_en/cpu_tx_data
```

**MUX 优先级:**
```verilog
assign final_tx_en   = cpu_tx_en ? cpu_tx_en : pt_en;
assign final_tx_data = cpu_tx_en ? cpu_tx_data : pt_data;
```

- CPU 有包要发时 (`cpu_tx_en=1`) → 走 CPU 注入路径
- CPU 无包时 → 走透传回环路径 (RX 数据直接回环到 TX)

---

### 3.7 `mac_tx` — CRC 插入

**源代码:** `/home/huamingh/work/FPGA_Prj/rtl/mac/mac_tx.v`

直接复用现有代码。功能:
1. 接收 `mac_tx_sop/en/data/eop/err` 格式的数据 (来自 `cpu_channel` 的 TX 输出)
2. 使用 `crc` 模块 (CRC-32) 计算 FCS
3. 通过 `fix_delay` (4 周期, 9bit) 对齐数据与 CRC
4. CRC 完成后, 在帧尾追加 4 字节 FCS (MSB first)
5. 输出 `tx_en/tx_data` → `gmii_to_rgmii` → RGMII TX

---

## 4. LCPU 读 FIFO 包接口设计

### 4.1 接口定义

LCPU 读包接口由 `cpu_channel` 的 `cpu_rd_*` 提供，位于 `cpu_clk` 时钟域:

```verilog
// ============================================================
// LCPU 读包接口 (cpu_clk 时钟域)
// 由 cpu_channel 内部 package_fifo_v2 (双时钟: clk_125m → cpu_clk) 提供
// ============================================================
output wire                          cpu_rd_empty;     // FIFO 空 (无包可读)
input  wire                          cpu_rd_rpkt_pop;  // CPU 通知读完当前包, 弹出下一包
output wire [ADDR_WIDTH:0]           cpu_rd_rpkt_len;  // 当前包长度 (字节数)
output wire [PARA_WIDTH-1:0]         cpu_rd_rpkt_para; // 当前包参数
input  wire                          cpu_rd_ren;       // CPU 读使能
input  wire [ADDR_WIDTH-1:0]         cpu_rd_raddr;     // CPU 读地址 (包内偏移)
output wire [DATA_WIDTH-1:0]         cpu_rd_rdata;     // CPU 读数据
output wire                          cpu_rd_reop_pre;  // 包尾预指示 (提前1拍)
```

### 4.2 读包流程

```
LCPU 读包流程:
1. 检测 cpu_rd_empty == 0 (有包可读)
2. 读取 cpu_rd_rpkt_len 获取包长度
3. 设置 cpu_rd_raddr = 0, cpu_rd_ren = 1
4. 每个时钟周期递增 raddr, 读取 rdata
5. 检测 cpu_rd_reop_pre == 1 (最后 1 拍)
6. 读完最后 1 拍后, 拉高 cpu_rd_rpkt_pop = 1 (弹出下一个包)
7. 回到步骤 1

时序波形:
              ┌─┐
rpkt_pop  ────┘ └───────────────────────────────────────────
                   ┌─────────────────────────────────
rpkt_len  ─────────┤  0x40  (64 字节)
                   └─────────────────────────────────
              ┌──────────────────────────────────────────────┐
ren        ──┘                                              └─
              00  01  02 ... 3E  3F
raddr      ───┬───┬───┬─────┬───┬─────────────────────────────
              D0   D1  D2 ... D62 D63
rdata      ───┬───┬───┬─────┬───┬─────────────────────────────
                                               ┌─┐
reop_pre   ────────────────────────────────────┘ └───────────
```

### 4.3 cpu_channel 内部数据通路

```
                    cpu_channel 内部
                    ═══════════════════════════════════════════

  mac_rx_en ──┬──▶ 地址计数器 (rx_byte_cnt++)
              │
              ├──▶ frame_buf[Block RAM] — 全帧缓存
              │    │  写使能: mac_rx_en && !extract_active
              │    │  写地址: rx_byte_cnt (0 起始)
              │    │
              │    │  ★ 硬接线过滤: match 默认为 1
              │    │     rx_byte_cnt==61 && mac_rx_data!=0x77 → match=0
              │    │
              │    ▼
              │    extract SM: EOP + match=1 后逐字节搬出
              │    │
              │    ▼
              │    ram2pktfifo_int
              │    │  ram_wen  = extract_ram_wen
              │    │  ram_wdata = extract_ram_wdata
              │    │  ram_waddr = extract_ram_waddr
              │    │
              │    │  ★ 打拍计长度: wen 有效时 wpkt_len 自增
              │    │  ★ 包完成检测: ~ram_wen & wen → wpkt_push
              │    │
              │    ▼
              │    package_fifo_v2 (RX, dual_clock=1)
              │    │  wclk  = clk (125MHz)   ← MAC 时钟域
              │    │  rclk  = cpu_clk (50MHz) ← CPU 时钟域
              │    │  block_mode = "false"
              │    │
              │    │  ★ 双时钟 CDC: pulse_clock_region_pass 处理 pop 事件
              │    │  ★ 数据存储: simple_dual_port_ram (双口RAM, 各侧独立时钟)
              │    │
              │    ▼
              │    cpu_rd_empty / cpu_rd_rpkt_len / cpu_rd_rpkt_para
              │    cpu_rd_rdata / cpu_rd_reop_pre
              │    cpu_rd_ren / cpu_rd_raddr / cpu_rd_rpkt_pop
              │
              │    → LCPU (在 cpu_clk 域读包)
              │
  (过滤器硬接线) match=0 → 帧丢弃, 不进 FIFO
```

### 4.4 LCPU 寄存器映射 (参考 cpu_channel_reg.v)

寄存器映射如下 (与 `cpu_channel_reg.v` 一致, v3.3 已移除 FILTER_CFG/FILTER_OFS):

| 地址 | 名称 | 访问 | 位段 | 描述 |
|------|------|------|------|------|
| 0x00 | CPU_RD_EMPTY | RO | [0] cpu_rd_empty | 读 FIFO 空标志 (1=无包可读) |
| 0x01 | CPU_RD_POP | RW | [0] rpkt_pop | 弹出当前包 (写 1 弹出, 自动清零) |
| 0x02 | PKT_LEN | RO | [31:0] rpkt_len | 当前包长度 (字节数) |
| 0x03 | CPU_RD_REN | RW | [0] ren | 读使能 |
| 0x04 | CPU_RD_ADDR | RW | [31:0] raddr | 包内偏移地址 |
| 0x05 | RD_DATA | RO | [31:0] rdata | 读 FIFO 数据 (返回当前 raddr 处字节) |
| 0x10 | CPU_WR_FULL | RO | [0] cpu_wr_full | 写 FIFO 满标志 |
| 0x11 | CPU_WR_WEN | RW | [0] wen | 写使能 |
| 0x12 | CPU_WR_ADDR | RW | [31:0] waddr | 写地址 (包内偏移) |
| 0x13 | CPU_WR_DATA | RW | [31:0] wdata | 写数据 |
| 0x14 | CPU_WR_LEN | RW | [31:0] wpkt_len | 发包长度 |
| 0x15 | CPU_WR_PUSH | RW | [0] wpkt_push | 包写完推入 FIFO |

**注:** 过滤器已硬接线 (`localparam CNT=61, DATA=8'h77`), 不再需要 FILTER_CFG/FILTER_OFS 寄存器。修改过滤条件需改 RTL 重综合。

**RD_DATA 读操作说明:**
- 读 0x05 时, `cpu_channel_reg` 将当前 `cpu_rd_raddr` 处的数据返回
- 每读一次 `RD_DATA`, `raddr` 自动递增, 方便连续读包
- 读完所有字节后写 0x01 (`CPU_RD_POP=1`) 弹出包
- 非 3 拍流水线 FSM, 直接用 `ack` 返回 `reg_ack`

---

## 5. 数据流与波形时序

### 5.1 完整数据通路 (一帧从 RX 到 TX)

```
时间 →

PHY RGMII RX (DDR):
  RXC:    _|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_
  RXD:    X55X55X55X55X55X55X55XD5XDAXSAX...XCRCXCRCXCRCXCRC

rgmii_to_gmii 输出 (GMII RX @ gmii_rx_clk):
  dv:     ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\___
  data:   XX_55_55_55_55_55_55_55_D5_DA_SA_..._CRC0_..._CRC3_XX

preamble_remove 输出 (pr_dv/pr_data @ gmii_rx_clk):
  pr_dv:  ________________________‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\___
  pr_data:XXXXXXXXXXXXXXXXXXXXXXXX_DA_SA_..._CRC0_..._CRC3_XX

CDC FIFO 输出 → mac_rx 输入 @ clk_125m:
  rx_en:  ________________________‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\___

mac_rx 输出 → cpu_channel:
  sop:    ________________________‾\________________________________
  en:     ________________________‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\___
  eop:    ______________________________________________________‾\_
  err:    ________________________________________________________‾\_

cpu_channel 内部 frame_buf + extract SM:
  frame_hit:  ___________________________________________________‾\_
  extract_active: ________________________________________________‾‾‾\___
  extract_ram_wen: ________________________________________________‾‾‾\___
  wpkt_push: ______________________________________________________‾\_
  wpkt_len:  XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX_N_

cpu_channel 内部 package_fifo_v2 (RX → cpu_clk):
  cpu_rd_empty: ‾\___________________________________________________  (在 cpu_clk 域)

cpu_channel 内部 TX 透传延迟线 → sop_eop_gen:
  cpu_tx_en:   ___________________‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\___
  cpu_tx_data: XXXXXXXXXXXXXXXXXXX_DA_SA_..._Payload_...(含新CRC)_XX
  tx_en:   ___________________‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\___
  tx_data: XXXXXXXXXXXXXXXXXXX_DA_SA_..._Payload_..._FCS0_..._FCS3_XX

gmii_to_rgmii 输出 (RGMII TX DDR):
  TXC:    _|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_
  TXD:    XX_DA_l_DA_h_SA_l_SA_h_..._FCS3_l_FCS3_h_XX
```

### 5.2 关键时序约束

| 路径 | 源时钟 | 目的时钟 | CDC 方式 | 备注 |
|------|--------|----------|----------|------|
| rgmii_rxc → gmii_rx_clk | RGMII RXC | (同源, BUFG) | 无需 CDC | 同一时钟 |
| gmii_rx_clk → clk_125m | RGMII RXC | MMCM 125M | dual_clock_fifo | 异步 CDC, Gray 码指针 |
| clk_125m → cpu_clk | MMCM 125M | CPU 时钟 | package_fifo_v2 内部 CDC | pulse_clock_region_pass + dual_clock_fifo |

---

## 6. 参数配置建议

### 6.1 地址宽度

| 参数 | 推荐值 | 适用模块 | 说明 |
|------|--------|----------|------|
| `CPU_BUF_ADDR_WIDTH` | 11 | cpu_channel | 最大 2048 字节/包, 支持 Jumbo Frame |
| `CPU_BUF_BLOCK_ADDR_WIDTH` | 3 | cpu_channel | 8 个 block |
| `PASS_THROUGH_DELAY` | 4 | cpu_channel | 透传延迟拍数 |
| `RX_PREAMBLE_STRIP` | 0 | cpu_channel | ★ 前导码已剥离, 内部不跳过 |

### 6.2 cpu_channel 参数

```verilog
// cpu_channel 参数配置
parameter CPU_BUF_ADDR_WIDTH       = 11;     // 地址宽度 (2048深度)
parameter CPU_BUF_BLOCK_MODE       = "false";// 非 block 模式 (与 block_mode="true" 二选一)
parameter CPU_BUF_BLOCK_ADDR_WIDTH = 3;
parameter CPU_BUF_DATA_WIDTH       = 8;      // 字节宽度
parameter CPU_BUF_PARA_WIDTH       = 3;      // 参数宽度
parameter CPU_BUF_DATA_RAM_TYPE    = "M9K";  // Block RAM
parameter CPU_BUF_PARA_RAM_TYPE    = "registers"; // 参数用分布式RAM
```

### 6.3 cpu_channel TX 参数 (内部透传回环)

```verilog
// cpu_channel TX 参数 (内部透传回环)
parameter PASS_THROUGH_DELAY = 4;  // 透传延迟拍数
// cpu_channel 内部 pktfifo2ram_int_v2 IPG = 8 拍 (64ns)
```

---

## 7. 文件清单

### 7.1 需要复用的 RTL 文件 (从 `/home/huamingh/work/FPGA_Prj/rtl/` 复制)

| 源路径 | 目的路径 | 模块名 | 说明 |
|--------|----------|--------|------|
| `rtl/mac/crc.v` | `rtl/crc.v` | `crc` | CRC 计算 (CRC-32 等 7 种) |
| `rtl/mac/mac_rx.v` | `rtl/mac_rx.v` | `mac_rx` | MAC RX + CRC 校验 |
| `rtl/mac/mac_tx.v` | `rtl/mac_tx.v` | `mac_tx` | MAC TX + CRC 插入 |
| `rtl/mac/sop_eop_gen.v` | `rtl/sop_eop_gen.v` | `sop_eop_gen` | en → sop/eop 生成 |
| `rtl/mac/simple_dual_port_ram.v` | `rtl/simple_dual_port_ram.v` | `simple_dual_port_ram` | 双口 RAM |
| `rtl/mac/fix_delay.v` | `rtl/fix_delay.v` | `fix_delay` | 固定延迟线 |
| `rtl/cpu_channel/RTL/cpu_channel.v` | `rtl/cpu_channel.v` | **`cpu_channel`** | **★ CPU 数据通道 (LCPU读包+RAM拦截计长)** |
| `rtl/cpu_channel/RTL/ram2pktfifo_int.v` | `rtl/ram2pktfifo_int.v` | `ram2pktfifo_int` | RAM→包FIFO |
| `rtl/cpu_channel/RTL/package_fifo_v2.v` | `rtl/package_fifo_v2.v` | `package_fifo_v2` | 包 FIFO |
| `rtl/cpu_channel/RTL/pkgtfifo2ram_int_v2.v` | `rtl/pkgtfifo2ram_int_v2.v` | `pktfifo2ram_int_v2` | 包FIFO→RAM + IPG |
| `rtl/cpu_channel/RTL/dual_clock_fifo.v` | `rtl/dual_clock_fifo.v` | `dual_clock_fifo` | 异步 FIFO (Gray 码 CDC) |
| `rtl/cpu_channel/RTL/single_clock_fifo.v` | `rtl/single_clock_fifo.v` | `single_clock_fifo` | 同步 FIFO |
| `rtl/cpu_channel/RTL/pulse_clock_region_pass.v` | `rtl/pulse_clock_region_pass.v` | `pulse_clock_region_pass` | 脉冲 CDC |
| `rtl/cpu_channel/rgmii2gmii/rgmii_gmii_bridge.v` | `rtl/rgmii_gmii_bridge.v` | `rgmii_gmii_bridge` | RGMII↔GMII 桥顶层 |
| `rtl/cpu_channel/rgmii2gmii/gmii_to_rgmii.v` | `rtl/gmii_to_rgmii.v` | `gmii_to_rgmii` | GMII→RGMII TX (ODDR) |
| `rtl/cpu_channel/rgmii2gmii/rgmii_to_gmii.v` | `rtl/rgmii_to_gmii.v` | `rgmii_to_gmii` | RGMII→GMII RX (IDELAYE2+IDDR) |

### 7.2 需要新建的 RTL 文件

| 文件路径 | 模块名 | 说明 |
|----------|--------|------|
| `mac/preamble_remove.v` | `preamble_remove` | 前导码去除 (新增, v1.1 含异常检测) |
| `rgmii_gmii_loopback_top.v` | `rgmii_gmii_loopback_top` | 顶层, 连接所有子模块 (v1.1: TX 由 cpu_channel 内部处理) |

### 7.3 LCPU 寄存器桥接文件

| 文件路径 | 模块名 | 说明 |
|----------|--------|------|
| `cpu/cpu_channel_reg.v` | `cpu_channel_reg` | LCPU 寄存器桥接 (已存在, 提供 CPU_RD/PKT_LEN/RD_DATA/CPU_WR 寄存器, 过滤器已硬接线) |

| 文件路径 | 说明 |
|----------|------|
| `sim/tb_loopback.v` | 顶层仿真 Testbench |
| `sim/tb_common.vh` | 共享 TB 基础设施 (时钟/复位/PHY 模型/发包任务/LCPU读包任务) |
| `sim/sim_models.v` | Xilinx 原语行为模型 (BUFG/IDDR/ODDR/IDELAYE2/IDELAYCTRL) |
| `sim/run_sim.sh` | 仿真脚本 (iverilog + GTKWave) |
| `sim/tb_loopback.tcl` | GTKWave 信号显示配置 |

### 7.4 需要新建的约束文件

| 文件路径 | 说明 |
|----------|------|
| `xdc/loopback.xdc` | 管脚约束 + 时序约束 (clk_125m, rgmii, idelay_refclk) |

---

## 8. 仿真验证方案

### 8.1 参考现有仿真框架

复用 `/home/huamingh/work/FPGA_Prj/test/sgmii_sgmii/sim/` 的仿真架构:

```
sim/
  tb_common.vh      — 共享 TB 基础设施
  sim_models.v      — Xilinx 原语行为模型
  tb_loopback.v     — 顶层 Testbench
  run_sim.sh        — 编译运行脚本
```

### 8.2 Testbench 关键组件

```verilog
// tb_common.vh 中需要提供:

// 1. 时钟生成
reg clk_125m      = 0;  always #4     clk_125m      = ~clk_125m;      // 125MHz
reg idelay_refclk = 0;  always #2.5   idelay_refclk = ~idelay_refclk; // 200MHz
reg cpu_clk       = 0;  always #10    cpu_clk       = ~cpu_clk;       // 50MHz

// 2. RGMII PHY 行为模型
//   - RXC = 125MHz (与 clk_125m 不同源, 有微小频偏模拟真实场景)
//   - RXD[3:0] + RX_CTL 在 RXC pos/neg 沿驱动 (DDR)
//   - 接收 TXC/TXD[3:0]/TX_CTL, 做回环数据比较

// 3. 发包任务 (含前导码)
task send_rgmii_frame(input [7:0] frame_data[0:FRAME_LEN-1]);
  // 自动添加 8 字节前导码 (7×0x55 + 1×0xD5)
  // 生成 RGMII DDR 时序:
  //   posedge RXC: {rx_ctl, rxd[3:0]} = {dv, data[3:0]}
  //   negedge RXC: {rx_ctl, rxd[3:0]} = {dv^er, data[7:4]}
endtask

// 4. LCPU 读包仿真任务 (测试 cpu_channel 的 cpu_rd_* 接口)
task cpu_read_packet();
  wait(cpu_rd_empty == 0);      // 等待 cpu_channel 中有包
  $display("CPU: pkt_len = %d", cpu_rd_rpkt_len);
  for (i = 0; i < cpu_rd_rpkt_len; i = i + 1) begin
    @(posedge cpu_clk);
    cpu_rd_raddr = i;
    cpu_rd_ren = 1;
    @(posedge cpu_clk);          // rdata 在下一拍有效
    $display("  [%0d] = 0x%02h", i, cpu_rd_rdata);
  end
  cpu_rd_ren = 0;
  cpu_rd_rpkt_pop = 1;
  @(posedge cpu_clk);
  cpu_rd_rpkt_pop = 0;
endtask

// 5. 回环数据比较任务
task check_loopback_data();
  // 从 RGMII TX 侧采集回环输出
  // 与原始发送的帧数据 (去除前导码后) 进行逐字节比较
endtask
```

### 8.3 仿真步骤

参考现有 5 步仿真流程:

1. **Step 1 — 时钟与复位验证:** 检查所有时钟稳定、复位释放、MMCM 锁定
2. **Step 2 — RGMII RX 入口验证:** 发送最小帧, 检查 `rgmii_to_gmii` 输出 GMII 信号正确
3. **Step 3 — 前导码去除验证:** 检查 `preamble_remove` 是否正确去除前 8 字节, SFD 之后透传
4. **Step 4 — CRC + cpu_channel 验证:**
   - 检查 `mac_rx` CRC 校验结果
   - 检查 `cpu_channel` 内部 `ram2pktfifo_int` 打拍计算的 `wpkt_len` 与实际帧长一致
   - 检查 `cpu_channel` 的 `cpu_rd_*` 接口能正确读到包数据
5. **Step 5 — 全链路回环 + LCPU 读包:**
   - 发送 5 帧 burst 流量 (含正确 CRC 和 1 帧错误 CRC)
   - 检查 `cpu_channel` 的 TX 输出 (透传回环) 数据与发送数据一致 (DA ~ Payload, 不含前导码)
   - 检查 RGMII TX 输出的回环数据完整 (mac_tx 重新插入了 CRC)
   - 检查 `cpu_channel` 的 `cpu_rd_*` 接口能独立读到每包数据
   - 验证 CRC 正确/错误包统计正确

### 8.4 快速仿真脚本

```bash
#!/bin/bash
# run_sim.sh — 参考 sgmii_sgmii/sim/run_sim.sh

iverilog -o tb_loopback.vvp \
    ../cpu/cpu_channel.v \
    ../cpu/cpu_channel_reg.v \
    ../cpu/ram2pktfifo_int.v \
    ../cpu/package_fifo.v \
    ../cpu/pktfifo2ram_int_v2.v \
    ../cpu/single_clock_fifo.v \
    ../cpu/pulse_clock_region_pass.v \
    ../mac/crc.v \
    ../mac/mac_rx.v \
    ../mac/mac_tx.v \
    ../mac/sop_eop_gen.v \
    ../mac/fix_delay.v \
    ../mac/preamble_remove.v \
    ../rgmii2gmii/rgmii_gmii_bridge.v \
    ../rgmii2gmii/gmii_to_rgmii.v \
    ../rgmii2gmii/rgmii_to_gmii.v \
    ../rgmii2gmii/simple_dual_port_ram.v \
    ../rgmii2gmii/mmcm_50_125.v \
    ../AMD/RTL/jtag_cpu_amd_core.v \
    ../AMD/RTL/axi2lcpu.v \
    ../rgmii_gmii_loopback_top.v \
    sim_models.v \
    tb_loopback.v \
    -g2012

vvp tb_loopback.vvp -fst
gtkwave tb_loopback.fst tb_loopback.tcl
```

---

## 9. LCPU JTAG 读包通路

### 9.1 通路概览

```
  Vivado HW Manager (PC)
       │ JTAG
       ▼
  ┌──────────────┐
  │ jtag_axi_0   │  Xilinx IP: JTAG → AXI4-Lite Master
  │ (XCI IP)     │
  └──────┬───────┘
         │ AXI4-Lite (m_axi_aw/w/ar/r)
         ▼
  ┌──────────────┐
  │ axi2lcpu     │  AXI4-Lite Slave → LCPU Register Bus
  │              │  3-state FSM: IDLE → WAIT → DONE
  └──────┬───────┘
         │ lcpu_req / lcpu_rh_wl / lcpu_address[31:0]
         │ lcpu_wdata[31:0] / lcpu_rdata[31:0] / lcpu_ack
         ▼
  ┌──────────────┐
  │ cpu_channel  │  LCPU Bus → cpu_channel Register Bridge
  │ _reg         │
  │              │  0x00: CPU_RD_EMPTY  [0] 读FIFO空
  │              │  0x01: CPU_RD_POP    [0] 弹出当前包
  │              │  0x02: PKT_LEN       [31:0] 当前包长度
  │              │  0x03: CPU_RD_REN    [0] 读使能
  │              │  0x04: CPU_RD_ADDR   [31:0] 包内偏移地址
  │              │  0x05: RD_DATA       [31:0] 读1字节
  │              │  0x10: CPU_WR_FULL   [0] 写FIFO满
  │              │  0x11: CPU_WR_WEN    [0] 写使能
  │              │  0x12: CPU_WR_ADDR   [31:0] 写地址
  │              │  0x13: CPU_WR_DATA   [31:0] 写数据
  │              │  0x14: CPU_WR_LEN    [31:0] 发包长度
  │              │  0x15: CPU_WR_PUSH   [0] 推包
  │              │  (过滤器硬接线: CNT=61, DATA=0x77)
  └──────┬───────┘
         │ cpu_rd_rpkt_pop/cpu_rd_ren/cpu_rd_raddr
         │ cpu_rd_empty/cpu_rd_rpkt_len/cpu_rd_rdata/cpu_rd_reop_pre
         ▼
  ┌──────────────┐
  │ cpu_channel  │  (cpu_clk 域的 cpu_rd_* 接口)
  └──────────────┘
```

### 9.2 LCPU 总线协议

```
lcpu_req     ___/‾‾‾‾‾‾‾‾‾‾‾‾‾‾\_____________________
lcpu_rh_wl   ___/‾‾‾‾‾‾‾‾‾‾‾‾‾‾\_____________________  (0=写, 1=读)
lcpu_address ────< ADDR >──────────────────────────────
lcpu_wdata   ────< DATA >──────────────────────────────  (写操作时有效)
lcpu_rdata   ─────────────────────< RDATA >────────────  (读操作时有效)
lcpu_ack     ______________________/‾‾‾‾‾‾\____________  (cpu_channel_reg 响应)
```

### 9.3 RD_DATA 读操作 (cpu_channel_reg)

读 0x05 (`RD_DATA`) 寄存器时, `cpu_channel_reg` 直接返回当前 `cpu_rd_raddr` 对应的字节数据:

```
读操作流程:
1. 写 0x04 (CPU_RD_ADDR) 设置要读的包内偏移
2. 写 0x03 (CPU_RD_REN=1) 使能读
3. 读 0x05 (RD_DATA) 获取数据, raddr 自动递增
4. 重复步骤 3 直到读完所有字节
5. 写 0x01 (CPU_RD_POP=1) 弹出当前包
```

**注:** 与旧版不同, `cpu_channel_reg` v3.3 不再使用 3 拍 FSM 流水线, 读请求直接通过 `reg_ack` 返回。

### 9.4 TCL 抓包流程 (lcpu_capture.tcl)

```tcl
# 过滤器已硬接线 (CNT=61, DATA=0x77), 无需配置过滤参数
# 约 3 秒后应有命中帧

# 1. 等待命中帧
while {1} {
    set empty [rd32 0x00]           # 读 CPU_RD_EMPTY
    if {$empty == 0} break          # empty=0 → 有包
    after 100
}

# 2. Pop 包 (使 rpkt_len 有效)
jwrite 0x01 1                       # CPU_RD_POP=1

# 3. 读包长度
set pkt_len [rd32 0x02]

# 4. 设置读地址从 0 开始, 使能读
jwrite 0x04 0                       # CPU_RD_ADDR = 0
jwrite 0x03 1                       # CPU_RD_REN = 1

# 5. 读包数据
for {set i 0} {$i < $pkt_len} {incr i} {
    set byte [rd32 0x05]
    puts -nonewline [format "%02X " $byte]
}

# 一键验证流程:
lcpu_quick_test
# → lcpu_flush           清空FIFO
# → lcpu_status          查看寄存器
# → wait_hit 5000        等待命中 (过滤条件已硬接线)
# → 读包→打印 MAC/IP 头
```

### 9.5 子模块来源

| 模块 | 文件 | 说明 |
|------|------|------|
| `jtag_axi_0` | `AMD/RTL/jtag_axi_0.xci` | Xilinx IP, JTAG→AXI4-Lite Master |
| `axi2lcpu` | `AMD/RTL/axi2lcpu.v` | AXI→LCPU bus 桥, 3态FSM |
| `jtag_cpu_amd_core` | `AMD/RTL/jtag_cpu_amd_core.v` | 封装 `jtag_axi_0` + `axi2lcpu` |
| `cpu_channel_reg` | `cpu/cpu_channel_reg.v` | LCPU bus → cpu_channel 寄存器桥 |
| `LCPU_AMD_Driver.tcl` | `AMD/TCL/` | 底层: `rd32`, `jwrite`, `jread` |
| `lcpu_capture.tcl` | `AMD/TCL/` | 抓包脚本: filter配置, wait_hit, capture |
| `lcpu_start.tcl` | `AMD/TCL/` | 一键启动: 连接HW→加载驱动→抓包 |

```
rgmii_gmii_loopback_top
  │
  ├── mmcm_50_125 (50MHz→125MHz+200MHz MMCME2_BASE)
  │
  ├── rgmii_gmii_bridge
  │     ├── gmii_to_rgmii (ODDR ×6, TX: SDR→DDR)
  │     └── rgmii_to_gmii (IDELAYCTRL + IDELAYE2 ×5 + IDDR ×5 + BUFG, RX: DDR→SDR)
  │
  ├── preamble_remove (★新增, gmii_rx_clk 域)
  │     └── FSM: IDLE → PREAMBLE → FRAME (含异常检测)
  │
  ├── dual_clock_fifo (CDC: gmii_rx_clk → clk_125m, 16深, 8bit)
  │
  ├── mac_rx
  │     ├── crc (CRC-32, 8bit 输入)
  │     └── sop_eop_gen (en → sop/eop)
  │
  ├── cpu_channel (★ v3.3, RX_PREAMBLE_STRIP=0, 过滤器硬接线)
  │     ├── [preamble 跳过] — 参数控制, =0 时不跳过
  │     ├── frame_buf (Block RAM, 全帧缓存)
  │     ├── [硬接线单字节过滤] (localparam CNT=61, DATA=8'h77)
  │     ├── extract SM (命中后 frame_buf → ram2pktfifo_int)
  │     ├── ram2pktfifo_int (RAM写拦截 + 打拍计长度)
  │     ├── package_fifo_v2 (RX: clk → cpu_clk, dual_clock=1)
  │     │     └── simple_dual_port_ram (双口 RAM)
  │     ├── package_fifo_v2 (TX: cpu_clk → clk, dual_clock=1)
  │     │     └── simple_dual_port_ram (双口 RAM)
  │     ├── pktfifo2ram_int_v2 (TX 读包 + IPG=8)
  │     ├── [透传延迟线] (PASS_THROUGH_DELAY=4)
  │     ├── [CPU 注入 MUX] (CPU 优先于透传)
  │     └── sop_eop_gen (en → sop/eop, TX 输出)
  │
  └── mac_tx
        ├── crc (CRC-32, 8bit 输入)
        └── fix_delay (4 周期, 9bit, 数据对齐)
```

## 附录 B: 前导码去除状态机 (FSM 图)

```
                   ┌──────────┐
          reset ──▶│  IDLE    │
                   └────┬─────┘
                        │ rx_dv=1
                        ▼
                   ┌──────────┐
             ┌────▶│ PREAMBLE │
             │     └────┬─────┘
             │          │
             │    ┌─────┴─────┐
             │    │ cnt<7     │──→ 期望 data=0x55, cnt++
             │    │ data=0x55 │
             │    ├───────────┤
             │    │ cnt=7     │──→ 期望 data=0xD5 (SFD), 进入 FRAME
             │    │ data=0xD5 │
             │    ├───────────┤
             │    │ 异常      │──→ 非 0x55/D5, 回到 IDLE
             │    └───────────┘
             │          │ sf_detected
             │          ▼
             │     ┌──────────┐
             └─────│  FRAME   │  rx_dv=0 ──→ IDLE
        rx_dv=1   └──────────┘
                  透传数据, pr_dv=1
```

## 附录 C: CRC-32 Magic Number

以太网 CRC-32 校验的 Magic Number:

```verilog
parameter CRC32_MAGIC = 32'h1cdf4421;  // 正确帧的 CRC 残余值
assign crc_err = (crc_out == CRC32_MAGIC) ? 1'b0 : crc_done;
```

CRC-32 多项式: `x^32 + x^26 + x^23 + x^22 + x^16 + x^12 + x^11 + x^10 + x^8 + x^7 + x^5 + x^4 + x^2 + x + 1`
即 `0x04C11DB7` (反映射: `0xEDB88320`)

## 附录 D: 关键信号速查表

| 信号名 | 宽度 | 方向 | 时钟域 | 描述 |
|--------|------|------|--------|------|
| `rgmii_rxc` | 1 | input | — | RGMII RX 时钟 (125MHz DDR) |
| `rgmii_rxd` | 4 | input | — | RGMII RX 数据 (DDR) |
| `rgmii_rx_ctl` | 1 | input | — | RGMII RX 控制 (DDR) |
| `rgmii_txc` | 1 | output | — | RGMII TX 时钟 (125MHz DDR) |
| `rgmii_txd` | 4 | output | — | RGMII TX 数据 (DDR) |
| `rgmii_tx_ctl` | 1 | output | — | RGMII TX 控制 (DDR) |
| `clk_125m` | 1 | input | — | 系统主时钟 (125MHz) |
| `idelay_refclk` | 1 | input | — | IDELAY 参考时钟 (200MHz) |
| `cpu_clk` | 1 | input | — | CPU 时钟 (典型 50MHz) |
| `rst_n` | 1 | input | — | 异步复位, 低有效 |
| `cpu_rd_empty` | 1 | output | cpu_clk | CPU 读 FIFO 空 |
| `cpu_rd_rpkt_pop` | 1 | input | cpu_clk | 弹出当前包 |
| `cpu_rd_rpkt_len` | 12 | output | cpu_clk | 当前包长度 |
| `cpu_rd_ren` | 1 | input | cpu_clk | CPU 读使能 |
| `cpu_rd_raddr` | 11 | input | cpu_clk | 包内偏移地址 |
| `cpu_rd_rdata` | 8 | output | cpu_clk | CPU 读数据 |
| `cpu_rd_reop_pre` | 1 | output | cpu_clk | 包尾预指示 |
| `cpu_wr_full` | 1 | output | cpu_clk | CPU 写 FIFO 满 |
| `cpu_wr_wen` | 1 | input | cpu_clk | CPU 写使能 |
| `cpu_wr_wdata` | 8 | input | cpu_clk | CPU 写数据 |
| `cpu_wr_wpkt_push` | 1 | input | cpu_clk | CPU 推包 |
| `cpu_wr_wpkt_len` | 12 | input | cpu_clk | CPU 发包长度 |
| `rx_stat_good_pkt` | 32 | output | clk_125m | CRC 正确包计数 |
| `rx_stat_bad_pkt` | 32 | output | clk_125m | CRC 错误包计数 |
| `tx_stat_pkt` | 32 | output | clk_125m | TX 发送包计数 |
| `pkt_drop_cnt` | 8 | output | clk_125m | 丢包计数 |

---

> **文档结束**
>
> 下一步: 基于本文档, 编写具体 RTL 代码并搭建仿真环境。
