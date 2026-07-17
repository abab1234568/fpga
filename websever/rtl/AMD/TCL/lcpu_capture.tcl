#==============================================================================
# lcpu_capture.tcl — LCPU 抓包验证脚本
#
# 前提: 已在 Vivado TCL 中 source 了 LCPU_AMD_Driver.tcl
#       (已定义 rd32 / jwrite 函数, 已连接硬件)
#
# 用法 (Vivado TCL Console):
#   source LCPU_AMD_Driver.tcl        ← 连接硬件 + 定义底层读写函数
#   source lcpu_capture.tcl           ← 加载本脚本 (抓包功能)
#   lcpu_quick_test                   ← 一键验证
#
# 终端直接启动:
#   vivado -mode tcl -source LCPU_AMD_Driver.tcl
#   然后在 TCL 中: source lcpu_capture.tcl
#==============================================================================

#==============================================================================
# 寄存器读写 (基于 LCPU_AMD_Driver.tcl 的 rd32 / jwrite)
#==============================================================================
# rd32 和 jwrite 由 LCPU_AMD_Driver.tcl 定义:
#   rd32 <addr>           → 返回 hex 值
#   jwrite <addr> <data>  → 写寄存器
#   jread <addr> [n]      → 读 n 次 (可选)

proc reg_read {addr} {
    return [rd32 [expr $addr]]
}

proc reg_write {addr data} {
    jwrite [expr $addr] [expr $data]
}

#==============================================================================
# 过滤器配置
#==============================================================================
proc filter_ipv4 {} {
    puts "--- 配置 IPv4 过滤 ---"
    reg_write 0x10 0x8008;   # FILTER_CFG: enable, match=0x00, mask=0x08
    reg_write 0x14 0x0C01;   # FILTER_OFS: start=12, count=1
    reg_write 0x18 26;        # EXTRACT_OFS: byte26 = srcIP起始
    after 100
    set r1 [reg_read 0x10]
    set r2 [reg_read 0x14]
    set r3 [reg_read 0x18]
    puts "  FILTER_CFG  0x[format %04X $r1]"
    puts "  FILTER_OFS  0x[format %04X $r2]"
    puts "  EXTRACT_OFS $r3"
}

proc filter_arp {} {
    puts "--- 配置 ARP 过滤 ---"
    reg_write 0x10 0x8006
    reg_write 0x14 0x0D01
    reg_write 0x18 14
}

proc filter_udp_echo {} {
    puts "--- 配置 UDP Echo 过滤 ---"
    reg_write 0x10 0x8007
    reg_write 0x14 0x2501
    reg_write 0x18 42
}

proc filter_pass_all {} {
    puts "--- 放行所有 (bypass) ---"
    reg_write 0x0C 0x00000002
}

#==============================================================================
# 状态查询
#==============================================================================
proc lcpu_status {} {
    puts "--- LCPU 寄存器状态 ---"
    set ctrl    [reg_read 0x0C]
    set drop    [reg_read 0x00]
    set fcfg    [reg_read 0x10]
    set fofs    [reg_read 0x14]
    set extr    [reg_read 0x18]
    set empty   [expr {$ctrl & 0x01}]
    set bypass  [expr {($ctrl >> 1) & 0x01}]

    puts "  STATUS      0x[format %08X $drop]"
    puts "  CONTROL     0x[format %08X $ctrl]"
    puts "    empty       = $empty"
    puts "    bypass_mode = $bypass"
    puts "  FILTER_CFG  0x[format %04X $fcfg]"
    puts "    enable      = [expr {($fcfg >> 15) & 1}]"
    puts "    match       = 0x[format %02X [expr {($fcfg >> 8) & 0x7F}]]"
    puts "    mask        = 0x[format %02X [expr {$fcfg & 0xFF}]]"
    puts "  FILTER_OFS  0x[format %04X $fofs]"
    puts "    start       = [expr {($fofs >> 8) & 0xFF}]"
    puts "    count       = [expr {$fofs & 0xFF}]"
    puts "  EXTRACT_OFS [expr $extr]"
    puts "  丢弃计数     [expr $drop]"
}

#==============================================================================
# 等待命中帧
#==============================================================================
proc wait_hit {{timeout_ms 5000}} {
    set waited 0
    while {$waited < $timeout_ms} {
        set ctrl [reg_read 0x0C]
        set empty [expr {$ctrl & 0x01}]
        if {!$empty} { return 1 }
        after 100
        incr waited 100
        if {[expr $waited % 1000] == 0} {
            puts "  等待中... (${waited}ms)"
        }
    }
    return 0
}

#==============================================================================
# 单次抓包
#==============================================================================
proc lcpu_capture_once {} {
    puts "\n=========================================="
    puts "  LCPU 单次抓包"
    puts "=========================================="

    # 检查连接
    if {[catch {reg_read 0x00} err]} {
        puts "[失败] 无法读取寄存器, 请先执行:"
        puts "  source LCPU_AMD_Driver.tcl"
        return
    }

    # 等待命中
    puts "  等待命中帧..."
    if {![wait_hit 5000]} {
        puts "  [超时] 未检测到命中帧"
        puts "  提示: 请确认 PC1 正在发包且过滤规则正确"
        puts "        检查 bypass_mode (lcpu_status)"
        return
    }
    puts "  ✓ 命中帧就绪"

    # 先 pop (本版 package_fifo 需要 pop 后 rpkt_len 才有效)
    reg_write 0x0C 0x00000001
    after 200

    # 读长度 (pop 后 2 周期有效)
    set pkt_len [reg_read 0x04]
    puts "  包长度: $pkt_len 字节"

    # 读数据 (从 MAC 地址开始的全帧)
    set bytes {}
    set hex ""
    for {set i 0} {$i < $pkt_len} {incr i} {
        set b [reg_read 0x08]
        lappend bytes $b
        append hex [format "%02X " $b]
    }
    puts "  数据: $hex"

    # 帧解析 (全帧: dstMAC + srcMAC + EtherType + payload)
    if {$pkt_len >= 14} {
        set dst_mac [join [lrange $bytes 0 5] ":"]
        set src_mac [join [lrange $bytes 6 11] ":"]
        set ethtype [format "%04X" [expr {[lindex $bytes 12]*256 + [lindex $bytes 13]}]]
        puts "  dstMAC:    $dst_mac"
        puts "  srcMAC:    $src_mac"
        puts "  EtherType: 0x$ethtype"
        if {$ethtype eq "0800" && $pkt_len >= 34} {
            set src_ip [join [lrange $bytes 26 29] "."]
            set dst_ip [join [lrange $bytes 30 33] "."]
            puts "  Src IP:    $src_ip"
            puts "  Dst IP:    $dst_ip"
        }
    }

    puts "  抓包完成!\n"
}

#==============================================================================
# 连续监控
#==============================================================================
proc lcpu_monitor {} {
    puts "\n=========================================="
    puts "  LCPU 连续监控 (Ctrl+C 停止)"
    puts "=========================================="
    set n 0
    while {1} {
        set ctrl [reg_read 0x0C]
        set empty [expr {$ctrl & 0x01}]
        if {!$empty} {
            incr n
            # 先 pop, 再读长度
            reg_write 0x0C 0x00000001
            after 100
            set len [reg_read 0x04]
            set hex ""
            for {set i 0} {$i < $len} {incr i} {
                append hex [format "%02X " [reg_read 0x08]]
            }
            puts "  #$n len=$len: $hex"
        }
        after 200
    }
}

#==============================================================================
# 清空 FIFO (丢弃所有积压的包)
#==============================================================================
proc lcpu_flush {} {
    puts "--- 清空 FIFO ---"
    set cnt 0
    while {1} {
        set ctrl [reg_read 0x0C]
        set empty [expr {$ctrl & 0x01}]
        if {$empty} break
        reg_write 0x0C 0x00000001
        incr cnt
        after 10
    }
    puts "  清除了 $cnt 个包"
}

#==============================================================================
# 快速验证
#==============================================================================
proc lcpu_quick_test {} {
    puts "\n=========================================="
    puts "  LCPU 快速验证"
    puts "=========================================="
    lcpu_flush
    filter_ipv4
    lcpu_status
    puts "\n请在 PC1 发测试包 (如 ping)..."
    lcpu_capture_once
}

#==============================================================================
# 帮助
#==============================================================================
proc lcpu_help {} {
    puts {
LCPU 抓包脚本 — 可用命令:
============================================================
lcpu_status           查看寄存器状态
lcpu_flush            清空 FIFO
filter_ipv4           配置: 过滤 IPv4 包
filter_arp            配置: 过滤 ARP 包
filter_udp_echo       配置: 过滤 UDP Echo
filter_pass_all       配置: 放行所有 (bypass)
lcpu_capture_once     单次抓包 (等待命中→读取→打印)
lcpu_monitor          持续监控
lcpu_quick_test       一键验证
lcpu_help             显示此帮助
============================================================
手动操作:
  reg_read  0x0C      读 CONTROL (bit0=empty)
  reg_write 0x10 0x8008  配置过滤
  reg_read  0x08      读 1 字节数据
  reg_write 0x0C 0x01  pop 弹出包
============================================================
    }
}

#==============================================================================
# 启动
#==============================================================================
puts "=========================================="
puts "  LCPU 抓包脚本已加载"
puts "  lcpu_help  → 查看命令"
puts "  lcpu_quick_test → 一键验证"
puts "=========================================="
