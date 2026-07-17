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
    parameter ADDR_WIDTH = 11,  // 缓冲地址宽度 (2048 字节)
    parameter DATA_WIDTH = 8,   // 数据位宽
    parameter PARA_WIDTH = 3    // 包参数位宽
) (
    input clk,
    input reset_l,
    input cpu_clk,

    // ---- RX: 从 mac_rx 来 (前导码已剥离, DA~FCS) ----
    input                  mac_rx_sop,
    input                  mac_rx_en,
    input [DATA_WIDTH-1:0] mac_rx_data,
    input                  mac_rx_eop,

    // ---- TX: 仅 CPU 注入, 无透传 ----
    output                  mac_tx_sop,
    output                  mac_tx_en,
    output [DATA_WIDTH-1:0] mac_tx_data,
    output                  mac_tx_eop,
    output                  mac_tx_err,

    output reg [7:0] recv_pkt_drop_cnt,

    // ---- CPU 读 FIFO ----
    output   cpu_rd_empty,
    input    cpu_rd_rpkt_pop,
    output [ADDR_WIDTH:0] cpu_rd_rpkt_len,
    output [PARA_WIDTH-1:0] cpu_rd_rpkt_para,
    input    cpu_rd_ren,
    input  [ADDR_WIDTH-1:0] cpu_rd_raddr,
    output [DATA_WIDTH-1:0] cpu_rd_rdata,
    output   cpu_rd_reop_pre,

    // ---- CPU 写 FIFO (CPU 发包到 mac_tx) ----
    output   cpu_wr_full,
    input    cpu_wr_wen,
    input  [ADDR_WIDTH-1:0] cpu_wr_waddr,
    input  [DATA_WIDTH-1:0] cpu_wr_wdata,
    input    cpu_wr_wpkt_push,
    input  [ADDR_WIDTH:0]  cpu_wr_wpkt_len,
    input  [PARA_WIDTH-1:0] cpu_wr_wpkt_para
);

  //============================================================================
  // 1. RX 字节计数器 + 流式单字节过滤器
  //============================================================================
  //============================================================================
  // 1. RX 字节计数器 + 过滤器 + 使能决策
  //    cnt==62: 查 D61==0x77 → frame_hit 锁存
  //    cnt==63: frame_hit==1 → filter_pass=1 (使能延迟线输出)
  //    cnt==64: D0 出延迟线, 经 filter_pass 门控 → ram2pktfifo
  //============================================================================
  localparam FILTER_BYTE = 62;
  localparam FILTER_DATA = 8'h77;
  localparam DELAY = FILTER_BYTE + 2;

  reg [ADDR_WIDTH-1:0] rx_byte_cnt  /* synthesis DONT_TOUCH = 1 */;
  reg                  frame_hit;
  reg                  filter_pass;

  always @(negedge reset_l or posedge clk)
    if (!reset_l) begin
      rx_byte_cnt <= {ADDR_WIDTH{1'b0}};
      frame_hit   <= 1'b1;
      filter_pass <= 1'b0;
    end else if (mac_rx_sop) begin
      rx_byte_cnt <= mac_rx_en ? 1'b1 : {ADDR_WIDTH{1'b0}};
      frame_hit   <= 1'b1;
      filter_pass <= 1'b0;
    end else if (mac_rx_en) begin
      rx_byte_cnt <= rx_byte_cnt + 1;
      if (!mac_rx_eop && rx_byte_cnt == FILTER_BYTE && mac_rx_data != FILTER_DATA)
        frame_hit <= 1'b0;
      if (rx_byte_cnt == FILTER_BYTE + 1)
        filter_pass <= frame_hit;
    end

  //============================================================================
  // 2. 延迟线: 对齐 filter_pass 决策与帧首字节
  //============================================================================
  wire       fifo_en;
  wire [7:0] fifo_data;

  fix_delay #(.delay_cycles(DELAY), .data_width(9)) u_fifo_delay (
      .clk(clk), .reset_l(reset_l), .clk_en(1'b1),
      .data_in ({mac_rx_en, mac_rx_data}),
      .data_out({fifo_en,   fifo_data})
  );

  wire gated_en = fifo_en & filter_pass;

  //============================================================================
  // 3. ram2pktfifo_int: 字节流 → 包 FIFO 写时序
  //============================================================================
  wire                  mac_in_full;
  wire                  mac_in_wen;
  wire [ADDR_WIDTH-1:0] mac_in_waddr;
  wire [DATA_WIDTH-1:0] mac_in_wdata;
  wire                  mac_in_wpkt_push;
  wire [  ADDR_WIDTH:0] mac_in_wpkt_len;
  wire [PARA_WIDTH-1:0] mac_in_wpkt_para;

  ram2pktfifo_int #(
      .addr_width(ADDR_WIDTH),
      .data_width(DATA_WIDTH),
      .para_width(PARA_WIDTH)
  ) u_ram2pktfifo_int (
      .reset_l       (reset_l),
      .clk           (clk),
      .clk_en        (1'b1),
      .ram_wen       (gated_en),
      .ram_wdata     (fifo_data),
      .ram_waddr     (),
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
      .addr_width      (ADDR_WIDTH),
      .block_addr_width(3),
      .data_width      (DATA_WIDTH),
      .para_width      (PARA_WIDTH),
      .para_ram_type   ("registers"),
      .data_ram_type   ("M9K"),
      .max_pkt_length  (1518),
      .block_mode      ("false")
  ) u_package_fifo_cpu_rd (
      .reset_l  (reset_l),
      .wclk     (clk),
      .wclk_en  (1'b1),
      .full     (mac_in_full),
      .wen      (mac_in_wen),
      .waddr    (mac_in_waddr),
      .wdata    (mac_in_wdata),
      .wpkt_push(mac_in_wpkt_push),
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
  wire [  ADDR_WIDTH:0] mac_in_rpkt_len;
  wire [PARA_WIDTH-1:0] mac_in_rpkt_para;
  wire [ADDR_WIDTH-1:0] mac_in_raddr;
  wire [DATA_WIDTH-1:0] mac_in_rdata;

  package_fifo_v2 #(
      .dual_clock      (1),
      .addr_width      (ADDR_WIDTH),
      .block_addr_width(3),
      .data_width      (DATA_WIDTH),
      .para_width      (PARA_WIDTH),
      .para_ram_type   ("registers"),
      .data_ram_type   ("M9K"),
      .max_pkt_length  (1518),
      .block_mode      ("false")
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
      .addr_width(ADDR_WIDTH),
      .data_width(DATA_WIDTH),
      .para_width(PARA_WIDTH),
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
