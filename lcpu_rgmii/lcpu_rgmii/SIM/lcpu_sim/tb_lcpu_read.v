`timescale 1ns / 1ns
// tb_lcpu_read — jtagCPU_Amd_Test_Top (BFM) + cpu_channel
// BFM 读 test_cmds.txt 执行完整收发自闭环测试
module tb_lcpu_read;
  reg clk, cpu_clk, reset_l;
  always #4  clk = ~clk;
  always #10 cpu_clk = ~cpu_clk;

  wire ce, rpop, rpopi, rren, wfull, wwen, wweni, wpush, wpushi;
  wire [31:0] rlen, raddr, rrdata, waddr, wdata, wplen;

  jtagCPU_Amd_Test_Top #(.sim_mod(1)) u_top (
      .clk(cpu_clk), .rst_n(reset_l),
      .cpu_rd_empty(ce), .cpu_rd_rpkt_pop(rpop), .cpu_rd_rpkt_pop_ind(rpopi),
      .cpu_rd_rpkt_len(rlen), .cpu_rd_ren(rren), .cpu_rd_raddr(raddr), .cpu_rd_rdata(rrdata),
      .cpu_wr_full(wfull), .cpu_wr_wen(wwen), .cpu_wr_wen_ind(wweni),
      .cpu_wr_waddr(waddr), .cpu_wr_wdata(wdata), .cpu_wr_wpkt_len(wplen),
      .cpu_wr_wpkt_push(wpush), .cpu_wr_wpkt_push_ind(wpushi)
  );

  // mac_tx → mac_rx 回环
  wire mts, mte, mtee, mterr;
  wire [7:0] mtd, rdc;

  cpu_channel #(.cpu_buf_addr_width(11), .cpu_buf_data_width(8), .cpu_buf_para_width(3)) u_dut (
      .clk(clk), .reset_l(reset_l), .cpu_clk(cpu_clk),
      .mac_rx_sop(mts), .mac_rx_en(mte), .mac_rx_data(mtd), .mac_rx_eop(mtee),
      .mac_tx_sop(mts), .mac_tx_en(mte), .mac_tx_data(mtd), .mac_tx_eop(mtee), .mac_tx_err(mterr),
      .recv_pkt_drop_cnt(rdc),
      .cpu_rd_empty(ce), .cpu_rd_rpkt_pop(rpop), .cpu_rd_rpkt_len(rlen[11:0]), .cpu_rd_rpkt_para(),
      .cpu_rd_ren(rren), .cpu_rd_raddr(raddr[10:0]), .cpu_rd_rdata(rrdata[7:0]), .cpu_rd_reop_pre(),
      .cpu_wr_full(wfull), .cpu_wr_wen(wwen), .cpu_wr_waddr(waddr[10:0]), .cpu_wr_wdata(wdata[7:0]),
      .cpu_wr_wpkt_push(wpush), .cpu_wr_wpkt_len(wplen[11:0]), .cpu_wr_wpkt_para(3'd0)
  );

  initial begin
    clk=0; cpu_clk=0; reset_l=0;
    $display("\n=== LCPU 读写联合仿真 (BFM + loopback) ===\n");
    $dumpfile("tb_lcpu_read.vcd"); $dumpvars(0,tb_lcpu_read);
    #50; repeat(40) @(posedge cpu_clk); reset_l=1; repeat(40) @(posedge cpu_clk);
    $display("[TB] Ready @ %0t", $time);
    #100000000;  // 100ms
    $display("[TB] Done @ %0t", $time);
    $finish;
  end
  initial begin #200000000; $display("[TB] TIMEOUT"); $finish; end
endmodule
