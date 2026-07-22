//Code Generate at: 2026-07-10 13:45:52
module cpu_channel_reg (
    input [0:0] cpu_rd_empty,
    output reg [0:0] cpu_rd_rpkt_pop,
    output reg cpu_rd_rpkt_pop_ind,
    input [31:0] cpu_rd_rpkt_len,
    output reg [0:0] cpu_rd_ren,
    output reg [31:0] cpu_rd_raddr,
    input [31:0] cpu_rd_rdata,
    input [0:0] cpu_wr_full,
    output reg [0:0] cpu_wr_wen,
    output reg cpu_wr_wen_ind,
    output reg [31:0] cpu_wr_waddr,
    output reg [31:0] cpu_wr_wdata,
    output reg [31:0] cpu_wr_wpkt_len,
    output reg [0:0] cpu_wr_wpkt_push,
    output reg cpu_wr_wpkt_push_ind,

    input clk,
    input rst_n,
    input req,
    input rhwl,
    input [31:0] wdata,
    input [15:0] address,
    output reg [31:0] rdata,
    output reg ack
);

  reg timeout_ack;
  reg is_req;
  reg [15:0] is_req_cnt;
  reg [31:0] reg_rdata;
  reg reg_ack;



  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      is_req <= 1'b0;
      is_req_cnt <= 16'b0;
      timeout_ack <= 1'b0;
    end else begin
      timeout_ack <= 1'b0;
      if (req == 1'b1) begin
        is_req <= req;
      end
      if (is_req == 1'b1) begin
        is_req_cnt <= is_req_cnt + 1;
      end else begin
        is_req_cnt <= 16'b0;
      end
      if (is_req_cnt >= 16'hf000 || ack == 1'b1) begin
        is_req <= 1'b0;
      end
      if (is_req_cnt == 16'hf000) begin
        timeout_ack <= 1'b1;
      end
    end
  end


  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cpu_rd_rpkt_pop <= 1'h0;
      cpu_rd_rpkt_pop_ind <= 1'b0;
    end else begin
      cpu_rd_rpkt_pop_ind <= 1'b0;
      if (req == 1'b1 && rhwl == 1'b0 && address == 16'h01) begin
        cpu_rd_rpkt_pop_ind <= 1'b1;
        cpu_rd_rpkt_pop <= wdata[0:0];
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cpu_rd_ren <= 1'h0;
    end else begin
      if (req == 1'b1 && rhwl == 1'b0 && address == 16'h03) begin
        cpu_rd_ren <= wdata[0:0];
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cpu_rd_raddr <= 32'h0;
    end else begin
      if (req == 1'b1 && rhwl == 1'b0 && address == 16'h04) begin
        cpu_rd_raddr <= wdata[31:0];
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cpu_wr_wen <= 1'h0;
      cpu_wr_wen_ind <= 1'b0;
    end else begin
      cpu_wr_wen_ind <= 1'b0;
      if (req == 1'b1 && rhwl == 1'b0 && address == 16'h11) begin
        cpu_wr_wen_ind <= 1'b1;
        cpu_wr_wen <= wdata[0:0];
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cpu_wr_waddr <= 32'h0;
    end else begin
      if (req == 1'b1 && rhwl == 1'b0 && address == 16'h12) begin
        cpu_wr_waddr <= wdata[31:0];
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cpu_wr_wdata <= 32'h0;
    end else begin
      if (req == 1'b1 && rhwl == 1'b0 && address == 16'h13) begin
        cpu_wr_wdata <= wdata[31:0];
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cpu_wr_wpkt_len <= 32'h0;
    end else begin
      if (req == 1'b1 && rhwl == 1'b0 && address == 16'h14) begin
        cpu_wr_wpkt_len <= wdata[31:0];
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cpu_wr_wpkt_push <= 1'h0;
      cpu_wr_wpkt_push_ind <= 1'b0;
    end else begin
      cpu_wr_wpkt_push_ind <= 1'b0;
      if (req == 1'b1 && rhwl == 1'b0 && address == 16'h15) begin
        cpu_wr_wpkt_push_ind <= 1'b1;
        cpu_wr_wpkt_push <= wdata[0:0];
      end
    end
  end


  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      reg_rdata <= 32'b0;
      reg_ack   <= 1'b0;
    end else begin
      reg_ack <= 1'b0;
      if (req == 1'b1 && rhwl == 1'b1) reg_rdata <= 32'b0;
      if (req == 1'b1 && address == 16'h00) begin
        reg_rdata[0:0] <= cpu_rd_empty;
        reg_ack <= 1'b1;
      end
      if (req == 1'b1 && address == 16'h01) begin
        reg_rdata[0:0] <= cpu_rd_rpkt_pop;
        reg_ack <= 1'b1;
      end
      if (req == 1'b1 && address == 16'h02) begin
        reg_rdata[31:0] <= cpu_rd_rpkt_len;
        reg_ack <= 1'b1;
      end
      if (req == 1'b1 && address == 16'h03) begin
        reg_rdata[0:0] <= cpu_rd_ren;
        reg_ack <= 1'b1;
      end
      if (req == 1'b1 && address == 16'h04) begin
        reg_rdata[31:0] <= cpu_rd_raddr;
        reg_ack <= 1'b1;
      end
      if (req == 1'b1 && address == 16'h05) begin
        reg_rdata[31:0] <= cpu_rd_rdata;
        reg_ack <= 1'b1;
      end
      if (req == 1'b1 && address == 16'h10) begin
        reg_rdata[0:0] <= cpu_wr_full;
        reg_ack <= 1'b1;
      end
      if (req == 1'b1 && address == 16'h11) begin
        reg_rdata[0:0] <= cpu_wr_wen;
        reg_ack <= 1'b1;
      end
      if (req == 1'b1 && address == 16'h12) begin
        reg_rdata[31:0] <= cpu_wr_waddr;
        reg_ack <= 1'b1;
      end
      if (req == 1'b1 && address == 16'h13) begin
        reg_rdata[31:0] <= cpu_wr_wdata;
        reg_ack <= 1'b1;
      end
      if (req == 1'b1 && address == 16'h14) begin
        reg_rdata[31:0] <= cpu_wr_wpkt_len;
        reg_ack <= 1'b1;
      end
      if (req == 1'b1 && address == 16'h15) begin
        reg_rdata[0:0] <= cpu_wr_wpkt_push;
        reg_ack <= 1'b1;
      end

    end
  end



  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ack   <= 1'b0;
      rdata <= 32'b0;
    end else begin
      ack <= timeout_ack | reg_ack;
      if (timeout_ack) rdata <= 32'hdeaddead;
      if (reg_ack) rdata <= reg_rdata;
    end
  end



endmodule


