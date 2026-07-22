//****************************************Copyright 2013[c]************************//
// ************************Declaration***************************************//
// File name:        mac_tx	                                       //
// Author:           huaming.huang@link-real.com.cn                                    //
// Date:             2015-01-08 00:00 	                                     //
// Version Number:   1.0                                                     //
// Abstract:    design for DP83848 RMII interface                            //
//              1.insert correct / incorrect FCS                             //
//              2.send packet number stat.                             //
//              3.Flow control (no design in v1.0)                             //
// Modification history:[including time, version, author and abstract]        //
// 2015-01-08 00:00        version 1.0     xxx                                //
// Abstract: Initial                                                          //
// 2015-06-04 00:00        version 1.1     xxx                                //
// Abstract: add fcs insert parmaeters                                                          //
//                                                                     //
// *********************************end************************************** //

module mac_tx (
    clk,
    clk_en,
    reset_l,
    //line side
    tx_en,
    tx_data,
    //system side
    mac_tx_sop,
    mac_tx_en,
    mac_tx_data,
    mac_tx_eop,
    mac_tx_err,
    //Stat.
    stat_cnt_0,
    stat_cnt_1
);
  parameter tx_fcs_insert_en = 1;
  input clk;
  input clk_en;
  input reset_l;

  output tx_en;
  output [7:0] tx_data;

  input mac_tx_sop;
  input mac_tx_en;
  input [7:0] mac_tx_data;
  input mac_tx_eop;
  input mac_tx_err;

  output [31:0] stat_cnt_0;
  output [31:0] stat_cnt_1;

  reg         tx_en;
  reg  [ 7:0] tx_data;
  reg  [31:0] stat_cnt_0;
  reg  [31:0] stat_cnt_1;
  reg         data_o_en;
  reg  [ 7:0] data_o;
  wire        data_o_en_d;
  wire [ 7:0] data_o_d;
  wire        crc_done;
  reg  [ 2:0] crc_done_dlyed;
  reg         ins_crc_err;
  wire [31:0] crc_out;
  reg  [31:0] crc_out_r;

  always @(negedge reset_l or posedge clk) begin
    if (reset_l == 1'b0) begin
      ins_crc_err <= 1'b0;
    end else begin
      if (clk_en == 1'b1) begin
        if (tx_en == 1'b1) begin
          if (mac_tx_eop == 1'b1 && mac_tx_err == 1'b1) begin  //error fcs insert
            ins_crc_err <= 1'b1;
          end
        end else begin
          ins_crc_err <= 1'b0;
        end
      end
    end
  end

  always @(negedge reset_l or posedge clk) begin
    if (reset_l == 1'b0) begin
      data_o_en <= 1'b0;
      data_o <= 8'b0;
      crc_done_dlyed <= 3'b0;
    end else begin
      if (clk_en == 1'b1) begin
        data_o_en <= mac_tx_en;
        data_o <= mac_tx_data;
        crc_done_dlyed <= {crc_done_dlyed[1:0], crc_done};
      end
    end
  end
  always @(negedge reset_l or posedge clk) begin
    if (reset_l == 1'b0) begin
      tx_en <= 1'b0;
      tx_data <= 8'b0;
      crc_out_r <= 32'b0;
    end else begin
      if (clk_en == 1'b1) begin
        tx_en   <= data_o_en_d;
        tx_data <= data_o_d;
        if (tx_fcs_insert_en == 1) begin
          //crc_send
          if (crc_done == 1'b1) begin
            crc_out_r <= crc_out;
            tx_data   <= crc_out[31:24];
          end
          if (crc_done_dlyed[0] == 1'b1) begin
            tx_data <= crc_out_r[23:16];
          end
          if (crc_done_dlyed[1] == 1'b1) begin
            tx_data <= crc_out_r[15:8];
          end
          if (crc_done_dlyed[2] == 1'b1) begin
            if (ins_crc_err == 1'b1) begin
              tx_data <= ~crc_out_r[7:0];
            end else begin
              tx_data <= crc_out_r[7:0];
            end
          end
        end
      end
    end
  end

  fix_delay #(
      .delay_cycles(4),
      .data_width(9),
      .ram_type("registers")
  ) u_fix_delay (
      .reset_l (reset_l),
      .clk   (clk),
      .clk_en   (clk_en),

      .data_in ({data_o_en, data_o}),
      .data_out({data_o_en_d, data_o_d})
  );
  crc #(
      .data_in_width(8),
      .crc_type     (0)   //crc32
  ) u_crc (
      .reset_l     (reset_l),
      .clk         (clk),
      .clk_en      (clk_en),
      .data_in_en  (data_o_en & data_o_en_d),
      .data_byte_en(1'b1),
      .data_in     (data_o_d),
      .crc_done    (crc_done),
      .crc_out     (crc_out)
  );

  always @(negedge reset_l or posedge clk) begin
    if (reset_l == 1'b0) begin
      stat_cnt_0 <= 32'b0;
      stat_cnt_1 <= 32'b0;
    end else begin
      if (clk_en == 1'b1) begin
        if (mac_tx_eop == 1'b1) begin
          if (mac_tx_err == 1'b1) begin  //error fcs insert
            stat_cnt_0[31:16] <= stat_cnt_0[31:16] + 1;
          end else begin
            stat_cnt_0[15:0] <= stat_cnt_0[15:0] + 1;  //correct fcs pkt stat.
          end
        end
      end
    end
  end



endmodule
