//****************************************Copyright 2026[c]************************//
// File name:        dual_clock_fifo.v
// Author:           huaming.huang@link-real.com.cn
// Date:             2026-06-11
// Version Number:   1.0
// Abstract:         异步双时钟 FIFO — 跨时钟域总线隔离
//                   格雷码指针 + 双寄存器同步器，安全 CDC。
//                   接口符合 LRIP dual_clock_fifo 标准。
//
//  接口:
//   reset_l    — 异步复位 (低有效，内部同步到各时钟域)
//   wclk       — 写时钟
//   write_en   — 写使能
//   write_data — 写数据
//   full       — FIFO 满标志
//   rclk       — 读时钟
//   read_en    — 读使能
//   read_data  — 读数据
//   empty      — FIFO 空标志
//
//  参数:
//   addr_width — 地址位宽 (深度 = 2^addr_width)，默认 4
//   data_width — 数据位宽，默认 8
//   ram_type   — "registers"=分布式RAM, "M9K"=Block RAM, 默认 "registers"
//
// Modification history:
//   2026-06-11, v1.0, huaming.huang, 初始版本
//
// *********************************end************************************** //

module dual_clock_fifo #(
    parameter addr_width = 4,
    parameter data_width = 8,
    parameter ram_type   = "registers"
) (
    // 全局复位 (异步，低有效)
    input wire reset_l,

    // 写口
    input  wire                  wclk,
    input  wire                  write_en,
    input  wire [data_width-1:0] write_data,
    output wire                  full,

    // 读口
    input  wire                  rclk,
    input  wire                  read_en,
    output wire [data_width-1:0] read_data,
    output wire                  empty
);

  //========================================================================
  // 内部常量
  //========================================================================
  localparam DEPTH = 1 << addr_width;

  //========================================================================
  // 复位同步 — 将全局 reset_l 同步到各自时钟域
  //========================================================================
  // 写域复位同步器 (2-FF)
  (* ASYNC_REG = "TRUE" *) reg rst_s1_w, rst_s2_w;
  always @(posedge wclk or negedge reset_l) begin
    if (!reset_l) begin
      rst_s1_w <= 1'b0;
      rst_s2_w <= 1'b0;
    end else begin
      rst_s1_w <= 1'b1;
      rst_s2_w <= rst_s1_w;
    end
  end
  wire wclk_rst_n;
  assign wclk_rst_n = rst_s2_w;

  // 读域复位同步器 (2-FF)
  (* ASYNC_REG = "TRUE" *) reg rst_s1_r, rst_s2_r;
  always @(posedge rclk or negedge reset_l) begin
    if (!reset_l) begin
      rst_s1_r <= 1'b0;
      rst_s2_r <= 1'b0;
    end else begin
      rst_s1_r <= 1'b1;
      rst_s2_r <= rst_s1_r;
    end
  end
  wire rclk_rst_n;
  assign rclk_rst_n = rst_s2_r;

  //========================================================================
  // 双端口 RAM
  //========================================================================
  (* ram_style = "distributed" *)reg  [data_width-1:0] mem                                          [0:DEPTH-1];

  //========================================================================
  // 写域: 写指针 + 格雷码
  //========================================================================
  reg  [  addr_width:0] wr_ptr_bin;  // 二进制写指针 (多 1bit)
  reg  [  addr_width:0] wr_ptr_gray;  // 格雷码写指针

  // 同步到写域的读指针
  (* ASYNC_REG = "TRUE" *)reg  [  addr_width:0] rd_ptr_gray_s1_w;
  (* ASYNC_REG = "TRUE" *)reg  [  addr_width:0] rd_ptr_gray_s2_w;
  wire [  addr_width:0] rd_ptr_gray_synced;
  assign rd_ptr_gray_synced = rd_ptr_gray_s2_w;

  // 写操作 + 指针更新
  always @(posedge wclk or negedge wclk_rst_n) begin
    if (!wclk_rst_n) begin
      wr_ptr_bin  <= {(addr_width + 1) {1'b0}};
      wr_ptr_gray <= {(addr_width + 1) {1'b0}};
    end else begin
      if (write_en && !full) begin
        mem[wr_ptr_bin[addr_width-1:0]] <= write_data;
        wr_ptr_bin <= wr_ptr_bin + 1'b1;
        wr_ptr_gray <= (wr_ptr_bin + 1'b1) ^ ((wr_ptr_bin + 1'b1) >> 1);
      end
    end
  end

  // CDCs: 读指针(格雷码) → 写域
  always @(posedge wclk) begin
    rd_ptr_gray_s1_w <= rd_ptr_gray;
    rd_ptr_gray_s2_w <= rd_ptr_gray_s1_w;
  end

  // 写域满判断
  assign full = (wr_ptr_gray[addr_width]   != rd_ptr_gray_synced[addr_width])   &&
	              (wr_ptr_gray[addr_width-1] != rd_ptr_gray_synced[addr_width-1]) &&
	              (wr_ptr_gray[addr_width-2:0] == rd_ptr_gray_synced[addr_width-2:0]);

  //========================================================================
  // 读域: 读指针 + 格雷码
  //========================================================================
  reg  [  addr_width:0] rd_ptr_bin;  // 二进制读指针
  reg  [  addr_width:0] rd_ptr_gray;  // 格雷码读指针
  reg  [data_width-1:0] read_data_r;  // 读数据寄存器

  // 同步到读域的写指针
  (* ASYNC_REG = "TRUE" *)reg  [  addr_width:0] wr_ptr_gray_s1_r;
  (* ASYNC_REG = "TRUE" *)reg  [  addr_width:0] wr_ptr_gray_s2_r;
  wire [  addr_width:0] wr_ptr_gray_synced;
  assign wr_ptr_gray_synced = wr_ptr_gray_s2_r;

  // 读操作 + 指针更新
  always @(posedge rclk or negedge rclk_rst_n) begin
    if (!rclk_rst_n) begin
      rd_ptr_bin  <= {(addr_width + 1) {1'b0}};
      rd_ptr_gray <= {(addr_width + 1) {1'b0}};
      read_data_r <= {data_width{1'b0}};
    end else begin
      if (read_en && !empty) begin
        read_data_r <= mem[rd_ptr_bin[addr_width-1:0]];
        rd_ptr_bin  <= rd_ptr_bin + 1'b1;
        rd_ptr_gray <= (rd_ptr_bin + 1'b1) ^ ((rd_ptr_bin + 1'b1) >> 1);
      end
    end
  end

  assign read_data = read_data_r;

  // CDCs: 写指针(格雷码) → 读域
  always @(posedge rclk) begin
    wr_ptr_gray_s1_r <= wr_ptr_gray;
    wr_ptr_gray_s2_r <= wr_ptr_gray_s1_r;
  end

  // 读域空判断
  assign empty = (rd_ptr_gray == wr_ptr_gray_synced);

endmodule
