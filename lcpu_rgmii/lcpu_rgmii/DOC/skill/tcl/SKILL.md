---
name: tcl
description: TCL 脚本编写 — Vivado JTAG/LCPU/ILA 调试
argument-hint: <要做什么>
---

# TCL Skill — LCPU/Vivado 调试

## 第一步：加载库

```tcl
source /home/huamingh/work/FPGA_Prj/test/lcpu_rgmii/lcpu_lib.tcl
```

之后用 `lread` / `lwrite` 替代 `jread` / `jwrite`，自动清理 AXI 事务残留。

---

## TCL 语法速查

### 循环
```tcl
# for 循环
for {set i 0} {$i < 5} {incr i} { jread 0x10 }

# while 循环
set i 0; while {$i < 5} { puts $i; incr i }

# foreach 遍历列表
set items {a b c d e}
foreach item $items { puts $item }
```

### 流程控制
```tcl
# break: 跳出循环
for {set i 0} {$i < 10} {incr i} {
    if {$i == 5} { break }
    puts "i: $i"
}

# continue: 跳过本次
for {set i 0} {$i < 10} {incr i} {
    if {$i % 2 == 0} { continue }
    puts "Odd i: $i"
}
```

### 间隔延时
```
Intel:  ~187ms/次 (921600 波特率)
Xilinx: ~187ms/次 (115200/921600 波特率)
循环里每轮至少 after 200
```

---

## LCPU 启动方式

### AMD (Vivado JTAG)
```tcl
source C:/work/LR_Common/JtagLCPU/AMD/TCL/lcpu_xilinx
source C:/work/LR_Common/JtagLCPU/AMD/TCL/LCPU_AMD_Driver.tcl
```

### Intel (Quartus JTAG)
```tcl
source ./Intel/lcpu
```

### UART
```tcl
# 1. 安装 ActiveTcl-8.6.7.0
# 2. 运行 Tclsh
source C:/work/LR_Common/JtagLCPU/UART/TCL/uart_lcpu
# 3. 设备管理器查 COM 端口
# 4. 修改 SerialPortDrv.tcl: set com_port com xxx
jopen
mm -rdl 0x10000
mm -wrl 0x100 0x88
jclose
```

---

## RAM 参数要求

| 厂商 | para_ram_type | data_ram_type |
|------|--------------|---------------|
| Intel/Altera | `"registers"` | `"M9K"` |
| AMD/Xilinx | `"distributed"` | `"BLOCK_RAM"` |

**设错症状:** 读任何地址返回值都是 0x0，或数据全空 `0x`。

---

## 读写格式

```
jread <addr>                   例: jread 0x0
jwrite <addr> <data>           例: jwrite 0x1 0x1

返回格式: Read Addr:00000000, Read Data Is:0x24073008
```

**本项目的 lread/lwrite (自动清理事务):**
```
lread 0x00         → bit0=0 有包, bit0=1 空
lwrite 0x01 0x01   → pop 包
```

---

## 本项目寄存器

| 地址 | 名 | R/W | 操作 |
|------|-----|-----|------|
| 0x00 | EMPTY | R | `[lread 0x00]` |
| 0x01 | POP | R/W | `lwrite 0x01 0x01` |
| 0x02 | LEN | R | `[lread 0x02]` |
| 0x03 | REN | R/W | `lwrite 0x03 0x01` / `0x00` |
| 0x04 | RADDR | R/W | `lwrite 0x04 $i` |
| 0x05 | RDATA | R | `[lread 0x05]` |
| 0x10 | WR_FULL | R | `[lread 0x10]` |
| 0x11 | WR_WEN | R/W | `lwrite 0x11 0x01` |
| 0x12 | WR_WADDR | R/W | `lwrite 0x12 $i` |
| 0x13 | WR_WDATA | R/W | `lwrite 0x13 $b` |
| 0x14 | WR_LEN | R/W | `lwrite 0x14 68` |
| 0x15 | WR_PUSH | R/W | `lwrite 0x15 0x01` |

---

## 模板

### 读包
```tcl
while {[lread 0x00]} { after 200 }
lwrite 0x01 0x01; after 500
set len [lread 0x02]
for {set i 0} {$i < $len} {incr i} {
    lwrite 0x04 $i; after 200
    lwrite 0x03 0x01; after 200
    lappend bytes [lread 0x05]; after 200
    lwrite 0x03 0x00; after 200
}
```

### 写包
```tcl
for {set i 0} {$i < 68} {incr i} {
    lwrite 0x13 $b; after 100
    lwrite 0x12 $i; after 100
    lwrite 0x11 0x01; after 100
}
after 200; lwrite 0x14 68; after 100; lwrite 0x15 0x01
```

### 监控
```tcl
set n 0
while {1} {
    if {![lread 0x00]} {
        incr n; lwrite 0x01 0x01; after 200
        set len [lread 0x02]; set hex ""
        for {set i 0} {$i < $len} {incr i} {
            lwrite 0x04 $i; lwrite 0x03 0x01
            append hex [format "%02X " [lread 0x05]]
            lwrite 0x03 0x00
        }
        puts "#$n len=$len: $hex"
    }
    after 200
}
```

### 清空
```tcl
set cnt 0
while {![lread 0x00]} { lwrite 0x01 0x01; incr cnt; after 10 }
puts "清除了 $cnt 个包"
```

### JTAG 重连
```tcl
disconnect_hw_server; connect_hw_server
open_hw_target; refresh_hw_device
```

### ILA 触发
```
边沿: <signal> → R / F
电平: <signal> == <value>
```

### 调试示例
```tcl
# 读 FPGA 时间
jread 0x1

# 读写 LED
jread 0x80000001
jwrite 0x80000001 0xf    # 全亮
jwrite 0x80000001 0x0    # 全灭
```

---

## 常见问题

**读出来值为空 (0x)**:
1. 波特率设置不对
2. UART 通信不正常
3. 内部 RAM 设置不对 (检查 uart_rx/tx 的 RAM 参数)
4. para_ram_type / data_ram_type 设错了

**所有地址都是 0 地址的值**: packet_fifo 的 data_ram 类型不对，按厂商切换 `M9K`/`BLOCK_RAM`
