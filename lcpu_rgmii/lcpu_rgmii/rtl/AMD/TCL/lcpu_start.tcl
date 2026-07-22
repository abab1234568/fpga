#==============================================================================
# lcpu_start.tcl — LCPU 一键启动脚本
#
# 用法 (终端):
#   vivado -mode tcl -source /home/huamingh/FPGA_prj/riscvwebserver/sgmii_sgmii/tcl/lcpu_start.tcl
#
# 或者已在 Vivado TCL Console 中:
#   source /home/huamingh/FPGA_prj/riscvwebserver/sgmii_sgmii/tcl/lcpu_start.tcl
#==============================================================================

set AMD_TCL_DIR /home/huamingh/FPGA_prj/riscvwebserver/sgmii_sgmii/rtl/AMD/TCL
set CAPTURE_TCL  /home/huamingh/FPGA_prj/riscvwebserver/sgmii_sgmii/tcl/lcpu_capture.tcl

#==============================================================================
# Step 1: 连接硬件
#==============================================================================
puts "--- Step 1: 连接硬件 ---"
if {[catch {
    open_hw_manager
    connect_hw_server
    open_hw_target [lindex [get_hw_targets] 0]
    refresh_hw_device
} err]} {
    puts "  连接失败: $err"
    puts "  若已手动连接, 可忽略此错误继续"
}

#==============================================================================
# Step 2: 加载 LCPU 底层驱动 (rd32 / jwrite)
#==============================================================================
puts "--- Step 2: 加载驱动 ---"
if {[catch {source $AMD_TCL_DIR/LCPU_AMD_Driver.tcl} err]} {
    puts "  加载驱动失败: $err"
    puts "  请确认路径: $AMD_TCL_DIR/LCPU_AMD_Driver.tcl"
    return
}
puts "  驱动已加载: rd32 / jwrite / jread"

#==============================================================================
# Step 3: 加载抓包功能
#==============================================================================
puts "--- Step 3: 加载抓包脚本 ---"
if {[catch {source $CAPTURE_TCL} err]} {
    puts "  加载抓包脚本失败: $err"
    return
}

#==============================================================================
# 启动
#==============================================================================
puts ""
puts "=========================================="
puts "  LCPU 抓包环境就绪"
puts "=========================================="
puts "  快速验证: lcpu_quick_test"
puts "  查看状态: lcpu_status"
puts "  单次抓包: lcpu_capture_once"
puts "  持续监控: lcpu_monitor"
puts "  帮助:     lcpu_help"
puts "=========================================="
