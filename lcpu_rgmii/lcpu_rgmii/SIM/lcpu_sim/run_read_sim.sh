#!/bin/bash
set -e
SIM_DIR="$(cd "$(dirname "$0")" && pwd)"
RTL_DIR="${SIM_DIR}/../rtl"
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
    "${SIM_DIR}/jtagCPU_Amd_Test_Top.v"
    "${SIM_DIR}/lcpu_bfm.v"
    "${SIM_DIR}/tb_lcpu_read.v"
)

cmd="${1:-run}"
case "$cmd" in
    clean) rm -rf "${OUT_DIR}" "${SIM_DIR}/tb_lcpu_read.vcd" ;;
    run)
        mkdir -p "${OUT_DIR}"
        echo "=== Compiling ==="
        iverilog -g2012 -Wall -o "${OUT_DIR}/tb_lcpu_read.vvp" "${RTL_FILES[@]}"
        echo "=== Running ==="
        cd "${SIM_DIR}"; vvp "${OUT_DIR}/tb_lcpu_read.vvp"
        echo ""; echo "=== VCD: ${SIM_DIR}/tb_lcpu_read.vcd ===" ;;
    wave) gtkwave "${SIM_DIR}/tb_lcpu_read.vcd" "${SIM_DIR}/tb_lcpu_read.gtkw" & ;;
    *) echo "Usage: $0 {clean|run|wave}"; exit 1 ;;
esac
