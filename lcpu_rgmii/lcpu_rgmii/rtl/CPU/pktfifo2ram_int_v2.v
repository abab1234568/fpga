 //****************************************Copyright 2016[c]************************//
// ************************Declaration***************************************//
// File name:        pktfifo2ram_int_v2	                                       //
// Author:           huaming.huang@link-real.com.cn                                    //
// Date:             2016-09-03 16:05:04 	                                     //
// Version Number:   1.0                                                     //
// Abstract:    auto package fifo read and outputting as ram writing timing with clock enable
//                                                                            //
// Modification history:[including time, version, author and abstract]        //
// 2016-09-03 16:05:05        version 1.0     xxx                                //
// Abstract: Initial                                                          //
//        2016-09-03 : based on pktfifo2ram_int, modify clock_enable function
// *********************************end************************************** //

module pktfifo2ram_int_v2 (
    reset_l,
    clk,
    clk_en,

    empty,
    rpkt_pop,
    rpkt_len,
    rpkt_para,
    ren,
    raddr,
    rdata,
    reop_pre,

    ipg_adjust,

    ram_wen,
    ram_wdata,
    ram_waddr,
    ram_wpara
);

  parameter	 addr_width = 8,
					 data_width = 8,
					 para_width = 2,
					 ipg = 12,
					 block_mode = "true"; //"true","false"

  input reset_l;
  input clk;
  input clk_en;

  input [31:0] ipg_adjust;

  output ram_wen;
  output [data_width-1:0] ram_wdata;
  output [addr_width-1:0] ram_waddr;
  output [para_width-1:0] ram_wpara;

  input empty;
  output rpkt_pop;
  input [addr_width:0] rpkt_len;
  input [para_width-1:0] rpkt_para;
  output ren;
  output [addr_width-1:0] raddr;
  input [data_width-1:0] rdata;
  input reop_pre;

  reg ram_wen;
  reg [addr_width-1:0] ram_waddr;
  wire [data_width-1:0] ram_wdata;
  reg op_doing;
  reg rpkt_pop;  //read parameter enable   (included   parameter and  data  length)
  reg [1:0] rpkt_pop_dly;
  reg [addr_width:0] data_len;
  reg ren;
  reg [addr_width-1:0] raddr;
  reg [31:0] ipg_cnt;
  reg ren_s;

  /* timing
                ____
rpkt_pop,______|    |___________________________________________________________
wpkt_len, xxxxxxxxxx|xxxxx|  6  |  6  |  6  |  6  |  6  |  6  |  6  |  6  |  6  | 
wpkt_para	xxxxxxxxxx|xxxxx|     |     |     |     |     |     |     |     |     |
                                 ___________________________________	 
ren,      ______________________|                                   |___________
raddr,     xxxxxxxxxxxxxxxxxxxxx|  A1 |  A2 |  A3 |  A4 |  A5 |  A6 |xxxx      
rdata,     xxxxxxxxxxxxxxxxxxxxxxxxxxx|  D1 |  D2 |  D3 |  D4 |  D5 |  D6 |xxxx 	
                                       ___________________________________
ram_wen   ____________________________|                                   |_________
ram_waddr  xxxxxxxxxxxxxxxxxxxxxxxxxxx|  A1 |  A2 |  A3 |  A4 |  A5 |  A6 |xxxx      
ram_wdata  xxxxxxxxxxxxxxxxxxxxxxxxxxx|  D1 |  D2 |  D3 |  D4 |  D5 |  D6 |xxxx  
*/
//ipg_cnt 计满 → rpkt_pop 翻转 → op_doing 忙 → ren 拉高读包 → ram_wen 延迟一拍写 RAM → 读完 ren 拉低 → ram_wen 最后写一拍 → op_doing 空闲 → ipg_cnt 重新计数
  assign ram_wpara = rpkt_para;

  always @(negedge reset_l or posedge clk)  //give a cycle level of  high   to  rpkt_pop
    if (reset_l == 1'b0) begin
      rpkt_pop <= 0;
      op_doing <= 0;
    end else begin
      if (op_doing == 1'b0 && empty == 1'b0 && ipg_cnt == ipg_adjust + ipg + 3) begin
        rpkt_pop <= ~rpkt_pop;
      end
      if (rpkt_pop == 1'b1) begin
        op_doing <= 1'b1;
      end
      if (clk_en == 1'b1) begin
        if (ren == 1'b0 && ram_wen == 1'b1) begin
          op_doing <= 1'b0;
        end
      end
    end

  always @(negedge reset_l or posedge clk)
    if (reset_l == 1'b0) begin
      rpkt_pop_dly <= 0;
      data_len <= 0;
      ren_s <= 0;
      ren <= 0;
      raddr <= 0;
      ram_wen <= 0;
      ram_waddr <= 0;
    end else begin
      rpkt_pop_dly <= {rpkt_pop_dly[0], rpkt_pop};  // delay   3 cycles
      if (rpkt_pop_dly[1] == 1'b1) begin
        data_len <= rpkt_len;
        ren <= 1;
      end
      if (clk_en == 1'b1) begin
        if (ren == 1'b1) begin
          raddr <= raddr + 1;
        end else begin
          raddr <= 0;
        end
        //if(block_mode == "true")begin
        if (raddr == data_len - 1) begin
          ren <= 0;
        end
        //end
        //else begin
        // if(reop_pre == 1'b1) begin
        //	ren <= 0;
        // end
        //end
        ram_wen   <= ren;
        ram_waddr <= raddr;
      end
    end
  assign ram_wdata = rdata;

  always @(negedge reset_l or posedge clk)
    if (reset_l == 1'b0) begin
      ipg_cnt <= 32'b0;
    end else begin
      if (clk_en == 1'b1) begin
        if (ram_wen == 1'b0) begin
          if (ipg_cnt < ipg_adjust + ipg + 3) begin
            ipg_cnt <= ipg_cnt + 1;
          end
        end else begin
          ipg_cnt <= 32'b0;
        end
      end
    end


endmodule
