//****************************************Copyright 2013[c]************************//
// ************************Declaration***************************************//
// File name:        crc	                                       //
// Author:           huaming.huang@link-real.com.cn                                    //
// Date:             2014-12-22 00:00 	                                     //
// Version Number:   1.0                                                     //
// Abstract:         support CRC32,CRC-16-IBM,CRC-16-CCITT,CRC8
//                   polynomial:
//                   CRC-4/ITU : x^4+x+1  (0 1 4)
//                   CRC-8 : x^8+x^2+x+1  (0 1 2 8)
//                   CRC-8-ITU : x^8+x^2+x+1  (0 1 2 8)
//                   CRC-12 : x^12+x^11+x^3+x^2+x+1  (0 1 2 3 11 12)
//                   CRC-16-IBM : x^16+x^15+x^2+1  (0 2 15 16)
//                   CRC-16-CCITT : x^16+x^12+x^5+1  (0 5 12 16)
//                   CRC-32 : x^32+x^26+x^23+x^22+x^16+x^12+x^11+x^10+x^8+x^7+x^5+x^4+x^2+x+1
//                            (0 1 2 4 5 7 8 10 11 12 16 22 23 26 32)
// Modification history:[including time, version, author and abstract]        //
// 2014-12-22 00:00        version 1.0     xxx                                //
// Abstract: Initial                                                          //
//          v1: just support 1,8,16,32 bits width input                       //
// ****************************important notes******************************* //
//              for 1bit serial crc calculate
//              if is crc8, input byte need not reverse bit sqeuence, so
//                if input is 1bit width, msb must first in.....
//                 such as:data byte 0x010203... should input as: 000100100011...
//              if is crc16,crc32, input byte need reverse bit sqeuence, so
//                if input is 1bit width, lsb must first in.....
//                 such as:data byte 0x010203... should input as: 100001001100...
// *********************************end************************************** //
// Modification history:[including time, version, author and abstract]        //
// 2015-01-20 00:00        version 1.0     xxx                                //
// *********************************end************************************** //
//          v2: add 1bit width CRC7:
//                   polynomial:
//                   CRC-7 : x^7+x^3+1  (0 3 7)
// ****************************important notes******************************* //
//              for 1bit serial crc calculate
//                if input is 1bit width, msb must first in.....
//                 such as:data byte 0x010203... should input as: 000100100011...
// *********************************end************************************** //

module crc (
    reset_l,
    clk,
    clk_en,
    data_in_en,
    data_byte_en,
    data_in,
    crc_done,
    crc_out
);
  parameter  data_in_width = 1,
           crc_type = 1; //0:CRC-32 1:CRC-16-CCITT 2:CRC-16-IBM 3:CRC-8 4:CRC-8-ITU 5:CRC-12 6:CRC-4 7:CRC-7

  function integer fun_crc_bits;
    //0:CRC-32 1:CRC-16-CCITT 2:CRC-16-IBM 3:CRC-8 4:CRC-8-ITU 5:CRC-12 6:CRC-4 7:CRC-7
    input integer crc_type;
    integer crc_o_width;
    begin
      case (crc_type)
        0: crc_o_width = 32;
        1: crc_o_width = 16;
        2: crc_o_width = 16;
        3: crc_o_width = 8;
        4: crc_o_width = 8;
        5: crc_o_width = 12;
        6: crc_o_width = 4;
        7: crc_o_width = 7;
        default: crc_o_width = 32;
      endcase
      fun_crc_bits = crc_o_width;
    end
  endfunction

  function [31:0] fun_crc32_d1;
    input [0:0] data_in;
    input [31:0] crc_t;
    reg [31:0] crc_out_tmp;
    begin
      crc_out_tmp[0] = crc_t[31] + data_in[0];
      crc_out_tmp[1] = crc_t[0] + crc_t[31] + data_in[0];
      crc_out_tmp[2] = crc_t[1] + crc_t[31] + data_in[0];
      crc_out_tmp[3] = crc_t[2];
      crc_out_tmp[4] = crc_t[3] + crc_t[31] + data_in[0];
      crc_out_tmp[5] = crc_t[4] + crc_t[31] + data_in[0];
      crc_out_tmp[6] = crc_t[5];
      crc_out_tmp[7] = crc_t[6] + crc_t[31] + data_in[0];
      crc_out_tmp[8] = crc_t[7] + crc_t[31] + data_in[0];
      crc_out_tmp[9] = crc_t[8];
      crc_out_tmp[10] = crc_t[9] + crc_t[31] + data_in[0];
      crc_out_tmp[11] = crc_t[10] + crc_t[31] + data_in[0];
      crc_out_tmp[12] = crc_t[11] + crc_t[31] + data_in[0];
      crc_out_tmp[13] = crc_t[12];
      crc_out_tmp[14] = crc_t[13];
      crc_out_tmp[15] = crc_t[14];
      crc_out_tmp[16] = crc_t[15] + crc_t[31] + data_in[0];
      crc_out_tmp[17] = crc_t[16];
      crc_out_tmp[18] = crc_t[17];
      crc_out_tmp[19] = crc_t[18];
      crc_out_tmp[20] = crc_t[19];
      crc_out_tmp[21] = crc_t[20];
      crc_out_tmp[22] = crc_t[21] + crc_t[31] + data_in[0];
      crc_out_tmp[23] = crc_t[22] + crc_t[31] + data_in[0];
      crc_out_tmp[24] = crc_t[23];
      crc_out_tmp[25] = crc_t[24];
      crc_out_tmp[26] = crc_t[25] + crc_t[31] + data_in[0];
      crc_out_tmp[27] = crc_t[26];
      crc_out_tmp[28] = crc_t[27];
      crc_out_tmp[29] = crc_t[28];
      crc_out_tmp[30] = crc_t[29];
      crc_out_tmp[31] = crc_t[30];
      fun_crc32_d1 = crc_out_tmp;
    end
  endfunction

  function [31:0] fun_crc32_d8;
    input [7:0] data_in;
    input [31:0] crc_t;
    reg [31:0] crc_out_tmp;
    begin
      crc_out_tmp[0] = crc_t[24] + crc_t[30] + data_in[0] + data_in[6];
      crc_out_tmp[1]  = crc_t[24] + crc_t[25] + crc_t[30] + crc_t[31] + data_in[0] + data_in[1] + data_in[6] + data_in[7];
      crc_out_tmp[2]  = crc_t[24] + crc_t[25] + crc_t[26] + crc_t[30] + crc_t[31] + data_in[0] + data_in[1] + data_in[2] + data_in[6] + data_in[7];
      crc_out_tmp[3]  = crc_t[25] + crc_t[26] + crc_t[27] + crc_t[31] + data_in[1] + data_in[2] + data_in[3] + data_in[7];
      crc_out_tmp[4]  = crc_t[24] + crc_t[26] + crc_t[27] + crc_t[28] + crc_t[30] + data_in[0] + data_in[2] + data_in[3] + data_in[4] + data_in[6];
      crc_out_tmp[5]  = crc_t[24] + crc_t[25] + crc_t[27] + crc_t[28] + crc_t[29] + crc_t[30] + crc_t[31] + data_in[0] + data_in[1] + data_in[3] + data_in[4] + data_in[5] + data_in[6] + data_in[7];
      crc_out_tmp[6]  = crc_t[25] + crc_t[26] + crc_t[28] + crc_t[29] + crc_t[30] + crc_t[31] + data_in[1] + data_in[2] + data_in[4] + data_in[5] + data_in[6] + data_in[7];
      crc_out_tmp[7]  = crc_t[24] + crc_t[26] + crc_t[27] + crc_t[29] + crc_t[31] + data_in[0] + data_in[2] + data_in[3] + data_in[5] + data_in[7];
      crc_out_tmp[8]  = crc_t[0] + crc_t[24] + crc_t[25] + crc_t[27] + crc_t[28] + data_in[0] + data_in[1] + data_in[3] + data_in[4];
      crc_out_tmp[9]  = crc_t[1] + crc_t[25] + crc_t[26] + crc_t[28] + crc_t[29] + data_in[1] + data_in[2] + data_in[4] + data_in[5];
      crc_out_tmp[10] = crc_t[2] + crc_t[24] + crc_t[26] + crc_t[27] + crc_t[29] + data_in[0] + data_in[2] + data_in[3] + data_in[5];
      crc_out_tmp[11] = crc_t[3] + crc_t[24] + crc_t[25] + crc_t[27] + crc_t[28] + data_in[0] + data_in[1] + data_in[3] + data_in[4];
      crc_out_tmp[12] = crc_t[4] + crc_t[24] + crc_t[25] + crc_t[26] + crc_t[28] + crc_t[29] + crc_t[30] + data_in[0] + data_in[1] + data_in[2] + data_in[4] + data_in[5] + data_in[6];
      crc_out_tmp[13] = crc_t[5] + crc_t[25] + crc_t[26] + crc_t[27] + crc_t[29] + crc_t[30] + crc_t[31] + data_in[1] + data_in[2] + data_in[3] + data_in[5] + data_in[6] + data_in[7];
      crc_out_tmp[14] = crc_t[6] + crc_t[26] + crc_t[27] + crc_t[28] + crc_t[30] + crc_t[31] + data_in[2] + data_in[3] + data_in[4] + data_in[6] + data_in[7];
      crc_out_tmp[15] = crc_t[7] + crc_t[27] + crc_t[28] + crc_t[29] + crc_t[31] + data_in[3] + data_in[4] + data_in[5] + data_in[7];
      crc_out_tmp[16] = crc_t[8] + crc_t[24] + crc_t[28] + crc_t[29] + data_in[0] + data_in[4] + data_in[5];
      crc_out_tmp[17] = crc_t[9] + crc_t[25] + crc_t[29] + crc_t[30] + data_in[1] + data_in[5] + data_in[6];
      crc_out_tmp[18] = crc_t[10] + crc_t[26] + crc_t[30] + crc_t[31] + data_in[2] + data_in[6] + data_in[7];
      crc_out_tmp[19] = crc_t[11] + crc_t[27] + crc_t[31] + data_in[3] + data_in[7];
      crc_out_tmp[20] = crc_t[12] + crc_t[28] + data_in[4];
      crc_out_tmp[21] = crc_t[13] + crc_t[29] + data_in[5];
      crc_out_tmp[22] = crc_t[14] + crc_t[24] + data_in[0];
      crc_out_tmp[23] =	crc_t[15] + crc_t[24] + crc_t[25] + crc_t[30] + data_in[0] + data_in[1] + data_in[6];
      crc_out_tmp[24] =	crc_t[16] + crc_t[25] + crc_t[26] + crc_t[31] + data_in[1] + data_in[2] + data_in[7];
      crc_out_tmp[25] = crc_t[17] + crc_t[26] + crc_t[27] + data_in[2] + data_in[3];
      crc_out_tmp[26] =	crc_t[18] + crc_t[24] + crc_t[27] + crc_t[28] + crc_t[30] + data_in[0] + data_in[3] + data_in[4] + data_in[6];
      crc_out_tmp[27] =	crc_t[19] + crc_t[25] + crc_t[28] + crc_t[29] + crc_t[31] + data_in[1] + data_in[4] + data_in[5] + data_in[7];
      crc_out_tmp[28] =	crc_t[20] + crc_t[26] + crc_t[29] + crc_t[30] + data_in[2] + data_in[5] + data_in[6];
      crc_out_tmp[29] =	crc_t[21] + crc_t[27] + crc_t[30] + crc_t[31] + data_in[3] + data_in[6] + data_in[7];
      crc_out_tmp[30] = crc_t[22] + crc_t[28] + crc_t[31] + data_in[4] + data_in[7];
      crc_out_tmp[31] = crc_t[23] + crc_t[29] + data_in[5];
      fun_crc32_d8 = crc_out_tmp;
    end
  endfunction

  function [31:0] fun_crc32_d16;
    input [15:0] data_in;
    input [31:0] crc_t;
    reg [31:0] crc_out_tmp;
    begin
      crc_out_tmp[0]	= crc_t[16] + crc_t[22] + crc_t[25] + crc_t[26] + crc_t[28] + data_in[0] + data_in[6] + data_in[9] + data_in[10] + data_in[12];
      crc_out_tmp[1]	= crc_t[16] + crc_t[17] + crc_t[22] + crc_t[23] + crc_t[25] + crc_t[27] + crc_t[28] + crc_t[29] + data_in[0] + data_in[1] + data_in[6] + data_in[7] + data_in[9] + data_in[11] + data_in[12] + data_in[13];
      crc_out_tmp[2]	= crc_t[16] + crc_t[17] + crc_t[18] + crc_t[22] + crc_t[23] + crc_t[24] + crc_t[25] + crc_t[29] + crc_t[30] + data_in[0] + data_in[1] + data_in[2] + data_in[6] + data_in[7] + data_in[8] + data_in[9] + data_in[13] + data_in[14];
      crc_out_tmp[3]	= crc_t[17] + crc_t[18] + crc_t[19] + crc_t[23] + crc_t[24] + crc_t[25] + crc_t[26] + crc_t[30] + crc_t[31] + data_in[1] + data_in[2] + data_in[3] + data_in[7] + data_in[8] + data_in[9] + data_in[10] + data_in[14] + data_in[15];
      crc_out_tmp[4]	= crc_t[16] + crc_t[18] + crc_t[19] + crc_t[20] + crc_t[22] + crc_t[24] + crc_t[27] + crc_t[28] + crc_t[31] + data_in[0] + data_in[2] + data_in[3] + data_in[4] + data_in[6] + data_in[8] + data_in[11] + data_in[12] + data_in[15];
      crc_out_tmp[5]	= crc_t[16] + crc_t[17] + crc_t[19] + crc_t[20] + crc_t[21] + crc_t[22] + crc_t[23] + crc_t[26] + crc_t[29] + data_in[0] + data_in[1] + data_in[3] + data_in[4] + data_in[5] + data_in[6] + data_in[7] + data_in[10] + data_in[13];
      crc_out_tmp[6]	= crc_t[17] + crc_t[18] + crc_t[20] + crc_t[21] + crc_t[22] + crc_t[23] + crc_t[24] + crc_t[27] + crc_t[30] + data_in[1] + data_in[2] + data_in[4] + data_in[5] + data_in[6] + data_in[7] + data_in[8] + data_in[11] + data_in[14];
      crc_out_tmp[7]	= crc_t[16] + crc_t[18] + crc_t[19] + crc_t[21] + crc_t[23] + crc_t[24] + crc_t[26] + crc_t[31] + data_in[0] + data_in[2] + data_in[3] + data_in[5] + data_in[7] + data_in[8] + data_in[10] + data_in[15];
      crc_out_tmp[8]	= crc_t[16] + crc_t[17] + crc_t[19] + crc_t[20] + crc_t[24] + crc_t[26] + crc_t[27] + crc_t[28] + data_in[0] + data_in[1] + data_in[3] + data_in[4] + data_in[8] + data_in[10] + data_in[11] + data_in[12];
      crc_out_tmp[9]	= crc_t[17] + crc_t[18] + crc_t[20] + crc_t[21] + crc_t[25] + crc_t[27] + crc_t[28] + crc_t[29] + data_in[1] + data_in[2] + data_in[4] + data_in[5] + data_in[9] + data_in[11] + data_in[12] + data_in[13];
      crc_out_tmp[10] = crc_t[16] + crc_t[18] + crc_t[19] + crc_t[21] + crc_t[25] + crc_t[29] + crc_t[30] + data_in[0] + data_in[2] + data_in[3] + data_in[5] + data_in[9] + data_in[13] + data_in[14];
      crc_out_tmp[11] = crc_t[16] + crc_t[17] + crc_t[19] + crc_t[20] + crc_t[25] + crc_t[28] + crc_t[30] + crc_t[31] + data_in[0] + data_in[1] + data_in[3] + data_in[4] + data_in[9] + data_in[12] + data_in[14] + data_in[15];
      crc_out_tmp[12] = crc_t[16] + crc_t[17] + crc_t[18] + crc_t[20] + crc_t[21] + crc_t[22] + crc_t[25] + crc_t[28] + crc_t[29] + crc_t[31] + data_in[0] + data_in[1] + data_in[2] + data_in[4] + data_in[5] + data_in[6] + data_in[9] + data_in[12] + data_in[13] + data_in[15];
      crc_out_tmp[13] = crc_t[17] + crc_t[18] + crc_t[19] + crc_t[21] + crc_t[22] + crc_t[23] + crc_t[26] + crc_t[29] + crc_t[30] + data_in[1] + data_in[2] + data_in[3] + data_in[5] + data_in[6] + data_in[7] + data_in[10] + data_in[13] + data_in[14];
      crc_out_tmp[14] = crc_t[18] + crc_t[19] + crc_t[20] + crc_t[22] + crc_t[23] + crc_t[24] + crc_t[27] + crc_t[30] + crc_t[31] + data_in[2] + data_in[3] + data_in[4] + data_in[6] + data_in[7] + data_in[8] + data_in[11] + data_in[14] + data_in[15];
      crc_out_tmp[15] = crc_t[19] + crc_t[20] + crc_t[21] + crc_t[23] + crc_t[24] + crc_t[25] + crc_t[28] + crc_t[31] + data_in[3] + data_in[4] + data_in[5] + data_in[7] + data_in[8] + data_in[9] + data_in[12] + data_in[15];
      crc_out_tmp[16] = crc_t[0] + crc_t[16] + crc_t[20] + crc_t[21] + crc_t[24] + crc_t[28] + crc_t[29] + data_in[0] + data_in[4] + data_in[5] + data_in[8] + data_in[12] + data_in[13];
      crc_out_tmp[17] = crc_t[1] + crc_t[17] + crc_t[21] + crc_t[22] + crc_t[25] + crc_t[29] + crc_t[30] + data_in[1] + data_in[5] + data_in[6] + data_in[9] + data_in[13] + data_in[14];
      crc_out_tmp[18] = crc_t[2] + crc_t[18] + crc_t[22] + crc_t[23] + crc_t[26] + crc_t[30] + crc_t[31] + data_in[2] + data_in[6] + data_in[7] + data_in[10] + data_in[14] + data_in[15];
      crc_out_tmp[19] = crc_t[3] + crc_t[19] + crc_t[23] + crc_t[24] + crc_t[27] + crc_t[31] + data_in[3] + data_in[7] + data_in[8] + data_in[11] + data_in[15];
      crc_out_tmp[20] = crc_t[4] + crc_t[20] + crc_t[24] + crc_t[25] + crc_t[28] + data_in[4] + data_in[8] + data_in[9] + data_in[12];
      crc_out_tmp[21] = crc_t[5] + crc_t[21] + crc_t[25] + crc_t[26] + crc_t[29] + data_in[5] + data_in[9] + data_in[10] + data_in[13];
      crc_out_tmp[22] = crc_t[6] + crc_t[16] + crc_t[25] + crc_t[27] + crc_t[28] + crc_t[30] + data_in[0] + data_in[9] + data_in[11] + data_in[12] + data_in[14];
      crc_out_tmp[23] = crc_t[7] + crc_t[16] + crc_t[17] + crc_t[22] + crc_t[25] + crc_t[29] + crc_t[31] + data_in[0] + data_in[1] + data_in[6] + data_in[9] + data_in[13] + data_in[15];
      crc_out_tmp[24] = crc_t[8] + crc_t[17] + crc_t[18] + crc_t[23] + crc_t[26] + crc_t[30] + data_in[1] + data_in[2] + data_in[7] + data_in[10] + data_in[14];
      crc_out_tmp[25] = crc_t[9] + crc_t[18] + crc_t[19] + crc_t[24] + crc_t[27] + crc_t[31] + data_in[2] + data_in[3] + data_in[8] + data_in[11] + data_in[15];
      crc_out_tmp[26] = crc_t[10] + crc_t[16] + crc_t[19] + crc_t[20] + crc_t[22] + crc_t[26] + data_in[0] + data_in[3] + data_in[4] + data_in[6] + data_in[10];
      crc_out_tmp[27] = crc_t[11] + crc_t[17] + crc_t[20] + crc_t[21] + crc_t[23] + crc_t[27] + data_in[1] + data_in[4] + data_in[5] + data_in[7] + data_in[11];
      crc_out_tmp[28] = crc_t[12] + crc_t[18] + crc_t[21] + crc_t[22] + crc_t[24] + crc_t[28] + data_in[2] + data_in[5] + data_in[6] + data_in[8] + data_in[12];
      crc_out_tmp[29] = crc_t[13] + crc_t[19] + crc_t[22] + crc_t[23] + crc_t[25] + crc_t[29] + data_in[3] + data_in[6] + data_in[7] + data_in[9] + data_in[13];
      crc_out_tmp[30] = crc_t[14] + crc_t[20] + crc_t[23] + crc_t[24] + crc_t[26] + crc_t[30] + data_in[4] + data_in[7] + data_in[8] + data_in[10] + data_in[14];
      crc_out_tmp[31] = crc_t[15] + crc_t[21] + crc_t[24] + crc_t[25] + crc_t[27] + crc_t[31] + data_in[5] + data_in[8] + data_in[9] + data_in[11] + data_in[15];
      fun_crc32_d16 = crc_out_tmp;
    end
  endfunction

  function [31:0] fun_crc32_d24;
    input [23:0] data_in;
    input [31:0] crc_t;
    reg [31:0] crc_out_tmp;
    begin
      crc_out_tmp[0]	= crc_t[8] + crc_t[14] + crc_t[17] + crc_t[18] + crc_t[20] + crc_t[24] + data_in[0] + data_in[6] + data_in[9] + data_in[10] + data_in[12] + data_in[16];
      crc_out_tmp[1]	= crc_t[8] + crc_t[9] + crc_t[14] + crc_t[15] + crc_t[17] + crc_t[19] + crc_t[20] + crc_t[21] + crc_t[24] + crc_t[25] + data_in[0] + data_in[1] + data_in[6] + data_in[7] + data_in[9] + data_in[11] + data_in[12] + data_in[13] + data_in[16] + data_in[17];
      crc_out_tmp[2]	= crc_t[8] + crc_t[9] + crc_t[10] + crc_t[14] + crc_t[15] + crc_t[16] + crc_t[17] + crc_t[21] + crc_t[22] + crc_t[24] + crc_t[25] + crc_t[26] + data_in[0] + data_in[1] + data_in[2] + data_in[6] + data_in[7] + data_in[8] + data_in[9] + data_in[13] + data_in[14] + data_in[16] + data_in[17] + data_in[18];
      crc_out_tmp[3]	= crc_t[9] + crc_t[10] + crc_t[11] + crc_t[15] + crc_t[16] + crc_t[17] + crc_t[18] + crc_t[22] + crc_t[23] + crc_t[25] + crc_t[26] + crc_t[27] + data_in[1] + data_in[2] + data_in[3] + data_in[7] + data_in[8] + data_in[9] + data_in[10] + data_in[14] + data_in[15] + data_in[17] + data_in[18] + data_in[19];
      crc_out_tmp[4]	= crc_t[8] + crc_t[10] + crc_t[11] + crc_t[12] + crc_t[14] + crc_t[16] + crc_t[19] + crc_t[20] + crc_t[23] + crc_t[26] + crc_t[27] + crc_t[28] + data_in[0] + data_in[2] + data_in[3] + data_in[4] + data_in[6] + data_in[8] + data_in[11] + data_in[12] + data_in[15] + data_in[18] + data_in[19] + data_in[20];
      crc_out_tmp[5]	= crc_t[8] + crc_t[9] + crc_t[11] + crc_t[12] + crc_t[13] + crc_t[14] + crc_t[15] + crc_t[18] + crc_t[21] + crc_t[27] + crc_t[28] + crc_t[29] + data_in[0] + data_in[1] + data_in[3] + data_in[4] + data_in[5] + data_in[6] + data_in[7] + data_in[10] + data_in[13] + data_in[19] + data_in[20] + data_in[21];
      crc_out_tmp[6]	= crc_t[9] + crc_t[10] + crc_t[12] + crc_t[13] + crc_t[14] + crc_t[15] + crc_t[16] + crc_t[19] + crc_t[22] + crc_t[28] + crc_t[29] + crc_t[30] + data_in[1] + data_in[2] + data_in[4] + data_in[5] + data_in[6] + data_in[7] + data_in[8] + data_in[11] + data_in[14] + data_in[20] + data_in[21] + data_in[22];
      crc_out_tmp[7]	= crc_t[8] + crc_t[10] + crc_t[11] + crc_t[13] + crc_t[15] + crc_t[16] + crc_t[18] + crc_t[23] + crc_t[24] + crc_t[29] + crc_t[30] + crc_t[31] + data_in[0] + data_in[2] + data_in[3] + data_in[5] + data_in[7] + data_in[8] + data_in[10] + data_in[15] + data_in[16] + data_in[21] + data_in[22] + data_in[23];
      crc_out_tmp[8]	= crc_t[8] + crc_t[9] + crc_t[11] + crc_t[12] + crc_t[16] + crc_t[18] + crc_t[19] + crc_t[20] + crc_t[25] + crc_t[30] + crc_t[31] + data_in[0] + data_in[1] + data_in[3] + data_in[4] + data_in[8] + data_in[10] + data_in[11] + data_in[12] + data_in[17] + data_in[22] + data_in[23];
      crc_out_tmp[9]	= crc_t[9] + crc_t[10] + crc_t[12] + crc_t[13] + crc_t[17] + crc_t[19] + crc_t[20] + crc_t[21] + crc_t[26] + crc_t[31] + data_in[1] + data_in[2] + data_in[4] + data_in[5] + data_in[9] + data_in[11] + data_in[12] + data_in[13] + data_in[18] + data_in[23];
      crc_out_tmp[10] = crc_t[8] + crc_t[10] + crc_t[11] + crc_t[13] + crc_t[17] + crc_t[21] + crc_t[22] + crc_t[24] + crc_t[27] + data_in[0] + data_in[2] + data_in[3] + data_in[5] + data_in[9] + data_in[13] + data_in[14] + data_in[16] + data_in[19];
      crc_out_tmp[11] = crc_t[8] + crc_t[9] + crc_t[11] + crc_t[12] + crc_t[17] + crc_t[20] + crc_t[22] + crc_t[23] + crc_t[24] + crc_t[25] + crc_t[28] + data_in[0] + data_in[1] + data_in[3] + data_in[4] + data_in[9] + data_in[12] + data_in[14] + data_in[15] + data_in[16] + data_in[17] + data_in[20];
      crc_out_tmp[12] = crc_t[8] + crc_t[9] + crc_t[10] + crc_t[12] + crc_t[13] + crc_t[14] + crc_t[17] + crc_t[20] + crc_t[21] + crc_t[23] + crc_t[25] + crc_t[26] + crc_t[29] + data_in[0] + data_in[1] + data_in[2] + data_in[4] + data_in[5] + data_in[6] + data_in[9] + data_in[12] + data_in[13] + data_in[15] + data_in[17] + data_in[18] + data_in[21];
      crc_out_tmp[13] = crc_t[9] + crc_t[10] + crc_t[11] + crc_t[13] + crc_t[14] + crc_t[15] + crc_t[18] + crc_t[21] + crc_t[22] + crc_t[24] + crc_t[26] + crc_t[27] + crc_t[30] + data_in[1] + data_in[2] + data_in[3] + data_in[5] + data_in[6] + data_in[7] + data_in[10] + data_in[13] + data_in[14] + data_in[16] + data_in[18] + data_in[19] + data_in[22];
      crc_out_tmp[14] = crc_t[10] + crc_t[11] + crc_t[12] + crc_t[14] + crc_t[15] + crc_t[16] + crc_t[19] + crc_t[22] + crc_t[23] + crc_t[25] + crc_t[27] + crc_t[28] + crc_t[31] + data_in[2] + data_in[3] + data_in[4] + data_in[6] + data_in[7] + data_in[8] + data_in[11] + data_in[14] + data_in[15] + data_in[17] + data_in[19] + data_in[20] + data_in[23];
      crc_out_tmp[15] = crc_t[11] + crc_t[12] + crc_t[13] + crc_t[15] + crc_t[16] + crc_t[17] + crc_t[20] + crc_t[23] + crc_t[24] + crc_t[26] + crc_t[28] + crc_t[29] + data_in[3] + data_in[4] + data_in[5] + data_in[7] + data_in[8] + data_in[9] + data_in[12] + data_in[15] + data_in[16] + data_in[18] + data_in[20] + data_in[21];
      crc_out_tmp[16] = crc_t[8] + crc_t[12] + crc_t[13] + crc_t[16] + crc_t[20] + crc_t[21] + crc_t[25] + crc_t[27] + crc_t[29] + crc_t[30] + data_in[0] + data_in[4] + data_in[5] + data_in[8] + data_in[12] + data_in[13] + data_in[17] + data_in[19] + data_in[21] + data_in[22];
      crc_out_tmp[17] = crc_t[9] + crc_t[13] + crc_t[14] + crc_t[17] + crc_t[21] + crc_t[22] + crc_t[26] + crc_t[28] + crc_t[30] + crc_t[31] + data_in[1] + data_in[5] + data_in[6] + data_in[9] + data_in[13] + data_in[14] + data_in[18] + data_in[20] + data_in[22] + data_in[23];
      crc_out_tmp[18] = crc_t[10] + crc_t[14] + crc_t[15] + crc_t[18] + crc_t[22] + crc_t[23] + crc_t[27] + crc_t[29] + crc_t[31] + data_in[2] + data_in[6] + data_in[7] + data_in[10] + data_in[14] + data_in[15] + data_in[19] + data_in[21] + data_in[23];
      crc_out_tmp[19] = crc_t[11] + crc_t[15] + crc_t[16] + crc_t[19] + crc_t[23] + crc_t[24] + crc_t[28] + crc_t[30] + data_in[3] + data_in[7] + data_in[8] + data_in[11] + data_in[15] + data_in[16] + data_in[20] + data_in[22];
      crc_out_tmp[20] = crc_t[12] + crc_t[16] + crc_t[17] + crc_t[20] + crc_t[24] + crc_t[25] + crc_t[29] + crc_t[31] + data_in[4] + data_in[8] + data_in[9] + data_in[12] + data_in[16] + data_in[17] + data_in[21] + data_in[23];
      crc_out_tmp[21] = crc_t[13] + crc_t[17] + crc_t[18] + crc_t[21] + crc_t[25] + crc_t[26] + crc_t[30] + data_in[5] + data_in[9] + data_in[10] + data_in[13] + data_in[17] + data_in[18] + data_in[22];
      crc_out_tmp[22] = crc_t[8] + crc_t[17] + crc_t[19] + crc_t[20] + crc_t[22] + crc_t[24] + crc_t[26] + crc_t[27] + crc_t[31] + data_in[0] + data_in[9] + data_in[11] + data_in[12] + data_in[14] + data_in[16] + data_in[18] + data_in[19] + data_in[23];
      crc_out_tmp[23] = crc_t[8] + crc_t[9] + crc_t[14] + crc_t[17] + crc_t[21] + crc_t[23] + crc_t[24] + crc_t[25] + crc_t[27] + crc_t[28] + data_in[0] + data_in[1] + data_in[6] + data_in[9] + data_in[13] + data_in[15] + data_in[16] + data_in[17] + data_in[19] + data_in[20];
      crc_out_tmp[24] = crc_t[0] + crc_t[9] + crc_t[10] + crc_t[15] + crc_t[18] + crc_t[22] + crc_t[24] + crc_t[25] + crc_t[26] + crc_t[28] + crc_t[29] + data_in[1] + data_in[2] + data_in[7] + data_in[10] + data_in[14] + data_in[16] + data_in[17] + data_in[18] + data_in[20] + data_in[21];
      crc_out_tmp[25] = crc_t[1] + crc_t[10] + crc_t[11] + crc_t[16] + crc_t[19] + crc_t[23] + crc_t[25] + crc_t[26] + crc_t[27] + crc_t[29] + crc_t[30] + data_in[2] + data_in[3] + data_in[8] + data_in[11] + data_in[15] + data_in[17] + data_in[18] + data_in[19] + data_in[21] + data_in[22];
      crc_out_tmp[26] = crc_t[2] + crc_t[8] + crc_t[11] + crc_t[12] + crc_t[14] + crc_t[18] + crc_t[26] + crc_t[27] + crc_t[28] + crc_t[30] + crc_t[31] + data_in[0] + data_in[3] + data_in[4] + data_in[6] + data_in[10] + data_in[18] + data_in[19] + data_in[20] + data_in[22] + data_in[23];
      crc_out_tmp[27] = crc_t[3] + crc_t[9] + crc_t[12] + crc_t[13] + crc_t[15] + crc_t[19] + crc_t[27] + crc_t[28] + crc_t[29] + crc_t[31] + data_in[1] + data_in[4] + data_in[5] + data_in[7] + data_in[11] + data_in[19] + data_in[20] + data_in[21] + data_in[23];
      crc_out_tmp[28] = crc_t[4] + crc_t[10] + crc_t[13] + crc_t[14] + crc_t[16] + crc_t[20] + crc_t[28] + crc_t[29] + crc_t[30] + data_in[2] + data_in[5] + data_in[6] + data_in[8] + data_in[12] + data_in[20] + data_in[21] + data_in[22];
      crc_out_tmp[29] = crc_t[5] + crc_t[11] + crc_t[14] + crc_t[15] + crc_t[17] + crc_t[21] + crc_t[29] + crc_t[30] + crc_t[31] + data_in[3] + data_in[6] + data_in[7] + data_in[9] + data_in[13] + data_in[21] + data_in[22] + data_in[23];
      crc_out_tmp[30] = crc_t[6] + crc_t[12] + crc_t[15] + crc_t[16] + crc_t[18] + crc_t[22] + crc_t[30] + crc_t[31] + data_in[4] + data_in[7] + data_in[8] + data_in[10] + data_in[14] + data_in[22] + data_in[23];
      crc_out_tmp[31] = crc_t[7] + crc_t[13] + crc_t[16] + crc_t[17] + crc_t[19] + crc_t[23] + crc_t[31] + data_in[5] + data_in[8] + data_in[9] + data_in[11] + data_in[15] + data_in[23];
      fun_crc32_d24 = crc_out_tmp;
    end
  endfunction

  function [31:0] fun_crc32_d32;
    input [31:0] data_in;
    input [31:0] crc_t;
    reg [31:0] crc_out_tmp;
    begin
      crc_out_tmp[0]	= crc_t[0] + crc_t[6] + crc_t[9] + crc_t[10] + crc_t[12] + crc_t[16] + crc_t[24] + crc_t[25] + crc_t[26] + crc_t[28] + crc_t[29] + crc_t[30] + crc_t[31] + data_in[0] + data_in[6] + data_in[9] + data_in[10] + data_in[12] + data_in[16] + data_in[24] + data_in[25] + data_in[26] + data_in[28] + data_in[29] + data_in[30] + data_in[31];
      crc_out_tmp[1]	= crc_t[0] + crc_t[1] + crc_t[6] + crc_t[7] + crc_t[9] + crc_t[11] + crc_t[12] + crc_t[13] + crc_t[16] + crc_t[17] + crc_t[24] + crc_t[27] + crc_t[28] + data_in[0] + data_in[1] + data_in[6] + data_in[7] + data_in[9] + data_in[11] + data_in[12] + data_in[13] + data_in[16] + data_in[17] + data_in[24] + data_in[27] + data_in[28];
      crc_out_tmp[2]	= crc_t[0] + crc_t[1] + crc_t[2] + crc_t[6] + crc_t[7] + crc_t[8] + crc_t[9] + crc_t[13] + crc_t[14] + crc_t[16] + crc_t[17] + crc_t[18] + crc_t[24] + crc_t[26] + crc_t[30] + crc_t[31] + data_in[0] + data_in[1] + data_in[2] + data_in[6] + data_in[7] + data_in[8] + data_in[9] + data_in[13] + data_in[14] + data_in[16] + data_in[17] + data_in[18] + data_in[24] + data_in[26] + data_in[30] + data_in[31];
      crc_out_tmp[3]	= crc_t[1] + crc_t[2] + crc_t[3] + crc_t[7] + crc_t[8] + crc_t[9] + crc_t[10] + crc_t[14] + crc_t[15] + crc_t[17] + crc_t[18] + crc_t[19] + crc_t[25] + crc_t[27] + crc_t[31] + data_in[1] + data_in[2] + data_in[3] + data_in[7] + data_in[8] + data_in[9] + data_in[10] + data_in[14] + data_in[15] + data_in[17] + data_in[18] + data_in[19] + data_in[25] + data_in[27] + data_in[31];
      crc_out_tmp[4]	= crc_t[0] + crc_t[2] + crc_t[3] + crc_t[4] + crc_t[6] + crc_t[8] + crc_t[11] + crc_t[12] + crc_t[15] + crc_t[18] + crc_t[19] + crc_t[20] + crc_t[24] + crc_t[25] + crc_t[29] + crc_t[30] + crc_t[31] + data_in[0] + data_in[2] + data_in[3] + data_in[4] + data_in[6] + data_in[8] + data_in[11] + data_in[12] + data_in[15] + data_in[18] + data_in[19] + data_in[20] + data_in[24] + data_in[25] + data_in[29] + data_in[30] + data_in[31];
      crc_out_tmp[5]	= crc_t[0] + crc_t[1] + crc_t[3] + crc_t[4] + crc_t[5] + crc_t[6] + crc_t[7] + crc_t[10] + crc_t[13] + crc_t[19] + crc_t[20] + crc_t[21] + crc_t[24] + crc_t[28] + crc_t[29] + data_in[0] + data_in[1] + data_in[3] + data_in[4] + data_in[5] + data_in[6] + data_in[7] + data_in[10] + data_in[13] + data_in[19] + data_in[20] + data_in[21] + data_in[24] + data_in[28] + data_in[29];
      crc_out_tmp[6]	= crc_t[1] + crc_t[2] + crc_t[4] + crc_t[5] + crc_t[6] + crc_t[7] + crc_t[8] + crc_t[11] + crc_t[14] + crc_t[20] + crc_t[21] + crc_t[22] + crc_t[25] + crc_t[29] + crc_t[30] + data_in[1] + data_in[2] + data_in[4] + data_in[5] + data_in[6] + data_in[7] + data_in[8] + data_in[11] + data_in[14] + data_in[20] + data_in[21] + data_in[22] + data_in[25] + data_in[29] + data_in[30];
      crc_out_tmp[7]	= crc_t[0] + crc_t[2] + crc_t[3] + crc_t[5] + crc_t[7] + crc_t[8] + crc_t[10] + crc_t[15] + crc_t[16] + crc_t[21] + crc_t[22] + crc_t[23] + crc_t[24] + crc_t[25] + crc_t[28] + crc_t[29] + data_in[0] + data_in[2] + data_in[3] + data_in[5] + data_in[7] + data_in[8] + data_in[10] + data_in[15] + data_in[16] + data_in[21] + data_in[22] + data_in[23] + data_in[24] + data_in[25] + data_in[28] + data_in[29];
      crc_out_tmp[8]	= crc_t[0] + crc_t[1] + crc_t[3] + crc_t[4] + crc_t[8] + crc_t[10] + crc_t[11] + crc_t[12] + crc_t[17] + crc_t[22] + crc_t[23] + crc_t[28] + crc_t[31] + data_in[0] + data_in[1] + data_in[3] + data_in[4] + data_in[8] + data_in[10] + data_in[11] + data_in[12] + data_in[17] + data_in[22] + data_in[23] + data_in[28] + data_in[31];
      crc_out_tmp[9]	= crc_t[1] + crc_t[2] + crc_t[4] + crc_t[5] + crc_t[9] + crc_t[11] + crc_t[12] + crc_t[13] + crc_t[18] + crc_t[23] + crc_t[24] + crc_t[29] + data_in[1] + data_in[2] + data_in[4] + data_in[5] + data_in[9] + data_in[11] + data_in[12] + data_in[13] + data_in[18] + data_in[23] + data_in[24] + data_in[29];
      crc_out_tmp[10] = crc_t[0] + crc_t[2] + crc_t[3] + crc_t[5] + crc_t[9] + crc_t[13] + crc_t[14] + crc_t[16] + crc_t[19] + crc_t[26] + crc_t[28] + crc_t[29] + crc_t[31] + data_in[0] + data_in[2] + data_in[3] + data_in[5] + data_in[9] + data_in[13] + data_in[14] + data_in[16] + data_in[19] + data_in[26] + data_in[28] + data_in[29] + data_in[31];
      crc_out_tmp[11] = crc_t[0] + crc_t[1] + crc_t[3] + crc_t[4] + crc_t[9] + crc_t[12] + crc_t[14] + crc_t[15] + crc_t[16] + crc_t[17] + crc_t[20] + crc_t[24] + crc_t[25] + crc_t[26] + crc_t[27] + crc_t[28] + crc_t[31] + data_in[0] + data_in[1] + data_in[3] + data_in[4] + data_in[9] + data_in[12] + data_in[14] + data_in[15] + data_in[16] + data_in[17] + data_in[20] + data_in[24] + data_in[25] + data_in[26] + data_in[27] + data_in[28] + data_in[31];
      crc_out_tmp[12] = crc_t[0] + crc_t[1] + crc_t[2] + crc_t[4] + crc_t[5] + crc_t[6] + crc_t[9] + crc_t[12] + crc_t[13] + crc_t[15] + crc_t[17] + crc_t[18] + crc_t[21] + crc_t[24] + crc_t[27] + crc_t[30] + crc_t[31] + data_in[0] + data_in[1] + data_in[2] + data_in[4] + data_in[5] + data_in[6] + data_in[9] + data_in[12] + data_in[13] + data_in[15] + data_in[17] + data_in[18] + data_in[21] + data_in[24] + data_in[27] + data_in[30] + data_in[31];
      crc_out_tmp[13] = crc_t[1] + crc_t[2] + crc_t[3] + crc_t[5] + crc_t[6] + crc_t[7] + crc_t[10] + crc_t[13] + crc_t[14] + crc_t[16] + crc_t[18] + crc_t[19] + crc_t[22] + crc_t[25] + crc_t[28] + crc_t[31] + data_in[1] + data_in[2] + data_in[3] + data_in[5] + data_in[6] + data_in[7] + data_in[10] + data_in[13] + data_in[14] + data_in[16] + data_in[18] + data_in[19] + data_in[22] + data_in[25] + data_in[28] + data_in[31];
      crc_out_tmp[14] = crc_t[2] + crc_t[3] + crc_t[4] + crc_t[6] + crc_t[7] + crc_t[8] + crc_t[11] + crc_t[14] + crc_t[15] + crc_t[17] + crc_t[19] + crc_t[20] + crc_t[23] + crc_t[26] + crc_t[29] + data_in[2] + data_in[3] + data_in[4] + data_in[6] + data_in[7] + data_in[8] + data_in[11] + data_in[14] + data_in[15] + data_in[17] + data_in[19] + data_in[20] + data_in[23] + data_in[26] + data_in[29];
      crc_out_tmp[15] = crc_t[3] + crc_t[4] + crc_t[5] + crc_t[7] + crc_t[8] + crc_t[9] + crc_t[12] + crc_t[15] + crc_t[16] + crc_t[18] + crc_t[20] + crc_t[21] + crc_t[24] + crc_t[27] + crc_t[30] + data_in[3] + data_in[4] + data_in[5] + data_in[7] + data_in[8] + data_in[9] + data_in[12] + data_in[15] + data_in[16] + data_in[18] + data_in[20] + data_in[21] + data_in[24] + data_in[27] + data_in[30];
      crc_out_tmp[16] = crc_t[0] + crc_t[4] + crc_t[5] + crc_t[8] + crc_t[12] + crc_t[13] + crc_t[17] + crc_t[19] + crc_t[21] + crc_t[22] + crc_t[24] + crc_t[26] + crc_t[29] + crc_t[30] + data_in[0] + data_in[4] + data_in[5] + data_in[8] + data_in[12] + data_in[13] + data_in[17] + data_in[19] + data_in[21] + data_in[22] + data_in[24] + data_in[26] + data_in[29] + data_in[30];
      crc_out_tmp[17] = crc_t[1] + crc_t[5] + crc_t[6] + crc_t[9] + crc_t[13] + crc_t[14] + crc_t[18] + crc_t[20] + crc_t[22] + crc_t[23] + crc_t[25] + crc_t[27] + crc_t[30] + crc_t[31] + data_in[1] + data_in[5] + data_in[6] + data_in[9] + data_in[13] + data_in[14] + data_in[18] + data_in[20] + data_in[22] + data_in[23] + data_in[25] + data_in[27] + data_in[30] + data_in[31];
      crc_out_tmp[18] = crc_t[2] + crc_t[6] + crc_t[7] + crc_t[10] + crc_t[14] + crc_t[15] + crc_t[19] + crc_t[21] + crc_t[23] + crc_t[24] + crc_t[26] + crc_t[28] + crc_t[31] + data_in[2] + data_in[6] + data_in[7] + data_in[10] + data_in[14] + data_in[15] + data_in[19] + data_in[21] + data_in[23] + data_in[24] + data_in[26] + data_in[28] + data_in[31];
      crc_out_tmp[19] = crc_t[3] + crc_t[7] + crc_t[8] + crc_t[11] + crc_t[15] + crc_t[16] + crc_t[20] + crc_t[22] + crc_t[24] + crc_t[25] + crc_t[27] + crc_t[29] + data_in[3] + data_in[7] + data_in[8] + data_in[11] + data_in[15] + data_in[16] + data_in[20] + data_in[22] + data_in[24] + data_in[25] + data_in[27] + data_in[29];
      crc_out_tmp[20] = crc_t[4] + crc_t[8] + crc_t[9] + crc_t[12] + crc_t[16] + crc_t[17] + crc_t[21] + crc_t[23] + crc_t[25] + crc_t[26] + crc_t[28] + crc_t[30] + data_in[4] + data_in[8] + data_in[9] + data_in[12] + data_in[16] + data_in[17] + data_in[21] + data_in[23] + data_in[25] + data_in[26] + data_in[28] + data_in[30];
      crc_out_tmp[21] = crc_t[5] + crc_t[9] + crc_t[10] + crc_t[13] + crc_t[17] + crc_t[18] + crc_t[22] + crc_t[24] + crc_t[26] + crc_t[27] + crc_t[29] + crc_t[31] + data_in[5] + data_in[9] + data_in[10] + data_in[13] + data_in[17] + data_in[18] + data_in[22] + data_in[24] + data_in[26] + data_in[27] + data_in[29] + data_in[31];
      crc_out_tmp[22] = crc_t[0] + crc_t[9] + crc_t[11] + crc_t[12] + crc_t[14] + crc_t[16] + crc_t[18] + crc_t[19] + crc_t[23] + crc_t[24] + crc_t[26] + crc_t[27] + crc_t[29] + crc_t[31] + data_in[0] + data_in[9] + data_in[11] + data_in[12] + data_in[14] + data_in[16] + data_in[18] + data_in[19] + data_in[23] + data_in[24] + data_in[26] + data_in[27] + data_in[29] + data_in[31];
      crc_out_tmp[23] = crc_t[0] + crc_t[1] + crc_t[6] + crc_t[9] + crc_t[13] + crc_t[15] + crc_t[16] + crc_t[17] + crc_t[19] + crc_t[20] + crc_t[26] + crc_t[27] + crc_t[29] + crc_t[31] + data_in[0] + data_in[1] + data_in[6] + data_in[9] + data_in[13] + data_in[15] + data_in[16] + data_in[17] + data_in[19] + data_in[20] + data_in[26] + data_in[27] + data_in[29] + data_in[31];
      crc_out_tmp[24] = crc_t[1] + crc_t[2] + crc_t[7] + crc_t[10] + crc_t[14] + crc_t[16] + crc_t[17] + crc_t[18] + crc_t[20] + crc_t[21] + crc_t[27] + crc_t[28] + crc_t[30] + data_in[1] + data_in[2] + data_in[7] + data_in[10] + data_in[14] + data_in[16] + data_in[17] + data_in[18] + data_in[20] + data_in[21] + data_in[27] + data_in[28] + data_in[30];
      crc_out_tmp[25] = crc_t[2] + crc_t[3] + crc_t[8] + crc_t[11] + crc_t[15] + crc_t[17] + crc_t[18] + crc_t[19] + crc_t[21] + crc_t[22] + crc_t[28] + crc_t[29] + crc_t[31] + data_in[2] + data_in[3] + data_in[8] + data_in[11] + data_in[15] + data_in[17] + data_in[18] + data_in[19] + data_in[21] + data_in[22] + data_in[28] + data_in[29] + data_in[31];
      crc_out_tmp[26] = crc_t[0] + crc_t[3] + crc_t[4] + crc_t[6] + crc_t[10] + crc_t[18] + crc_t[19] + crc_t[20] + crc_t[22] + crc_t[23] + crc_t[24] + crc_t[25] + crc_t[26] + crc_t[28] + crc_t[31] + data_in[0] + data_in[3] + data_in[4] + data_in[6] + data_in[10] + data_in[18] + data_in[19] + data_in[20] + data_in[22] + data_in[23] + data_in[24] + data_in[25] + data_in[26] + data_in[28] + data_in[31];
      crc_out_tmp[27] = crc_t[1] + crc_t[4] + crc_t[5] + crc_t[7] + crc_t[11] + crc_t[19] + crc_t[20] + crc_t[21] + crc_t[23] + crc_t[24] + crc_t[25] + crc_t[26] + crc_t[27] + crc_t[29] + data_in[1] + data_in[4] + data_in[5] + data_in[7] + data_in[11] + data_in[19] + data_in[20] + data_in[21] + data_in[23] + data_in[24] + data_in[25] + data_in[26] + data_in[27] + data_in[29];
      crc_out_tmp[28] = crc_t[2] + crc_t[5] + crc_t[6] + crc_t[8] + crc_t[12] + crc_t[20] + crc_t[21] + crc_t[22] + crc_t[24] + crc_t[25] + crc_t[26] + crc_t[27] + crc_t[28] + crc_t[30] + data_in[2] + data_in[5] + data_in[6] + data_in[8] + data_in[12] + data_in[20] + data_in[21] + data_in[22] + data_in[24] + data_in[25] + data_in[26] + data_in[27] + data_in[28] + data_in[30];
      crc_out_tmp[29] = crc_t[3] + crc_t[6] + crc_t[7] + crc_t[9] + crc_t[13] + crc_t[21] + crc_t[22] + crc_t[23] + crc_t[25] + crc_t[26] + crc_t[27] + crc_t[28] + crc_t[29] + crc_t[31] + data_in[3] + data_in[6] + data_in[7] + data_in[9] + data_in[13] + data_in[21] + data_in[22] + data_in[23] + data_in[25] + data_in[26] + data_in[27] + data_in[28] + data_in[29] + data_in[31];
      crc_out_tmp[30] = crc_t[4] + crc_t[7] + crc_t[8] + crc_t[10] + crc_t[14] + crc_t[22] + crc_t[23] + crc_t[24] + crc_t[26] + crc_t[27] + crc_t[28] + crc_t[29] + crc_t[30] + data_in[4] + data_in[7] + data_in[8] + data_in[10] + data_in[14] + data_in[22] + data_in[23] + data_in[24] + data_in[26] + data_in[27] + data_in[28] + data_in[29] + data_in[30];
      crc_out_tmp[31] = crc_t[5] + crc_t[8] + crc_t[9] + crc_t[11] + crc_t[15] + crc_t[23] + crc_t[24] + crc_t[25] + crc_t[27] + crc_t[28] + crc_t[29] + crc_t[30] + crc_t[31] + data_in[5] + data_in[8] + data_in[9] + data_in[11] + data_in[15] + data_in[23] + data_in[24] + data_in[25] + data_in[27] + data_in[28] + data_in[29] + data_in[30] + data_in[31];
      fun_crc32_d32 = crc_out_tmp;
    end
  endfunction


  function [15:0] fun_crc16_ccitt_d1;
    input [0:0] data_in;
    input [15:0] crc_t;
    reg [15:0] crc_out_tmp;
    begin
      crc_out_tmp[0] = crc_t[15] + data_in[0];
      crc_out_tmp[1] = crc_t[0];
      crc_out_tmp[2] = crc_t[1];
      crc_out_tmp[3] = crc_t[2];
      crc_out_tmp[4] = crc_t[3];
      crc_out_tmp[5] = crc_t[4] + crc_t[15] + data_in[0];
      crc_out_tmp[6] = crc_t[5];
      crc_out_tmp[7] = crc_t[6];
      crc_out_tmp[8] = crc_t[7];
      crc_out_tmp[9] = crc_t[8];
      crc_out_tmp[10] = crc_t[9];
      crc_out_tmp[11] = crc_t[10];
      crc_out_tmp[12] = crc_t[11] + crc_t[15] + data_in[0];
      crc_out_tmp[13] = crc_t[12];
      crc_out_tmp[14] = crc_t[13];
      crc_out_tmp[15] = crc_t[14];
      fun_crc16_ccitt_d1 = crc_out_tmp;
    end
  endfunction

  function [15:0] fun_crc16_ccitt_d8;
    input [7:0] data_in;
    input [15:0] crc_t;
    reg [15:0] crc_out_tmp;
    begin
      crc_out_tmp[0] = crc_t[8] + crc_t[12] + data_in[0] + data_in[4];
      crc_out_tmp[1] = crc_t[9] + crc_t[13] + data_in[1] + data_in[5];
      crc_out_tmp[2] = crc_t[10] + crc_t[14] + data_in[2] + data_in[6];
      crc_out_tmp[3] = crc_t[11] + crc_t[15] + data_in[3] + data_in[7];
      crc_out_tmp[4] = crc_t[12] + data_in[4];
      crc_out_tmp[5] = crc_t[8] + crc_t[12] + crc_t[13] + data_in[0] + data_in[4] + data_in[5];
      crc_out_tmp[6] = crc_t[9] + crc_t[13] + crc_t[14] + data_in[1] + data_in[5] + data_in[6];
      crc_out_tmp[7] = crc_t[10] + crc_t[14] + crc_t[15] + data_in[2] + data_in[6] + data_in[7];
      crc_out_tmp[8] = crc_t[0] + crc_t[11] + crc_t[15] + data_in[3] + data_in[7];
      crc_out_tmp[9] = crc_t[1] + crc_t[12] + data_in[4];
      crc_out_tmp[10] = crc_t[2] + crc_t[13] + data_in[5];
      crc_out_tmp[11] = crc_t[3] + crc_t[14] + data_in[6];
      crc_out_tmp[12] = crc_t[4] + crc_t[8] + crc_t[12] + crc_t[15] + data_in[0] + data_in[4] + data_in[7];
      crc_out_tmp[13] = crc_t[5] + crc_t[9] + crc_t[13] + data_in[1] + data_in[5];
      crc_out_tmp[14] = crc_t[6] + crc_t[10] + crc_t[14] + data_in[2] + data_in[6];
      crc_out_tmp[15] = crc_t[7] + crc_t[11] + crc_t[15] + data_in[3] + data_in[7];
      fun_crc16_ccitt_d8 = crc_out_tmp;
    end
  endfunction

  function [15:0] fun_crc16_ccitt_d16;
    input [15:0] data_in;
    input [15:0] crc_t;
    reg [15:0] crc_out_tmp;
    begin
      crc_out_tmp[0]  = crc_t[0] + crc_t[4] + crc_t[8] + crc_t[11] + crc_t[12] + data_in[0] + data_in[4] + data_in[8] + data_in[11] + data_in[12];
      crc_out_tmp[1]  = crc_t[1] + crc_t[5] + crc_t[9] + crc_t[12] + crc_t[13] + data_in[1] + data_in[5] + data_in[9] + data_in[12] + data_in[13];
      crc_out_tmp[2]  = crc_t[2] + crc_t[6] + crc_t[10] + crc_t[13] + crc_t[14] + data_in[2] + data_in[6] + data_in[10] + data_in[13] + data_in[14];
      crc_out_tmp[3]  = crc_t[3] + crc_t[7] + crc_t[11] + crc_t[14] + crc_t[15] + data_in[3] + data_in[7] + data_in[11] + data_in[14] + data_in[15];
      crc_out_tmp[4]  = crc_t[4] + crc_t[8] + crc_t[12] + crc_t[15] + data_in[4] + data_in[8] + data_in[12] + data_in[15];
      crc_out_tmp[5]  = crc_t[0] + crc_t[4] + crc_t[5] + crc_t[8] + crc_t[9] + crc_t[11] + crc_t[12] + crc_t[13] + data_in[0] + data_in[4] + data_in[5] + data_in[8] + data_in[9] + data_in[11] + data_in[12] + data_in[13];
      crc_out_tmp[6]  = crc_t[1] + crc_t[5] + crc_t[6] + crc_t[9] + crc_t[10] + crc_t[12] + crc_t[13] + crc_t[14] + data_in[1] + data_in[5] + data_in[6] + data_in[9] + data_in[10] + data_in[12] + data_in[13] + data_in[14];
      crc_out_tmp[7]  = crc_t[2] + crc_t[6] + crc_t[7] + crc_t[10] + crc_t[11] + crc_t[13] + crc_t[14] + crc_t[15] + data_in[2] + data_in[6] + data_in[7] + data_in[10] + data_in[11] + data_in[13] + data_in[14] + data_in[15];
      crc_out_tmp[8]  = crc_t[3] + crc_t[7] + crc_t[8] + crc_t[11] + crc_t[12] + crc_t[14] + crc_t[15] + data_in[3] + data_in[7] + data_in[8] + data_in[11] + data_in[12] + data_in[14] + data_in[15];
      crc_out_tmp[9]  = crc_t[4] + crc_t[8] + crc_t[9] + crc_t[12] + crc_t[13] + crc_t[15] + data_in[4] + data_in[8] + data_in[9] + data_in[12] + data_in[13] + data_in[15];
      crc_out_tmp[10] = crc_t[5] + crc_t[9] + crc_t[10] + crc_t[13] + crc_t[14] + data_in[5] + data_in[9] + data_in[10] + data_in[13] + data_in[14];
      crc_out_tmp[11] = crc_t[6] + crc_t[10] + crc_t[11] + crc_t[14] + crc_t[15] + data_in[6] + data_in[10] + data_in[11] + data_in[14] + data_in[15];
      crc_out_tmp[12] = crc_t[0] + crc_t[4] + crc_t[7] + crc_t[8] + crc_t[15] + data_in[0] + data_in[4] + data_in[7] + data_in[8] + data_in[15];
      crc_out_tmp[13] = crc_t[1] + crc_t[5] + crc_t[8] + crc_t[9] + data_in[1] + data_in[5] + data_in[8] + data_in[9];
      crc_out_tmp[14] = crc_t[2] + crc_t[6] + crc_t[9] + crc_t[10] + data_in[2] + data_in[6] + data_in[9] + data_in[10];
      crc_out_tmp[15] = crc_t[3] + crc_t[7] + crc_t[10] + crc_t[11] + data_in[3] + data_in[7] + data_in[10] + data_in[11];
      fun_crc16_ccitt_d16 = crc_out_tmp;
    end
  endfunction

  function [15:0] fun_crc16_ccitt_d24;
    input [23:0] data_in;
    input [15:0] crc_t;
    reg [15:0] crc_out_tmp;
    begin
      crc_out_tmp[0]  = crc_t[0] + crc_t[3] + crc_t[4] + crc_t[11] + crc_t[12] + crc_t[14] + data_in[0] + data_in[4] + data_in[8] + data_in[11] + data_in[12] + data_in[19] + data_in[20] + data_in[22];
      crc_out_tmp[1]  = crc_t[1] + crc_t[4] + crc_t[5] + crc_t[12] + crc_t[13] + crc_t[15] + data_in[1] + data_in[5] + data_in[9] + data_in[12] + data_in[13] + data_in[20] + data_in[21] + data_in[23];
      crc_out_tmp[2]  = crc_t[2] + crc_t[5] + crc_t[6] + crc_t[13] + crc_t[14] + data_in[2] + data_in[6] + data_in[10] + data_in[13] + data_in[14] + data_in[21] + data_in[22];
      crc_out_tmp[3]  = crc_t[3] + crc_t[6] + crc_t[7] + crc_t[14] + crc_t[15] + data_in[3] + data_in[7] + data_in[11] + data_in[14] + data_in[15] + data_in[22] + data_in[23];
      crc_out_tmp[4]  = crc_t[0] + crc_t[4] + crc_t[7] + crc_t[8] + crc_t[15] + data_in[4] + data_in[8] + data_in[12] + data_in[15] + data_in[16] + data_in[23];
      crc_out_tmp[5]  = crc_t[0] + crc_t[1] + crc_t[3] + crc_t[4] + crc_t[5] + crc_t[8] + crc_t[9] + crc_t[11] + crc_t[12] + crc_t[14] + data_in[0] + data_in[4] + data_in[5] + data_in[8] + data_in[9] + data_in[11] + data_in[12] + data_in[13] + data_in[16] + data_in[17] + data_in[19] + data_in[20] + data_in[22];
      crc_out_tmp[6]  = crc_t[1] + crc_t[2] + crc_t[4] + crc_t[5] + crc_t[6] + crc_t[9] + crc_t[10] + crc_t[12] + crc_t[13] + crc_t[15] + data_in[1] + data_in[5] + data_in[6] + data_in[9] + data_in[10] + data_in[12] + data_in[13] + data_in[14] + data_in[17] + data_in[18] + data_in[20] + data_in[21] + data_in[23];
      crc_out_tmp[7]  = crc_t[2] + crc_t[3] + crc_t[5] + crc_t[6] + crc_t[7] + crc_t[10] + crc_t[11] + crc_t[13] + crc_t[14] + data_in[2] + data_in[6] + data_in[7] + data_in[10] + data_in[11] + data_in[13] + data_in[14] + data_in[15] + data_in[18] + data_in[19] + data_in[21] + data_in[22];
      crc_out_tmp[8]  = crc_t[0] + crc_t[3] + crc_t[4] + crc_t[6] + crc_t[7] + crc_t[8] + crc_t[11] + crc_t[12] + crc_t[14] + crc_t[15] + data_in[3] + data_in[7] + data_in[8] + data_in[11] + data_in[12] + data_in[14] + data_in[15] + data_in[16] + data_in[19] + data_in[20] + data_in[22] + data_in[23];
      crc_out_tmp[9]  = crc_t[0] + crc_t[1] + crc_t[4] + crc_t[5] + crc_t[7] + crc_t[8] + crc_t[9] + crc_t[12] + crc_t[13] + crc_t[15] + data_in[4] + data_in[8] + data_in[9] + data_in[12] + data_in[13] + data_in[15] + data_in[16] + data_in[17] + data_in[20] + data_in[21] + data_in[23];
      crc_out_tmp[10] = crc_t[1] + crc_t[2] + crc_t[5] + crc_t[6] + crc_t[8] + crc_t[9] + crc_t[10] + crc_t[13] + crc_t[14] + data_in[5] + data_in[9] + data_in[10] + data_in[13] + data_in[14] + data_in[16] + data_in[17] + data_in[18] + data_in[21] + data_in[22];
      crc_out_tmp[11] = crc_t[2] + crc_t[3] + crc_t[6] + crc_t[7] + crc_t[9] + crc_t[10] + crc_t[11] + crc_t[14] + crc_t[15] + data_in[6] + data_in[10] + data_in[11] + data_in[14] + data_in[15] + data_in[17] + data_in[18] + data_in[19] + data_in[22] + data_in[23];
      crc_out_tmp[12] = crc_t[0] + crc_t[7] + crc_t[8] + crc_t[10] + crc_t[14] + crc_t[15] + data_in[0] + data_in[4] + data_in[7] + data_in[8] + data_in[15] + data_in[16] + data_in[18] + data_in[22] + data_in[23];
      crc_out_tmp[13] = crc_t[0] + crc_t[1] + crc_t[8] + crc_t[9] + crc_t[11] + crc_t[15] + data_in[1] + data_in[5] + data_in[8] + data_in[9] + data_in[16] + data_in[17] + data_in[19] + data_in[23];
      crc_out_tmp[14] = crc_t[1] + crc_t[2] + crc_t[9] + crc_t[10] + crc_t[12] + data_in[2] + data_in[6] + data_in[9] + data_in[10] + data_in[17] + data_in[18] + data_in[20];
      crc_out_tmp[15] = crc_t[2] + crc_t[3] + crc_t[10] + crc_t[11] + crc_t[13] + data_in[3] + data_in[7] + data_in[10] + data_in[11] + data_in[18] + data_in[19] + data_in[21];
      fun_crc16_ccitt_d24 = crc_out_tmp;
    end
  endfunction

  function [15:0] fun_crc16_ccitt_d32;
    input [31:0] data_in;
    input [15:0] crc_t;
    reg [15:0] crc_out_tmp;
    begin
      crc_out_tmp[0]  = crc_t[3] + crc_t[4] + crc_t[6] + crc_t[10] + crc_t[11] + crc_t[12] + data_in[0] + data_in[4] + data_in[8] + data_in[11] + data_in[12] + data_in[19] + data_in[20] + data_in[22] + data_in[26] + data_in[27] + data_in[28];
      crc_out_tmp[1]  = crc_t[4] + crc_t[5] + crc_t[7] + crc_t[11] + crc_t[12] + crc_t[13] + data_in[1] + data_in[5] + data_in[9] + data_in[12] + data_in[13] + data_in[20] + data_in[21] + data_in[23] + data_in[27] + data_in[28] + data_in[29];
      crc_out_tmp[2]  = crc_t[5] + crc_t[6] + crc_t[8] + crc_t[12] + crc_t[13] + crc_t[14] + data_in[2] + data_in[6] + data_in[10] + data_in[13] + data_in[14] + data_in[21] + data_in[22] + data_in[24] + data_in[28] + data_in[29] + data_in[30];
      crc_out_tmp[3]  = crc_t[6] + crc_t[7] + crc_t[9] + crc_t[13] + crc_t[14] + crc_t[15] + data_in[3] + data_in[7] + data_in[11] + data_in[14] + data_in[15] + data_in[22] + data_in[23] + data_in[25] + data_in[29] + data_in[30] + data_in[31];
      crc_out_tmp[4]  = crc_t[0] + crc_t[7] + crc_t[8] + crc_t[10] + crc_t[14] + crc_t[15] + data_in[4] + data_in[8] + data_in[12] + data_in[15] + data_in[16] + data_in[23] + data_in[24] + data_in[26] + data_in[30] + data_in[31];
      crc_out_tmp[5]  = crc_t[0] + crc_t[1] + crc_t[3] + crc_t[4] + crc_t[6] + crc_t[8] + crc_t[9] + crc_t[10] + crc_t[12] + crc_t[15] + data_in[0] + data_in[4] + data_in[5] + data_in[8] + data_in[9] + data_in[11] + data_in[12] + data_in[13] + data_in[16] + data_in[17] + data_in[19] + data_in[20] + data_in[22] + data_in[24] + data_in[25] + data_in[26] + data_in[28] + data_in[31];
      crc_out_tmp[6]  = crc_t[1] + crc_t[2] + crc_t[4] + crc_t[5] + crc_t[7] + crc_t[9] + crc_t[10] + crc_t[11] + crc_t[13] + data_in[1] + data_in[5] + data_in[6] + data_in[9] + data_in[10] + data_in[12] + data_in[13] + data_in[14] + data_in[17] + data_in[18] + data_in[20] + data_in[21] + data_in[23] + data_in[25] + data_in[26] + data_in[27] + data_in[29];
      crc_out_tmp[7]  = crc_t[2] + crc_t[3] + crc_t[5] + crc_t[6] + crc_t[8] + crc_t[10] + crc_t[11] + crc_t[12] + crc_t[14] + data_in[2] + data_in[6] + data_in[7] + data_in[10] + data_in[11] + data_in[13] + data_in[14] + data_in[15] + data_in[18] + data_in[19] + data_in[21] + data_in[22] + data_in[24] + data_in[26] + data_in[27] + data_in[28] + data_in[30];
      crc_out_tmp[8]  = crc_t[0] + crc_t[3] + crc_t[4] + crc_t[6] + crc_t[7] + crc_t[9] + crc_t[11] + crc_t[12] + crc_t[13] + crc_t[15] + data_in[3] + data_in[7] + data_in[8] + data_in[11] + data_in[12] + data_in[14] + data_in[15] + data_in[16] + data_in[19] + data_in[20] + data_in[22] + data_in[23] + data_in[25] + data_in[27] + data_in[28] + data_in[29] + data_in[31];
      crc_out_tmp[9]  = crc_t[0] + crc_t[1] + crc_t[4] + crc_t[5] + crc_t[7] + crc_t[8] + crc_t[10] + crc_t[12] + crc_t[13] + crc_t[14] + data_in[4] + data_in[8] + data_in[9] + data_in[12] + data_in[13] + data_in[15] + data_in[16] + data_in[17] + data_in[20] + data_in[21] + data_in[23] + data_in[24] + data_in[26] + data_in[28] + data_in[29] + data_in[30];
      crc_out_tmp[10] = crc_t[0] + crc_t[1] + crc_t[2] + crc_t[5] + crc_t[6] + crc_t[8] + crc_t[9] + crc_t[11] + crc_t[13] + crc_t[14] + crc_t[15] + data_in[5] + data_in[9] + data_in[10] + data_in[13] + data_in[14] + data_in[16] + data_in[17] + data_in[18] + data_in[21] + data_in[22] + data_in[24] + data_in[25] + data_in[27] + data_in[29] + data_in[30] + data_in[31];
      crc_out_tmp[11] = crc_t[1] + crc_t[2] + crc_t[3] + crc_t[6] + crc_t[7] + crc_t[9] + crc_t[10] + crc_t[12] + crc_t[14] + crc_t[15] + data_in[6] + data_in[10] + data_in[11] + data_in[14] + data_in[15] + data_in[17] + data_in[18] + data_in[19] + data_in[22] + data_in[23] + data_in[25] + data_in[26] + data_in[28] + data_in[30] + data_in[31];
      crc_out_tmp[12] = crc_t[0] + crc_t[2] + crc_t[6] + crc_t[7] + crc_t[8] + crc_t[12] + crc_t[13] + crc_t[15] + data_in[0] + data_in[4] + data_in[7] + data_in[8] + data_in[15] + data_in[16] + data_in[18] + data_in[22] + data_in[23] + data_in[24] + data_in[28] + data_in[29] + data_in[31];
      crc_out_tmp[13] = crc_t[0] + crc_t[1] + crc_t[3] + crc_t[7] + crc_t[8] + crc_t[9] + crc_t[13] + crc_t[14] + data_in[1] + data_in[5] + data_in[8] + data_in[9] + data_in[16] + data_in[17] + data_in[19] + data_in[23] + data_in[24] + data_in[25] + data_in[29] + data_in[30];
      crc_out_tmp[14] = crc_t[1] + crc_t[2] + crc_t[4] + crc_t[8] + crc_t[9] + crc_t[10] + crc_t[14] + crc_t[15] + data_in[2] + data_in[6] + data_in[9] + data_in[10] + data_in[17] + data_in[18] + data_in[20] + data_in[24] + data_in[25] + data_in[26] + data_in[30] + data_in[31];
      crc_out_tmp[15] = crc_t[2] + crc_t[3] + crc_t[5] + crc_t[9] + crc_t[10] + crc_t[11] + crc_t[15] + data_in[3] + data_in[7] + data_in[10] + data_in[11] + data_in[18] + data_in[19] + data_in[21] + data_in[25] + data_in[26] + data_in[27] + data_in[31];
      fun_crc16_ccitt_d32 = crc_out_tmp;
    end
  endfunction

  function [15:0] fun_crc16_ibm_d1;
    input [0:0] data_in;
    input [15:0] crc_t;
    reg [15:0] crc_out_tmp;
    begin
      crc_out_tmp[0]   = crc_t[15] + data_in[0];
      crc_out_tmp[1]   = crc_t[0];
      crc_out_tmp[2]   = crc_t[1] + crc_t[15] + data_in[0];
      crc_out_tmp[3]   = crc_t[2];
      crc_out_tmp[4]   = crc_t[3];
      crc_out_tmp[5]   = crc_t[4];
      crc_out_tmp[6]   = crc_t[5];
      crc_out_tmp[7]   = crc_t[6];
      crc_out_tmp[8]   = crc_t[7];
      crc_out_tmp[9]   = crc_t[8];
      crc_out_tmp[10]  = crc_t[9];
      crc_out_tmp[11]  = crc_t[10];
      crc_out_tmp[12]  = crc_t[11];
      crc_out_tmp[13]  = crc_t[12];
      crc_out_tmp[14]  = crc_t[13];
      crc_out_tmp[15]  = crc_t[14] + crc_t[15] + data_in[0];
      fun_crc16_ibm_d1 = crc_out_tmp;
    end
  endfunction

  function [15:0] fun_crc16_ibm_d8;
    input [7:0] data_in;
    input [15:0] crc_t;
    reg [15:0] crc_out_tmp;
    begin
      crc_out_tmp[0]  = crc_t[8] + crc_t[9] + crc_t[10] + crc_t[11] + crc_t[12] + crc_t[13] + crc_t[14] + crc_t[15] + data_in[0] + data_in[1] + data_in[2] + data_in[3] + data_in[4] + data_in[5] + data_in[6] + data_in[7];
      crc_out_tmp[1]  = crc_t[9] + crc_t[10] + crc_t[11] + crc_t[12] + crc_t[13] + crc_t[14] + crc_t[15] + data_in[1] + data_in[2] + data_in[3] + data_in[4] + data_in[5] + data_in[6] + data_in[7];
      crc_out_tmp[2] = crc_t[8] + crc_t[9] + data_in[0] + data_in[1];
      crc_out_tmp[3] = crc_t[9] + crc_t[10] + data_in[1] + data_in[2];
      crc_out_tmp[4] = crc_t[10] + crc_t[11] + data_in[2] + data_in[3];
      crc_out_tmp[5] = crc_t[11] + crc_t[12] + data_in[3] + data_in[4];
      crc_out_tmp[6] = crc_t[12] + crc_t[13] + data_in[4] + data_in[5];
      crc_out_tmp[7] = crc_t[13] + crc_t[14] + data_in[5] + data_in[6];
      crc_out_tmp[8] = crc_t[0] + crc_t[14] + crc_t[15] + data_in[6] + data_in[7];
      crc_out_tmp[9] = crc_t[1] + crc_t[15] + data_in[7];
      crc_out_tmp[10] = crc_t[2];
      crc_out_tmp[11] = crc_t[3];
      crc_out_tmp[12] = crc_t[4];
      crc_out_tmp[13] = crc_t[5];
      crc_out_tmp[14] = crc_t[6];
      crc_out_tmp[15] = crc_t[7] + crc_t[8] + crc_t[9] + crc_t[10] + crc_t[11] + crc_t[12] + crc_t[13] + crc_t[14] + crc_t[15] + data_in[0] + data_in[1] + data_in[2] + data_in[3] + data_in[4] + data_in[5] + data_in[6] + data_in[7];
      fun_crc16_ibm_d8 = crc_out_tmp;
    end
  endfunction

  function [15:0] fun_crc16_ibm_d16;
    input [15:0] data_in;
    input [15:0] crc_t;
    reg [15:0] crc_out_tmp;
    begin
      crc_out_tmp[0]  = crc_t[0] + crc_t[1] + crc_t[2] + crc_t[3] + crc_t[4] + crc_t[5] + crc_t[6] + crc_t[7] + crc_t[8] + crc_t[9] + crc_t[10] + crc_t[11] + crc_t[12] + crc_t[13] + crc_t[15] + data_in[0] + data_in[1] + data_in[2] + data_in[3] + data_in[4] + data_in[5] + data_in[6] + data_in[7] + data_in[8] + data_in[9] + data_in[10] + data_in[11] + data_in[12] + data_in[13] + data_in[15];
      crc_out_tmp[1]  = crc_t[1] + crc_t[2] + crc_t[3] + crc_t[4] + crc_t[5] + crc_t[6] + crc_t[7] + crc_t[8] + crc_t[9] + crc_t[10] + crc_t[11] + crc_t[12] + crc_t[13] + crc_t[14] + data_in[1] + data_in[2] + data_in[3] + data_in[4] + data_in[5] + data_in[6] + data_in[7] + data_in[8] + data_in[9] + data_in[10] + data_in[11] + data_in[12] + data_in[13] + data_in[14];
      crc_out_tmp[2] = crc_t[0] + crc_t[1] + crc_t[14] + data_in[0] + data_in[1] + data_in[14];
      crc_out_tmp[3] = crc_t[1] + crc_t[2] + crc_t[15] + data_in[1] + data_in[2] + data_in[15];
      crc_out_tmp[4] = crc_t[2] + crc_t[3] + data_in[2] + data_in[3];
      crc_out_tmp[5] = crc_t[3] + crc_t[4] + data_in[3] + data_in[4];
      crc_out_tmp[6] = crc_t[4] + crc_t[5] + data_in[4] + data_in[5];
      crc_out_tmp[7] = crc_t[5] + crc_t[6] + data_in[5] + data_in[6];
      crc_out_tmp[8] = crc_t[6] + crc_t[7] + data_in[6] + data_in[7];
      crc_out_tmp[9] = crc_t[7] + crc_t[8] + data_in[7] + data_in[8];
      crc_out_tmp[10] = crc_t[8] + crc_t[9] + data_in[8] + data_in[9];
      crc_out_tmp[11] = crc_t[9] + crc_t[10] + data_in[9] + data_in[10];
      crc_out_tmp[12] = crc_t[10] + crc_t[11] + data_in[10] + data_in[11];
      crc_out_tmp[13] = crc_t[11] + crc_t[12] + data_in[11] + data_in[12];
      crc_out_tmp[14] = crc_t[12] + crc_t[13] + data_in[12] + data_in[13];
      crc_out_tmp[15] = crc_t[0] + crc_t[1] + crc_t[2] + crc_t[3] + crc_t[4] + crc_t[5] + crc_t[6] + crc_t[7] + crc_t[8] + crc_t[9] + crc_t[10] + crc_t[11] + crc_t[12] + crc_t[14] + crc_t[15] + data_in[0] + data_in[1] + data_in[2] + data_in[3] + data_in[4] + data_in[5] + data_in[6] + data_in[7] + data_in[8] + data_in[9] + data_in[10] + data_in[11] + data_in[12] + data_in[14] + data_in[15];
      fun_crc16_ibm_d16 = crc_out_tmp;
    end
  endfunction

  function [15:0] fun_crc16_ibm_d24;
    input [23:0] data_in;
    input [15:0] crc_t;
    reg [15:0] crc_out_tmp;
    begin
      crc_out_tmp[0]  = crc_t[0] + crc_t[1] + crc_t[2] + crc_t[3] + crc_t[4] + crc_t[5] + crc_t[7] + crc_t[8] + crc_t[9] + crc_t[10] + crc_t[11] + crc_t[12] + crc_t[13] + crc_t[14] + crc_t[15] + data_in[0] + data_in[1] + data_in[2] + data_in[3] + data_in[4] + data_in[5] + data_in[6] + data_in[7] + data_in[8] + data_in[9] + data_in[10] + data_in[11] + data_in[12] + data_in[13] + data_in[15] + data_in[16] + data_in[17] + data_in[18] + data_in[19] + data_in[20] + data_in[21] + data_in[22] + data_in[23];
      crc_out_tmp[1]  = crc_t[0] + crc_t[1] + crc_t[2] + crc_t[3] + crc_t[4] + crc_t[5] + crc_t[6] + crc_t[8] + crc_t[9] + crc_t[10] + crc_t[11] + crc_t[12] + crc_t[13] + crc_t[14] + crc_t[15] + data_in[1] + data_in[2] + data_in[3] + data_in[4] + data_in[5] + data_in[6] + data_in[7] + data_in[8] + data_in[9] + data_in[10] + data_in[11] + data_in[12] + data_in[13] + data_in[14] + data_in[16] + data_in[17] + data_in[18] + data_in[19] + data_in[20] + data_in[21] + data_in[22] + data_in[23];
      crc_out_tmp[2] = crc_t[6] + crc_t[8] + data_in[0] + data_in[1] + data_in[14] + data_in[16];
      crc_out_tmp[3] = crc_t[7] + crc_t[9] + data_in[1] + data_in[2] + data_in[15] + data_in[17];
      crc_out_tmp[4] = crc_t[8] + crc_t[10] + data_in[2] + data_in[3] + data_in[16] + data_in[18];
      crc_out_tmp[5] = crc_t[9] + crc_t[11] + data_in[3] + data_in[4] + data_in[17] + data_in[19];
      crc_out_tmp[6] = crc_t[10] + crc_t[12] + data_in[4] + data_in[5] + data_in[18] + data_in[20];
      crc_out_tmp[7] = crc_t[11] + crc_t[13] + data_in[5] + data_in[6] + data_in[19] + data_in[21];
      crc_out_tmp[8] = crc_t[12] + crc_t[14] + data_in[6] + data_in[7] + data_in[20] + data_in[22];
      crc_out_tmp[9]  = crc_t[0] + crc_t[13] + crc_t[15] + data_in[7] + data_in[8] + data_in[21] + data_in[23];
      crc_out_tmp[10] = crc_t[0] + crc_t[1] + crc_t[14] + data_in[8] + data_in[9] + data_in[22];
      crc_out_tmp[11] = crc_t[1] + crc_t[2] + crc_t[15] + data_in[9] + data_in[10] + data_in[23];
      crc_out_tmp[12] = crc_t[2] + crc_t[3] + data_in[10] + data_in[11];
      crc_out_tmp[13] = crc_t[3] + crc_t[4] + data_in[11] + data_in[12];
      crc_out_tmp[14] = crc_t[4] + crc_t[5] + data_in[12] + data_in[13];
      crc_out_tmp[15] = crc_t[0] + crc_t[1] + crc_t[2] + crc_t[3] + crc_t[4] + crc_t[6] + crc_t[7] + crc_t[8] + crc_t[9] + crc_t[10] + crc_t[11] + crc_t[12] + crc_t[13] + crc_t[14] + crc_t[15] + data_in[0] + data_in[1] + data_in[2] + data_in[3] + data_in[4] + data_in[5] + data_in[6] + data_in[7] + data_in[8] + data_in[9] + data_in[10] + data_in[11] + data_in[12] + data_in[14] + data_in[15] + data_in[16] + data_in[17] + data_in[18] + data_in[19] + data_in[20] + data_in[21] + data_in[22] + data_in[23];
      fun_crc16_ibm_d24 = crc_out_tmp;
    end
  endfunction

  function [15:0] fun_crc16_ibm_d32;
    input [31:0] data_in;
    input [15:0] crc_t;
    reg [15:0] crc_out_tmp;
    begin
      crc_out_tmp[0]  = crc_t[0] + crc_t[1] + crc_t[2] + crc_t[3] + crc_t[4] + crc_t[5] + crc_t[6] + crc_t[7] + crc_t[8] + crc_t[9] + crc_t[10] + crc_t[11] + crc_t[14] + crc_t[15] + data_in[0] + data_in[1] + data_in[2] + data_in[3] + data_in[4] + data_in[5] + data_in[6] + data_in[7] + data_in[8] + data_in[9] + data_in[10] + data_in[11] + data_in[12] + data_in[13] + data_in[15] + data_in[16] + data_in[17] + data_in[18] + data_in[19] + data_in[20] + data_in[21] + data_in[22] + data_in[23] + data_in[24] + data_in[25] + data_in[26] + data_in[27] + data_in[30] + data_in[31];
      crc_out_tmp[1]  = crc_t[0] + crc_t[1] + crc_t[2] + crc_t[3] + crc_t[4] + crc_t[5] + crc_t[6] + crc_t[7] + crc_t[8] + crc_t[9] + crc_t[10] + crc_t[11] + crc_t[12] + crc_t[15] + data_in[1] + data_in[2] + data_in[3] + data_in[4] + data_in[5] + data_in[6] + data_in[7] + data_in[8] + data_in[9] + data_in[10] + data_in[11] + data_in[12] + data_in[13] + data_in[14] + data_in[16] + data_in[17] + data_in[18] + data_in[19] + data_in[20] + data_in[21] + data_in[22] + data_in[23] + data_in[24] + data_in[25] + data_in[26] + data_in[27] + data_in[28] + data_in[31];
      crc_out_tmp[2]  = crc_t[0] + crc_t[12] + crc_t[13] + crc_t[14] + crc_t[15] + data_in[0] + data_in[1] + data_in[14] + data_in[16] + data_in[28] + data_in[29] + data_in[30] + data_in[31];
      crc_out_tmp[3]  = crc_t[1] + crc_t[13] + crc_t[14] + crc_t[15] + data_in[1] + data_in[2] + data_in[15] + data_in[17] + data_in[29] + data_in[30] + data_in[31];
      crc_out_tmp[4]  = crc_t[0] + crc_t[2] + crc_t[14] + crc_t[15] + data_in[2] + data_in[3] + data_in[16] + data_in[18] + data_in[30] + data_in[31];
      crc_out_tmp[5]  = crc_t[1] + crc_t[3] + crc_t[15] + data_in[3] + data_in[4] + data_in[17] + data_in[19] + data_in[31];
      crc_out_tmp[6] = crc_t[2] + crc_t[4] + data_in[4] + data_in[5] + data_in[18] + data_in[20];
      crc_out_tmp[7] = crc_t[3] + crc_t[5] + data_in[5] + data_in[6] + data_in[19] + data_in[21];
      crc_out_tmp[8] = crc_t[4] + crc_t[6] + data_in[6] + data_in[7] + data_in[20] + data_in[22];
      crc_out_tmp[9] = crc_t[5] + crc_t[7] + data_in[7] + data_in[8] + data_in[21] + data_in[23];
      crc_out_tmp[10] = crc_t[6] + crc_t[8] + data_in[8] + data_in[9] + data_in[22] + data_in[24];
      crc_out_tmp[11] = crc_t[7] + crc_t[9] + data_in[9] + data_in[10] + data_in[23] + data_in[25];
      crc_out_tmp[12] = crc_t[8] + crc_t[10] + data_in[10] + data_in[11] + data_in[24] + data_in[26];
      crc_out_tmp[13] = crc_t[9] + crc_t[11] + data_in[11] + data_in[12] + data_in[25] + data_in[27];
      crc_out_tmp[14] = crc_t[10] + crc_t[12] + data_in[12] + data_in[13] + data_in[26] + data_in[28];
      crc_out_tmp[15] = crc_t[0] + crc_t[1] + crc_t[2] + crc_t[3] + crc_t[4] + crc_t[5] + crc_t[6] + crc_t[7] + crc_t[8] + crc_t[9] + crc_t[10] + crc_t[13] + crc_t[14] + crc_t[15] + data_in[0] + data_in[1] + data_in[2] + data_in[3] + data_in[4] + data_in[5] + data_in[6] + data_in[7] + data_in[8] + data_in[9] + data_in[10] + data_in[11] + data_in[12] + data_in[14] + data_in[15] + data_in[16] + data_in[17] + data_in[18] + data_in[19] + data_in[20] + data_in[21] + data_in[22] + data_in[23] + data_in[24] + data_in[25] + data_in[26] + data_in[29] + data_in[30] + data_in[31];
      fun_crc16_ibm_d32 = crc_out_tmp;
    end
  endfunction

  function [7:0] fun_crc8_d1;
    input [0:0] data_in;
    input [7:0] crc_t;
    reg [7:0] crc_out_tmp;
    begin
      crc_out_tmp[0] = crc_t[7] + data_in[0];
      crc_out_tmp[1] = crc_t[0] + crc_t[7] + data_in[0];
      crc_out_tmp[2] = crc_t[1] + crc_t[7] + data_in[0];
      crc_out_tmp[3] = crc_t[2];
      crc_out_tmp[4] = crc_t[3];
      crc_out_tmp[5] = crc_t[4];
      crc_out_tmp[6] = crc_t[5];
      crc_out_tmp[7] = crc_t[6];
      fun_crc8_d1 = crc_out_tmp;
    end
  endfunction

  function [7:0] fun_crc8_d8;
    input [7:0] data_in;
    input [7:0] crc_t;
    reg [7:0] crc_out_tmp;
    begin
      crc_out_tmp[0] = crc_t[0] + crc_t[6] + crc_t[7] + data_in[0] + data_in[6] + data_in[7];
      crc_out_tmp[1] = crc_t[0] + crc_t[1] + crc_t[6] + data_in[0] + data_in[1] + data_in[6];
      crc_out_tmp[2]  = crc_t[0] + crc_t[1] + crc_t[2] + crc_t[6] + data_in[0] + data_in[1] + data_in[2] + data_in[6];
      crc_out_tmp[3]  = crc_t[1] + crc_t[2] + crc_t[3] + crc_t[7] + data_in[1] + data_in[2] + data_in[3] + data_in[7];
      crc_out_tmp[4] = crc_t[2] + crc_t[3] + crc_t[4] + data_in[2] + data_in[3] + data_in[4];
      crc_out_tmp[5] = crc_t[3] + crc_t[4] + crc_t[5] + data_in[3] + data_in[4] + data_in[5];
      crc_out_tmp[6] = crc_t[4] + crc_t[5] + crc_t[6] + data_in[4] + data_in[5] + data_in[6];
      crc_out_tmp[7] = crc_t[5] + crc_t[6] + crc_t[7] + data_in[5] + data_in[6] + data_in[7];
      fun_crc8_d8 = crc_out_tmp;
    end
  endfunction

  function [7:0] fun_crc8_d16;
    input [15:0] data_in;
    input [7:0] crc_t;
    reg [7:0] crc_out_tmp;
    begin
      crc_out_tmp[0]  = crc_t[0] + crc_t[4] + crc_t[6] + data_in[0] + data_in[6] + data_in[7] + data_in[8] + data_in[12] + data_in[14];
      crc_out_tmp[1]  = crc_t[1] + crc_t[4] + crc_t[5] + crc_t[6] + crc_t[7] + data_in[0] + data_in[1] + data_in[6] + data_in[9] + data_in[12] + data_in[13] + data_in[14] + data_in[15];
      crc_out_tmp[2]  = crc_t[0] + crc_t[2] + crc_t[4] + crc_t[5] + crc_t[7] + data_in[0] + data_in[1] + data_in[2] + data_in[6] + data_in[8] + data_in[10] + data_in[12] + data_in[13] + data_in[15];
      crc_out_tmp[3]  = crc_t[1] + crc_t[3] + crc_t[5] + crc_t[6] + data_in[1] + data_in[2] + data_in[3] + data_in[7] + data_in[9] + data_in[11] + data_in[13] + data_in[14];
      crc_out_tmp[4]  = crc_t[0] + crc_t[2] + crc_t[4] + crc_t[6] + crc_t[7] + data_in[2] + data_in[3] + data_in[4] + data_in[8] + data_in[10] + data_in[12] + data_in[14] + data_in[15];
      crc_out_tmp[5]  = crc_t[1] + crc_t[3] + crc_t[5] + crc_t[7] + data_in[3] + data_in[4] + data_in[5] + data_in[9] + data_in[11] + data_in[13] + data_in[15];
      crc_out_tmp[6]  = crc_t[2] + crc_t[4] + crc_t[6] + data_in[4] + data_in[5] + data_in[6] + data_in[10] + data_in[12] + data_in[14];
      crc_out_tmp[7]  = crc_t[3] + crc_t[5] + crc_t[7] + data_in[5] + data_in[6] + data_in[7] + data_in[11] + data_in[13] + data_in[15];
      fun_crc8_d16 = crc_out_tmp;
    end
  endfunction

  function [7:0] fun_crc8_d24;
    input [23:0] data_in;
    input [7:0] crc_t;
    reg [7:0] crc_out_tmp;
    begin
      crc_out_tmp[0]  = crc_t[0] + crc_t[2] + crc_t[3] + crc_t[5] + crc_t[7] + data_in[0] + data_in[6] + data_in[7] + data_in[8] + data_in[12] + data_in[14] + data_in[16] + data_in[18] + data_in[19] + data_in[21] + data_in[23];
      crc_out_tmp[1]  = crc_t[0] + crc_t[1] + crc_t[2] + crc_t[4] + crc_t[5] + crc_t[6] + crc_t[7] + data_in[0] + data_in[1] + data_in[6] + data_in[9] + data_in[12] + data_in[13] + data_in[14] + data_in[15] + data_in[16] + data_in[17] + data_in[18] + data_in[20] + data_in[21] + data_in[22] + data_in[23];
      crc_out_tmp[2]  = crc_t[1] + crc_t[6] + data_in[0] + data_in[1] + data_in[2] + data_in[6] + data_in[8] + data_in[10] + data_in[12] + data_in[13] + data_in[15] + data_in[17] + data_in[22];
      crc_out_tmp[3]  = crc_t[0] + crc_t[2] + crc_t[7] + data_in[1] + data_in[2] + data_in[3] + data_in[7] + data_in[9] + data_in[11] + data_in[13] + data_in[14] + data_in[16] + data_in[18] + data_in[23];
      crc_out_tmp[4]  = crc_t[1] + crc_t[3] + data_in[2] + data_in[3] + data_in[4] + data_in[8] + data_in[10] + data_in[12] + data_in[14] + data_in[15] + data_in[17] + data_in[19];
      crc_out_tmp[5]  = crc_t[0] + crc_t[2] + crc_t[4] + data_in[3] + data_in[4] + data_in[5] + data_in[9] + data_in[11] + data_in[13] + data_in[15] + data_in[16] + data_in[18] + data_in[20];
      crc_out_tmp[6]  = crc_t[0] + crc_t[1] + crc_t[3] + crc_t[5] + data_in[4] + data_in[5] + data_in[6] + data_in[10] + data_in[12] + data_in[14] + data_in[16] + data_in[17] + data_in[19] + data_in[21];
      crc_out_tmp[7]  = crc_t[1] + crc_t[2] + crc_t[4] + crc_t[6] + data_in[5] + data_in[6] + data_in[7] + data_in[11] + data_in[13] + data_in[15] + data_in[17] + data_in[18] + data_in[20] + data_in[22];
      fun_crc8_d24 = crc_out_tmp;
    end
  endfunction

  function [7:0] fun_crc8_d32;
    input [31:0] data_in;
    input [7:0] crc_t;
    reg [7:0] crc_out_tmp;
    begin
      crc_out_tmp[0]  = crc_t[4] + crc_t[6] + crc_t[7] + data_in[0] + data_in[6] + data_in[7] + data_in[8] + data_in[12] + data_in[14] + data_in[16] + data_in[18] + data_in[19] + data_in[21] + data_in[23] + data_in[28] + data_in[30] + data_in[31];
      crc_out_tmp[1]  = crc_t[0] + crc_t[4] + crc_t[5] + crc_t[6] + data_in[0] + data_in[1] + data_in[6] + data_in[9] + data_in[12] + data_in[13] + data_in[14] + data_in[15] + data_in[16] + data_in[17] + data_in[18] + data_in[20] + data_in[21] + data_in[22] + data_in[23] + data_in[24] + data_in[28] + data_in[29] + data_in[30];
      crc_out_tmp[2]  = crc_t[0] + crc_t[1] + crc_t[4] + crc_t[5] + data_in[0] + data_in[1] + data_in[2] + data_in[6] + data_in[8] + data_in[10] + data_in[12] + data_in[13] + data_in[15] + data_in[17] + data_in[22] + data_in[24] + data_in[25] + data_in[28] + data_in[29];
      crc_out_tmp[3]  = crc_t[1] + crc_t[2] + crc_t[5] + crc_t[6] + data_in[1] + data_in[2] + data_in[3] + data_in[7] + data_in[9] + data_in[11] + data_in[13] + data_in[14] + data_in[16] + data_in[18] + data_in[23] + data_in[25] + data_in[26] + data_in[29] + data_in[30];
      crc_out_tmp[4]  = crc_t[0] + crc_t[2] + crc_t[3] + crc_t[6] + crc_t[7] + data_in[2] + data_in[3] + data_in[4] + data_in[8] + data_in[10] + data_in[12] + data_in[14] + data_in[15] + data_in[17] + data_in[19] + data_in[24] + data_in[26] + data_in[27] + data_in[30] + data_in[31];
      crc_out_tmp[5]  = crc_t[1] + crc_t[3] + crc_t[4] + crc_t[7] + data_in[3] + data_in[4] + data_in[5] + data_in[9] + data_in[11] + data_in[13] + data_in[15] + data_in[16] + data_in[18] + data_in[20] + data_in[25] + data_in[27] + data_in[28] + data_in[31];
      crc_out_tmp[6]  = crc_t[2] + crc_t[4] + crc_t[5] + data_in[4] + data_in[5] + data_in[6] + data_in[10] + data_in[12] + data_in[14] + data_in[16] + data_in[17] + data_in[19] + data_in[21] + data_in[26] + data_in[28] + data_in[29];
      crc_out_tmp[7]  = crc_t[3] + crc_t[5] + crc_t[6] + data_in[5] + data_in[6] + data_in[7] + data_in[11] + data_in[13] + data_in[15] + data_in[17] + data_in[18] + data_in[20] + data_in[22] + data_in[27] + data_in[29] + data_in[30];
      fun_crc8_d32 = crc_out_tmp;
    end
  endfunction

  function [6:0] fun_crc7_d1;
    input [0:0] data_in;
    input [6:0] crc_t;
    reg [6:0] crc_out_tmp;
    begin
      crc_out_tmp[0] = crc_t[6] + data_in[0];
      crc_out_tmp[1] = crc_t[0];
      crc_out_tmp[2] = crc_t[1];
      crc_out_tmp[3] = crc_t[2] + crc_t[6] + data_in[0];
      crc_out_tmp[4] = crc_t[3];
      crc_out_tmp[5] = crc_t[4];
      crc_out_tmp[6] = crc_t[5];
      fun_crc7_d1 = crc_out_tmp;
    end
  endfunction

  parameter crc_out_width = fun_crc_bits(crc_type);
  input reset_l;
  input clk;
  input clk_en;

  input data_in_en;
  input [data_in_width/8-1:0] data_byte_en;
  input [data_in_width-1:0] data_in;
  output crc_done;
  output [crc_out_width-1:0] crc_out;

  reg [data_in_width-1:0] data_in_rev;
  reg                     data_in_en_d0;
  reg [crc_out_width-1:0] crc_out_t;
  reg [crc_out_width-1:0] crc_out_s;
  reg [crc_out_width-1:0] crc_out;
  integer i, j, m, n;

  /*******************************************************************************************************
**                              Main Program    
**  
********************************************************************************************************/
  always @(negedge reset_l or posedge clk)
    if (reset_l == 1'b0) begin
      data_in_en_d0 <= 1'b0;
    end else begin
      if (clk_en == 1'b1) begin
        data_in_en_d0 <= data_in_en;
      end
    end
  //core crc32 calculate
  generate
    if (crc_type == 0) begin : crc32_inout_gen
      //input data bit reverse
      always @(*) begin
        if (data_in_width > 1) begin
          for (i = 0; i < data_in_width / 8; i = i + 1) begin
            for (j = 0; j <= 7; j = j + 1) begin
              data_in_rev[i*8+j] <= data_in[i*8+(7-j)];
            end
          end
        end else begin
          data_in_rev <= data_in;
        end
      end
      //output crc bit reverse and xor 0xffffffff
      always @(*)
        for (m = 0; m < crc_out_width / 8; m = m + 1) begin
          for (n = 0; n <= 7; n = n + 1) begin
            crc_out[m*8+n] <= ~crc_out_s[m*8+(7-n)];
          end
        end
    end
  endgenerate
  generate
    if (crc_type == 0 && data_in_width == 1) begin : crc32_d1_gen
      wire [crc_out_width-1:0] crc_init = {crc_out_width{1'b1}};
      always @(negedge reset_l or posedge clk)
        if (reset_l == 1'b0) begin
          crc_out_t = {crc_out_width{1'b0}};
          crc_out_s = {crc_out_width{1'b0}};
        end else begin
          if (clk_en == 1'b1) begin
            if (data_in_en == 1'b1 && data_in_en_d0 == 1'b0) begin
              crc_out_t = fun_crc32_d1(data_in_rev, crc_init);
            end else begin
              //if(data_byte_en == 1'b1) begin
              crc_out_t = fun_crc32_d1(data_in_rev, crc_out_s);
              //end
            end
            crc_out_s = crc_out_t;
          end
        end  // else: !if(reset_l == 1'b0)	
    end
  endgenerate
  generate
    if (crc_type == 0 && data_in_width == 8) begin : crc32_d8_gen
      wire [crc_out_width-1:0] crc_init = {crc_out_width{1'b1}};
      always @(negedge reset_l or posedge clk)
        if (reset_l == 1'b0) begin
          crc_out_t = {crc_out_width{1'b0}};
          crc_out_s = {crc_out_width{1'b0}};
        end else begin
          if (clk_en == 1'b1) begin
            if (data_in_en == 1'b1 && data_in_en_d0 == 1'b0) begin
              crc_out_t = fun_crc32_d8(data_in_rev, crc_init);
            end else begin
              if (data_byte_en == 1'b1) begin
                crc_out_t = fun_crc32_d8(data_in_rev, crc_out_s);
              end
            end
            crc_out_s = crc_out_t;
          end
        end  // else: !if(reset_l == 1'b0)	
    end
  endgenerate
  generate
    if (crc_type == 0 && data_in_width == 16) begin : crc32_d16_gen
      wire [crc_out_width-1:0] crc_init = {crc_out_width{1'b1}};
      always @(negedge reset_l or posedge clk)
        if (reset_l == 1'b0) begin
          crc_out_t = {crc_out_width{1'b0}};
          crc_out_s = {crc_out_width{1'b0}};
        end else begin
          if (clk_en == 1'b1) begin
            if (data_in_en == 1'b1 && data_in_en_d0 == 1'b0) begin
              case (data_byte_en)
                2'b10:   crc_out_t = fun_crc32_d8(data_in_rev[15:8], crc_init);
                2'b01:   crc_out_t = fun_crc32_d8(data_in_rev[7:0], crc_init);
                2'b11:   crc_out_t = fun_crc32_d16(data_in_rev, crc_init);
                default: ;
              endcase
            end else begin
              case (data_byte_en)
                2'b10:   crc_out_t = fun_crc32_d8(data_in_rev[15:8], crc_out_s);
                2'b01:   crc_out_t = fun_crc32_d8(data_in_rev[7:0], crc_out_s);
                2'b11:   crc_out_t = fun_crc32_d16(data_in_rev, crc_out_s);
                default: ;
              endcase
            end
            crc_out_s = crc_out_t;
          end
        end  // else: !if(reset_l == 1'b0)	
    end
  endgenerate
  generate
    if (crc_type == 0 && data_in_width == 32) begin : crc32_d32_gen
      wire [crc_out_width-1:0] crc_init = {crc_out_width{1'b1}};
      always @(negedge reset_l or posedge clk)
        if (reset_l == 1'b0) begin
          crc_out_t = {crc_out_width{1'b0}};
          crc_out_s = {crc_out_width{1'b0}};
        end else begin
          if (clk_en == 1'b1) begin
            if (data_in_en == 1'b1 && data_in_en_d0 == 1'b0) begin
              case (data_byte_en)
                4'b1000: crc_out_t = fun_crc32_d8(data_in_rev[31:24], crc_init);
                4'b0001: crc_out_t = fun_crc32_d8(data_in_rev[7:0], crc_init);
                4'b1100: crc_out_t = fun_crc32_d16(data_in_rev[31:16], crc_init);
                4'b0011: crc_out_t = fun_crc32_d16(data_in_rev[15:0], crc_init);
                4'b1110: crc_out_t = fun_crc32_d24(data_in_rev[31:8], crc_init);
                4'b0111: crc_out_t = fun_crc32_d24(data_in_rev[23:0], crc_init);
                4'b1111: crc_out_t = fun_crc32_d32(data_in_rev, crc_init);
                default: ;
              endcase
            end else begin
              case (data_byte_en)
                4'b1000: crc_out_t = fun_crc32_d8(data_in_rev[31:24], crc_out_s);
                4'b0001: crc_out_t = fun_crc32_d8(data_in_rev[7:0], crc_out_s);
                4'b1100: crc_out_t = fun_crc32_d16(data_in_rev[31:16], crc_out_s);
                4'b0011: crc_out_t = fun_crc32_d16(data_in_rev[15:0], crc_out_s);
                4'b1110: crc_out_t = fun_crc32_d24(data_in_rev[31:8], crc_out_s);
                4'b0111: crc_out_t = fun_crc32_d24(data_in_rev[23:0], crc_out_s);
                4'b1111: crc_out_t = fun_crc32_d32(data_in_rev, crc_out_s);
                default: ;
              endcase
            end
            crc_out_s = crc_out_t;
          end
        end  // else: !if(reset_l == 1'b0)	
    end
  endgenerate

  //core crc16-ccitt calculate
  generate
    if (crc_type == 1) begin : crc16_ccitt_inout_gen
      //input data bit reverse
      always @(*) begin
        if (data_in_width > 1) begin
          for (i = 0; i < data_in_width / 8; i = i + 1) begin
            for (j = 0; j <= 7; j = j + 1) begin
              data_in_rev[i*8+j] <= data_in[i*8+(7-j)];
            end
          end
        end else begin
          data_in_rev <= data_in;
        end
      end
      //output crc bit reverse and xor 0x0000
      always @(*)
        for (m = 0; m < crc_out_width / 8; m = m + 1) begin
          for (n = 0; n <= 7; n = n + 1) begin
            crc_out[m*8+n] <= crc_out_s[m*8+(7-n)];
          end
        end
    end
  endgenerate
  generate
    if (data_in_width == 8 && crc_type == 1) begin : crc16_ccitt_d8_gen
      wire [crc_out_width-1:0] crc_init = {crc_out_width{1'b0}};
      always @(negedge reset_l or posedge clk)
        if (reset_l == 1'b0) begin
          crc_out_t = {crc_out_width{1'b0}};
          crc_out_s = {crc_out_width{1'b0}};
        end else begin
          if (clk_en == 1'b1) begin
            if (data_in_en == 1'b1 && data_in_en_d0 == 1'b0) begin
              crc_out_t = fun_crc16_ccitt_d8(data_in_rev, crc_init);
            end else begin
              if (data_byte_en == 1'b1) begin
                crc_out_t = fun_crc16_ccitt_d8(data_in_rev, crc_out_s);
              end
            end
            crc_out_s = crc_out_t;
          end
        end  // else: !if(reset_l == 1'b0)	
    end
  endgenerate
  generate
    if (data_in_width == 1 && crc_type == 1) begin : crc16_ccitt_d1_gen
      wire [crc_out_width-1:0] crc_init = {crc_out_width{1'b0}};
      always @(negedge reset_l or posedge clk)
        if (reset_l == 1'b0) begin
          crc_out_t = {crc_out_width{1'b0}};
          crc_out_s = {crc_out_width{1'b0}};
        end else begin
          if (clk_en == 1'b1) begin
            if (data_in_en == 1'b1 && data_in_en_d0 == 1'b0) begin
              crc_out_t = fun_crc16_ccitt_d1(data_in_rev, crc_init);
            end else begin
              //if(data_byte_en == 1'b1) begin
              crc_out_t = fun_crc16_ccitt_d1(data_in_rev, crc_out_s);
              //end
            end
            crc_out_s = crc_out_t;
          end
        end  // else: !if(reset_l == 1'b0)	
    end
  endgenerate
  generate
    if (data_in_width == 16 && crc_type == 1) begin : crc16_ccitt_d16_gen
      wire [crc_out_width-1:0] crc_init = {crc_out_width{1'b0}};
      always @(negedge reset_l or posedge clk)
        if (reset_l == 1'b0) begin
          crc_out_t = {crc_out_width{1'b0}};
          crc_out_s = {crc_out_width{1'b0}};
        end else begin
          if (clk_en == 1'b1) begin
            if (data_in_en == 1'b1 && data_in_en_d0 == 1'b0) begin
              case (data_byte_en)
                2'b10:   crc_out_t = fun_crc16_ccitt_d8(data_in_rev[15:8], crc_init);
                2'b01:   crc_out_t = fun_crc16_ccitt_d8(data_in_rev[7:0], crc_init);
                2'b11:   crc_out_t = fun_crc16_ccitt_d16(data_in_rev, crc_init);
                default: ;
              endcase
            end else begin
              case (data_byte_en)
                2'b10:   crc_out_t = fun_crc16_ccitt_d8(data_in_rev[15:8], crc_out_s);
                2'b01:   crc_out_t = fun_crc16_ccitt_d8(data_in_rev[7:0], crc_out_s);
                2'b11:   crc_out_t = fun_crc16_ccitt_d16(data_in_rev, crc_out_s);
                default: ;
              endcase
            end
            crc_out_s = crc_out_t;
          end
        end  // else: !if(reset_l == 1'b0)
    end
  endgenerate
  generate
    if (data_in_width == 32 && crc_type == 1) begin : crc16_ccitt_d32_gen
      wire [crc_out_width-1:0] crc_init = {crc_out_width{1'b0}};
      always @(negedge reset_l or posedge clk)
        if (reset_l == 1'b0) begin
          crc_out_t = {crc_out_width{1'b0}};
          crc_out_s = {crc_out_width{1'b0}};
        end else begin
          if (clk_en == 1'b1) begin
            if (data_in_en == 1'b1 && data_in_en_d0 == 1'b0) begin
              case (data_byte_en)
                4'b1000: crc_out_t = fun_crc16_ccitt_d8(data_in_rev[31:24], crc_init);
                4'b0001: crc_out_t = fun_crc16_ccitt_d8(data_in_rev[7:0], crc_init);
                4'b1100: crc_out_t = fun_crc16_ccitt_d16(data_in_rev[31:16], crc_init);
                4'b0011: crc_out_t = fun_crc16_ccitt_d16(data_in_rev[15:0], crc_init);
                4'b1110: crc_out_t = fun_crc16_ccitt_d24(data_in_rev[31:8], crc_init);
                4'b0111: crc_out_t = fun_crc16_ccitt_d24(data_in_rev[23:0], crc_init);
                4'b1111: crc_out_t = fun_crc16_ccitt_d32(data_in_rev, crc_init);
                default: ;
              endcase
            end else begin
              case (data_byte_en)
                4'b1000: crc_out_t = fun_crc16_ccitt_d8(data_in_rev[31:24], crc_out_s);
                4'b0001: crc_out_t = fun_crc16_ccitt_d8(data_in_rev[7:0], crc_out_s);
                4'b1100: crc_out_t = fun_crc16_ccitt_d16(data_in_rev[31:16], crc_out_s);
                4'b0011: crc_out_t = fun_crc16_ccitt_d16(data_in_rev[15:0], crc_out_s);
                4'b1110: crc_out_t = fun_crc16_ccitt_d24(data_in_rev[31:8], crc_out_s);
                4'b0111: crc_out_t = fun_crc16_ccitt_d24(data_in_rev[23:0], crc_out_s);
                4'b1111: crc_out_t = fun_crc16_ccitt_d32(data_in_rev, crc_out_s);
                default: ;
              endcase
            end
            crc_out_s = crc_out_t;
          end
        end  // else: !if(reset_l == 1'b0)	
    end
  endgenerate


  //core crc16-ibm calculate
  generate
    if (crc_type == 2) begin : crc16_ibm_inout_gen
      //input data bit reverse
      always @(*) begin
        if (data_in_width > 1) begin
          for (i = 0; i < data_in_width / 8; i = i + 1) begin
            for (j = 0; j <= 7; j = j + 1) begin
              data_in_rev[i*8+j] <= data_in[i*8+(7-j)];
            end
          end
        end else begin
          data_in_rev <= data_in;
        end
      end
      //output crc bit reverse and xor 0x0000
      always @(*)
        for (m = 0; m < crc_out_width / 8; m = m + 1) begin
          for (n = 0; n <= 7; n = n + 1) begin
            crc_out[m*8+n] <= crc_out_s[m*8+(7-n)];
          end
        end
    end
  endgenerate
  generate
    if (data_in_width == 1 && crc_type == 2) begin : crc16_ibm_d1_gen
      wire [crc_out_width-1:0] crc_init = {crc_out_width{1'b0}};
      always @(negedge reset_l or posedge clk)
        if (reset_l == 1'b0) begin
          crc_out_t = {crc_out_width{1'b0}};
          crc_out_s = {crc_out_width{1'b0}};
        end else begin
          if (clk_en == 1'b1) begin
            if (data_in_en == 1'b1 && data_in_en_d0 == 1'b0) begin
              crc_out_t = fun_crc16_ibm_d1(data_in_rev, crc_init);
            end else begin
              //if(data_byte_en == 1'b1) begin
              crc_out_t = fun_crc16_ibm_d1(data_in_rev, crc_out_s);
              //end
            end
            crc_out_s = crc_out_t;
          end
        end  // else: !if(reset_l == 1'b0)	
    end
  endgenerate
  generate
    if (data_in_width == 8 && crc_type == 2) begin : crc16_ibm_d8_gen
      wire [crc_out_width-1:0] crc_init = {crc_out_width{1'b0}};
      always @(negedge reset_l or posedge clk)
        if (reset_l == 1'b0) begin
          crc_out_t = {crc_out_width{1'b0}};
          crc_out_s = {crc_out_width{1'b0}};
        end else begin
          if (clk_en == 1'b1) begin
            if (data_in_en == 1'b1 && data_in_en_d0 == 1'b0) begin
              crc_out_t = fun_crc16_ibm_d8(data_in_rev, crc_init);
            end else begin
              if (data_byte_en == 1'b1) begin
                crc_out_t = fun_crc16_ibm_d8(data_in_rev, crc_out_s);
              end
            end
            crc_out_s = crc_out_t;
          end
        end  // else: !if(reset_l == 1'b0)	
    end
  endgenerate
  generate
    if (data_in_width == 16 && crc_type == 2) begin : crc16_ibm_d16_gen
      wire [crc_out_width-1:0] crc_init = {crc_out_width{1'b0}};
      always @(negedge reset_l or posedge clk)
        if (reset_l == 1'b0) begin
          crc_out_t = {crc_out_width{1'b0}};
          crc_out_s = {crc_out_width{1'b0}};
        end else begin
          if (clk_en == 1'b1) begin
            if (data_in_en == 1'b1 && data_in_en_d0 == 1'b0) begin
              case (data_byte_en)
                2'b10:   crc_out_t = fun_crc16_ibm_d8(data_in_rev[15:8], crc_init);
                2'b01:   crc_out_t = fun_crc16_ibm_d8(data_in_rev[7:0], crc_init);
                2'b11:   crc_out_t = fun_crc16_ibm_d16(data_in_rev, crc_init);
                default: ;
              endcase
            end else begin
              case (data_byte_en)
                2'b10:   crc_out_t = fun_crc16_ibm_d8(data_in_rev[15:8], crc_out_s);
                2'b01:   crc_out_t = fun_crc16_ibm_d8(data_in_rev[7:0], crc_out_s);
                2'b11:   crc_out_t = fun_crc16_ibm_d16(data_in_rev, crc_out_s);
                default: ;
              endcase
            end
            crc_out_s = crc_out_t;
          end
        end  // else: !if(reset_l == 1'b0)
    end
  endgenerate
  generate
    if (data_in_width == 32 && crc_type == 2) begin : crc16_ibm_d32_gen
      wire [crc_out_width-1:0] crc_init = {crc_out_width{1'b0}};
      always @(negedge reset_l or posedge clk)
        if (reset_l == 1'b0) begin
          crc_out_t = {crc_out_width{1'b0}};
          crc_out_s = {crc_out_width{1'b0}};
        end else begin
          if (clk_en == 1'b1) begin
            if (data_in_en == 1'b1 && data_in_en_d0 == 1'b0) begin
              case (data_byte_en)
                4'b1000: crc_out_t = fun_crc16_ibm_d8(data_in_rev[31:24], crc_init);
                4'b0001: crc_out_t = fun_crc16_ibm_d8(data_in_rev[7:0], crc_init);
                4'b1100: crc_out_t = fun_crc16_ibm_d16(data_in_rev[31:16], crc_init);
                4'b0011: crc_out_t = fun_crc16_ibm_d16(data_in_rev[15:0], crc_init);
                4'b1110: crc_out_t = fun_crc16_ibm_d24(data_in_rev[31:8], crc_init);
                4'b0111: crc_out_t = fun_crc16_ibm_d24(data_in_rev[23:0], crc_init);
                4'b1111: crc_out_t = fun_crc16_ibm_d32(data_in_rev, crc_init);
                default: ;
              endcase
            end else begin
              case (data_byte_en)
                4'b1000: crc_out_t = fun_crc16_ibm_d8(data_in_rev[31:24], crc_out_s);
                4'b0001: crc_out_t = fun_crc16_ibm_d8(data_in_rev[7:0], crc_out_s);
                4'b1100: crc_out_t = fun_crc16_ibm_d16(data_in_rev[31:16], crc_out_s);
                4'b0011: crc_out_t = fun_crc16_ibm_d16(data_in_rev[15:0], crc_out_s);
                4'b1110: crc_out_t = fun_crc16_ibm_d24(data_in_rev[31:8], crc_out_s);
                4'b0111: crc_out_t = fun_crc16_ibm_d24(data_in_rev[23:0], crc_out_s);
                4'b1111: crc_out_t = fun_crc16_ibm_d32(data_in_rev, crc_out_s);
                default: ;
              endcase
            end
            crc_out_s = crc_out_t;
          end
        end  // else: !if(reset_l == 1'b0)	
    end
  endgenerate

  //core crc8 calculate
  generate
    if (crc_type == 3) begin : crc8_inout_gen
      //input data bit don't reverse
      always @(*) begin
        if (data_in_width > 1) begin
          for (i = 0; i < data_in_width / 8; i = i + 1) begin
            for (j = 0; j <= 7; j = j + 1) begin
              data_in_rev[i*8+j] <= data_in[i*8+j];
            end
          end
        end else begin
          data_in_rev <= data_in;
        end
      end
      //output crc bit don't reverse and xor 0x00
      always @(*)
        for (m = 0; m < crc_out_width / 8; m = m + 1) begin
          for (n = 0; n <= 7; n = n + 1) begin
            crc_out[m*8+n] <= crc_out_s[m*8+n];
          end
        end
    end
  endgenerate
  generate
    if (crc_type == 4) begin : crc8_itu_inout_gen
      //input data bit don't reverse
      always @(*) begin
        if (data_in_width > 1) begin
          for (i = 0; i < data_in_width / 8; i = i + 1) begin
            for (j = 0; j <= 7; j = j + 1) begin
              data_in_rev[i*8+j] <= data_in[i*8+j];
            end
          end
        end else begin
          data_in_rev <= data_in;
        end
      end
      //output crc bit don't reverse and xor 0x55
      always @(*)
        for (m = 0; m < crc_out_width / 8; m = m + 1) begin
          for (n = 0; n <= 7; n = n + 1) begin
            if (n % 2 == 0) begin
              crc_out[m*8+n] <= ~crc_out_s[m*8+n];
            end else begin
              crc_out[m*8+n] <= crc_out_s[m*8+n];
            end
          end
        end
    end
  endgenerate
  generate
    if ((crc_type == 3 || crc_type == 4) && data_in_width == 1) begin : crc8_d1_gen
      wire [crc_out_width-1:0] crc_init = {crc_out_width{1'b0}};
      always @(negedge reset_l or posedge clk)
        if (reset_l == 1'b0) begin
          crc_out_t = {crc_out_width{1'b0}};
          crc_out_s = {crc_out_width{1'b0}};
        end else begin
          if (clk_en == 1'b1) begin
            if (data_in_en == 1'b1 && data_in_en_d0 == 1'b0) begin
              crc_out_t = fun_crc8_d1(data_in_rev, crc_init);
            end else begin
              //if(data_byte_en == 1'b1) begin
              crc_out_t = fun_crc8_d1(data_in_rev, crc_out_s);
              //end
            end
            crc_out_s = crc_out_t;
          end
        end  // else: !if(reset_l == 1'b0)	
    end
  endgenerate
  generate
    if ((crc_type == 3 || crc_type == 4) && data_in_width == 8) begin : crc8_d8_gen
      wire [crc_out_width-1:0] crc_init = {crc_out_width{1'b0}};
      always @(negedge reset_l or posedge clk)
        if (reset_l == 1'b0) begin
          crc_out_t = {crc_out_width{1'b0}};
          crc_out_s = {crc_out_width{1'b0}};
        end else begin
          if (clk_en == 1'b1) begin
            if (data_in_en == 1'b1 && data_in_en_d0 == 1'b0) begin
              crc_out_t = fun_crc8_d8(data_in_rev, crc_init);
            end else begin
              if (data_byte_en == 1'b1) begin
                crc_out_t = fun_crc8_d8(data_in_rev, crc_out_s);
              end
            end
            crc_out_s = crc_out_t;
          end
        end  // else: !if(reset_l == 1'b0)	
    end
  endgenerate
  generate
    if ((crc_type == 3 || crc_type == 4) && data_in_width == 16) begin : crc8_d16_gen
      wire [crc_out_width-1:0] crc_init = {crc_out_width{1'b0}};
      always @(negedge reset_l or posedge clk)
        if (reset_l == 1'b0) begin
          crc_out_t = {crc_out_width{1'b0}};
          crc_out_s = {crc_out_width{1'b0}};
        end else begin
          if (clk_en == 1'b1) begin
            if (data_in_en == 1'b1 && data_in_en_d0 == 1'b0) begin
              case (data_byte_en)
                2'b10:   crc_out_t = fun_crc8_d8(data_in_rev[15:8], crc_init);
                2'b01:   crc_out_t = fun_crc8_d8(data_in_rev[7:0], crc_init);
                2'b11:   crc_out_t = fun_crc8_d16(data_in_rev, crc_init);
                default: ;
              endcase
            end else begin
              case (data_byte_en)
                2'b10:   crc_out_t = fun_crc8_d8(data_in_rev[15:8], crc_out_s);
                2'b01:   crc_out_t = fun_crc8_d8(data_in_rev[7:0], crc_out_s);
                2'b11:   crc_out_t = fun_crc8_d16(data_in_rev, crc_out_s);
                default: ;
              endcase
            end
            crc_out_s = crc_out_t;
          end
        end  // else: !if(reset_l == 1'b0)	
    end
  endgenerate
  generate
    if ((crc_type == 3 || crc_type == 4) && data_in_width == 32) begin : crc8_d32_gen
      wire [crc_out_width-1:0] crc_init = {crc_out_width{1'b0}};
      always @(negedge reset_l or posedge clk)
        if (reset_l == 1'b0) begin
          crc_out_t = {crc_out_width{1'b0}};
          crc_out_s = {crc_out_width{1'b0}};
        end else begin
          if (clk_en == 1'b1) begin
            if (data_in_en == 1'b1 && data_in_en_d0 == 1'b0) begin
              case (data_byte_en)
                4'b1000: crc_out_t = fun_crc8_d8(data_in_rev[31:24], crc_init);
                4'b0001: crc_out_t = fun_crc8_d8(data_in_rev[7:0], crc_init);
                4'b1100: crc_out_t = fun_crc8_d16(data_in_rev[31:16], crc_init);
                4'b0011: crc_out_t = fun_crc8_d16(data_in_rev[15:0], crc_init);
                4'b1110: crc_out_t = fun_crc8_d24(data_in_rev[31:8], crc_init);
                4'b0111: crc_out_t = fun_crc8_d24(data_in_rev[23:0], crc_init);
                4'b1111: crc_out_t = fun_crc8_d32(data_in_rev, crc_init);
                default: ;
              endcase
            end else begin
              case (data_byte_en)
                4'b1000: crc_out_t = fun_crc8_d8(data_in_rev[31:24], crc_out_s);
                4'b0001: crc_out_t = fun_crc8_d8(data_in_rev[7:0], crc_out_s);
                4'b1100: crc_out_t = fun_crc8_d16(data_in_rev[31:16], crc_out_s);
                4'b0011: crc_out_t = fun_crc8_d16(data_in_rev[15:0], crc_out_s);
                4'b1110: crc_out_t = fun_crc8_d24(data_in_rev[31:8], crc_out_s);
                4'b0111: crc_out_t = fun_crc8_d24(data_in_rev[23:0], crc_out_s);
                4'b1111: crc_out_t = fun_crc8_d32(data_in_rev, crc_out_s);
                default: ;
              endcase
            end
            crc_out_s = crc_out_t;
          end
        end  // else: !if(reset_l == 1'b0)	
    end
  endgenerate


  //core crc7 calculate
  generate
    if (crc_type == 7) begin : crc7_inout_gen
      //input data bit don't reverse
      always @(*) begin
        if (data_in_width > 1) begin
          for (i = 0; i < data_in_width / 8; i = i + 1) begin
            for (j = 0; j <= 7; j = j + 1) begin
              data_in_rev[i*8+j] <= data_in[i*8+j];
            end
          end
        end else begin
          data_in_rev <= data_in;
        end
      end
      //output crc bit don't reverse and xor 0x00
      always @(*)
        //for(m=0;m<crc_out_width/8;m=m+1)begin
        //	for(n=0;n<=7;n=n+1)begin
        //		crc_out[m*8+n] <= crc_out_s[m*8+n];
        //	end
        //end
        crc_out <= crc_out_s;
    end
  endgenerate
  generate
    if ((crc_type == 7) && data_in_width == 1) begin : crc7_d1_gen
      wire [crc_out_width-1:0] crc_init = {crc_out_width{1'b0}};
      always @(negedge reset_l or posedge clk)
        if (reset_l == 1'b0) begin
          crc_out_t = {crc_out_width{1'b0}};
          crc_out_s = {crc_out_width{1'b0}};
        end else begin
          if (clk_en == 1'b1) begin
            if (data_in_en == 1'b1 && data_in_en_d0 == 1'b0) begin
              crc_out_t = fun_crc7_d1(data_in_rev, crc_init);
            end else begin
              //if(data_byte_en == 1'b1) begin
              crc_out_t = fun_crc7_d1(data_in_rev, crc_out_s);
              //end
            end
            crc_out_s = crc_out_t;
          end
        end  // else: !if(reset_l == 1'b0)	
    end
  endgenerate

  assign crc_done = ~data_in_en & data_in_en_d0;

endmodule  // crc
