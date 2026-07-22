# RGMII 数据通路 — 6段 Wavedrom 时序图

> 项目: lcpu_rgmii | 日期: 2026-07-15 | 基于 `development_guide.md` 第5章

---

## 第1段: PC → MAC RX (RGMII 接收 → GMII → 前导码剥离 → CRC32)

```wavedrom
{
  config: { hscale: 2 },
  signal: [
    { name: "rgmii_rxc",   wave: "p..........", period: 1 },
    { name: "rgmii_rxd",   wave: "x=====|x", data: ["0x5","0x5","0xD","0x5"] },
    { name: "rgmii_rx_ctl",wave: "01.....0" },
    {},
    { name: "gmii_rx_clk", wave: "p......." },
    { name: "gmii_rxd",    wave: "x===|x", data: ["55","D5"] },
    { name: "gmii_rx_dv",  wave: "01...0" },
    { name: "gmii_rx_er",  wave: "0......." },
    { name: "rx_byte_cnt",   wave: "x.==|=x",
      data: ["1","","8"] },
    {},
    { name: "clk_125m",    wave: "p..............", period: 1 },
    { name: "mac_rx_sop",  wave: "0......10......" },
    { name: "mac_rx_en",   wave: "0......1......0" },
    { name: "mac_rx_data", wave: "x......==|====x", data: ["D0","","FCS0","FCS1","FCS2","FCS3"] },
    { name: "mac_rx_eop",  wave: "0............10" },
    { name: "mac_rx_err",  wave: "0.............." }
  ],
}
```

### 关键时序说明

| 时刻 | 事件 |
|------|------|
| `rgmii_rxd=0x55×7` | RGMII DDR 前导码 (每拍半字节, 共14拍) |
| `rgmii_rxd=0xD5` | SFD 帧起始定界符 |
| `gmii_rx_dv↑` | GMII SDR 数据有效开始 (IDDR转换后) |
| `mac_rx_sop` | clk_125m 域帧起始脉冲 (前导码已剥离) |
| `mac_rx_en=1` | 帧数据有效期间 (DA~FCS) |
| `mac_rx_eop` + `mac_rx_err` | 帧结束, err=0 表示 CRC32 校验通过 |

### 子模块链

```
rgmii_to_gmii (IDELAYE2 + IDDR) → dual_clock_fifo (CDC) → eth_presemble (前导码剥离) → mac_rx (CRC32校验 + sop_eop_gen)
```

---

## 第2段: MAC RX → FIFO (流式字节计数 → 单字节过滤 → wpkt_push 门控)

### 过滤原理 (v5.0 流式)

```
mac_rx_en/data → rx_byte_cnt 逐字节编号 (SOP清零)
              → ram2pktfifo_int 流式写入 (地址=rx_byte_cnt)
                frame_hit: SOP=1, byte61==0x77保持, 否则变0
              → wpkt_push & frame_hit → package_fifo_v2(RX)
```

```wavedrom
{
  config: { hscale: 2 },
  signal: [
    { name: "clk_125m",      wave: "p........................", period: 1 },
    { name: "mac_rx_sop",    wave: "0.10....................." },
    { name: "mac_rx_en",     wave: "0.1.....................0" },
    { name: "mac_rx_data",   wave: "x.==|===============|===x",
      data: ["D0","D1","","0x77","","D66","D67","FCS0","FCS1","FCS2","FCS3"] },
    { name: "mac_rx_eop",    wave: "0......................10" },
    {},
    { name: "rx_byte_cnt",   wave: "x.====|==============|...=x",
      data: ["0","1","2","","61","","66","67"] },
    { name: "frame_hit",     wave: "1.....................|...1" },
    {},
    { name: "mac_in_wen",    wave: "x.1.....................|.0" },
    { name: "mac_in_wdata",  wave: "x.==|===============|===|.=x",
      data: ["D0","D1","","0x77","","D66","D67","FCS0","FCS1","FCS2","FCS3","FCS3"] },
    { name: "mac_in_wpkt_push", wave: "0......................|.10" },
    { name: "cpu_rd_empty",     wave: "1......................0.." }
  ],
  edge: [
    "P~>Q mac_rx_sop SOP清零rx_byte_cnt",
    "P+35~>P+36 byte61=0x77 frame_hit保持1",
    "P+40~>Q mac_rx_eop EOP+wpkt_push",
    "P+44~>Q cpu_rd_empty 1→0 FIFO非空"
  ],
  foot: { text: [
    "流式写入: mac_rx_en/data 直连 ram2pktfifo_int, 无帧缓存/extract",
    "过滤: byte61==0x77 → frame_hit=1; 否则 frame_hit=0",
    "门控: wpkt_push & frame_hit → 仅命中帧推入 FIFO",
    "总长: 68字节 (64数据+4FCS)"
  ], tock: 4 }
}
```

### 关键时序

| 时刻 | 事件 |
|------|------|
| `mac_rx_sop=1` | rx_byte_cnt ← 0, frame_hit ← 1 |
| `rx_byte_cnt==61` | 判定 byte61 是否 == 0x77 |
| `rx_byte_cnt==61 && data!=0x77` | frame_hit ← 0 (失配) |
| `rx_byte_cnt==61 && data==0x77` | frame_hit 保持 1 (命中) |
| `mac_rx_eop=1` | ram2pktfifo 产生 wpkt_push |
| `wpkt_push & frame_hit` | 门控: 命中→推入FIFO, 失配→丢弃 |
| `cpu_rd_empty: 1→0` | 命中帧可被 LCPU 读取 |

---

## 第3段: LCPU 读 FIFO (JTAG → AXI → LCPU → 逐字节读包)

```wavedrom
{
  config: { hscale: 2 },
  signal: [
    { name: "cpu_clk",         wave: "p............", period: 1 },
    { name: "cpu_rd_empty",    wave: "10..........." },
    { name: "cpu_rd_rpkt_pop", wave: "0.10........." },
    { name: "cpu_rd_rpkt_len", wave: "x...=x.......", data: ["68"] },
    { name: "cpu_rd_ren",      wave: "0.....1.....0" },
    { name: "cpu_rd_raddr",    wave: "x.....===|.=x", data: ["0","1","","67"] },
    { name: "cpu_rd_rdata",    wave: "x......==|..=x", data: ["D0","","D67"] }
  ]
}
```

### LCPU 读操作码序列

| 步骤 | TCL 操作 | 寄存器 | 说明 |
|------|----------|--------|------|
| 1 | `jread 0x00` | EMPTY | bit0=0 有包, 轮询等待 |
| 2 | `jwrite 0x01 1` | POP | 弹出包, rpkt_len 下一拍有效 |
| 3 | `jread 0x02` | LEN | 获取包长度 = 68 |
| 4 | `jwrite 0x03 1` | REN | 读使能 = 1 |
| 5 | `jwrite 0x04 $i` | RADDR | 设读地址 |
| 6 | `jread 0x05` | RDATA | 2拍后数据有效 |
| 7 | `jwrite 0x03 0` | REN | 关读使能 |

---

## 第4段: LCPU 写 FIFO (JTAG → 逐字节注入 → package_fifo → 推入)

### LCPU 写操作码序列

| 步骤 | TCL 操作 | 寄存器 | 说明 |
|------|----------|--------|------|
| 1 | `jwrite 0x12 $i` | WR_WADDR | **先**设写地址 |
| 2 | `jwrite 0x13 $byte` | WR_WDATA | **再**设写数据 |
| 3 | `jwrite 0x11 0x01` | WR_WEN | **最后** wen=1 脉冲写入 |
| 4 | `jwrite 0x14 68` | WR_LEN | 设包长度 = 68 |
| 5 | `jwrite 0x15 0x01` | WR_PUSH | 推入 FIFO |
```wavedrom
{
  config: { hscale: 2 },
  signal: [
    { name: "cpu_clk",         wave: "p........", period: 1 },
    { name: "cpu_wr_full",     wave: "0........" },
    { name: "cpu_wr_waddr",    wave: "x===|=x..", data: ["0","1","","67"] },
    { name: "cpu_wr_wdata",    wave: "x===|=x..", data: ["D0","D1","","D67"] },
    { name: "cpu_wr_wen",      wave: "01....0.." },
    { name: "cpu_wr_wpkt_len", wave: "x.....=x.", data: ["68"] },
    { name: "cpu_wr_wpkt_push",wave: "0......10" }
  ],
}
```
---

## 第5段: FIFO → MAC TX (pktfifo2ram → sop_eop_gen → CRC32 → FCS插入)

```wavedrom
{
  config: { hscale: 2 },
  signal: [
    { name: "clk_125m",     wave: "p.......", period: 1 },
    { name: "mac_tx_sop",   wave: "010....." },
    { name: "mac_tx_en",    wave: "01....0." },
    { name: "mac_tx_data",  wave: "x==|.=x.", data: ["D0","","63"] },
    { name: "mac_tx_eop",   wave: "0....10." },
    {},
    { name: "crc_done",     wave: "0......10" },
    { name: "crc_insert",   wave: "x......=...", data: ["1000","0100","0010","0001"] },
    { name: "tx_data(mux)", wave: "x....=...x..", data: ["CRC[31:24]","[23:16]","[15:8]","[7:0]"] },
    { name: "gmii_tx_en",   wave: "=.1.......0.", data: ["8B前导码"] },
    { name: "gmii_txd",     wave: "===..=====x.", data: ["55xD5","DA","SA","Payload","crc","crc","crc","crc"] },
    { name: "gmii_tx_er",   wave: "0............." }
  ],
  edge: [
    "P~>Q mac_tx_sop TX帧起始",
    "P+8->Q crc_done CRC32覆盖DA~Payload(60B)",
    "P+9->Q gmii_txd 4拍FCS插入"
  ],
  foot: { text: [
    "mac_tx: SOP→Payload (不含FCS, 60B)",
    "crc_done后4拍插入新FCS(MSB first)",
    "gmii_tx: 多了8B前导码(55x7+D5) + 4B新FCS",
    "总长: 60+4FCS=64B → gmii侧 64+8前导码=72B"
  ], tock: 4 }
}
```

### FCS 插入时序

```
crc_done ─┐
           ├─ crc_insert[3]=1 → gmii_txd = crc_out[31:24]
           ├─ crc_insert[2]=1 → gmii_txd = crc_out[23:16]
           ├─ crc_insert[1]=1 → gmii_txd = crc_out[15:8]
           └─ crc_insert[0]=1 → gmii_txd = crc_out[7:0]
```

---

## 第6段: MAC TX → PC (GMII SDR → RGMII DDR → PHY → 以太网)

```wavedrom
{
  config: { hscale: 2 },
  signal: [
    { name: "clk_125m",     wave: "p..................", period: 1 },
    { name: "gmii_tx_en",   wave: "01.........0." },
    { name: "gmii_txd",     wave: "x==========x.", data: ["55","D5","DA","SA","T","...","crc3","crc2","crc1","crc0"] },
    { name: "gmii_tx_er",   wave: "0............" },
    {},
    { name: "rgmii_txc",    wave: "p.................", period: 1 },
    { name: "rgmii_txd",    wave: "x====.=====.x.", data: ["D[3:0]","D[7:4]","S[3:0]","S[7:4]","T[3:0]","T[7:4]","...","C[3:0]","C[7:4]"] },
    { name: "rgmii_tx_ctl", wave: "01..........0." }
  ],
}
```

### RGMII DDR 编码规则

| 信号 | posedge (D1) | negedge (D2) |
|------|-------------|-------------|
| `rgmii_txd[3:0]` | `gmii_txd[3:0]` | `gmii_txd[7:4]` |
| `rgmii_tx_ctl` | `gmii_tx_en` | `gmii_tx_en ^ gmii_tx_er` |

---

## 6段数据流总览

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│  第1段   │    │  第2段   │    │  第3段   │    │  第4段   │    │  第5段   │    │  第6段   │
│ PC→MAC_RX│───▶│ MAC→FIFO │───▶│ LCPU读   │    │ LCPU写   │───▶│ FIFO→MAC │───▶│ MAC→PC   │
│ 125MHz   │    │ 125MHz   │    │ 50MHz    │    │ 50MHz    │    │ 125MHz   │    │ 125MHz   │
│ RGMII→   │    │ 流式→    │    │ JTAG→    │    │ JTAG→    │    │ CRC32→   │    │ GMII→    │
│ GMII     │    │ 字节过滤 │    │ 逐字节读  │    │ 逐字节写  │    │ FCS插入  │    │ RGMII    │
└──────────┘    └──────────┘    └──────────┘    └──────────┘    └──────────┘    └──────────┘
```

### 时钟域分布

| 时钟 | 频率 | 段 |
|------|------|-----|
| `gmii_rx_clk` | 125MHz | 第1段 (RGMII RX) |
| `clk_125m` | 125MHz | 第1/2/5/6段 (数据面) |
| `cpu_clk` | 50MHz | 第3/4段 (LCPU JTAG) |
| `rgmii_txc` | 125MHz(90°) | 第6段 (RGMII TX) |

---

> 所有时序图使用 Wavedrom 语法 | VS Code 预览: 安装 Markdown Preview Wavedrom 插件后 `Ctrl+Shift+V`
