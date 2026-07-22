# RGMII → GMII 回环 + cpu_channel + LCPU 仿真执行顺序

> 项目: lcpu_rgmii | 日期: 2026-07-16 | 基于 `CLAUDE.md` 数据通路设计

---

## 仿真环境

| 项目 | 说明 |
|------|------|
| 被测模块 | `rgmii_gmii_loopback_top` |
| 时钟 | `clk_50m` (20ns), MMCM → `clk_125m` / `clk_200m` / `clk_125m_tx` / `cpu_clk` |
| 复位 | `rst_n` 低有效, MMCM 锁定后 `rst_n_int` 内部释放 |
| 寄存器接口 | LCPU bus (`lcpu_req`/`lcpu_rh_wl`/`lcpu_address`/`lcpu_wdata`/`lcpu_rdata`/`lcpu_ack`) |

---

## 阶段 0：初始化

| 步骤 | 操作 | 说明 |
|------|------|------|
| 0.1 | 产生 `clk_50m`（周期 20ns） | 外部 50MHz 时钟 |
| 0.2 | 拉低 `rst_n`，保持 ≥ 200ns | 外部复位 |
| 0.3 | 释放 `rst_n` | 启动 MMCM |
| 0.4 | 轮询 `mmcm_locked == 1` | MMCM 锁定后内部时钟 (`clk_125m`/`cpu_clk`) 就绪 |
| 0.5 | 等待 `phy_rst_n == 1` | PHY 复位释放（~16ms @125MHz） |

---

## 阶段 1：RX 通路 — 过滤未命中帧

| 步骤 | 操作 | 说明 |
|------|------|------|
| 1.1 | 构造以太网帧 A：byte[61] = 0x00，帧长 64B（GMII 侧 DA~FCS 共 60B + 前导码 8B = 68B RGMII 传输） | 过滤条件 byte[61]==0x77 不满足 |
| 1.2 | 在 `rgmii_rxc` 时钟下，按 RGMII DDR 时序发送帧 A | `rgmii_rxd[3:0]` 上升沿发 gmii_txd[3:0]，下降沿发 gmii_txd[7:4] |
| 1.3 | `rgmii_rx_ctl` 在数据有效期间拉高（DDR，上升沿=RX_DV，下降沿=RX_DV^RX_ER） | |
| 1.4 | 等待 `cpu_rd_empty == 1` | 确认 FIFO 为空，帧被过滤丢弃 |
| 1.5 | 检查 `recv_pkt_drop_cnt` 不变 | 非命中帧不应计入丢弃计数 |

---

## 阶段 2：RX 通路 — 过滤命中帧 + CPU 读包

| 步骤 | 操作 | 说明 |
|------|------|------|
| 2.1 | 构造以太网帧 B：byte[0..60] 可自定义，byte[61] = 0x77 ('w')，其余字节任意 | 过滤条件满足 |
| 2.2 | 按 RGMII DDR 时序发送帧 B | |
| 2.3 | 在 `cpu_clk` 域轮询，等待 `cpu_rd_empty == 0` | 有包待读 |
| 2.4 | **CPU 读包（LCPU bus 操作）：** | |
| 2.4a | `req=1, rhwl=0, address=0x01, wdata=0x01` → 等 `ack=1` | 写 `cpu_rd_rpkt_pop`，弹出包 |
| 2.4b | `req=1, rhwl=1, address=0x02` → 等 `ack=1`，读 `rdata` | 读 `cpu_rd_rpkt_len`，获取包长度 N |
| 2.4c | for i = 0 to N-1: | 逐字节读取 |
| 2.4c1 | `req=1, rhwl=0, address=0x04, wdata=i` → 等 `ack=1` | 写 `cpu_rd_raddr`，设置读地址 |
| 2.4c2 | `req=1, rhwl=0, address=0x03, wdata=0x01` → 等 `ack=1` | 写 `cpu_rd_ren`，读使能 |
| 2.4c3 | 等待 2 拍 `cpu_clk` | 读数据延迟 2 拍 |
| 2.4c4 | `req=1, rhwl=1, address=0x05` → 等 `ack=1`，读 `rdata[7:0]` | 读 `cpu_rd_rdata` |
| 2.4c5 | `req=1, rhwl=0, address=0x03, wdata=0x00` → 等 `ack=1` | 写 `cpu_rd_ren=0`，关读使能 |
| 2.5 | 验证读出的 byte[0..N-1] 与发送帧 B 的 DA~Payload 一致 | 数据完整性校验 |

---

## 阶段 3：RX 通路 — 多帧连续测试

| 步骤 | 操作 | 说明 |
|------|------|------|
| 3.1 | 连续发送 3 帧：byte[61] 分别为 0x77 / 0x00 / 0x77 | 命中→丢弃→命中 |
| 3.2 | 验证只有 2 帧进入 CPU FIFO（`cpu_rd_empty` 变化 2 次） | |
| 3.3 | 依次 CPU 读包（重复阶段 2.4），验证两帧数据正确 | |

---

## 阶段 4：TX 通路 — CPU 写包 + RGMII 发送

| 步骤 | 操作 | 说明 |
|------|------|------|
| 4.1 | LCPU 读 0x10，确认 `cpu_wr_full == 0` | 写 FIFO 未满 |
| 4.2 | **CPU 写包（LCPU bus 操作）：** | |
| 4.2a | for i = 0 to M-1: | 逐字节写入（M 为包长，不含 FCS） |
| 4.2a1 | `req=1, rhwl=0, address=0x12, wdata=i` → 等 `ack=1` | 写 `cpu_wr_waddr`（**先地址**） |
| 4.2a2 | `req=1, rhwl=0, address=0x13, wdata=byte_val` → 等 `ack=1` | 写 `cpu_wr_wdata`（**再数据**） |
| 4.2a3 | `req=1, rhwl=0, address=0x11, wdata=0x01` → 等 `ack=1` | 写 `cpu_wr_wen`（**最后 wen 脉冲**） |
| 4.2b | `req=1, rhwl=0, address=0x14, wdata=M` → 等 `ack=1` | 写 `cpu_wr_wpkt_len` |
| 4.2c | `req=1, rhwl=0, address=0x15, wdata=0x01` → 等 `ack=1` | 写 `cpu_wr_wpkt_push`，推入 FIFO |
| 4.3 | 监控 RGMII TX：`rgmii_tx_ctl=1` 期间捕获 `rgmii_txd` | 观察 TX 帧输出 |
| 4.4 | 验证 RGMII TX 发出的帧： | |
| 4.4a | 前 8B = 7×0x55 + 0xD5 | eth_presemble TX 自动插入前导码 |
| 4.4b | 后续 M 字节 = CPU 写入的数据 | 数据一致 |
| 4.4c | 最后 4B = MAC 自动计算的 FCS | CRC32 自动插入 |

---

## 阶段 5：RX+TX 并发测试

| 步骤 | 操作 | 说明 |
|------|------|------|
| 5.1 | 同时启动两个操作： | 验证 RX/TX 通路独立，无互相干扰 |
| 5.1a | RGMII RX 发送命中帧（byte[61]=0x77） | |
| 5.1b | CPU 写 FIFO 注入另一帧（阶段 4.2 流程） | |
| 5.2 | CPU 读包验证 RX 帧正确 | |
| 5.3 | RGMII TX 监控验证 CPU 注入帧正确发出 | |

---

## 阶段 6：边界条件测试

| 步骤 | 操作 | 说明 |
|------|------|------|
| 6.1 | 发送最小帧（64B 含 FCS，GMII 侧 60B）byte[61]=0x77 | 最小帧过滤命中 |
| 6.2 | CPU 读包验证数据完整，`cpu_rd_rpkt_len == 60` | |
| 6.3 | 发送最大帧（1518B 含 FCS，GMII 侧 1514B）byte[61]=0x77 | 最大帧过滤命中 |
| 6.4 | CPU 读包验证数据完整，`cpu_rd_rpkt_len == 1514` | |
| 6.5 | 连续 CPU 写 FIFO 直到 `cpu_wr_full == 1` | 验证 FIFO 反压 |
| 6.6 | 发送 CRC 错误帧（正常时序但 FCS 故意错误），验证 `mac_rx_err==1` | CRC 错误帧被丢弃，不进 CPU FIFO |
| 6.7 | 发送 byte[61]=0x77 但 byte[60]=0x77 的帧 | 验证仅 byte[61] 位置参与过滤 |
| 6.8 | 在帧中间（非 byte[61] 位置）出现 0x77，验证不影响过滤结果 | 位置精确匹配 |

---

## 阶段 7：结束

| 步骤 | 操作 | 说明 |
|------|------|------|
| 7.1 | 打印统计计数器 | `rx_correct_pkt_cnt` / `rx_crc_err_pkt_cnt` / `recv_pkt_drop_cnt` |
| 7.2 | `$finish` | 仿真结束 |

---

## 附录：LCPU 寄存器操作速查

### 读侧寄存器（RX 抓包）

| 地址 | 名称 | 操作 | 说明 |
|------|------|------|------|
| 0x00 | cpu_rd_empty | **读** | bit[0]=0 有包待读，bit[0]=1 空 |
| 0x01 | cpu_rd_rpkt_pop | **写 0x01** | 弹出包（WC 脉冲） |
| 0x02 | cpu_rd_rpkt_len | **读** | 当前包长度（pop 后下一拍有效） |
| 0x03 | cpu_rd_ren | **写** 0x01/0x00 | 读使能 |
| 0x04 | cpu_rd_raddr | **写** offset | 包内字节偏移地址 |
| 0x05 | cpu_rd_rdata | **读** | 读数据（低 8bit 有效） |

### 写侧寄存器（TX 发包）

| 地址 | 名称 | 操作 | 说明 |
|------|------|------|------|
| 0x10 | cpu_wr_full | **读** | bit[0]=1 表示 FIFO 满 |
| 0x11 | cpu_wr_wen | **写 0x01** | 写使能脉冲（WC，**最后写**） |
| 0x12 | cpu_wr_waddr | **写** offset | 写地址（**先写地址**） |
| 0x13 | cpu_wr_wdata | **写** byte | 写数据（**再写数据**） |
| 0x14 | cpu_wr_wpkt_len | **写** length | 写包长度 |
| 0x15 | cpu_wr_wpkt_push | **写 0x01** | 推包发送（WC 脉冲） |

### LCPU Bus 信号

| 信号 | 方向 | 说明 |
|------|------|------|
| `lcpu_req` | in | 请求有效 |
| `lcpu_rh_wl` | in | 1=读, 0=写 |
| `lcpu_address[15:0]` | in | 寄存器地址 |
| `lcpu_wdata[31:0]` | in | 写数据 |
| `lcpu_rdata[31:0]` | out | 读数据 |
| `lcpu_ack` | out | 操作完成应答 |

> **写操作要点：** 写地址(0x12) → 写数据(0x13) → **写使能脉冲(0x11)**，顺序不可颠倒。
