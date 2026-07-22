# RTL 模块功能说明

> 项目: lcpu_rgmii | 更新: 2026-07-14

---

## 模块层次总览

```
rgmii_gmii_loopback_top                    ← 顶层
├── mmcm_50_125                            ← 时钟生成 (MMCM)
├── rgmii_gmii_bridge                      ← RGMII↔GMII 双向桥
│   ├── rgmii_to_gmii                      ←   RX: RGMII DDR → GMII SDR (IDELAYE2 + IDDR)
│   └── gmii_to_rgmii                      ←   TX: GMII SDR → RGMII DDR (ODDR)
├── gmii2mac                               ← GMII → MAC (CDC + 前导码)
│   ├── dual_clock_fifo                    ←   CDC: gmii_rx_clk → clk_125m
│   ├── eth_presemble                      ←   前导码检测 (0x55×7 + 0xD5)
│   └── mac_top                            ←   MAC 顶层
│       ├── mac_rx                         ←     RX: CRC32 校验 + sop/eop 成帧
│       │   ├── crc                        ←       CRC32 计算器
│       │   └── sop_eop_gen                ←       en → sop/eop 生成
│       └── mac_tx                         ←     TX: 前导码插入 + CRC32 生成 + FCS 追加
│           ├── crc                        ←       CRC32 计算器
│           └── fix_delay                  ←       固定延迟线
├── cpu_channel                            ← CPU 数据通道 (过滤 + 提取 + 透传)
│   ├── frame_buf (Block RAM)              ←   全帧缓存
│   ├── ram2pktfifo_int                    ←   RAM 写时序 → 包 FIFO 写时序
│   ├── package_fifo_v2 (×2)              ←   包 FIFO (RX 读 + TX 写)
│   └── pktfifo2ram_int_v2                 ←   包 FIFO 读时序 → RAM 写时序
├── cpu_channel_reg                        ← LCPU 寄存器桥接
├── jtag_cpu_amd_core                      ← JTAG → LCPU 总线转换
└── axi2lcpu                               ← AXI4-Lite → LCPU 总线桥接
```

---

## 1. 顶层

### `rgmii_gmii_loopback_top.v`

**功能:** RGMII 以太网帧回环测试顶层，整合 RGMII 桥、MAC、CPU 通道、LCPU JTAG 读写。

**数据流:**
```
PC → PHY → RGMII RX → gmii2mac → cpu_channel → gmii2mac → RGMII TX → PHY → PC
                              ↓
                         LCPU JTAG 读写 (cpu_channel_reg)
```

**时钟域:**
| 时钟 | 频率 | 来源 | 用途 |
|------|------|------|------|
| `gmii_rx_clk` | 125MHz | PHY RXC | RX 恢复时钟 |
| `clk_125m` | 125MHz | MMCM CLKOUT0 | 数据面主时钟 |
| `clk_125m_tx` | 125MHz(90°) | MMCM CLKOUT2 | RGMII TXC |
| `clk_200m` | 200MHz | MMCM CLKOUT1 | IDELAYCTRL 参考 |
| `cpu_clk` | 50MHz | 外部直连 | LCPU 子系统 |

**参数:**
| 参数 | 默认值 | 说明 |
|------|--------|------|
| `CPU_BUF_ADDR_WIDTH` | 11 | 包缓冲地址宽度 (2048 字节) |
| `CPU_BUF_DATA_WIDTH` | 8 | 数据宽度 |
| `CPU_BUF_PARA_WIDTH` | 3 | 侧带参数宽度 |
| `CPU_BUF_DATA_RAM_TYPE` | "M9K" | Block RAM 类型 |
| `CPU_BUF_BLOCK_MODE` | "true" | FIFO 分块模式 |

---

## 2. 时钟生成

### `mmcm_50_125.v`

**功能:** Xilinx MMCM 时钟管理，从 50MHz 晶振生成各路工作时钟。

**输出时钟:**
| 输出 | 频率 | 相位 | 用途 |
|------|------|------|------|
| CLKOUT0 | 125MHz | 0° | 数据面主时钟 |
| CLKOUT1 | 200MHz | 0° | IDELAYCTRL 参考时钟 |
| CLKOUT2 | 125MHz | 90° | RGMII TXC (ODDR 用) |
| LOCKED | — | — | PLL 锁定指示 |

---

## 3. RGMII ↔ GMII 桥

### `rgmii_gmii_bridge.v`

**功能:** RGMII ↔ GMII 双向桥接顶层，实例化 TX 和 RX 两个子模块。

**子模块:**
- `gmii_to_rgmii` — TX: GMII → RGMII (FPGA → PHY)
- `rgmii_to_gmii` — RX: RGMII → GMII (PHY → FPGA)

---

### `gmii_to_rgmii.v`

**功能:** GMII → RGMII 发送方向转换。GMII 8bit SDR @125MHz → RGMII 4bit DDR @125MHz。

**实现:** Xilinx ODDR 原语 (OPPOSITE_EDGE 模式)
- posedge: `gmii_txd[3:0]`
- negedge: `gmii_txd[7:4]`
- TX_CTL: posedge = `TX_EN`, negedge = `TX_EN ^ TX_ER`

---

### `rgmii_to_gmii.v`

**功能:** RGMII → GMII 接收方向转换。RGMII 4bit DDR @125MHz → GMII 8bit SDR @125MHz。

**实现:** Xilinx IDELAYE2 (~1.5ns 延迟补偿) + IDDR (SAME_EDGE_PIPELINED) + BUFG

**关键修复 (v1.2):** IDELAYE2 将 RGMII RX 数据延迟 ~1.56ns 到时钟窗口中央，解决保持时间违例。

---

## 4. MAC 层

### `gmii2mac.v`

**功能:** GMII 接口 → MAC 层转换。内部包含：
1. **CDC:** `dual_clock_fifo` (gmii_rx_clk → clk_125m)，16 深度，10bit 位宽 {ER, DV, DATA}
2. **前导码剥离:** `eth_presemble` — 检测 0x55×7 + 0xD5
3. **MAC 顶层:** `mac_top` — 实例化 mac_rx + mac_tx

**RX 方向:** GMII SDR → CDC → 前导码剥离 → MAC RX (CRC32 校验) → sop/eop 格式输出

**TX 方向:** sop/eop 格式输入 → MAC TX (CRC32 + 前导码) → GMII SDR

---

### `mac_top.v`

**功能:** MAC 层顶层，实例化 `mac_rx` 和 `mac_tx`，RX_PREAMBLE_STRIP 参数控制内部前导码处理。

---

### `mac_rx.v`

**功能:** MAC 接收处理器。
1. **CRC32 校验:** 对 DA~FCS 全帧计算，Magic Residue = `32'h1cdf4421`
2. **帧格式转换:** en → sop/eop 生成 (通过 `sop_eop_gen`)
3. **丢包计数:** FCS 错误统计

**输出格式:** `mac_rx_sop` (脉冲) → `mac_rx_en` + `mac_rx_data` (帧数据) → `mac_rx_eop` (脉冲) + `mac_rx_err` (CRC 结果)

---

### `mac_tx.v`

**功能:** MAC 发送处理器。
1. **前导码插入:** 自动在帧前插入 8B 前导码 (0x55×7 + 0xD5)
2. **CRC32 生成:** 对 DA~Payload 计算 CRC32 (多项式 `x^32+x^26+...+1`)
3. **FCS 追加:** crc_done 后 4 拍将 FCS 插入帧尾 (MSB first)

---

### `eth_presemble.v`

**功能:** 以太网前导码处理。

- **RX 方向:** 检测连续 7 字节 0x55 + 1 字节 0xD5 (SFD)，`rx_valid_header=1` 后透传后续数据（剥离前导码）
- **TX 方向:** 通过 `fix_delay` 延迟 8 拍，在帧前插入 7 字节 0x55 + 1 字节 0xD5 SFD

**关键信号:**
- `rx_valid_header` — 前导码检测完成，后续数据有效

---

### `crc.v`

**功能:** 通用 CRC 计算器，支持多种多项式。

**支持标准:**
| 标准 | 多项式 | 位宽 |
|------|--------|------|
| CRC32 (Ethernet) | `x^32+x^26+...+x+1` | 32 |
| CRC-16-IBM | `x^16+x^15+x^2+1` | 16 |
| CRC-16-CCITT | `x^16+x^12+x^5+1` | 16 |
| CRC-8 | `x^8+x^2+x+1` | 8 |

**参数:**
| 参数 | 说明 |
|------|------|
| `POLYNOMIAL` | 多项式值 |
| `INIT_VALUE` | 初始值 (CRC32: `32'hFFFFFFFF`) |
| `DATA_WIDTH` | 输入数据位宽 (1~64) |
| `SYNC_RESET` | 同步复位模式 |

**CRC32 正确性判定:** 对含正确 FCS 的完整帧做 CRC, 残余值恒为 `32'h1cdf4421`。

---

### `sop_eop_gen.v`

**功能:** 从 data enable 信号生成 SOP/EOP 帧边界脉冲。

**接口:**
- 输入: `i_en`, `i_data`, `i_err`
- 输出: `o_sop` (首字节脉冲), `o_en`, `o_data`, `o_eop` (末字节脉冲), `o_err`

---

### `fix_delay.v`

**功能:** 固定周期延迟线。支持 `clk_en` 门控，数据总线宽度可配置。

**参数:**
| 参数 | 说明 |
|------|------|
| `DELAY_CYCLE` | 延迟周期数 |
| `DATA_WIDTH` | 数据位宽 |

---

## 5. CPU 数据通道

### `cpu_channel.v`

**功能:** CPU 数据包通道核心模块，负责帧过滤、全帧缓存、提取搬移、透传回环。

**数据路径:**

```
RX: mac_rx → [frame_buf 全帧缓存] → [单字节过滤] → frame_hit
                                              ↓ (命中)
           extract SM → ram2pktfifo_int → package_fifo_v2 → cpu_rd_* (LCPU 读)

TX: cpu_wr_* (LCPU 写) → package_fifo_v2 → pktfifo2ram_int_v2 → sop_eop_gen → mac_tx

透传: mac_rx → [PASS_THROUGH_DELAY 延迟] → (CPU 空时) → mac_tx
```

**过滤逻辑 (v3.3 简化版):**
```verilog
localparam FILTER_BYTE_OFFSET = 61;     // 检查字节偏移
localparam FILTER_BYTE_MATCH  = 8'h77;  // 期望值 'w'

// SOP → cnt 开始计数
// cnt==61 && data==0x77 → match=1
// EOP match=1 → frame_hit=1 → extract SM 搬帧进 FIFO
```

**关键参数:**
| 参数 | 默认值 | 说明 |
|------|--------|------|
| `cpu_buf_addr_width` | 11 | 包缓冲地址宽度 (2048 深度) |
| `RX_PREAMBLE_STRIP` | 1 | 0=已剥离前导码, 1=内部跳过 8B |
| `PASS_THROUGH_DELAY` | 4 | 透传延迟拍数 |

**内部子模块:**
| 实例 | 模块 | 功能 |
|------|------|------|
| `u_ram2pktfifo_int` | ram2pktfifo_int | extract RAM 写 → 包 FIFO 写时序 |
| `u_package_fifo_cpu_rd` | package_fifo_v2 | RX 包 FIFO (125MHz→50MHz CDC) |
| `u_package_fifo_cpu_wr` | package_fifo_v2 | TX 包 FIFO (50MHz→125MHz CDC) |
| `u_pktfifo2ram_int` | pktfifo2ram_int_v2 | 包 FIFO 读 → 连续 RAM 读时序 |
| `u_sop_eop_gen` | sop_eop_gen | en → sop/eop 帧边界生成 |

---

### `package_fifo_v2.v`

**功能:** 包级 FIFO，支持单/双时钟模式、分块/非分块模式。以"包"为单位 push/pop，每个包携带长度和侧带参数。

**特性:**
- 双时钟 CDC (wclk ↔ rclk)
- Block RAM 存储 (数据 + 侧带参数)
- 包级 push/pop 操作
- 可配置最大包长度 (`max_pkt_length`)

**接口:**
| 方向 | 信号 | 说明 |
|------|------|------|
| 写侧 | `wen`, `waddr`, `wdata` | 逐字节写入 |
| 写侧 | `wpkt_push`, `wpkt_len`, `wpkt_para` | 包推送 + 长度 + 参数 |
| 读侧 | `empty`, `rpkt_pop` | 包状态 + 弹出 |
| 读侧 | `rpkt_len`, `rpkt_para` | 包长度 + 参数 (pop 后有效) |
| 读侧 | `ren`, `raddr`, `rdata` | 逐字节读出 |

---

### `ram2pktfifo_int.v`

**功能:** RAM 写时序 → 包 FIFO 写时序转换。

将连续的 `ram_wen/wdata/waddr` RAM 写操作转换为 `wen/wdata/waddr` + `wpkt_push/wpkt_len` 包 FIFO 写操作。自动打拍计算写入字节数，在帧结束时发出 `wpkt_push`。

---

### `pktfifo2ram_int_v2.v`

**功能:** 包 FIFO 读时序 → RAM 写时序转换 (v2，支持 clock enable)。

自动从包 FIFO 弹包 (`rpkt_pop`) 并逐字节读出 (`ren/raddr/rdata`)，输出为连续的 RAM 写时序 (`ram_wen/ram_wdata`)。支持 `ipg` (Inter-Packet Gap) 可配。

---

## 6. LCPU 寄存器桥接

### `cpu_channel_reg.v`

**功能:** LCPU 总线 → CPU 通道寄存器映射。将 32-bit LCPU 总线读写转换为 `cpu_channel` 各控制信号的 pulse/level 时序。

**寄存器映射:**
| 地址 | 名称 | R/W | 位宽 | 说明 |
|------|------|-----|------|------|
| 0x00 | EMPTY | R | [0] | 0=有包待读 |
| 0x01 | POP | W | [0] | 1=弹出包 |
| 0x02 | LEN | R | [31:0] | 包长度 (pop 后有效) |
| 0x03 | REN | R/W | [0] | 读使能 |
| 0x04 | RADDR | R/W | [31:0] | 读地址 (包内偏移) |
| 0x05 | RDATA | R | [7:0] | 读数据 (ren 后 2 拍有效) |
| 0x10 | WR_FULL | R | [0] | 1=FIFO 满 |
| 0x11 | WR_WEN | W | [0] | 写使能脉冲 |
| 0x12 | WR_WADDR | R/W | [31:0] | 写地址 |
| 0x13 | WR_WDATA | R/W | [7:0] | 写数据 |
| 0x14 | WR_LEN | R/W | [31:0] | 写包长度 |
| 0x15 | WR_PUSH | W | [0] | 包推送 |

**注意:** 寄存器内部自动生成脉冲信号 (`_ind`)，避免 LCPU 写 1→0 的手动操作。包含超时保护：若 `lcpu_ack` 超过 ~0xF000 周期未响应，自动产生 `timeout_ack`，返回 `DEADDEAD`。

---

### `axi2lcpu.v`

**功能:** AXI4-Lite Slave → LCPU 寄存器总线桥接。将 JTAG-AXI IP (`jtag_axi_0`) 的 AXI4-Lite 读写转换为 LCPU 总线协议 (`lcpu_req/rh_wl/address/wdata/rdata/ack`)。

**状态机:**
```
IDLE → (ar_hs) → WAIT → (lcpu_ack) → DONE → (rvalid) → IDLE
```

---

### `jtag_cpu_amd_core.v`

**功能:** JTAG → LCPU 转换顶层 (AMD/Xilinx 专用)。实例化 `jtag_axi_0` (Xilinx IP) + `axi2lcpu`。PC 通过 JTAG 电缆访问 FPGA 内部 LCPU 总线寄存器。

---

## 7. 基础组件

### `dual_clock_fifo.v`

**功能:** 异步双时钟 FIFO，用于跨时钟域总线隔离。

**实现:** 格雷码指针 + 双寄存器同步器，安全 CDC。

**接口:** `wclk` 写时钟域 + `rclk` 读时钟域，`wen/ren` 读写使能，`full/empty` 状态。

---

### `single_clock_fifo.v`

**功能:** 同步 FIFO，单时钟域操作。

---

### `pulse_clock_region_pass.v`

**功能:** 单脉冲跨时钟域传递。将一个时钟域的单周期脉冲安全传递到另一个时钟域。

---

### `simple_dual_port_ram.v`

**功能:** 通用简单双端口 RAM，一个读端口 + 一个写端口，支持 Byte Enable。

---

## 时钟域总览

```
                    ┌──────────────────────────────────────┐
                    │           clk_125m (125MHz)          │ ← MMCM CLKOUT0
                    │  gmii2mac / mac_top / cpu_channel   │
                    │  rgmii_gmii_bridge (GMII侧)         │
                    └──────┬───────────────┬───────────────┘
                           │               │
              dual_clock   │               │ package_fifo_v2
              _fifo (CDC)  │               │ (CDC)
                           │               │
    ┌──────────────────┐   │       ┌──────────────────┐
    │ gmii_rx_clk      │   │       │ cpu_clk (50MHz)  │
    │ (125MHz, PHY RXC)│   │       │ LCPU + JTAG      │
    │ rgmii_to_gmii     │   │       │ cpu_channel_reg  │
    └──────────────────┘   │       └──────────────────┘
                           │
              ┌────────────────────────┐
              │ clk_125m_tx (90°)      │ ← MMCM CLKOUT2
              │ gmii_to_rgmii (ODDR)  │
              └────────────────────────┘
              ┌────────────────────────┐
              │ clk_200m              │ ← MMCM CLKOUT1
              │ IDELAYCTRL 参考       │
              └────────────────────────┘
```

---

## 数据流完整路径

### RX 路径 (PC → LCPU)
```
PHY (RGMII DDR)
  → rgmii_to_gmii (IDELAYE2 + IDDR)
  → dual_clock_fifo (CDC: gmii_rx_clk → clk_125m)
  → eth_presemble (前导码剥离)
  → mac_rx (CRC32 校验 → sop/eop 成帧)
  → cpu_channel:
      frame_buf (全帧缓存)
      → 单字节过滤 (cnt==61 && data==0x77 → match=1)
      → extract SM (命中后搬帧)
      → ram2pktfifo_int
      → package_fifo_v2 (CDC: clk_125m → cpu_clk)
  → cpu_channel_reg (LCPU 寄存器)
  → axi2lcpu (LCPU bus → AXI)
  → jtag_axi_0 (AXI → JTAG)
  → PC (JTAG 电缆)
```

### TX 路径 (LCPU → PC)
```
PC (JTAG 电缆)
  → jtag_axi_0 (JTAG → AXI)
  → axi2lcpu (AXI → LCPU bus)
  → cpu_channel_reg (LCPU 寄存器)
  → cpu_channel:
      package_fifo_v2 (CDC: cpu_clk → clk_125m)
      → pktfifo2ram_int_v2
      → sop_eop_gen
  → mac_tx (前导码插入 + CRC32 + FCS 追加)
  → gmii_to_rgmii (ODDR)
  → PHY (RGMII DDR)
  → PC
```

### 透传路径 (RX → TX bypass)
```
mac_rx → cpu_channel (PASS_THROUGH_DELAY=4 延迟)
       → (CPU TX 空时选通)
       → mac_tx → gmii_to_rgmii → PHY
```
