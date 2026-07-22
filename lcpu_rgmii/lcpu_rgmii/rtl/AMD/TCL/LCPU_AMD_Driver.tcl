proc jread {address args} {
		set len1 [llength $args]
		if {$len1 == 0} {
				rd32 $address
		} elseif {$len1 == 1} {
				set val [lindex $args 0]
				for {set i 0} {$i < $val} {incr i} {
					  after 100
						rd32 [expr $address+$i]
				}
		}
}

# 创建全局事务
#global ::write_txn
#set ::write_txn [create_hw_axi_txn write_txn [get_hw_axis hw_axi_1]  -address 0x00000000 -data 0x00000000 -type write]
#proc jwrite { address data } {
#		set address [format "%08x" $address]
#		set data [format "%08x" $data]
#		run_hw_axi  write_txn
#		#set write_value [lindex [report_hw_axi_txn  write_txn] 1];
#}

proc jwrite { address data } {
		set address [format "%08x" $address]
		set data [format "%08x" $data]
		create_hw_axi_txn write_txn [get_hw_axis hw_axi_1] -address $address -data $data -type write
		run_hw_axi  write_txn
		set write_value [lindex [report_hw_axi_txn  write_txn] 1];
		delete_hw_axi_txn write_txn
}

##---------------------------------------------------------------------------------------------------
proc rd32 { address } {
		set address [format "%08x" $address]
		create_hw_axi_txn read_txn [get_hw_axis hw_axi_1] -address $address -type read
		run_hw_axi  read_txn
		set read_value [lindex [report_hw_axi_txn  read_txn] 1];
		delete_hw_axi_txn read_txn
	
		return 0x$read_value
}

proc kill_r {} {
		delete_hw_axi_txn read_txn
}

proc kill_w {} {
		delete_hw_axi_txn write_txn
}

proc chk {addr value {msg ""}} {
		set r_data [rd $addr]
		if {$r_data != $value} {
				puts "$msg check failed"
				puts "r_data : $r_data; compare_data : $value"
		}
}
