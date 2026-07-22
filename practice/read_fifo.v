  /* timing
                ____
rpkt_pop,______|    |___________________________________________________________
wpkt_len, xxxxxxxxxx|xxxxx|  6  |  6  |  6  |  6  |  6  |  6  |  6  |  6  |  6  | 
wpkt_para	xxxxxxxxxx|xxxxx|     |     |     |     |     |     |     |     |     |
                                 ___________________________________	 
ren,      ______________________|                                   |___________
raddr,     xxxxxxxxxxxxxxxxxxxxx|  A1 |  A2 |  A3 |  A4 |  A5 |  A6 |xxxx      
rdata,     xxxxxxxxxxxxxxxxxxxxxxxxxxx|  D1 |  D2 |  D3 |  D4 |  D5 |  D6 |xxxx 	
                                       ___________________________________
ram_wen   ____________________________|                                   |_________
ram_waddr  xxxxxxxxxxxxxxxxxxxxxxxxxxx|  A1 |  A2 |  A3 |  A4 |  A5 |  A6 |xxxx      
ram_wdata  xxxxxxxxxxxxxxxxxxxxxxxxxxx|  D1 |  D2 |  D3 |  D4 |  D5 |  D6 |xxxx  
*/
module read_fifo (
    clk,
    rest_l,
    clk_en,

    empty,
    rpop,
    rlen,
    rpara,
    ren,
    radder,
    rdata,

    wen,
    wadder,
    wdata,
    wpara
);
 
 parameter data_width  = 8;
           adder_width = 8;
           para_width  = 2;

 input  clk;
 input  rest_l;
 input  clk_en;

 input  empty;
 output rpop;
 output ren;
 input  [adder_wideth:0]  rlen;
 output [adder_width-1:0] radder;
 input  [data_width-1:0]  rdata;

 output wen;
 output [adder_width-1:0] wadder;
 output [data_width-1:0]  wdata;
 output [para_wideth-1:0] wpara;

 reg pop_doing;
 reg rpop;

 reg ren;
 reg wen;
 reg len;
 reg [1:0] pop_delay;
 reg [adder_width-1:0] radder;
 reg [adder_width-1:0] wadder;

 always @(posedge clk or negedge rest_l) begin
    if(!rest_l) begin
        rpop <= 0;
        pop_doing <= 0;
    end else begin
        if(empty == 1'b0 && pop_doing == 1'b0)begin
            rpop <= 1'b1;
        end
        if(rpop == 1'b1)begin
            rpop <= 1'b0;
            pop_doing <= 1'b1;
        end
        if(ren == 1'b0 && wen == 1'b1)begin
            pop_doing <= 1'b0;
        end
    end
 end

always @(posedge clk or negedge rest_l)begin
    if(!rest_l)begin
        pop_delay <= 1'b0;
        len <= 1'b0; 
        ren <= 1'b0;
        radder <= 1'b0;
        wen <= 1'b0;
        wadder <= 1'b0;
    end else begin
        pop_delay <= {pop_delay[0],rpop};
        if(pop_delay[1] == 1'b1)begin
            len <= rlen;
            ren <= 1'b1;
        end
        if
        
    end
end

endmodule