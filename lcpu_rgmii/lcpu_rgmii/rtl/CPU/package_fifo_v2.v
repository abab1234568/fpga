//****************************************Copyright 2013[c]************************//
// ************************Declaration***************************************//
// File name:        package_fifo					                                       //
// Author:           huaming.huang@link-real.com.cn                                    //
// Date:             2014-12-01 00:00 	                                     //
// Version Number:   1.0                                                     //
// Abstract:    support single clock and dual clock operation
//                                                                            //
// Modification history:[including time, version, author and abstract]        //
// 2014-12-01 00:00        version 1.0     xxx                                //
// Abstract: Initial                                                          //
// 2015-08-27 00:00        version 2.0     add support none block mode        //
//                         2015-10-20 found in none block mode, data in fifo must be continuely
//                                    or else, have error!!!!!!!
// 2016-06-30 00:00        version 3.0     redesign none block mode        //
//                         this mode don't support dual clock, packet must input continuelly
// 2016-11-28 00:00        version 5.0     upgrade none block mode        //
//                         support dual clock, support open address read/write
//                         the shortest packet length is 64bytes.
//                         shorter than 64 bytes packet could cause error not predict.
// 2016-11-30 00:00        version 5.1     upgrade none block mode further  //
//                         support dual clock for none block mode,support open address read/write
//                         the shortest packet length is 16words.
//                         shorter than 16words packet could cause error not predict.
// *********************************end************************************** //

module package_fifo_v2 (
    reset_l,

    wclk,
    wclk_en,
    full,
    wen,
    waddr,
    wdata,
    wpkt_push,
    wpkt_len,
    wpkt_para,

    rclk,
    rclk_en,
    empty,
    rpkt_pop,
    rpkt_len,
    rpkt_para,
    ren,
    raddr,
    rdata,
    reop_pre
);
  parameter	 dual_clock = 1, //1: support dual clock operation.  0: just support same clock for package read & write
  addr_width = 8,  //indicate each data block have 256 data
  block_addr_width = 4,  //indicate there have 16 data block
  data_width = 32,  //each data bits
  para_width = 16,
					 para_ram_type = "registers",
					 data_ram_type = "M9K", // Cyclone IV device : "M9K","registers"
  max_pkt_length = 1518, block_mode = "true";  //"true","false"

  input reset_l;
  input wclk;
  input wclk_en;
  output full;
  input wen;
  input [addr_width-1:0] waddr;
  input [data_width-1:0] wdata;
  input wpkt_push;
  input [addr_width:0] wpkt_len;
  input [para_width-1:0] wpkt_para;

  input rclk;
  input rclk_en;
  output empty;
  input rpkt_pop;
  output [addr_width:0] rpkt_len;
  output [para_width-1:0] rpkt_para;
  input ren;
  input [addr_width-1:0] raddr;
  output [data_width-1:0] rdata;
  output reop_pre;

  generate
    if (block_mode == "false") begin : none_block_mode_generation
      wire [addr_width+para_width+addr_width:0] wpkt_para_data;
      wire [addr_width+para_width+addr_width:0] rpkt_para_data;
      wire [addr_width+para_width+addr_width:0] rpkt_para_data_wclk;
      wire [                    addr_width-1:0] wpkt_data_addr;
      reg  [                      addr_width:0] rpkt_len_i;
      reg  [                    para_width-1:0] rpkt_para_b;
      wire [                    addr_width-1:0] rpkt_data_addr;
      reg                                       rpkt_pop_d0;
      reg  [                    addr_width-1:0] none_block_waddr_pt;
      reg  [                    addr_width-1:0] none_block_raddr_pt;
      reg  [                    addr_width-1:0] none_block_raddr_pt_wclk;
      reg                                       rpkt_pop_wclk_d0;
      wire                                      rpkt_pop_wclk;
      reg                                       full_i;
      assign full = full_i;
      assign rpkt_len = rpkt_len_i;
      always @(negedge reset_l or posedge wclk)
        if (reset_l == 1'b0) begin
          full_i <= 1'b0;
        end else begin
          full_i <= 1'b0;
          if (none_block_waddr_pt >= none_block_raddr_pt_wclk) begin
            if (none_block_waddr_pt - none_block_raddr_pt_wclk > 2 ** addr_width - max_pkt_length)
              full_i <= 1'b1;
          end else begin
            if (none_block_raddr_pt_wclk - none_block_waddr_pt <= max_pkt_length) full_i <= 1'b1;
          end
        end
      always @(negedge reset_l or posedge wclk)
        if (reset_l == 1'b0) begin
          none_block_waddr_pt <= {addr_width{1'b0}};
        end else begin
          if (wclk_en == 1'b1) begin
            if ((wpkt_push == 1'b1) && (full_i == 1'b0)) begin
              none_block_waddr_pt <= none_block_waddr_pt + wpkt_len;
            end
          end
        end
      assign wpkt_para_data[addr_width:0] = wpkt_len;
      assign wpkt_para_data[para_width+addr_width:addr_width+1] = wpkt_para;
      assign wpkt_para_data[addr_width+para_width+addr_width:para_width+addr_width+1] = none_block_waddr_pt;

      if (dual_clock == 0) begin : single_clk_pkt_fifo_generation
        single_clock_fifo #(
            .addr_width(addr_width - 4),
            .data_width(addr_width + para_width + addr_width + 1),
            .ram_type  (para_ram_type)
        ) u_pkt_para_buf (
            .clk       (wclk),
            .reset_l   (reset_l),
            .write_en  (wpkt_push & wclk_en & !full_i),
            .write_data(wpkt_para_data),
            .full      (),
            .read_en   (rpkt_pop & rclk_en),
            .read_data (rpkt_para_data),
            .empty     (empty)
        );
        always @(negedge reset_l or posedge rclk)
          if (reset_l == 1'b0) begin
            rpkt_pop_d0 <= 1'b0;
            rpkt_len_i <= 0;
            rpkt_para_b <= 0;
            none_block_raddr_pt <= 0;
            none_block_raddr_pt_wclk <= 0;
          end else begin
            if (rclk_en == 1'b1) begin
              rpkt_pop_d0 <= rpkt_pop;
              if (rpkt_pop_d0 == 1'b1) begin
                rpkt_len_i <= rpkt_para_data[addr_width:0];
                rpkt_para_b <= rpkt_para_data[para_width+addr_width:addr_width+1];
                none_block_raddr_pt  <= rpkt_para_data[addr_width+para_width+addr_width:para_width+addr_width+1];
                none_block_raddr_pt_wclk  <= rpkt_para_data[addr_width+para_width+addr_width:para_width+addr_width+1];
              end
            end
          end
      end else begin : dual_clk_pkt_fifo_generation
        pulse_clock_region_pass u_pop_pass_clk (
            .reset_l(reset_l),
            .clk_a  (rclk),
            .pulse_a(rpkt_pop),
            .clk_b  (wclk),
            .pulse_b(rpkt_pop_wclk)
        );
        single_clock_fifo #(
            .addr_width(addr_width - 4),
            .data_width(addr_width + para_width + addr_width + 1),
            .ram_type  (para_ram_type)
        ) u_pkt_para_buf_wclk (
            .clk       (wclk),
            .reset_l   (reset_l),
            .write_en  (wpkt_push & wclk_en & !full_i),
            .write_data(wpkt_para_data),
            .full      (),
            .read_en   (rpkt_pop_wclk & rclk_en),
            .read_data (rpkt_para_data_wclk),
            .empty     ()
        );

        dual_clock_fifo #(
            .addr_width(addr_width - 4),
            .data_width(addr_width + para_width + addr_width + 1),
            .ram_type  (para_ram_type)
        ) u_pkt_para_buf (
            .wclk      (wclk),
            .reset_l   (reset_l),
            .write_en  (wpkt_push & !full_i),
            .write_data(wpkt_para_data),
            .full      (),
            .rclk      (rclk),
            .read_en   (rpkt_pop),
            .read_data (rpkt_para_data),
            .empty     (empty)
        );
        always @(negedge reset_l or posedge rclk)
          if (reset_l == 1'b0) begin
            rpkt_pop_d0 <= 1'b0;
            rpkt_len_i <= 0;
            rpkt_para_b <= 0;
            none_block_raddr_pt <= 0;
          end else begin
            if (rclk_en == 1'b1) begin
              rpkt_pop_d0 <= rpkt_pop;
              if (rpkt_pop_d0 == 1'b1) begin
                rpkt_len_i <= rpkt_para_data[addr_width:0];
                rpkt_para_b <= rpkt_para_data[para_width+addr_width:addr_width+1];
                none_block_raddr_pt  <= rpkt_para_data[addr_width+para_width+addr_width:para_width+addr_width+1];
              end
            end
          end
        always @(negedge reset_l or posedge wclk)
          if (reset_l == 1'b0) begin
            rpkt_pop_wclk_d0 <= 1'b0;
            none_block_raddr_pt_wclk <= 0;
          end else begin
            if (rclk_en == 1'b1) begin
              rpkt_pop_wclk_d0 <= rpkt_pop_wclk;
              if (rpkt_pop_wclk_d0 == 1'b1) begin
                none_block_raddr_pt_wclk  <= rpkt_para_data_wclk[addr_width+para_width+addr_width:para_width+addr_width+1];
              end
            end
          end
      end

      simple_dual_port_ram #(
          .addr_width(addr_width),
          .data_width(data_width),
          .ram_type  (data_ram_type)
      ) u_pkt_data_buf (
          .aclk    (wclk),
          .aclk_en (wclk_en),
          .awr_en  (wen & (!full_i)),
          .awr_addr(wpkt_data_addr),
          .awr_data(wdata),
          .bclk    (rclk),
          .bclk_en (rclk_en),
          .brd_addr(rpkt_data_addr),
          .brd_data(rdata)
      );


      assign wpkt_data_addr = none_block_waddr_pt + waddr;
      assign rpkt_data_addr = none_block_raddr_pt + raddr;
      assign rpkt_para = rpkt_para_b;
      assign reop_pre = ren && (raddr == rpkt_len_i - 1);
    end
  endgenerate


  generate
    if (block_mode == "true") begin : block_mode_generation
      reg  [                    block_addr_width-1:0] block_waddr_pt;
      wire [block_addr_width+para_width+addr_width:0] wpkt_para_data;
      wire [block_addr_width+para_width+addr_width:0] rpkt_para_data;
      reg  [                    block_addr_width-1:0] block_raddr_pt;
      wire [         block_addr_width+addr_width-1:0] wpkt_data_addr;
      reg  [                            addr_width:0] rpkt_len_i;
      reg  [                          para_width-1:0] rpkt_para_b;
      wire [         block_addr_width+addr_width-1:0] rpkt_data_addr;
      reg                                             rpkt_pop_d0;
      assign rpkt_len = rpkt_len_i;

      always @(negedge reset_l or posedge wclk)
        if (reset_l == 1'b0) begin
          block_waddr_pt <= 0;
        end else begin
          if (wclk_en == 1'b1) begin
            if (wpkt_push == 1'b1) begin
              block_waddr_pt <= block_waddr_pt + 1;
            end
          end
        end
      assign wpkt_para_data[addr_width:0] = wpkt_len;
      assign wpkt_para_data[para_width+addr_width:addr_width+1] = wpkt_para;
      assign wpkt_para_data[block_addr_width+para_width+addr_width:para_width+addr_width+1] = block_waddr_pt;

      always @(negedge reset_l or posedge rclk)
        if (reset_l == 1'b0) begin
          rpkt_pop_d0 <= 1'b0;
          rpkt_len_i <= 0;
          rpkt_para_b <= 0;
          block_raddr_pt <= 0;
        end else begin
          if (rclk_en == 1'b1) begin
            rpkt_pop_d0 <= rpkt_pop;
            if (rpkt_pop_d0 == 1'b1) begin
              rpkt_len_i <= rpkt_para_data[addr_width:0];
              rpkt_para_b <= rpkt_para_data[para_width+addr_width:addr_width+1];
              block_raddr_pt  <= rpkt_para_data[block_addr_width+para_width+addr_width:para_width+addr_width+1];
            end
          end
        end

      if (dual_clock == 0) begin : single_clk_pkt_fifo_generation
        single_clock_fifo #(
            .addr_width(block_addr_width),
            .data_width(block_addr_width + para_width + addr_width + 1),
            .ram_type  (para_ram_type)
        ) u_pkt_para_buf (
            .clk       (wclk),
            .reset_l   (reset_l),
            .write_en  (wpkt_push & wclk_en),
            .write_data(wpkt_para_data),
            .full      (full),
            .read_en   (rpkt_pop & rclk_en),
            .read_data (rpkt_para_data),
            .empty     (empty)
        );
      end else begin : dual_clk_pkt_fifo_generation
        dual_clock_fifo #(
            .addr_width(block_addr_width),
            .data_width(block_addr_width + para_width + addr_width + 1),
            .ram_type  (para_ram_type)
        ) u_pkt_para_buf (
            .wclk      (wclk),
            .reset_l   (reset_l),
            .write_en  (wpkt_push),
            .write_data(wpkt_para_data),
            .full      (full),
            .rclk      (rclk),
            .read_en   (rpkt_pop),
            .read_data (rpkt_para_data),
            .empty     (empty)
        );
      end

      simple_dual_port_ram #(
          .addr_width(block_addr_width + addr_width),
          .data_width(data_width),
          .ram_type  (data_ram_type)
      ) u_pkt_data_buf (
          .aclk    (wclk),
          .aclk_en (wclk_en),
          .awr_en  (wen & (!full)),
          .awr_addr(wpkt_data_addr),
          .awr_data(wdata),
          .bclk    (rclk),
          .bclk_en (rclk_en),
          .brd_addr(rpkt_data_addr),
          .brd_data(rdata)
      );
      assign wpkt_data_addr = {block_waddr_pt, waddr};
      assign rpkt_data_addr = {block_raddr_pt, raddr};
      assign rpkt_para = rpkt_para_b;
      assign reop_pre = ren && (raddr == rpkt_len_i - 1);
    end
  endgenerate

endmodule
