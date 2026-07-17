//****************************************Copyright 2013[c]************************//
// ************************Declaration***************************************//
// File name:        sop_eop_gen	                                       //
// Author:           huaming.huang@link-real.com.cn                                    //
// Date:             2015-01-08 00:00 	                                     //
// Version Number:   1.0                                                     //
// Abstract:         based on data enable, generate SOP,SOP signals          //
// Modification history:[including time, version, author and abstract]        //
// 2015-01-08 00:00        version 1.0     xxx                                //
// Abstract: Initial                                                          //
//                                                                     //
// *********************************end************************************** //

module sop_eop_gen (
    clk,
    clk_en,
    reset_l,

    i_en,
    i_err,
    i_data,

    o_sop,
    o_en,
    o_data,
    o_eop,
    o_err
);
  parameter data_width = 8;

  input clk;
  input clk_en;
  input reset_l;

  input i_en;
  input i_err;
  input [data_width-1:0] i_data;

  output o_sop;
  output o_en;
  output [data_width-1:0] o_data;
  output o_eop;
  output o_err;

  reg                  i_en_d0;
  reg [data_width-1:0] i_data_d0;
  reg                  o_sop;
  reg                  i_err_d0;
  always @(negedge reset_l or posedge clk) begin
    if (reset_l == 1'b0) begin
      i_en_d0 <= 1'b0;
      i_data_d0 <= {data_width{1'b0}};
      o_sop <= 1'b0;
      i_err_d0 <= 1'b0;
    end else begin
      if (clk_en == 1'b1) begin
        i_en_d0 <= i_en;
        i_data_d0 <= i_data;
        o_sop <= i_en & (~i_en_d0);
        i_err_d0 <= i_err;
      end
    end
  end
  assign o_en   = i_en_d0;
  assign o_data = i_data_d0;
  assign o_eop  = ~i_en & i_en_d0;
  assign o_err  = o_eop & i_err_d0;
endmodule
