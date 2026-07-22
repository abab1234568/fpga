#!/bin/bash
#=============================================================================
# run_sim.sh — LCPU Write 仿真编译与运行脚本
# 用法: ./run_sim.sh [clean|run|wave]
#=============================================================================
set -e

SIM_DIR="$(cd "$(dirname "$0")" && pwd)"
RTL_DIR="${SIM_DIR}/../rtl"
TOP_MODULE="tb_lcpu_write"
OUT_DIR="${SIM_DIR}/build"

RTL_FILES=(
    "${RTL_DIR}/FIFO/simple_dual_port_ram.v"
    "${RTL_DIR}/FIFO/single_clock_fifo.v"
    "${RTL_DIR}/FIFO/dual_clock_fifo.v"
    "${RTL_DIR}/FIFO/fix_delay.v"
    "${RTL_DIR}/FIFO/pulse_clock_region_pass.v"
    "${RTL_DIR}/CPU/package_fifo_v2.v"
    "${RTL_DIR}/CPU/ram2pktfifo_int.v"
    "${RTL_DIR}/CPU/pktfifo2ram_int_v2.v"
    "${RTL_DIR}/CPU/cpu_channel.v"
    "${RTL_DIR}/CPU/cpu_channel_reg.v"
    "${RTL_DIR}/MAC/sop_eop_gen.v"
)

TB_FILE="${SIM_DIR}/tb_lcpu_write.v"

cmd="${1:-run}"

case "$cmd" in
    clean)
        echo "=== Cleaning build artifacts ==="
        rm -rf "${OUT_DIR}"
        rm -f "${SIM_DIR}/tb_lcpu_write.vcd"
        echo "Clean done."
        ;;
    run)
        mkdir -p "${OUT_DIR}"
        echo "=== Compiling LCPU Write Simulation ==="
        iverilog -g2012 -Wall \
            -o "${OUT_DIR}/${TOP_MODULE}.vvp" \
            "${RTL_FILES[@]}" \
            "${TB_FILE}"
        echo "=== Running Simulation ==="
        cd "${SIM_DIR}"
        vvp "${OUT_DIR}/${TOP_MODULE}.vvp"
        echo ""
        echo "=== Simulation Complete ==="
        echo "VCD waveform: ${SIM_DIR}/tb_lcpu_write.vcd"
        ;;
    wave)
        if command -v gtkwave &>/dev/null; then
            gtkwave "${SIM_DIR}/tb_lcpu_write.vcd" &
        else
            echo "gtkwave not found. Install gtkwave or open the VCD manually."
        fi
        ;;
    *)
        echo "Usage: $0 {clean|run|wave}"
        exit 1
        ;;
esac
