`timescale 1ns / 1ns
// tb_lcpu_read — lcpu_sim 原有文件 + cpu_channel, BFM 读 64字节包
module tb_lcpu_read;
  reg clk, cpu_clk, reset_l;
  reg mac_rx_sop, mac_rx_en, mac_rx_eop;
  reg [7:0] mac_rx_data;
  always #4  clk = ~clk; always #10 cpu_clk = ~cpu_clk;

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

  cpu_channel #(.cpu_buf_addr_width(11), .cpu_buf_data_width(8), .cpu_buf_para_width(3)) u_dut (
      .clk(clk), .reset_l(reset_l), .cpu_clk(cpu_clk),
      .mac_rx_sop(mac_rx_sop), .mac_rx_en(mac_rx_en), .mac_rx_data(mac_rx_data), .mac_rx_eop(mac_rx_eop),
      .mac_tx_sop(), .mac_tx_en(), .mac_tx_data(), .mac_tx_eop(), .mac_tx_err(), .recv_pkt_drop_cnt(),
      .cpu_rd_empty(ce), .cpu_rd_rpkt_pop(rpop), .cpu_rd_rpkt_len(rlen[11:0]), .cpu_rd_rpkt_para(),
      .cpu_rd_ren(rren), .cpu_rd_raddr(raddr[10:0]), .cpu_rd_rdata(rrdata[7:0]), .cpu_rd_reop_pre(),
      .cpu_wr_full(wfull), .cpu_wr_wen(wwen), .cpu_wr_waddr(waddr[10:0]), .cpu_wr_wdata(wdata[7:0]),
      .cpu_wr_wpkt_push(wpush), .cpu_wr_wpkt_len(wplen[11:0]), .cpu_wr_wpkt_para(3'd0)
  );

  reg [7:0] pk [0:255]; integer i;
  initial begin
    clk=0; cpu_clk=0; reset_l=0; mac_rx_sop=0; mac_rx_en=0; mac_rx_eop=0; mac_rx_data=0;
    for(i=0;i<60;i=i+1) pk[i]=i[7:0];  // 60字节递增 0x00~0x3B, 不触发 filter
    $dumpfile("tb_lcpu_read.vcd"); $dumpvars(0,tb_lcpu_read);
    #50; repeat(40) @(posedge cpu_clk); reset_l=1; repeat(40) @(posedge cpu_clk);
    $display("=== Ready @ %0t ===", $time);
    @(posedge clk); mac_rx_sop<=1; mac_rx_en<=1; mac_rx_data<=pk[0];
    @(posedge clk); mac_rx_sop<=0;
    for(i=1;i<59;i=i+1) begin mac_rx_data<=pk[i]; @(posedge clk); end
    mac_rx_data<=pk[59]; mac_rx_eop<=1; @(posedge clk);
    mac_rx_en<=0; mac_rx_eop<=0;
    $display("=== Frame sent @ %0t ===", $time);
    #500000;  // 500us for BFM
    $display("=== Done @ %0t ===", $time);
    $finish;
  end
endmodule
