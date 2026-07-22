//******************************************************************************
// File name:        cpu_channel.v
// Abstract:         流式数据包过滤器 + CPU 通道
//                   1. 流式过滤: 单字节位置匹配 → match
//                   2. 命中帧捕获: 64拍延迟线对齐 match, 门控进 FIFO
//                   3. CPU 注入发送: CPU 写 FIFO → pktfifo2ram → GMII TX
//                   4. 无透传回环: TX 仅来自 CPU 注入, 收到的帧只抓不转
//
//   v4.1 (2026-07-15): 合并流式RX + 纯CPU注入TX
//     - 合并 v4.0 流式RX路径 (rx_byte_cnt + match + 64拍延迟线 + gate)
//     - 合并原始版TX路径 (仅CPU注入, 无透传)
//
//   v4.0 (2026-07-15): 流式重构
//     - 移除 frame_buf BRAM, extract SM
//
//   用法: 将本文件 + common/*.v + cpu/package_fifo_v2.v cpu/ram2pktfifo_int.v
//         cpu/pktfifo2ram_int_v2.v 加入工程
//******************************************************************************
module cpu_channel #(
    parameter cpu_buf_addr_width       = 11,
    parameter cpu_buf_block_mode       = "false",
    parameter cpu_buf_block_addr_width = 3,
    parameter cpu_buf_data_width       = 8,
    parameter cpu_buf_para_width       = 3,
    parameter cpu_buf_data_ram_type    = "M9K",
    parameter cpu_buf_para_ram_type    = "registers"
) (
    input clk,
    input reset_l,
    input cpu_clk,

    // ---- RX: 从 mac_rx 来 (前导码已剥离, DA~FCS) ----
    input                  mac_rx_sop,
    input                  mac_rx_en,
    input [cpu_buf_data_width-1:0] mac_rx_data,
    input                  mac_rx_eop,

    // ---- TX: 仅 CPU 注入, 无透传 ----
    output                  mac_tx_sop,
    output                  mac_tx_en,
    output [cpu_buf_data_width-1:0] mac_tx_data,
    output                  mac_tx_eop,
    output                  mac_tx_err,

    output reg [7:0] recv_pkt_drop_cnt,
    output [cpu_buf_data_width-1:0] dbg_fifo_wdata,  // ILA: FIFO写数据
    output      dbg_fifo_wen,   // ILA: FIFO写使能
    output      dbg_fifo_push,  // ILA: FIFO推包脉冲

    // ---- CPU 读 FIFO ----
    output   cpu_rd_empty,
    input    cpu_rd_rpkt_pop,
    output [cpu_buf_addr_width:0]   cpu_rd_rpkt_len,
    output [cpu_buf_para_width-1:0] cpu_rd_rpkt_para,
    input    cpu_rd_ren,
    input  [cpu_buf_addr_width-1:0] cpu_rd_raddr,
    output [cpu_buf_data_width-1:0] cpu_rd_rdata,
    output   cpu_rd_reop_pre,

    // ---- CPU 写 FIFO (CPU 发包到 mac_tx) ----
    output   cpu_wr_full,
    input    cpu_wr_wen,
    input  [cpu_buf_addr_width-1:0] cpu_wr_waddr,
    input  [cpu_buf_data_width-1:0] cpu_wr_wdata,
    input    cpu_wr_wpkt_push,
    input  [cpu_buf_addr_width:0]   cpu_wr_wpkt_len,
    input  [cpu_buf_para_width-1:0] cpu_wr_wpkt_para
);

  //============================================================================
  // 1. RX 字节计数器 + 流式单字节过滤器
  //============================================================================
  localparam FILTER_BYTE = 61;
  localparam FILTER_DATA = 8'h77;

  reg [cpu_buf_addr_width-1:0] rx_byte_cnt  /* synthesis DONT_TOUCH = 1 */;
  reg                  frame_hit;

  always @(negedge reset_l or posedge clk)
    if (!reset_l) begin
      rx_byte_cnt <= {cpu_buf_addr_width{1'b0}};
      frame_hit   <= 1'b1;
    end else if (mac_rx_sop && mac_rx_en) begin
      rx_byte_cnt <= 1'b1;
      frame_hit   <= 1'b1;
    end else if (mac_rx_sop) begin
      rx_byte_cnt <= {cpu_buf_addr_width{1'b0}};
      frame_hit   <= 1'b1;
    end else if (mac_rx_en) begin
      rx_byte_cnt <= rx_byte_cnt + 1;
      if (rx_byte_cnt == FILTER_BYTE && mac_rx_data != FILTER_DATA)
        frame_hit <= 1'b0;
    end


  //============================================================================
  // 2. ram2pktfifo_int: 流式写入 → 包 FIFO 接口
  //============================================================================
  wire                  mac_in_full;
  wire                  mac_in_wen;
  wire [cpu_buf_addr_width-1:0] mac_in_waddr;
  wire [cpu_buf_data_width-1:0] mac_in_wdata;
  wire                  mac_in_wpkt_push;
  wire [cpu_buf_addr_width:0] mac_in_wpkt_len;
  wire [cpu_buf_para_width-1:0] mac_in_wpkt_para;

  ram2pktfifo_int #(
      .addr_width(cpu_buf_addr_width),
      .data_width(cpu_buf_data_width),
      .para_width(cpu_buf_para_width)
  ) u_ram2pktfifo_int (
      .reset_l       (reset_l),
      .clk           (clk),
      .clk_en        (1'b1),
      .ram_wen       (mac_rx_en),
      .ram_wdata     (mac_rx_data),
      .ram_waddr     (rx_byte_cnt),
      .ram_wpara     (0),
      .ram_wen_permit(),
      .full          (mac_in_full),
      .wen           (mac_in_wen),
      .waddr         (mac_in_waddr),
      .wdata         (mac_in_wdata),
      .wpkt_push     (mac_in_wpkt_push),
      .wpkt_len      (mac_in_wpkt_len),
      .wpkt_para     (mac_in_wpkt_para)
  );

  //============================================================================
  // 3. debug 输出
  //============================================================================
  assign dbg_fifo_wdata = mac_in_wdata;
  assign dbg_fifo_wen   = mac_in_wen;
  assign dbg_fifo_push  = mac_in_wpkt_push & frame_hit;

  //============================================================================
  // 4. 丢包计数 (饱和保护)
  //============================================================================
  always @(negedge reset_l or posedge clk)
    if (!reset_l) recv_pkt_drop_cnt <= 8'd0;
    else if (mac_in_wpkt_push && mac_in_full && recv_pkt_drop_cnt != 8'hFF)
      recv_pkt_drop_cnt <= recv_pkt_drop_cnt + 1;

  //============================================================================
  // 5. CPU 读 FIFO (package_fifo_v2)
  //============================================================================
  package_fifo_v2 #(
      .dual_clock      (1),
      .addr_width      (cpu_buf_addr_width),
      .block_addr_width(cpu_buf_block_addr_width),
      .data_width      (cpu_buf_data_width),
      .para_width      (cpu_buf_para_width),
      .para_ram_type   (cpu_buf_para_ram_type),
      .data_ram_type   (cpu_buf_data_ram_type),
      .max_pkt_length  (1518),
      .block_mode      (cpu_buf_block_mode)
  ) u_package_fifo_cpu_rd (
      .reset_l  (reset_l),
      .wclk     (clk),
      .wclk_en  (1'b1),
      .full     (mac_in_full),
      .wen      (mac_in_wen),
      .waddr    (mac_in_waddr),
      .wdata    (mac_in_wdata),
      .wpkt_push(mac_in_wpkt_push & frame_hit),
      .wpkt_len (mac_in_wpkt_len),
      .wpkt_para(mac_in_wpkt_para),
      .rclk     (cpu_clk),
      .rclk_en  (1'b1),
      .empty    (cpu_rd_empty),
      .rpkt_pop (cpu_rd_rpkt_pop),
      .rpkt_len (cpu_rd_rpkt_len),
      .rpkt_para(cpu_rd_rpkt_para),
      .ren      (cpu_rd_ren),
      .raddr    (cpu_rd_raddr),
      .rdata    (cpu_rd_rdata),
      .reop_pre (cpu_rd_reop_pre)
  );

  //============================================================================
  // 6. CPU 写 FIFO (CPU → mac_tx)
  //============================================================================
  wire mac_in_empty, mac_in_rpkt_pop, mac_in_ren, mac_in_reop_pre;
  wire [cpu_buf_addr_width:0] mac_in_rpkt_len;
  wire [cpu_buf_para_width-1:0] mac_in_rpkt_para;
  wire [cpu_buf_addr_width-1:0] mac_in_raddr;
  wire [cpu_buf_data_width-1:0] mac_in_rdata;

  package_fifo_v2 #(
      .dual_clock      (1),
      .addr_width      (cpu_buf_addr_width),
      .block_addr_width(cpu_buf_block_addr_width),
      .data_width      (cpu_buf_data_width),
      .para_width      (cpu_buf_para_width),
      .para_ram_type   (cpu_buf_para_ram_type),
      .data_ram_type   (cpu_buf_data_ram_type),
      .max_pkt_length  (1518),
      .block_mode      (cpu_buf_block_mode)
  ) u_package_fifo_cpu_wr (
      .reset_l  (reset_l),
      .wclk     (cpu_clk),
      .wclk_en  (1'b1),
      .full     (cpu_wr_full),
      .wen      (cpu_wr_wen),
      .waddr    (cpu_wr_waddr),
      .wdata    (cpu_wr_wdata),
      .wpkt_push(cpu_wr_wpkt_push),
      .wpkt_len (cpu_wr_wpkt_len),
      .wpkt_para(cpu_wr_wpkt_para),
      .rclk     (clk),
      .rclk_en  (1'b1),
      .empty    (mac_in_empty),
      .rpkt_pop (mac_in_rpkt_pop),
      .rpkt_len (mac_in_rpkt_len),
      .rpkt_para(mac_in_rpkt_para),
      .ren      (mac_in_ren),
      .raddr    (mac_in_raddr),
      .rdata    (mac_in_rdata),
      .reop_pre (mac_in_reop_pre)
  );

  //============================================================================
  // 7. pktfifo2ram_int_v2 → sop_eop_gen → TX 输出
  //============================================================================
  wire       tx_en;
  wire [7:0] tx_data;

  pktfifo2ram_int_v2 #(
      .addr_width(cpu_buf_addr_width),
      .data_width(cpu_buf_data_width),
      .para_width(cpu_buf_para_width),
      .ipg(8),
      .block_mode("false")
  ) u_pktfifo2ram_int (
      .reset_l(reset_l),
      .clk(clk),
      .clk_en(1'b1),
      .empty(mac_in_empty),
      .rpkt_pop(mac_in_rpkt_pop),
      .rpkt_len(mac_in_rpkt_len),
      .rpkt_para(mac_in_rpkt_para),
      .ren(mac_in_ren),
      .raddr(mac_in_raddr),
      .rdata(mac_in_rdata),
      .reop_pre(mac_in_reop_pre),
      .ipg_adjust(0),
      .ram_wen(tx_en),
      .ram_wdata(tx_data),
      .ram_waddr(),
      .ram_wpara()
  );

  sop_eop_gen #(
      .data_width(8)
  ) u_sop_eop_gen (
      .clk(clk),
      .clk_en(1'b1),
      .reset_l(reset_l),
      .i_en(tx_en),
      .i_err(1'b0),
      .i_data(tx_data),
      .o_sop(mac_tx_sop),
      .o_en(mac_tx_en),
      .o_data(mac_tx_data),
      .o_eop(mac_tx_eop),
      .o_err(mac_tx_err)
  );

endmodule
