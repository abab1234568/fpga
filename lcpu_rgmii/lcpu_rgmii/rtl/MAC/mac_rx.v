//****************************************Copyright 2013[c]************************//
// ************************Declaration***************************************//
// File name:        mac_rx	                                       //
// Author:           huaming.huang@link-real.com.cn                                    //
// Date:             2015-01-08 00:00 	                                     //
// Version Number:   1.0                                                     //
// Abstract:    design for DP83848 RMII interface                            //
//              1.check correct / incorrect FCS                             //
//              2.receive packet number stat.                             //
//              3.Flow control (no design in v1.0)                             //
// Modification history:[including time, version, author and abstract]        //
// 2015-01-08 00:00        version 1.0     xxx                                //
// Abstract: Initial                                                          //
// 2015-06-04 00:00        version 1.1     xxx                                //
// Abstract: add fcs check parmaeters                                                          //
//                                                                     //
// *********************************end************************************** //

module mac_rx (
    clk,
    clk_en,
    reset_l,
    //line side
    rx_en,
    rx_data,
    //system side
    mac_rx_sop,
    mac_rx_en,
    mac_rx_data,
    mac_rx_eop,
    mac_rx_err,
    //Stat.
    stat_cnt_0,
    stat_cnt_1
);
  parameter rx_fcs_check_en = 1;

  input clk;
  input clk_en;
  input reset_l;

  input rx_en;
  input [7:0] rx_data;

  output mac_rx_sop;
  output mac_rx_en;
  output [7:0] mac_rx_data;
  output mac_rx_eop;
  output mac_rx_err;

  output [31:0] stat_cnt_0;
  output [31:0] stat_cnt_1;

  wire        crc_done;
  wire [31:0] crc_out;
  wire        crc_err;
  reg         rx_en_r;
  reg  [ 7:0] rx_data_r;
  reg  [31:0] stat_cnt_0;
  reg  [31:0] stat_cnt_1;

  always @(negedge reset_l or posedge clk) begin
    if (reset_l == 1'b0) begin
      rx_en_r   <= 1'b0;
      rx_data_r <= 8'b0;
    end else begin
      if (clk_en == 1'b1) begin
        rx_en_r   <= rx_en;
        rx_data_r <= rx_data;
      end
    end
  end

  generate
    if (rx_fcs_check_en == 1) begin : crc_chk_gen
      crc #(
          .data_in_width(8),
          .crc_type     (0)   //crc32
      ) u_crc (
          .reset_l     (reset_l),
          .clk         (clk),
          .clk_en      (clk_en),
          .data_in_en  (rx_en),
          .data_byte_en(1'b1),
          .data_in     (rx_data),
          .crc_done    (crc_done),
          .crc_out     (crc_out)
      );
      assign crc_err = (crc_out == 32'h1cdf4421) ? 1'b0 : crc_done;
    end else begin : no_crc_chk_gen
      assign crc_err = 1'b0;
    end
  endgenerate

  sop_eop_gen #(
      .data_width(8)
  ) u_sop_eop_gen (
      .reset_l(reset_l),
      .clk    (clk),
      .clk_en (clk_en),
      .i_en   (rx_en_r),
      .i_err  (crc_err),
      .i_data (rx_data_r),
      .o_sop  (mac_rx_sop),
      .o_en   (mac_rx_en),
      .o_data (mac_rx_data),
      .o_eop  (mac_rx_eop),
      .o_err  (mac_rx_err)
  );
  always @(negedge reset_l or posedge clk) begin
    if (reset_l == 1'b0) begin
      stat_cnt_0 <= 32'b0;
      stat_cnt_1 <= 32'b0;
    end else begin
      if (clk_en == 1'b1) begin
        if (mac_rx_eop == 1'b1) begin
          if (mac_rx_err == 1'b1) begin  //error fcs recv
            stat_cnt_1 <= stat_cnt_1 + 1;
          end else begin
            stat_cnt_0 <= stat_cnt_0 + 1;  //correct fcs pkt stat.
          end
        end
      end
    end
  end

endmodule
