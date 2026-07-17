/*
组合逻辑：没有存储功能，输出仅依赖于输入的实时变化，
        例如加法器、译码器、多路选择器。
时序逻辑：依赖时钟或控制信号，具备存储功能，输出不仅与输入有关，还与电路的历史状态相关，
        例如寄存器、计数器、状态机
*/

//时序逻辑
// 异步复位寄存器：复位立即生效
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)  
	    q <= 8'd0;
    else         
	    q <= d;
end

// 同步复位寄存器：复位在时钟边沿生效
always @(posedge clk) begin
    if (!rst_n)  
	    q <= 8'd0;
    else         
	    q <= d;
end

//组合逻辑
// 连线式：更直观
assign y = sel ? d1 : d0;

// 过程式：便于写复杂条件（务必用 @(*) 和阻塞赋值 =）
always @(*) begin
    case (sel)
        1'b0: y = d0;
        1'b1: y = d1;
        default: y = 1'b0; // 默认分支避免锁存器
    endcase
end

//时序逻辑➕组合逻辑
// 1) 时序：状态寄存
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)  
	    state <= IDLE;
    else         
	    state <= state_nxt; // 非阻塞
end

// 2) 组合：下一个状态/输出逻辑
always @(*) begin
    state_nxt = state;  // 默认值避免锁存器
    out = 1'b0;
    case (state)
        IDLE:  if (start) begin state_nxt = RUN; out = 1'b1; end
        RUN:   if (done)  begin state_nxt = IDLE; end
        default: state_nxt = IDLE;
    endcase
end
