//****************************************Copyright 2013[c]************************//
// ************************Declaration***************************************//
// File name:        mac_top	                                       //
// Author:           huaming.huang@link-real.com.cn                                    //
// Date:             2015-01-08 00:00 	                                     //
// Version Number:   1.0                                                     //
// Abstract:    design for DP83848 RMII interface                            //
//              1.check/insert correct / incorrect FCS                             //
//              2.receive/send packet number stat.                             //
//              3.Flow control (no design in v1.0)                             //
// Modification history:[including time, version, author and abstract]        //
// 2015-01-08 00:00        version 1.0     xxx                                //
// Abstract: Initial                                                          //
//                                                                     //
// *********************************end************************************** //

module mac_top (
    clk,
    clk_en,
    reset_l,
    //line side
    rx_en,
    rx_data,
    tx_en,
    tx_data,
    //system side
    mac_rx_sop,
    mac_rx_en,
    mac_rx_data,
    mac_rx_eop,
    mac_rx_err,
    mac_tx_sop,
    mac_tx_en,
    mac_tx_data,
    mac_tx_eop,
    mac_tx_err,
    //Stat.
    mac_rx_stat_cnt_0,
    mac_rx_stat_cnt_1,
    mac_tx_stat_cnt_0,
    mac_tx_stat_cnt_1
);

  input clk;
  input clk_en;
  input reset_l;

  input rx_en;
  input [7:0] rx_data;
  output tx_en;
  output [7:0] tx_data;

  output mac_rx_sop;
  output mac_rx_en;
  output [7:0] mac_rx_data;
  output mac_rx_eop;
  output mac_rx_err;
  input mac_tx_sop;
  input mac_tx_en;
  input [7:0] mac_tx_data;
  input mac_tx_eop;
  input mac_tx_err;

  output [31:0] mac_rx_stat_cnt_0;
  output [31:0] mac_rx_stat_cnt_1;
  output [31:0] mac_tx_stat_cnt_0;
  output [31:0] mac_tx_stat_cnt_1;

  mac_rx u_mac_rx (
      .clk(clk),
      .clk_en(clk_en),
      .reset_l(reset_l),
      .rx_en(rx_en),
      .rx_data(rx_data),
      .mac_rx_sop(mac_rx_sop),
      .mac_rx_en(mac_rx_en),
      .mac_rx_data(mac_rx_data),
      .mac_rx_eop(mac_rx_eop),
      .mac_rx_err(mac_rx_err),
      .stat_cnt_0(mac_rx_stat_cnt_0),
      .stat_cnt_1(mac_rx_stat_cnt_1)
  );

  mac_tx u_mac_tx (
      .clk(clk),
      .clk_en(clk_en),
      .reset_l(reset_l),
      .tx_en(tx_en),
      .tx_data(tx_data),
      .mac_tx_sop(mac_tx_sop),
      .mac_tx_en(mac_tx_en),
      .mac_tx_data(mac_tx_data),
      .mac_tx_eop(mac_tx_eop),
      .mac_tx_err(mac_tx_err),
      .stat_cnt_0(mac_tx_stat_cnt_0),
      .stat_cnt_1(mac_tx_stat_cnt_1)
  );


endmodule
