//****************************************Copyright 2014[c]************************//
// ************************Declaration***************************************//
// File name:        pulse_clock_region_pass.v	                                    //
// Author:           huaming.huang@link-real.com.cn                             //
// Date:             2014-11-25 18:50                                        //
// Version Number:   1.0                                                     //
// Abstract:         single pulse pass clock region
//                                                                            //
// Modification history:[including time, version, author and abstract]        //
// 2014-11-25 18:50        version 1.0     xxx                                //
// Abstract: Initial                                                          //
//                                                                   //
// *********************************end************************************** //
module pulse_clock_region_pass (
    input reset_l,
    input clk_a,
    input pulse_a,

    input  clk_b,
    output pulse_b
);

  reg pulse_as;
  reg pulse_bs;
  reg pulse_bss;
  reg pulse_bsss;

  always @(posedge clk_a or negedge reset_l) begin
    if (reset_l == 1'b0) begin
      pulse_as <= 1'b0;
    end else begin
      if (pulse_a == 1'b1) begin
        pulse_as <= ~pulse_as;
      end
    end
  end

  always @(posedge clk_b or negedge reset_l) begin
    if (reset_l == 1'b0) begin
      pulse_bs   <= 1'b0;
      pulse_bss  <= 1'b0;
      pulse_bsss <= 1'b0;
    end else begin
      pulse_bs   <= pulse_as;
      pulse_bss  <= pulse_bs;
      pulse_bsss <= pulse_bss;
    end
  end
  assign pulse_b = pulse_bss ^ pulse_bsss;

endmodule
