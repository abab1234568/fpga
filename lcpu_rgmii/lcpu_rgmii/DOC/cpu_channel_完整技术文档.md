# 3.6.5 二级 cpu_channel 模块

## 3.6.5.1 二级 cpu_channel 模块功能描述（Feature）

### 1. 模块标识

| 属性     | 值                              |
| -------- | -------------------------------- |
| 模块名称 | cpu_channel                      |
| 文件路径 | fpga_webserver/rtl/cpu_channel.v |

### 2. 功能描述

- CPU 与以太网 MAC 之间的数据通道，桥接 125MHz MAC 域和 50MHz CPU 域
- **RX 路径**：MAC → ram2pktfifo_int（字节流→包FIFO接口）→ package_fifo_v2（异步FIFO，125MHz→50MHz）→ CPU 读端口
- **TX 路径**：CPU 写端口 → package_fifo_v2（异步FIFO，50MHz→125MHz）→ pktfifo2ram_int_v2（包FIFO→字节流）→ sop_eop_gen（生成SOP/EOP边带）→ MAC
- 集成数据包过滤器：根据 filter_data/filter_offset 匹配数据字节决定转发/丢弃
- 丢包计数器

### 3. 内部模块结构图

**图24 cpu_channel 模块内部结构**

```
                MAC RX                              RISC-V CPU
           (sop/en/data/eop)                             │
                  │                                       │ CPU WR Port
                  │                                       ▼
   ┌──────────────┼───────────────────────────────────────────────────────────┐
   │              ▼                cpu_channel                                │
   │  ┌─────────────────────┐               ┌─────────────────────┐          │
   │  │   ram2pktfifo_int    │               │   package_fifo_v2    │          │
   │  │   字节流→包FIFO       │               │      (异步FIFO)       │          │
   │  └──────────┬──────────┘               └──────────┬──────────┘          │
   │              │                                     │                     │
   │  ┌───────────▼───────────┐             ┌───────────▼───────────┐        │
   │  │       包过滤器          │             │   pktfifo2ram_int_v2   │        │
   │  │   data match @ offset  │◄─filter_data │    包FIFO→字节流       │        │
   │  │                        │  filter_offset└───────────┬───────────┘        │
   │  └───┬────────────────┬──┘                            │                 │
   │      │pass_enable     │(未命中/丢包)                    ▼                 │
   │      ▼                └──────────────────►  ┌──────────────────┐        │
   │  ┌─────────────────────┐                     │    sop_eop_gen    │        │
   │  │   package_fifo_v2    │                     │   生成SOP/EOP     │        │
   │  │      (异步FIFO)       │                     └─────────┬────────┘        │
   │  └──────────┬──────────┘                               │                 │
   │             │                                           │                 │
   └─────────────┼───────────────────────────────────────────┼─────────────────┘
                 │ CPU RD Port                                │ MAC TX
                 ▼                                            ▼
            RISC-V CPU                                     MAC TX

   （包过滤器另有一路输出连接 recv_pkt_drop_cnt，用于丢包计数）
```

> 说明：RX 路径中，`包过滤器` 依据 `filter_data`/`filter_offset` 对 `ram2pktfifo_int` 输出的数据在指定偏移处做匹配；命中（`pass_enable`）的包才会进入第二级 `package_fifo_v2` 供 CPU 读取，未命中的包计入 `recv_pkt_drop_cnt`。

---

### 4. 接口信号表

**表16 cpu_channel 模块接口信号表**

#### 系统接口

| 信号名   | 位宽（Bits） | IO  | 说明               |
| -------- | ------------ | --- | ------------------ |
| clk      | 1            | I   | MAC侧时钟（125MHz） |
| cpu_clk  | 1            | I   | CPU侧时钟（50MHz）  |
| reset_l  | 1            | I   | 复位（低有效）      |

#### MAC RX接口（125MHz）

| 信号名      | 位宽（Bits）       | IO  | 说明       |
| ----------- | ------------------ | --- | ---------- |
| mac_rx_sop  | 1                  | I   | 接收包起始 |
| mac_rx_en   | 1                  | I   | 接收数据使能 |
| mac_rx_data | cpu_buf_data_width | I   | 接收数据   |
| mac_rx_eop  | 1                  | I   | 接收包结束 |
| mac_rx_err  | 1                  | I   | 接收错误   |

#### MAC TX接口（125MHz）

| 信号名      | 位宽（Bits）       | IO  | 说明       |
| ----------- | ------------------ | --- | ---------- |
| mac_tx_sop  | 1                  | O   | 发送包起始 |
| mac_tx_en   | 1                  | O   | 发送数据使能 |
| mac_tx_data | cpu_buf_data_width | O   | 发送数据   |
| mac_tx_eop  | 1                  | O   | 发送包结束 |
| mac_tx_err  | 1                  | O   | 发送错误   |

#### 过滤器配置

| 信号名           | 位宽（Bits） | IO  | 说明         |
| ---------------- | ------------ | --- | ------------ |
| filter_data       | 16           | I   | 过滤匹配数据 |
| filter_offset     | 16           | I   | 过滤匹配偏移 |
| recv_pkt_drop_cnt | 8            | O   | 丢包计数     |

#### CPU读端口（50MHz）

| 信号名           | 位宽（Bits）             | IO  | 说明     |
| ---------------- | ------------------------ | --- | -------- |
| cpu_rd_empty      | 1                         | O   | 读FIFO空 |
| cpu_rd_rpkt_pop   | 1                         | I   | 读包弹出 |
| cpu_rd_rpkt_len   | cpu_buf_addr_width+1     | O   | 读包长度 |
| cpu_rd_ren        | 1                         | I   | 读使能   |
| cpu_rd_raddr      | cpu_buf_addr_width       | I   | 读地址   |
| cpu_rd_rdata      | cpu_buf_data_width       | O   | 读数据   |

#### CPU写端口（50MHz）

| 信号名           | 位宽（Bits）             | IO  | 说明     |
| ---------------- | ------------------------ | --- | -------- |
| cpu_wr_full       | 1                         | O   | 写FIFO满 |
| cpu_wr_wen        | 1                         | I   | 写使能   |
| cpu_wr_waddr      | cpu_buf_addr_width       | I   | 写地址   |
| cpu_wr_wdata      | cpu_buf_data_width       | I   | 写数据   |
| cpu_wr_wpkt_push  | 1                         | I   | 写包推送 |
| cpu_wr_wpkt_len   | cpu_buf_addr_width+1     | I   | 写包长度 |

---

### 5. 接口时序

#### 图25 cpu_channel RX 数据通道（MAC→CPU）

**MAC侧（125MHz clk，信号名来自 `ip_common/doc/常用LRIP接口时序.md` gmii2mac MAC侧包流接口）：**

```
clk         : _/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_
mac_rx_sop  : ____/‾\____________________________________________
mac_rx_en   : ____/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\____
mac_rx_data : XXXX|DMAC..|SMAC..|........|........FSC..|XXXXX
mac_rx_eop  : ____________________________________________/‾\___
mac_rx_err  : ___________________________________________________
```

> RX数据在 `mac_rx_en=1` 期间有效，`mac_rx_sop`/`mac_rx_eop` 各持续1个 clk 周期。

**CPU侧（50MHz cpu_clk，参考包FIFO读时序，信号名调整为 cpu_channel 端口名）：**

```
cpu_clk        : _/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_
cpu_rd_empty   : ‾‾‾\_______________________________________
cpu_rd_rpkt_pop: ______/‾\____________________________________
cpu_rd_rpkt_len: XXXXXXXX|  n  |XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
cpu_rd_ren     : ______________/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\________
cpu_rd_raddr   : XXXXXXXXXXXXXX| 0 | 1 |  ...  | n-1 |XXXXXXXX
cpu_rd_rdata   : XXXXXXXXXXXXXX| D0| D1|  ...  |Dn-1 |XXXXXXXX
```

> `cpu_rd_empty=0` 时 CPU 通过 reg_webserver 发送 `cpu_rd_rpkt_pop=1` 弹出包；2周期后 `cpu_rd_rpkt_len` 有效；随后 `cpu_rd_ren=1` 逐字读取，`cpu_rd_raddr` 递增。

---

#### 图26 cpu_channel TX 数据通道（CPU→MAC）

**CPU侧（50MHz cpu_clk，参考包FIFO写时序，信号名调整为 cpu_channel 端口名）：**

```
cpu_clk          : _/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_
cpu_wr_wen       : ____/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\____________
cpu_wr_waddr     : XXXX| 0 | 1 |    ...    | n-1 |XXXXXXXXXXXXXXX
cpu_wr_wdata     : XXXX| D0| D1|    ...    |Dn-1 |XXXXXXXXXXXXXXX
cpu_wr_wpkt_push : ___________________________________/‾\________
cpu_wr_wpkt_len  : XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX| n |XXXXXX
cpu_wr_full      : _________________________________________________
```

> CPU 通过 reg_webserver 逐字写入包数据（`cpu_wr_wen=1`），写入完成后发送 `cpu_wr_wpkt_push=1` 推送完整包。

**MAC侧（125MHz clk，TX方向与RX对称，来源同 MAC侧包流接口）：**

```
clk         : _/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_
mac_tx_sop  : ____/‾\____________________________________________
mac_tx_en   : ____/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\____
mac_tx_data : XXXX|DMAC..|SMAC..|........|........FSC..|XXXXX
mac_tx_eop  : ____________________________________________/‾\___
mac_tx_err  : ___________________________________________________
```

> MAC TX 方向时序与 RX 对称：`sop`/`eop` 各1周期脉冲，`en=1` 期间 `data` 有效。`err=1` 时强制产生错误 FCS。

---

### 6. 数据流总述

- **RX**：MAC(125MHz) → ram2pktfifo_int → 包FIFO写 → CDC(125→50MHz) → 包FIFO读 → CPU读端口
- **TX**：CPU写端口 → 包FIFO写 → CDC(50→125MHz) → 包FIFO读 → pktfifo2ram_int_v2 → sop_eop_gen → MAC TX(125MHz)

---

## 3.6.5.1 三级 ram2pktfifo_int 模块

### 1. 模块标识

| 属性     | 值                                |
| -------- | ---------------------------------- |
| 模块名称 | ram2pktfifo_int                    |
| 文件路径 | ip_common/rtl/ram2pktfifo_int.v     |

### 2. 功能描述

- 将连续字节流（ram_wen/ram_wdata/ram_waddr）转换为包FIFO接口
- 通过 ram_wen_permit 实现背压控制
- 自动检测包边界并生成 wpkt_push/wpkt_len 信号

### 3. 接口信号

**表17 ram2pktfifo_int 模块接口信号表**

| 信号名     | 位宽（Bits） | IO  | 说明       |
| ---------- | ------------ | --- | ---------- |
| clk        | 1            | I   | 时钟       |
| reset_l    | 1            | I   | 复位       |
| ram_wen    | 1            | I   | 字节写使能 |
| ram_wdata  | data_width   | I   | 字节写数据 |
| ram_waddr  | addr_width   | I   | 字节写地址 |
| wen        | 1            | O   | FIFO写使能 |
| wdata      | data_width   | O   | FIFO写数据 |
| waddr      | addr_width   | O   | FIFO写地址 |
| wpkt_push  | 1            | O   | 包推送     |
| wpkt_len   | addr_width+1 | O   | 包长度     |

### 4. 接口时序

**图27 ram2pktfifo_int 字节流转包FIFO时序**

`ram2pktfifo_int: 连续字节流 → 包FIFO写接口`

```
clk        : _/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_
ram_wen    : ____/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\____________
ram_wdata  : XXXX| D0| D1| D2| D3| D4| D5|XXXXXXXXXXXXXXXXX
ram_waddr  : XXXX| 0 | 1 | 2 | 3 | 4 | 5 |XXXXXXXXXXXXXXXXX
wen        : ____/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\____________
wdata      : XXXX| D0| D1| D2| D3| D4| D5|XXXXXXXXXXXXXXXXX
waddr      : XXXX| 0 | 1 | 2 | 3 | 4 | 5 |XXXXXXXXXXXXXXXXX
wpkt_push  : ______________________________________/‾\_____
wpkt_len   : XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX| 6 |XXX
```

> **EOP检测**：`ram_wen` 连续拉高后拉低，自动生成 `wpkt_push` 脉冲和 `wpkt_len`（累计字节数）。

---

## 3.6.5.2 三级 package_fifo_v2 模块

### 1. 模块标识

| 属性     | 值                              |
| -------- | -------------------------------- |
| 模块名称 | package_fifo_v2                  |
| 文件路径 | ip_common/rtl/package_fifo_v2.v   |

### 2. 功能描述

- 双时钟异步数据包FIFO（支持跨时钟域）
- 存储数据包及其长度/参数信息
- 支持 Block RAM 或分布式RAM实现
- 支持 block 模式（多块组合）和 max_pkt_length 限制
- 在 cpu_channel 中例化2个：RX方向（125→50MHz）和TX方向（50→125MHz）

### 3. 内部模块结构图

**图28 package_fifo_v2 模块内部结构**

```
   写端口                                    ┌─────────────────────┐
(wen/wdata/wpkt_push) ─────────────────────► │   dual_port_ram      │──────┐
        │                                    │      数据RAM         │      │
        │              ┌──────────────┐      └─────────────────────┘      │
        ├─────────────►│              │                                    ▼
        │              │  控制逻辑     │      ┌─────────────────────┐   读端口
   wclk ───────────────►│ 读写指针/空满 │─────►│      para_ram        │──►(ren/rdata)
        │              │              │      │      参数RAM         │      ▲
   rclk ───────────────►│              │      └─────────────────────┘      │
        │              └──────────────┘                                    │
        └─────────────────────────────────────────────────────────────────┘
```

### 4. 接口信号

**表18 package_fifo_v2 模块接口信号表**

| 信号名     | 位宽（Bits） | IO  | 说明     |
| ---------- | ------------ | --- | -------- |
| reset_l    | 1            | I   | 复位     |

**写端口**

| 信号名     | 位宽（Bits） | IO  | 说明     |
| ---------- | ------------ | --- | -------- |
| wclk       | 1            | I   | 写时钟   |
| full       | 1            | O   | FIFO满   |
| wen        | 1            | I   | 写使能   |
| waddr      | addr_width   | I   | 写地址   |
| wdata      | data_width   | I   | 写数据   |
| wpkt_push  | 1            | I   | 包推送   |
| wpkt_len   | addr_width+1 | I   | 包长度   |
| wpkt_para  | para_width   | I   | 包参数   |

**读端口**

| 信号名     | 位宽（Bits） | IO  | 说明     |
| ---------- | ------------ | --- | -------- |
| rclk       | 1            | I   | 读时钟   |
| empty      | 1            | O   | FIFO空   |
| rpkt_pop   | 1            | I   | 包弹出   |
| rpkt_len   | addr_width+1 | O   | 包长度   |
| rpkt_para  | para_width   | O   | 包参数   |
| ren        | 1            | I   | 读使能   |
| raddr      | addr_width   | I   | 读地址   |
| rdata      | data_width   | O   | 读数据   |

### 5. 接口时序

**图29 包FIFO写时序**

```
wclk       : _/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_
wen        : ____/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\_________
waddr      : XXXX| 0 | 1 |   ...   | n-1 |XXXXXXXXXXXXXXX
wdata      : XXXX| D0| D1|   ...   |Dn-1 |XXXXXXXXXXXXXXX
wpkt_push  : ______________________________/‾\____________
wpkt_len   : XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX| n |XXXXXXXXXX
wpkt_para  : XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX|Para|XXXXXXXXX
full       : ____________________________________________
```

> **包FIFO写时序说明**（来源：`ip_common/doc/常用LRIP接口时序.md`）：
> - `wclk` 为写侧时钟，`wen=1` 时 `waddr`/`wdata` 有效，逐字写入包数据。
> - 包数据写入完成后，紧接着发送 `wpkt_push=1`（与 `wen=0` 同一周期），`wpkt_len` 给出包总长度（word数），`wpkt_para` 为附带参数。
> - `full=1` 时表示 FIFO 剩余空间不足以容纳最大包，此时不应再写入。

**图30 包FIFO读时序**

```
rclk       : _/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_
empty      : ‾‾\_____________________________________
rpkt_pop   : ____/‾\_________________________________
rpkt_len   : XXXXXXXX| n |XXXXXXXXXXXXXXXXXXXXXXXXXXXX
rpkt_para  : XXXXXXXX|Para|XXXXXXXXXXXXXXXXXXXXXXXXXXX
ren        : ________________/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\________
raddr      : XXXXXXXXXXXXXXXX| 0 | 1 |...| n-1 |XXXXXXX
rdata      : XXXXXXXXXXXXXXXX| D0| D1|...|Dn-1 |XXXXXXX
```

> **包FIFO读时序说明**（来源：`ip_common/doc/常用LRIP接口时序.md`）：
> - `rclk` 为读侧时钟，`empty=0` 时发送 `rpkt_pop=1` 弹出一个包。
> - `rpkt_pop` 发出后 2 个时钟周期 `rpkt_len` 和 `rpkt_para` 有效。
> - 通过 `ren=1` 逐字读取，`raddr` 为偏移地址（0~`rpkt_len`-1），`rdata` 在下一个时钟周期返回。

**RAM 实现配置**

| RAM 类型   | 数量 | 配置        | 用途           |
| ---------- | ---- | ----------- | -------------- |
| M9K        | 2    | 4096×8bits  | RX/TX数据缓冲  |
| 分布式RAM  | 少量 | —           | 包参数存储     |

---

## 3.6.5.3 三级 pktfifo2ram_int_v2 模块

### 1. 模块标识

| 属性     | 值                                  |
| -------- | ------------------------------------ |
| 模块名称 | pktfifo2ram_int_v2                   |
| 文件路径 | ip_common/rtl/pktfifo2ram_int_v2.v    |

### 2. 功能描述

- 将包FIFO接口（rpkt_pop/rpkt_len/ren/rdata）转换为连续字节流输出
- 自动插入 IPG（Inter-Packet Gap）间隔
- 支持 block 模式

### 3. 接口信号

**表19 pktfifo2ram_int_v2 模块接口信号表**

| 信号名     | 位宽（Bits） | IO  | 说明         |
| ---------- | ------------ | --- | ------------ |
| clk        | 1            | I   | 时钟         |
| reset_l    | 1            | I   | 复位         |
| empty      | 1            | I   | FIFO空       |
| rpkt_pop   | 1            | O   | 包弹出       |
| rpkt_len   | addr_width+1 | I   | 包长度       |
| ren        | 1            | O   | 读使能       |
| raddr      | addr_width   | O   | 读地址       |
| rdata      | data_width   | I   | 读数据       |
| ram_wen    | 1            | O   | 字节流写使能 |
| ram_wdata  | data_width   | O   | 字节流写数据 |

**模块控制参数**

| 参数 | 类型      | 说明             |
| ---- | --------- | ---------------- |
| ipg  | integer   | IPG间隔（8周期）  |

### 4. 接口时序

**图31 pktfifo2ram_int_v2 包FIFO→字节流+IPG时序**

`pktfifo2ram_int_v2: 包FIFO读取 → 字节流输出+IPG间隔插入`

```
clk        : _/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_
empty      : ‾‾\_____________________________________
rpkt_pop   : ____/‾\_________________________________
rpkt_len   : XXXX|          2          |XXXXXXXXXXXXXX
ren        : ________/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\__________________
rdata      : XXXXXXXX| D0| D1| D2| D3|XXXXXXXXXXXXXXXXXX
ram_wen    : ________/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\__________________
ram_wdata  : XXXXXXXX| D0| D1| D2| D3|XXXXXXXXXXXXXXXXXX
```

> `rpkt_pop` 弹出包 → 逐字节 `ren` 读取 → `ram_wen` 输出；包间自动插入 `ipg=8` 个时钟周期。

---

## 3.6.5.4 三级 sop_eop_gen 模块

### 1. 模块标识

| 属性     | 值                          |
| -------- | ---------------------------- |
| 模块名称 | sop_eop_gen                  |
| 文件路径 | ip_common/rtl/sop_eop_gen.v   |

### 2. 功能描述

- 从连续字节流（i_en/i_data）生成带SOP/EOP边带信号的包流
- 检测 i_en 的上升沿作为 SOP
- 检测 i_en 的下降沿作为 EOP
- 用于 cpu_channel TX路径中 pktfifo2ram_int_v2 输出转换为 MAC 所需格式

### 3. 时序图

**图32 sop_eop_gen 时序**

`sop_eop_gen: 连续字节流 → 带SOP/EOP边带的包流`

```
clk    : _/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_
i_en   : ____/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\____
i_data : XXXX| D0| D1| D2| D3| D4| D5|XXXXX
o_sop  : ____/‾\______________________________
o_en   : ______/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\____
o_data : XXXXXX| D0| D1| D2| D3| D4| D5|XXXXX
o_eop  : __________________________/‾\________
```

> `i_en` 上升沿 → `o_sop=1`；`i_en` 下降沿 → `o_eop=1`；`o_en` 比 `i_en` 延迟1个时钟周期。
