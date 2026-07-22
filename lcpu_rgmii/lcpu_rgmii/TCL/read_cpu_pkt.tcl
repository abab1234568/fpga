# read_cpu_pkt.tcl — Read packets from cpu_channel CPU_RD FIFO (JTAG)
# Usage: source read_cpu_pkt.tcl ; read_all_pkts
#
# Registers:
#   0x00 cpu_rd_empty      RO  1=empty 0=has_pkt
#   0x01 cpu_rd_rpkt_pop   WC  write 1 to pop, then write 0
#   0x02 cpu_rd_rpkt_len   RO  pkt length (valid after pop)
#   0x03 cpu_rd_ren        RW  write 1 to enable read
#   0x04 cpu_rd_raddr      RW  byte offset in pkt
#   0x05 cpu_rd_rdata      RO  byte data at raddr

# Clean leftover AXI transactions
catch {delete_hw_axi_txn read_txn}
catch {delete_hw_axi_txn write_txn}

proc read_one_pkt {} {
    catch {delete_hw_axi_txn read_txn}
    catch {delete_hw_axi_txn write_txn}

    set empty [expr {[jread 0x00]}]
    if {$empty == 1} {
        puts "FIFO empty"
        return {}
    }

    jwrite 0x01 1
    after 200
    jwrite 0x01 0

    set len [expr {[jread 0x02]}]
    if {$len <= 0} {
        puts "WARNING: bad pkt_len=$len"
        return {}
    }
    puts "pkt_len: $len bytes"

    jwrite 0x03 1

    set bytes {}
    for {set i 0} {$i < $len} {incr i} {
        jwrite 0x04 $i
        after 200
        set b [expr {[jread 0x05] & 0xff}]
        lappend bytes $b
    }

    jwrite 0x03 0

    # Print hex, 16 bytes per line
    set line ""
    for {set i 0} {$i < $len} {incr i} {
        append line [format "%02x " [lindex $bytes $i]]
        if {[expr {($i+1) % 16}] == 0} { puts $line; set line "" }
    }
    if {$line != ""} { puts $line }

    return $bytes
}

proc read_all_pkts {} {
    set pkt_cnt 0
    while {[expr {[jread 0x00]}] == 0} {
        puts "---- pkt # [incr pkt_cnt] ----"
        read_one_pkt
    }
    if {$pkt_cnt == 0} {
        puts "FIFO empty"
    } else {
        puts "Total: $pkt_cnt packets"
    }
}

puts "[info script] loaded: read_one_pkt / read_all_pkts"
