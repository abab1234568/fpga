//****************************************Copyright 2013[c]************************//
// ************************Declaration***************************************//
// File name:        ram2pktfifo_int	                                       //
// Author:           huaming.huang@link-real.com.cn                                    //
// Date:             2014-12-02 00:00 	                                     //
// Version Number:   1.0                                                     //
// Abstract:    ram write interface convert to package fifo write timing 
//                                                                            //
// Modification history:[including time, version, author and abstract]        //
// 2014-12-02 00:00        version 1.0     xxx                                //
// Abstract: Initial                                                          //
//                                                                     //
// *********************************end************************************** //

module ram2pktfifo_int (
    reset_l,
    clk,
    clk_en,

    ram_wen,  //wen must be valid continuelly, except terminal one time opertion
    ram_wdata,
    ram_waddr,
    ram_wpara,
    ram_wen_permit,

    full,
    wen,
    waddr,
    wdata,
    wpkt_push,
    wpkt_len,
    wpkt_para
);

  parameter addr_width = 8, data_width = 32, para_width = 16;

  input reset_l;
  input clk;
  input clk_en;
  input ram_wen;
  input [data_width-1:0] ram_wdata;
  input [addr_width-1:0] ram_waddr;
  input [para_width-1:0] ram_wpara;
  output ram_wen_permit;
  input full;
  output wen;
  output [addr_width-1:0] waddr;
  output [data_width-1:0] wdata;
  output wpkt_push;
  output [addr_width:0] wpkt_len;
  output [para_width-1:0] wpkt_para;

  reg                  wen;
  reg [addr_width-1:0] waddr;
  reg [data_width-1:0] wdata;
  reg [  addr_width:0] wpkt_len;
  reg                  wpkt_push;

  assign ram_wen_permit = ~full;
  assign wpkt_para = ram_wpara;

  /* timing
               _____________________________
ram_wen   ____|                             |_________
ram_waddr  xxx| A1 | A2 | A3 | A4 | A5 | A6 |xxxx      
ram_wdata  xxx| D1 | D2 | D3 | D4 | D5 | D6 |xxxx                                  
                    _____________________________
wen,      _________|                             |____
waddr,     xxxxxxxx| A1 | A2 | A3 | A4 | A5 | A6 |xxxx      
wdata,     xxxxxxxx| D1 | D2 | D3 | D4 | D5 | D6 |xxxx 
                                                  ____
wpkt_push,_______________________________________|    |_____
wpkt_len, xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx|  6 |xxxx 
wpkt_para	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx|    |xxxx 		
*/

  always @(negedge reset_l or posedge clk)
    if (reset_l == 1'b0) begin
      wen <= 0;
      waddr <= 0;
      wdata <= 0;
      wpkt_len <= 0;
      wpkt_push <= 0;
    end else begin
      if (clk_en == 1'b1) begin
        wen <= ram_wen;
        waddr <= ram_waddr;
        wdata <= ram_wdata;
        wpkt_push <= ~ram_wen & wen;
        if (wen == 1'b1) begin
          wpkt_len <= wpkt_len + 1;
        end else begin
          wpkt_len <= 0;
        end
      end
    end

endmodule
