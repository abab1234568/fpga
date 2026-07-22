# full_test.tcl — End-to-end test: flush, write, loopback, read, verify
# Usage: source full_test.tcl

# Load read/write procs
source /home/huamingh/FPGA_prj/lcpu_rgmii/tcl/read_cpu_pkt.tcl
source /home/huamingh/FPGA_prj/lcpu_rgmii/tcl/write_cpu_pkt.tcl

# Test packet (68 bytes)
set PKT {
    0x9c 0x2d 0xcd 0xac 0x8f 0xa4 0x9c 0x69 0xd3 0x7d 0x47 0x4c 0x08 0x00
    0x45 0x00 0x00 0x32 0x21 0xb3 0x00 0x00 0x40 0x11 0x02 0xb8 0xa9 0xfe
    0xfc 0xf8 0xa9 0xfe 0x05 0x5b 0x05 0x21 0x27 0x15 0x00 0x1e 0x20 0x9a
    0x30 0x30 0x30 0x30 0x30 0x30 0x30 0x30 0x30 0x30 0x30 0x30 0x30 0x30
    0x30 0x30 0x30 0x30 0x30 0x77 0x7a 0x68 0xa4 0x5e 0xe0 0xbb
}

proc full_loopback_test {{pkt $PKT}} {
    catch {delete_hw_axi_txn read_txn}
    catch {delete_hw_axi_txn write_txn}

    # Step 1: Flush RX FIFO
    puts "=== Step 1: Flush RX FIFO ==="
    set cnt 0
    while {[expr {[jread 0x00]}] == 0} {
        jwrite 0x01 1; after 100; jwrite 0x01 0
        incr cnt
    }
    puts "  Flushed $cnt old packets"

    # Step 2: Check TX FIFO
    puts "=== Step 2: Check TX FIFO ==="
    if {[expr {[jread 0x10]}] == 1} {
        puts "  TX FIFO full, abort"
        return 0
    }
    puts "  TX FIFO ready"

    # Step 3: Write packet to TX
    puts "=== Step 3: Write to TX ==="
    write_one_pkt $PKT

    # Step 4: Wait for loopback
    puts "=== Step 4: Wait loopback ==="
    for {set waited 0} {$waited < 10000} {incr waited 200} {
        if {[expr {[jread 0x00]}] == 0} break
        after 200
    }

    # Step 5: Read and verify
    puts "=== Step 5: Read and Verify ==="
    write_and_verify $PKT 0
}

full_loopback_test
