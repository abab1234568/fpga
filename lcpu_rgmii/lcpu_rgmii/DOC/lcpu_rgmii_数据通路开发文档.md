# lcpu_rgmii 数据通路开发文档

## 1. 文档概述

本文档描述 FPGA 内部以太网帧的完整数据通路，覆盖四个关键环节：

| 章节 | 数据流 | 说明 |
|------|--------|------|
| 2 | PC → mac_rx | 网线进来到 CRC 校验完成 |
| 3 | mac_rx → FIFO | 过滤器 + 帧缓冲 + 提取状态机 + 异步 FIFO |
| 4 | FIFO → mac_tx | 透传回环 + CPU 注入 → CRC 插入 |
| 5 | mac_tx → PC | 前导码插入 → RGMII 发出 |

时钟域总览：

```
gmii_rx_clk (125MHz, PHY恢复)     clk_125m (125MHz, MMCM)     cpu_clk (50MHz, MMCM)
       │                                    │                        │
  rgmii_to_gmii                      eth_presemble              cpu_channel_reg
  dual_clock_fifo(w)                 mac_rx / mac_tx            package_fifo_v2(r)
       │                            cpu_channel                 jtag_axi_0
       └──── CDC ────┘                    │                        │
                                     gmii_to_rgmii            package_fifo_v2(w/r)
                                          │                        │
                                     clk_125m_tx (90°)
```

---

## 2. PC → mac_rx

### 2.1 数据流

```
PC 网卡 → 网线 → RTL8211 PHY (ACX750板载)
       → RGMII (4bit DDR @125MHz)
       → FPGA: rgmii_rxc/rxd[3:0]/rx_ctl
       → rgmii_to_gmii → gmii_rx_clk/gmii_rxd[7:0]/gmii_rx_dv/gmii_rx_er
       → dual_clock_fifo (CDC: gmii_rx_clk → clk_125m)
       → eth_presemble (RX前导码剥离)
       → mac_rx (CRC32校验)
       → mac_rx_sop/en/data[7:0]/eop/err
```

### 2.2 模块功能描述

#### 2.2.1 rgmii_to_gmii — RGMII RX → GMII RX

| 属性 | 值 |
|------|-----|
| 文件 | `rtl/rgmii2gmii/rgmii_to_gmii.v` |
| 时钟域 | `gmii_rx_clk`（rgmii_rxc 经 BUFG） |
| 功能 | RGMII 4bit DDR @125MHz → GMII 8bit SDR @125MHz |

**实现细节**：

- **IDELAYCTRL**：例化在 Bank 内，REFCLK = 200MHz（MMCM CLKOUT1）
- **IDELAYE2**：`rgmii_rxd[3:0]` + `rgmii_rx_ctl` 各经 20tap 固定延迟（~1.56ns），补偿 PCB 走线偏差，将数据移到 RXC 采样窗口中央
- **IDDR**：SAME_EDGE_PIPELINED 模式，Q1=posedge 采样（lower nibble），Q2=negedge 采样（upper nibble），两者在下一拍同时输出
- **BUFG**：`rgmii_rxc` 进全局时钟网络 → `gmii_rx_clk`

**输出信号**：

| 信号 | 位宽 | 说明 |
|------|------|------|
| `gmii_rx_clk` | 1 | 125MHz，从 RXC 恢复 |
| `gmii_rxd` | 8 | GMII 接收数据 |
| `gmii_rx_dv` | 1 | 数据有效 |
| `gmii_rx_er` | 1 | 接收错误 |

#### 2.2.2 dual_clock_fifo — CDC 跨时钟域

| 属性 | 值 |
|------|-----|
| 文件 | `rtl/dual_clock_fifo.v` |
| 时钟域 | wclk=`gmii_rx_clk`, rclk=`clk_125m` |
| 参数 | addr_width=4 (深度16), data_width=10 |

**实现细节**：

- 写侧：`{gmii_rx_er, gmii_rx_dv, gmii_rxd[7:0]}` 共 10bit 写入
- 格雷码指针 + 2-FF 同步器 (`ASYNC_REG`) 安全 CDC
- 读侧：`read_en = ~empty` 连续读取，数据出现在 `read_data`（1 拍延迟）
- 读写时钟完全异步，`set_clock_groups -asynchronous` 切断时序分析

#### 2.2.3 eth_presemble — 前导码剥离

| 属性 | 值 |
|------|-----|
| 文件 | `rtl/mac/eth_presemble.v` |
| 时钟域 | `clk_125m` |
| 参数 | rx_presemble_en=1 |

**状态机**：

```
        rx_en=1
IDLE ──────────→ PREAMBLE
                   │
                   ├─ 前7字节==0x55 → pream_cnt++
                   ├─ 第8字节==0xD5 → SFD检测 → FRAME
                   └─ 异常 → IDLE
                                      
FRAME: pr_dv=rx_dv, pr_data=rx_data  (透传帧数据)
       rx_dv=0 → IDLE
```

**输出**：`pr_dv`, `pr_data[7:0]`, `pr_er` — 帧数据不含前导码/SFD。

#### 2.2.4 mac_rx — CRC32 校验

| 属性 | 值 |
|------|-----|
| 文件 | `rtl/mac/mac_rx.v` |
| 时钟域 | `clk_125m` |
| 参数 | rx_fcs_check_en=1 |

**CRC32 多项式**：IEEE 802.3 `x^32 + x^26 + x^23 + x^22 + x^16 + x^12 + x^11 + x^10 + x^8 + x^7 + x^5 + x^4 + x^2 + x + 1`

**校验逻辑**：

```
CRC 初值 = 0xFFFFFFFF
逐字节更新: crc_reg <= crc_next(data_byte)
EOP 时: crc_err = (crc_reg != 0x1CDF4421)
```

`sop_eop_gen` 将连续 `rx_en` 转为带 sop/eop 边带的包流输出。

### 2.3 时序

```
                   ┌─ preamble ─┐┌─────────── 帧数据 (含CRC) ───────────┐
gmii_rxd[7:0]  ───┤55..55 D5  ├┤dstMAC[0]..[5]..srcMAC..Type..Payload..CRC[0..3]├───
gmii_rx_dv     ___/            \______________________________________________/‾‾‾‾
                                ┌─────────── 帧数据 (前导码已剥离) ───────────┐
pr_data[7:0]   ─────────────────┤dstMAC[0]..[5]..srcMAC..Type..Payload..CRC[0..3]├───
pr_dv          ________________/                                             \_____
                                                                                 ┌─┐
mac_rx_sop     _______________________________/‾\____________________________________
mac_rx_en      _______________________________/    \_____________________________
mac_rx_data    XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX│ 帧数据                         │XXXX
mac_rx_eop     ____________________________________________________________/‾\_____
mac_rx_err     ____________________________________________________________/‾\_____  (CRC错时)
```

---

## 3. mac_rx → FIFO

### 3.1 数据流

```
mac_rx_sop/en/data/eop/err
       → cpu_channel:
           rx_byte_cnt (逐字节计数)
           frame_buf (Block RAM 全帧缓存)
           多字节过滤器 (match @ offset)
           frame_hit 触发提取状态机
       → ram2pktfifo_int (字节流 → 包FIFO接口)
       → package_fifo_v2 (RX, 125MHz→50MHz 异步FIFO)
       → cpu_rd_empty/rpkt_len/rdata (50MHz CPU读端口)
```

### 3.2 cpu_channel 内部结构

| 子模块 | 功能 |
|--------|------|
| `rx_byte_cnt + frame_buf` | 逐字节计数，Block RAM 存储全帧 |
| 多字节过滤器 | `filter_offset` 指定起始偏移和检查字节数，`filter_data` 指定匹配值和掩码 |
| `frame_hit` 检测 | EOP 时 `all_bytes_match && filter_enable && !bypass_mode` |
| 提取状态机 | `frame_hit` 上升沿触发，从 frame_buf 逐字节读出 → ram2pktfifo_int |
| `ram2pktfifo_int` | 连续字节流接口 → 包 FIFO 写时序（wen/wdata/wpkt_push/wpkt_len） |
| `package_fifo_v2` (RX) | 双时钟异步包 FIFO，wclk=125MHz, rclk=50MHz |
| `package_fifo_v2` (TX) | CPU 发包路径，wclk=50MHz, rclk=125MHz |

### 3.3 过滤器配置

```
filter_data[15]    = filter_enable    (1=开启过滤)
filter_data[14:8]  = filter_match_val (7bit 匹配值)
filter_data[7:0]   = filter_mask      (8bit 掩码, 0=不关心)

filter_offset[15:8] = filter_start_offset  (起始字节偏移)
filter_offset[7:0]  = filter_check_count   (连续检查字节数)
```

**匹配逻辑**：

```
in_match_window = (rx_byte_cnt >= start_offset) &&
                  (rx_byte_cnt <  start_offset + check_count)
byte_match = ((mac_rx_data & mask) == (match_val & mask))
all_bytes_match: 初始=1, 窗口内任意字节不匹配则=0
frame_hit = all_bytes_match && filter_enable && !bypass_mode (EOP时)
```

**默认配置**（上电即捕获所有帧）：

| 寄存器 | 复位值 | 含义 |
|--------|--------|------|
| filter_data | 0x8000 | enable=1, mask=0x00, 任意字节匹配 |
| filter_offset | 0x0001 | start=0, count=1, 检查 dstMAC[0] |
| bypass_mode | 0 | 使用过滤路径 |

### 3.4 提取状态机

```
                    frame_hit上升沿
IDLE (extract_active=0) ──────────→ ACTIVE
  extract_rd_ptr=0                   extract_active=1
  extract_wr_addr=0                  extract_len = frame_len
                                     ┌─ 从 frame_buf[rd_ptr] 逐字节读出
                                     │  → extract_ram_wen/waddr/wdata
                                     │  mac_in_full=1 时暂停
                                     └─ rd_ptr == len-1 → IDLE
```

### 3.5 ram2pktfifo_int — 字节流→包FIFO接口

| 属性 | 值 |
|------|-----|
| 文件 | `rtl/cpu/ram2pktfifo_int.v` |

**时序转换**：

```
ram_wen   ____/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\________
ram_wdata XXXX| D0| D1| ... |  Dn-1 |XXXXXXX
                                                   ____
wen/wdata  (同 ram_wen/wdata, 1拍延迟)
                                                 /    \
wpkt_push  ____________________________________/      \___
wpkt_len   XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX|  n   |XXX
```

`ram_wen` 下降沿 → `wpkt_push` 脉冲 + `wpkt_len`。

### 3.6 package_fifo_v2 — 双时钟异步包FIFO

| 属性 | 值 |
|------|-----|
| 文件 | `rtl/cpu/package_fifo.v` |

**配置（RX）**：

| 参数 | 值 |
|------|-----|
| dual_clock | 1 |
| addr_width | 11 (2048 字节/块) |
| block_mode | "false" |
| max_pkt_length | 1518 |

**写时序（125MHz）**：

```
wclk      _/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_
wen       ___/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\_______
waddr     XXXX| 0 | 1 | ... | n-1 |XXXXXXXXXX
wdata     XXXX| D0| D1| ... |Dn-1 |XXXXXXXXXX
                          ___/‾\___
wpkt_push ________________/      \___________
wpkt_len  XXXXXXXXXXXXXXXX|  n   |XXXXXXXXXXX
```

**读时序（50MHz）**：

```
rclk      _/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_
empty     ‾‾‾\_________________________
rpkt_pop  ____/‾\______________________
rpkt_len  XXXXXX| n |XXXXXXXXXXXXXXXXX
ren       __________/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\______
raddr     XXXXXXXXXX| 0 | 1 |...|n-1|XXXXX
rdata     XXXXXXXXXX| D0| D1|...|Dn-1|XXXXX
```

`rpkt_pop` 发出后 2 个时钟周期 `rpkt_len` 有效，之后 `ren=1` 逐字读取。

### 3.7 LCPU 寄存器读包流程

| 步骤 | 操作 | 说明 |
|------|------|------|
| 1 | `jwrite 0x0C 0x00000001` | CONTROL bit0=1, `rpkt_pop` 弹出一帧 |
| 2 | `jread 0x04` | 读 PKT_LEN, 得帧字节数 N |
| 3 | `jread 0x08` × N 次 | 逐字节读 RD_DATA, `rd_addr` 自动递增 |

---

## 4. FIFO → mac_tx

### 4.1 数据流

```
透传路径 (回环):
  mac_rx_en/data → pt_en_dly/pt_data_dly (4级流水)
       → pt_en/pt_data (4拍延迟)
       → MUX: cpu_tx_en ? cpu_tx_data : pt_data
       → sop_eop_gen → cpu_tx_sop/en/data/eop/err

CPU注入路径 (发包):
  cpu_wr_wen/wdata/wpkt_push → package_fifo_v2(TX, 50MHz→125MHz)
       → pktfifo2ram_int_v2 (包FIFO读接口 → 字节流)
       → cpu_tx_en/cpu_tx_data
       → MUX 选通 → sop_eop_gen
```

### 4.2 透传延迟线

```
PASS_THROUGH_DELAY = 4

pt_en_dly[0] ← mac_rx_en      pt_data_dly[0] ← mac_rx_data
pt_en_dly[1] ← pt_en_dly[0]    pt_data_dly[1] ← pt_data_dly[0]
pt_en_dly[2] ← pt_en_dly[1]    pt_data_dly[2] ← pt_data_dly[1]
pt_en_dly[3] ← pt_en_dly[2]    pt_data_dly[3] ← pt_data_dly[2]
pt_en = pt_en_dly[3]           pt_data = pt_data_dly[3]
```

`sop_eop_gen` 将延迟后的连续 `pt_en` 转为带 sop/eop 边带的包流。

### 4.3 多路复用

```
final_tx_en   = cpu_tx_en ? cpu_tx_en : pt_en
final_tx_data = cpu_tx_en ? cpu_tx_data : pt_data
```

CPU 发包优先。CPU FIFO 空时自动走透传回环。

### 4.4 pktfifo2ram_int_v2 — 包FIFO→字节流

| 属性 | 值 |
|------|-----|
| 文件 | `rtl/cpu/pktfifo2ram_int_v2.v` |
| 参数 | ipg=8 |

```
empty=0 → rpkt_pop 拉高
  2拍后 rpkt_len 有效 → ren=1, raddr 递增
  raddr == rpkt_len-1 → 停止
  ram_wen/ram_wdata 输出连续字节流
  包间自动插入 ipg=8 个空闲周期
```

---

## 5. mac_tx → PC

### 5.1 数据流

```
cpu_tx_sop/en/data/eop/err
       → mac_tx (CRC32 计算 + 4字节CRC插入)
       → eth_presemble(TX) (前导码 55×7 + D5 插入)
       → gmii_to_rgmii (ODDR: 8bit SDR → 4bit DDR @ clk_125m_tx 90°)
       → rgmii_txc/txd[3:0]/tx_ctl
       → RTL8211 PHY → 网线 → PC
```

### 5.2 mac_tx — CRC32 插入

| 属性 | 值 |
|------|-----|
| 文件 | `rtl/mac/mac_tx.v` |
| 参数 | tx_fcs_insert_en=1 |

**CRC 插入时序**：

```
mac_tx_en   ___/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\___________
mac_tx_data XXXX| D0| D1| ... |  Dn-1 |XXXXXXXXXXXXXX

内部: data_o_en (1拍延迟), data_o_en_d (fix_delay 4拍)
      CRC 计算: data_in_en = data_o_en & data_o_en_d
      crc_done → 4拍 CRC 字节插入
                                       ┌ CRC[31:24] CRC[23:16] CRC[15:8] CRC[7:0]
tx_data     XXXX| D0| D1| ... |Dn-1 |  | CRC0 | CRC1 | CRC2 | CRC3 |XXXXXXXXXX
tx_en       ___/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\___________
```

`tx_en` 通过 fix_delay(4) 延长，确保 4 字节 CRC 都在 `tx_en=1` 期间输出。

**错误 CRC 插入**：`mac_tx_err=1` 时末字节 CRC 取反。

### 5.3 eth_presemble(TX) — 前导码插入

```
tx_data_en_in  ___/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\_________
tx_data_in     XXXX| D0| D1| ... |CRC3|XXXXXXXXX

tx_data_out    │55│55│55│55│55│55│55│D5│ D0│ D1│ ... │CRC3│
tx_data_en_out ___/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\___
```

`fix_delay(8)` 延迟数据流，在前 8 拍插入 `55×7 + D5`。

### 5.4 gmii_to_rgmii — GMII TX → RGMII TX

| 属性 | 值 |
|------|-----|
| 文件 | `rtl/rgmii2gmii/gmii_to_rgmii.v` |
| 时钟 | `clk_125m_tx` (MMCM CLKOUT2, 125MHz @90°) |

**ODDR 原语 (OPPOSITE_EDGE)**：

| 信号 | D1 (posedge) | D2 (negedge) |
|------|-------------|-------------|
| `rgmii_txc` | 1 | 0 |
| `rgmii_txd[i]` | `gmii_txd[i]` | `gmii_txd[i+4]` |
| `rgmii_tx_ctl` | `gmii_tx_en` | `gmii_tx_en ^ gmii_tx_er` |

TXC 连续翻转产生 125MHz 时钟。90° 移相使数据在时钟窗口中央，满足 RGMII spec Tsetup/Thold。

### 5.5 时序

```
clk_125m_tx (90°)
              _/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_
rgmii_txc    _/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_
rgmii_txd    X│55│55│55│D5│D0│D1│D2│D3│D4│D5│  (DDR: 上升沿=low nibble, 下降沿=high nibble)
rgmii_tx_ctl X│ 1│ 1│ 1│ 1│ 1│ 1│ 1│ 1│ 1│ 1│
```

---

## 6. 注意事项

| 项目 | 说明 |
|------|------|
| 时钟频率 | `clk_50m`=50MHz(板载晶振), `clk_125m`=125MHz(MMCM), `clk_125m_tx`=125MHz@90°, `gmii_rx_clk`=125MHz(PHY恢复), `cpu_clk`=50MHz(MMCM内部) |
| 异步时钟域 | `gmii_rx_clk` / `clk_125m` / `cpu_clk` 三组异步，`set_clock_groups -asynchronous` 隔离 |
| 复位 | `rst_n_int = rst_n & mmcm_locked_i`，MMCM 锁定后才释放内部复位 |
| PHY 复位 | `phy_rst_n` FPGA 内部延时 ~16ms 释放，接 ACX750 P14 |
| Block RAM | `frame_buf` 推断为 Block RAM (2048×8bit)，`(* ram_style = "block" *)` |
| 帧长限制 | 最大 1518 字节 (标准以太网帧)，`cpu_buf_addr_width=11` 支持 2048 字节 |
| 过滤器默认 | 上电 `filter_enable=1, mask=0x00`，所有帧进 FIFO |
| LCPU 读包 | 需先 `jwrite 0x0C 0x01` pop 包，再逐次 `jread 0x08` |