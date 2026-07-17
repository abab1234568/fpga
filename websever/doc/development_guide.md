# RGMII 数据通路开发文档

> 项目: lcpu_rgmii | 日期: 2026-07-10 | 版本: v1.0

---

## 1. 文档概述

本文档描述 FPGA 内 RGMII 以太网帧的完整数据通路，包含 6 段：

| 段 | 名称 | 方向 | 功能 |
|----|------|------|------|
| 1 | PC → MAC RX | PHY→FPGA | RGMII 接收、前导码剥离、CRC32 校验 |
| 2 | MAC RX → FIFO | FPGA 内部 | 全帧缓存、多字节过滤、包 FIFO 写入 |
| 3 | LCPU 读 FIFO | FPGA→PC(JTAG) | PC 通过 JTAG 寄存器逐字节读取包数据 |
| 4 | LCPU 写 FIFO | PC(JTAG)→FPGA | PC 通过 JTAG 寄存器逐字节注入包数据 |
| 5 | FIFO → MAC TX | FPGA 内部 | 包 FIFO 读出、CRC32 生成、前导码插入 |
| 6 | MAC TX → PC | FPGA→PHY | GMII SDR→RGMII DDR 转换、以太网发送 |

**涉及模块:** `rgmii_gmii_loopback_top`、`rgmii_gmii_bridge`、`gmii2mac`、`cpu_channel`、`Lcpu_Top`

**时钟域:** `gmii_rx_clk`(125MHz)、`clk_125m`(125MHz)、`cpu_clk`(50MHz, =clk_50m 内部直连)

---

## 2. 模块接口信号

### 2.1 PC → MAC RX (第 1 段)

| 信号 | 位宽 | I/O | 时钟域 | 说明 |
|------|------|-----|--------|------|
| `rgmii_rxc` | 1 | in | — | PHY RX 时钟 125MHz |
| `rgmii_rxd` | 4 | in | — | PHY RX DDR 数据 |
| `rgmii_rx_ctl` | 1 | in | — | PHY RX DDR 控制 |
| `gmii_rx_clk` | 1 | out | gmii_rx_clk | BUFG 后 RX 时钟 |
| `gmii_rxd` | 8 | out | gmii_rx_clk | GMII SDR 字节 |
| `gmii_rx_dv` | 1 | out | gmii_rx_clk | 数据有效 |
| `gmii_rx_er` | 1 | out | gmii_rx_clk | RX 错误 |
| `mac_rx_sop` | 1 | out | clk_125m | 帧起始脉冲 |
| `mac_rx_en` | 1 | out | clk_125m | 数据有效 |
| `mac_rx_data` | 8 | out | clk_125m | 帧字节(已去前导码) |
| `mac_rx_eop` | 1 | out | clk_125m | 帧结束脉冲 |
| `mac_rx_err` | 1 | out | clk_125m | CRC 错误(eop时) |

### 2.2 MAC RX → FIFO (第 2 段)

| 信号 | 位宽 | I/O | 说明 |
|------|------|-----|------|
| `mac_rx_sop` | 1 | in | 来自 mac_rx |
| `mac_rx_en` | 1 | in | 数据有效 |
| `mac_rx_data` | 8 | in | 帧字节(含FCS) |
| `mac_rx_eop` | 1 | in | 帧结束 |
| `mac_rx_err` | 1 | in | CRC 错误 |
| `filter_data` | 16 | in | [15]=en [14:8]=match [7:0]=mask |
| `filter_offset` | 16 | in | [15:8]=start [7:0]=count |
| `bypass_mode` | 1 | in | 1=全放行 |
| `frame_hit` | 1 | out | 过滤命中 |
| `cpu_rd_empty` | 1 | out | FIFO 空 |
| `cpu_rd_rpkt_len` | 32 | out | 包长度(pop后) |

### 2.3 LCPU 读 FIFO (第 3 段)

| 地址 | 名称 | R/W | 信号 | 功能 |
|------|------|-----|------|------|
| 0x00 | EMPTY | R | `cpu_rd_empty` | bit0=0 有包 |
| 0x01 | POP | R/W | `cpu_rd_rpkt_pop` | bit0=1 弹出包 |
| 0x02 | LEN | R | `cpu_rd_rpkt_len` | 包长度(68) |
| 0x03 | REN | R/W | `cpu_rd_ren` | bit0=1 读使能 |
| 0x04 | RADDR | R/W | `cpu_rd_raddr` | 读地址(包内偏移) |
| 0x05 | RDATA | R | `cpu_rd_rdata` | 读出的1字节 |

### 2.4 LCPU 写 FIFO (第 4 段)

| 地址 | 名称 | R/W | 信号 | 功能 |
|------|------|-----|------|------|
| 0x10 | WR_FULL | R | `cpu_wr_full` | bit0=1 FIFO满 |
| 0x11 | WR_WEN | R/W | `cpu_wr_wen` | bit0=1 写使能脉冲 |
| 0x12 | WR_WADDR | R/W | `cpu_wr_waddr` | 写地址(包内偏移) |
| 0x13 | WR_WDATA | R/W | `cpu_wr_wdata` | 写数据(1字节) |
| 0x14 | WR_LEN | R/W | `cpu_wr_wpkt_len` | 包长度(68) |
| 0x15 | WR_PUSH | R/W | `cpu_wr_wpkt_push` | bit0=1 包推送脉冲 |

### 2.5 FIFO → MAC TX (第 5 段)

| 信号 | 位宽 | I/O | 时钟域 | 说明 |
|------|------|-----|--------|------|
| `cpu_tx_sop` | 1 | in | clk_125m | TX 帧起始 |
| `cpu_tx_en` | 1 | in | clk_125m | TX 数据有效 |
| `cpu_tx_data` | 8 | in | clk_125m | TX 字节 |
| `cpu_tx_eop` | 1 | in | clk_125m | TX 帧结束 |
| `gmii_txd` | 8 | out | clk_125m | GMII TX SDR 字节 |
| `gmii_tx_en` | 1 | out | clk_125m | GMII TX 有效 |

### 2.6 MAC TX → PC (第 6 段)

| 信号 | 位宽 | I/O | 说明 |
|------|------|-----|------|
| `gmii_txd` | 8 | in | GMII SDR 输入 |
| `gmii_tx_en` | 1 | in | TX 数据有效 |
| `rgmii_txc` | 1 | out | TX 时钟 125MHz |
| `rgmii_txd` | 4 | out | TX DDR 数据 |
| `rgmii_tx_ctl` | 1 | out | TX DDR 控制 |

---

## 3. 功能描述与定义

### 3.1 PC → MAC RX

**数据路径:**
```
PC 以太网帧 → RTL8211 PHY → RGMII DDR → rgmii_gmii_bridge (DDR→SDR)
→ gmii2mac (CDC→前导码剥离→CRC32校验) → mac_rx_sop/en/data/eop/err
```

**子模块链:**
1. **rgmii_to_gmii**: IDELAYE2(20tap≈1.56ns延迟补偿) → IDDR(SAME_EDGE_PIPELINED, DDR→SDR) → BUFG
2. **dual_clock_fifo**: 10bit={ER,DV,DATA}, CDC gmii_rx_clk→clk_125m, 16深
3. **eth_presemble**: 字节0-6检测0x55, 字节7检测0xD5, `rx_valid_header=1`后透传
4. **mac_rx**: CRC32校验 → sop_eop_gen输出包格式

**CRC32 校验定义:**
- 多项式: `x^32+x^26+x^23+x^22+x^16+x^12+x^11+x^10+x^8+x^7+x^5+x^4+x^2+x+1`
- 初始值: `32'hFFFFFFFF`
- 覆盖范围: DA(6B)+SA(6B)+Type(2B)+Payload+FCS(4B) 全部
- Magic Residue: `32'h1cdf4421` — 对含正确FCS的帧做CRC, 残余恒为此值
- 正确判断: `crc_err = (crc_out == 32'h1cdf4421) ? 0 : crc_done`

### 3.2 MAC RX → FIFO

**数据路径:**
```
mac_rx_sop/en/data/eop/err → cpu_channel (RX_PREAMBLE_STRIP=0)
  1. 前导码跳过: 已剥离, 直通
  2. frame_buf: Block RAM 全帧缓存(2048深度)
  3. 多字节窗口掩码过滤 → frame_hit
  4. extract SM: frame_hit_rising→逐字节搬入 ram2pktfifo_int
  5. ram2pktfifo_int: 打拍计长度→wpkt_push
  6. package_fifo_v2: dual_clock=1, clk_125m→cpu_clk
```

**过滤定义 (v4.0 — 双窗口硬接线):**

```
窗口1: start=61, count=1, match=0x77, mask=0xFF  → byte61 == 'w'
窗口2: start=23, count=1, match=0x11, mask=0xFF  → byte23 == UDP

两个窗口都命中 → all_bytes_match1 && all_bytes_match2 → frame_hit=1
任一不命中 → 帧丢弃, 不进 FIFO
```

RTL 顶层硬接线, 不需要 LCPU 寄存器配:
```verilog
.filter_data   (16'h8077)  // 窗口1
.filter_offset (16'h3D01)
.filter_data2  (16'h8011)  // 窗口2
.filter_offset2(16'h1701)
```

| 窗口 | 值 | 含义 |
|------|-----|------|
| 1 | start=61, match=0x77, mask=0xFF | payload 第19字节 = 'w' → 锁死你的包 |
| 2 | start=23, match=0x11, mask=0xFF | IP Protocol = UDP → 只放 UDP |

**参考帧结构 (UDP, 68字节):**
```
偏移  值              字段
 0-5  9c 2d cd ac 8f a4  DA         ← 锁①
 6-11 9c 69 d3 7d 47 4c  SA
12-13 08 00              Type = IPv4
14-33 45 00 00 32 ...     IPv4 头 (20B)
  23  11                 Protocol = UDP
26-29 a9 fe fc f8        Src IP     ← 锁②
34-41 05 21 27 15 ...     UDP 头 (8B)
36-37 27 15              Dst Port   ← 锁③
42-60 30×19              Payload (0x30 × 19)
  61  77                 'w' ← 硬件过滤点
  62  7a                 'z'
  63  68                 'h'
64-67 ?? ?? ?? ??         FCS (CRC32)
```

**CRC32帧尾:**
- frame_buf存储含原始4字节FCS
- wpkt_len = data_bytes + 4 (例: 64+4=68)
- CRC校验结果在mac_rx_err中(err=0正确)

### 3.3 LCPU 读 FIFO

**数据路径:**
```
PC(JTAG) → jtag_axi_0 → AXI4-Lite → axi2lcpu → LCPU bus
→ cpu_channel_reg → cpu_channel.cpu_rd_* → package_fifo_v2(读侧)
```

**TCL 操作流程:**
```tcl
# 1. 等包
set empty [jread 0x00]     # bit0=0 有包

# 2. 弹出包
jwrite 0x01 1               # rpkt_pop=1

# 3. 读包长度
set len [jread 0x02]        # 68 (64 data + 4 FCS)

# 4. 逐字节读
for {set i 0} {$i < $len} {incr i} {
    jwrite 0x04 $i           # 设 raddr
    jwrite 0x03 1            # ren=1
    set b [jread 0x05]       # 读 rdata
    jwrite 0x03 0            # ren=0
}
```

### 3.4 LCPU 写 FIFO

**数据路径:**
```
PC(JTAG) → cpu_channel_reg → cpu_channel.cpu_wr_*
→ package_fifo_v2(TX, cpu_clk→clk_125m, dual_clock=1)
→ 数据写入 simple_dual_port_ram
wpkt_push → 锁存包参数
```

**TCL 操作流程 (先设 wdata/waddr, 再 wen 脉冲):**
```tcl
# 68 字节帧 (64 data + 4 FCS)
for {set i 0} {$i < 68} {incr i} {
    jwrite 0x13 $byte        # 1. 设 wdata
    jwrite 0x12 $i           # 2. 设 waddr
    jwrite 0x11 0x01         # 3. wen=1 脉冲 → 写入1字节
}

# 全部字节写完后
jwrite 0x14 68               # 4. wpkt_len = 68
jwrite 0x15 0x01             # 5. wpkt_push → 推入 FIFO
```

### 3.5 FIFO → MAC TX

**数据路径:**
```
package_fifo_v2(TX读侧) → pktfifo2ram_int_v2
  - empty=0 && IPG满 → 自动 rpkt_pop
  - 锁存 rpkt_len, ren=1, raddr 0→len-1 自增
  - ram_wen=ren → 字节流 cpu_tx_en, cpu_tx_data

sop_eop_gen:
  cpu_tx_en 流 → cpu_tx_sop(上升沿) + cpu_tx_eop(下降沿)

mac_tx:
  fix_delay(4拍,9bit) → crc.v(CRC32计算) → 4拍FCS插入
  → gmii_tx_en, gmii_txd[7:0]
```

**CRC32 生成定义:**
- crc.v: `crc_type=0, data_in_width=8`
- 输入: `data_in_en = data_o_en & data_o_en_d`, `data_in = data_o_d[7:0]`
- 覆盖范围: DA+SA+Type+Payload (不含旧FCS), 共60字节
- 输出: `crc_done` → 4拍 `crc_insert` 移位 → tx_data替换为crc[31:24][23:16][15:8][7:0]
- **mac_tx 重新计算并覆盖帧尾最后4字节**

### 3.6 MAC TX → PC

**数据路径:**
```
gmii_tx_en, gmii_txd[7:0]
→ eth_presemble(tx_presemble_en=1, 插入8B前导码 55×7+D5)
→ gmii_to_rgmii (ODDR×6, SDR→DDR)
→ RGMII TXC/TXD[3:0]/TX_CTL → RTL8211 PHY → Ethernet → PC
```

---

## 4. 状态机设计

### 4.1 eth_presemble — RX 前导码检测 (第 1 段)

隐式FSM (字节计数器实现):

```
rx_eth_byte_cnt:
  rx_data_en_in=0 → 清零
  rx_data_en_in=1 → 自增

  0≤cnt<7: 期望 data==0x55, 记录到 rx_premble[cnt]
  cnt==7:   rx_premble==7'b111_1111 && data==0xD5 → rx_valid_header=1
  cnt≥7:    rx_valid_header=1 → 透传

异常: 前导码非0x55或SFD非0xD5 → rx_valid_header=0 → 帧丢弃
```

### 4.2 extract SM — 帧搬移 (第 2 段)

2态FSM:

```
IDLE ──frame_hit_rising──▶ ACTIVE
  ↑                          │
  └──extract_rd_ptr==len-1──┘

IDLE:
  extract_ram_wen=0, rd_ptr=0, wr_addr=0
  frame_hit_rising → extract_active=1, extract_len=frame_len

ACTIVE:
  mac_in_full=0 → wen=1, wdata=frame_buf[rd_ptr], wr_addr++, rd_ptr++
  mac_in_full=1 → wen=0 (背压暂停)
  rd_ptr==len-1 → extract_active=0 (下一拍)
```

### 4.3 axi2lcpu — AXI→LCPU 桥 (第 3/4 段)

3态FSM:

```
IDLE ──aw_hs||ar_hs──▶ WAIT ──lcpu_ack──▶ DONE ──bready||r_hs──▶ IDLE

IDLE:  等AXI写地址+数据或读地址 → 发起lcpu_req
WAIT:  等lcpu_ack
DONE:  写→返回B响应, 读→锁存rdata→返回R响应
```

### 4.4 cpu_channel_reg — LCPU 总线协议 (第 3/4 段)

超时保护:

```
is_req: req上升沿→锁存为1
is_req_cnt: is_req=1时自增, ≥0x0008→timeout_ack=1, is_req=0
ack: timeout_ack | reg_ack
rdata: timeout→DEADDEAD, reg_ack→reg_rdata
```

---

## 5. 时序说明与时序图

### 5.1 PC → MAC RX (第 1 段) — 全接口

```
rgmii_rxc:    _/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_
rgmii_rxd:    __55_55_55_55_55_55_55_D5_DA_SA_Type_Payload__________________________FCS3_____________
rgmii_rx_ctl: ___/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\__________
                                                                              ↑ dv=1 期间数据有效

gmii_rx_clk:  _/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_
gmii_rxd:     __55_55_55_55_55_55_55_D5_DA_SA_Type_Payload__________________________FCS3_____________
gmii_rx_dv:   ___/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\__________
gmii_rx_er:   ______________________________________________________________________________________

mac_rx_sop:   ________________________/‾\___________________________________________________________
mac_rx_en:    ________________________/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\______
mac_rx_data:  ________________________DA_SA_Type_Payload_______________________________FCS0_FCS1_FCS2_FCS3_
mac_rx_eop:   ________________________________________________________________________/‾\_____________
mac_rx_err:   ________________________________________________________________________/‾\_____________
                                                                                      ↑ 0=CRC正确 1=错误
```

### 5.2 MAC RX → FIFO (第 2 段) — 全接口

```
mac_rx_sop:       __________/‾\______________
mac_rx_en:        __________/‾‾‾‾‾‾‾‾‾‾‾‾‾\___
mac_rx_data:      __________DA_SA_...FCS_____
mac_rx_eop:       _____________________/‾\_____
mac_rx_err:       _____________________/‾\_____
filter_enable:    _____________________________  (来自 filter_data[15])
bypass_mode:      _____________________________  (1=全放行)

frame_hit:        _____________________/‾\_____  (EOP时: all_match && enable && !bypass)
extract_active:   _____________________/‾‾‾‾‾\_
extract_ram_wen:  _____________________/‾\_/‾\_/‾\_/‾\_
extract_wdata:    _____________________DA_SA_Type_...FCS_

wpkt_push:       _______________________________/‾\_
wpkt_len:        _______________________________│68│_

cpu_rd_empty:     ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\_____________  (cpu_clk域: 0=有包可读)
cpu_rd_rpkt_len:  XXXXXXXXXXXXXXXXXXXXXXXXXX│68│____  (cpu_clk域: pop后有效)
```

### 5.3 LCPU 读 FIFO (第 3 段) — 全接口

```
cpu_rd_empty:     ‾‾\____________________________  (0=有包, 可读)

jwrite 0x01 1 (pop):
cpu_rd_rpkt_pop:  __________/‾\___________________  (弹出包脉冲)

cpu_rd_rpkt_len:  XXXXXXXXXX│68│__________________  (pop后有效)

for i=0,1,2...67:
  jwrite 0x04 i (设raddr):
  cpu_rd_raddr:   __________│ 0 │_____│ 1 │______  (设读地址)

  jwrite 0x03 1 (ren=1):
  cpu_rd_ren:     __________/‾‾‾\______/‾‾‾\_____  (读使能)

  jread 0x05 (读rdata):
  cpu_rd_rdata:   ______________│D0│______│D1 │__  (2拍后数据有效)

  jwrite 0x03 0 (ren=0):
  cpu_rd_ren:     __________/‾‾‾‾‾‾‾\_____________  (关读使能)
```

### 5.4 LCPU 写 FIFO (第 4 段) — 全接口

```
cpu_wr_full:      ________________________________  (0=可写)

for i=0,1,2...67:
  jwrite 0x13 byte (设wdata):
  cpu_wr_wdata:   __________│D0│_____│D1 │_______  (先设写数据)

  jwrite 0x12 i (设waddr):
  cpu_wr_waddr:   __________│ 0 │_____│ 1 │_______  (再设写地址)

  jwrite 0x11 0x01 (wen脉冲):
  cpu_wr_wen:     __________/‾\_______/‾\__________  (最后脉冲 → 写入1字节)

...全部68字节写完后:

  jwrite 0x14 68 (设包长度):
  cpu_wr_wpkt_len:   ______________________│68│______

  jwrite 0x15 0x01 (推送):
  cpu_wr_wpkt_push:  ______________________/‾\_________
```

### 5.5 FIFO → MAC TX (第 5 段) — 全接口

```
cpu_tx_sop:      ________________/‾\________________
cpu_tx_en:       ________________/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\___
cpu_tx_data:     ________________DA_SA_...Payload_____
cpu_tx_eop:      ________________________________/‾\__

crc_done:        ________________________________/‾\__
crc_insert[3]:   ________________________________/‾\_____ → tx_data = crc[31:24]
crc_insert[2]:   _________________________________/‾\____ → tx_data = crc[23:16]
crc_insert[1]:   __________________________________/‾\___ → tx_data = crc[15:8]
crc_insert[0]:   ___________________________________/‾\__ → tx_data = crc[7:0]

gmii_tx_en:      __/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\___  (比cpu_tx多了8B前导码+4B新FCS)
gmii_txd:        __55_55_55_55_55_55_55_D5_DA_SA_..._crc31_crc23_crc15_crc7__
gmii_tx_er:      ____________________________________________________________
               ↑ 8B前导码(eth_presemble插入)                            ↑ 新FCS(mac_tx插入)
```

### 5.6 MAC TX → PC (第 6 段) — 全接口

```
gmii_tx_en:      __/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\___
gmii_txd:        __55_55_55_55_55_55_55_D5_DA_SA_Type_Payload_____crc31_..._crc7__
gmii_tx_er:      __________________________________________________________________

rgmii_txc:       _/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_
rgmii_txd:       __DA[3:0]_DA[7:4]_SA[3:0]_SA[7:4]_Type[3:0]_Type[7:4]_..._crc[3:0]_crc[7:4]__
rgmii_tx_ctl:    __/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\__

ODDR: posedge → gmii_txd[3:0] (低位)    negedge → gmii_txd[7:4] (高位)
      posedge → TX_CTL = TX_EN          negedge → TX_CTL = TX_EN ^ TX_ER
```

---

## 6. 实现细节

### 6.1 CRC32 计算 (第 1/5 段)

**模块:** `crc.v`, `crc_type=0, data_in_width=8`

**fun_crc32_d8:** 组合逻辑, 1拍完成 8bit→32bit CRC更新:
```
crc_next = f(data_in[7:0], crc_reg[31:0])
每个 clk_en && data_in_en → crc_reg <= crc_next
```

**Magic Number:**
- 对含正确FCS的完整帧计算CRC32 → 残余恒为 `32'h1cdf4421`
- `mac_rx` 判断: `crc_err = (crc_out==MAGIC) ? 0 : crc_done`

### 6.2 FCS 插入 (第 5 段)

4拍crc_insert移位寄存器:
```
crc_done → crc_insert=4'b1000 → crc_out_r锁存
         → tx_data = crc_out_r[31:24]  (MSB first)
crc_done+1 → crc_insert=4'b0100
         → tx_data = crc_out_r[23:16]
crc_done+2 → crc_insert=4'b0010
         → tx_data = crc_out_r[15:8]
crc_done+3 → crc_insert=4'b0001
         → tx_data = crc_out_r[7:0]
```

### 6.3 包长度计数 (第 2 段)

**ram2pktfifo_int:**
```verilog
if (clk_en && wen)  wpkt_len <= wpkt_len + 1;
else                wpkt_len <= 0;
wpkt_push <= ~ram_wen & wen;  // 下降沿
```
64字节payload + 4字节FCS = **68字节**

### 6.4 过滤窗口匹配 (第 2 段)

```verilog
in_match_window = (rx_byte_cnt >= start) && (rx_byte_cnt < start+count);
byte_match = ((data & mask) == (match_val & mask));

all_bytes_match: SOP→1, 窗口内任一不匹配→0
frame_hit = all_bytes_match && filter_enable && !bypass; // EOP判断
```

### 6.5 RGMII DDR 采样 (第 1/6 段)

**RX IDDR SAME_EDGE_PIPELINED:**
- Q1(posedge)=低位 → gmii_rxd[3:0]
- Q2(negedge)=高位 → gmii_rxd[7:4]
- gmii_rx_dv=Q1, gmii_rx_er=Q1^Q2

**TX ODDR OPPOSITE_EDGE:**
- D1(posedge)=gmii_txd[3:0], D2(negedge)=gmii_txd[7:4]
- TX_CTL: D1=TX_EN, D2=TX_EN^TX_ER

---

## 7. 注意事项

### 7.1 时钟频率

| 时钟 | 频率 | 说明 |
|------|------|------|
| `clk_50m` | 50MHz | 板载晶振, MMCM输入+LCPU时钟 |
| `clk_125m` | 125MHz | MMCM CLKOUT0, 数据面主时钟 |
| `clk_200m` | 200MHz | MMCM CLKOUT1, IDELAYCTRL参考 |
| `clk_125m_tx` | 125MHz(90°) | MMCM CLKOUT2, RGMII TXC |
| `gmii_rx_clk` | 125MHz | PHY RXC恢复, 与clk_125m异步 |
| `cpu_clk` | 50MHz | =clk_50m直连, LCPU子系统 |

### 7.2 包长度

- 最短: 64字节(含FCS)
- 最长: 1518字节(标准MTU) / 2048字节(jumbo)
- CPU注入: wpkt_len = data_bytes + 4
- mac_tx 重新计算覆盖帧尾4字节FCS

### 7.3 LCPU 注意事项

- req→ack超时: 8周期, 超时返回DEADDEAD
- `cpu_rd_rdata`: ren=1后2拍有效
- `cpu_wr_wen`: 脉冲后数据立即写入FIFO
- `rpkt_pop`后 `rpkt_len` 下一拍有效
- 跨时钟域: cpu_clk(50MHz)↔clk_125m(125MHz), package_fifo_v2内部CDC

### 7.4 ILA 观测

- ILA时钟: clk_125m (125MHz)
- cpu_clk域信号(cpu_rd_empty/rpkt_len)异步采样不可靠
- gmii_rx_clk域信号(probe0)异步采样可能有亚稳态
- 建议: cpu_clk域状态用LCPU寄存器读, 不要依赖ILA

---

## 8. 附录

### 8.1 寄存器完整映射 (16 个)

| 地址 | 名称 | R/W | 信号 | 功能 |
|------|------|-----|------|------|
| 0x00 | EMPTY | R | cpu_rd_empty | bit0=0 有包 |
| 0x01 | POP | R/W | cpu_rd_rpkt_pop | bit0=1 弹出包 |
| 0x02 | LEN | R | cpu_rd_rpkt_len | 包长度(pop后有效) |
| 0x03 | REN | R/W | cpu_rd_ren | bit0=1 读使能 |
| 0x04 | RADDR | R/W | cpu_rd_raddr | 读地址(包内偏移) |
| 0x05 | RDATA | R | cpu_rd_rdata | 读出的1字节 |
| 0x10 | WR_FULL | R | cpu_wr_full | bit0=1 FIFO满 |
| 0x11 | WR_WEN | R/W | cpu_wr_wen | bit0=1 写使能脉冲 |
| 0x12 | WR_WADDR | R/W | cpu_wr_waddr | 写地址 |
| 0x13 | WR_WDATA | R/W | cpu_wr_wdata | 写数据(1字节) |
| 0x14 | WR_LEN | R/W | cpu_wr_wpkt_len | 写包长度 |
| 0x15 | WR_PUSH | R/W | cpu_wr_wpkt_push | bit0=1 包推送**

> 注: filter 不经过寄存器, 顶层直接硬接线到 cpu_channel。要改过滤规则需改 RTL 重综合。

### 8.2 TCL 抓包脚本

**脚本位置:** `lcpu_filter_capture.tcl`

**使用:**
```tcl
source /home/huamingh/work/FPGA_Prj/test/lcpu_rgmii/lcpu_filter_capture.tcl
capture_print       # 单次抓包+打印帧详情
monitor             # 持续监控
flush               # 清空 FIFO
```

**过滤流程:**
```
硬件 (RTL):  byte61 == 0x77  → 初筛, 挡 99.6% 流量
                                      │
LCPU (TCL): ① dstMAC = 9c:2d:cd:ac:8f:a4
            ② srcIP  = a9.fe.fc.f8
            ③ dstPort = 10005
            → 全部匹配才打印
```

**手动操作序列:**
```tcl
# 注: filter 已硬件接线 (byte61='w' + byte23=UDP), 不用寄存器配

# ===== 读 FIFO =====
while {[jread 0x00]} { after 100 }
jwrite 0x01 1          # pop
set len [jread 0x02]
for {set i 0} {$i < $len} {incr i} {
    jwrite 0x04 $i; jwrite 0x03 1
    set b [jread 0x05]; jwrite 0x03 0
}

# ===== LCPU 软件锁死 =====
# 检查 dstMAC (byte 0-5), srcIP (byte 26-29), dstPort (byte 36-37)
# 任一不匹配 → continue 读下一帧
set dport [expr {[lindex $bytes 36]*256 + [lindex $bytes 37]}]
if {$dport != 10005} { ... }

# ===== 写 FIFO =====
for {set i 0} {$i < 68} {incr i} {
    jwrite 0x13 $byte   # wdata 先设
    jwrite 0x12 $i      # waddr
    jwrite 0x11 0x01    # wen 脉冲
}
jwrite 0x14 68          # wpkt_len
jwrite 0x15 0x01        # wpkt_push
```

### 8.3 6段数据流总图

```
PC1 ──Eth──▶ PHY ──RGMII──▶ Bridge ──GMII──▶ gmii2mac
                                                  │ CDC + 前导码 + CRC32
                                                  ▼ mac_rx_sop/en/data/eop/err
                                            cpu_channel
                                           ┌──frame_buf→过滤→extract──┐
                                           │                           │
                                           ▼ cpu_rd_*          cpu_wr_* ▼
                                      Lcpu_Top ◀──JTAG── PC2   Lcpu_Top
                                           │                           │
                                           │                    package_fifo(TX)
                                           │                      │ pktfifo2ram
                                           │                      ▼ cpu_tx_en/data
                                           └──────────────────────────┘
                                                                      │
                                                                  mac_tx (CRC32)
                                                                      │ gmii_tx
                                                                  Bridge (SDR→DDR)
                                                                      │ RGMII
                                                                     PHY ──Eth──▶ PC2
```

---

> 文档结束
