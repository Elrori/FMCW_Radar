/*****************************************************************************
*  Name        :   AD interface 
*  Origin      :   171118
*                  171201
*                  180418
*                  180423
*                  180425
*                  180426 - add the SAWTOOTH_DSYNC_BUFF to buffer SAWTOOTH_DSYNC
*  Important   :   Only for AD9283,12bit ADC,6 channel with dsync,and FMCW radar 
*                  vco ADF4158,that used in SAWTOOTH mode     
*  Author      :   helrori
******************************************************************************/
module AD_interface
(
   //Base
   input        clk_50M,
   input        rst_n, 
   //ADF4158 port 
   input        SAWTOOTH_DSYNC,
   //AD8283 ctrl port not use now
   output       ADC_SCLK,
   output       ADC_CSB,
   output       ADC_DIO, 
   output       ADC_PDN,    //Full Power-Down. Logic high overrides SPI and powers down the part, logic low allows selection through SPI.
   output       ADC_AUX,    //Logic high forces to Channel ADC (INADC+/INADC−); AUX has a higher priority than MUXA. 
   output       ADC_MUA,    //Logic high forces to Channel A unless AUX is asserted. 
   output       ADC_SEL,    //Logic high overrides SPI and sets it to 200 kΩ;logic low allows selection through SPI. 
  //AD8283 data port in
   input        ADC_clk,    //单端 single end  连接到 ADC差分时钟脚转单单端
   input        ADC_DSYNC,
   input    [11:0]ADC_DATA,
   //Test
   output	reg [2:0]STATE,
   //Output to cyusb_interface 16bit width
   output   reg FIFO_ADDR,
   output   reg FIFO_rst,
   output   reg [15:0]ADC_DATA_OUT,
   output       FIFO_wr_en_div,
   output       FIFO_wr_clk,
   output       FIFO_data_prepare_ok//当fpga作为从机，主机取数据的时间点是不确定的，需要有数据有效信号，以便主机知道取得的数据是否安全。
);
//----------------------------------------------------------------------------
//  TODO
//  GET_POINT_NUM是：分频后,需要取得的点数(ADC_CHANNEL_CNT个通道为一个点),必须为偶数
//  且应当略小于 SINGLE_CHANNEL_CLK_FREQ/DIV_BY/(1000/SAWTOOTH_LONG_MS)这里等于300因此取256
parameter   GET_POINT_NUM           =   32'd256;        
parameter   ADC_CLK_FREQ            =   32'd36_000_000; //frequence of ADC_clk
parameter   ECHO_DELAY_TIME_US      =   32'd25;         //回波延迟(us)
parameter   DIV_BY                  =   32'd20;         //每通道采样率分频
localparam  SAWTOOTH_LONG_MS        =   32'd1;          //锯齿周期，也就是SAWTOOTH_DSYNC的周期,修改无效
localparam  ADC_CHANNEL_CNT         =   32'd6;          //ADC_DSYNC 内包含的通道数,修改无效
localparam  SINGLE_CHANNEL_CLK_FREQ =   ADC_CLK_FREQ/ADC_CHANNEL_CNT;
localparam  __SAMPLE_RATE__         =   SINGLE_CHANNEL_CLK_FREQ/DIV_BY;//分频后每通道真实采样率
localparam  ONE_SAWTOOTH_MAX_SAMPLE_POINT   =   SINGLE_CHANNEL_CLK_FREQ*SAWTOOTH_LONG_MS/1000 - SINGLE_CHANNEL_CLK_FREQ*ECHO_DELAY_TIME_US/1_000_000;//8000-40
parameter   ADC_FIFO_LENGTH         =  GET_POINT_NUM*ADC_CHANNEL_CNT;
//----------------------------------------------------------------------------
reg         FIFO_wr_en;
assign      FIFO_data_prepare_ok = ((Ponit_Cnt >= 1) && (Ponit_Cnt <= 1280))?1'd1:1'd0;
assign      FIFO_wr_en_div = (Ponit_Cnt % DIV_BY == 14'd0)?FIFO_wr_en:1'd0;
assign      ADC_PDN = 1'd0;
assign      ADC_AUX = 1'd0;
assign      ADC_MUA = 1'd0;
assign      ADC_SEL = 1'd1;//set 200KΩ
assign      FIFO_wr_clk = ADC_clk;
//reg [2:0]   STATE;
reg [13:0]  Ponit_Cnt;    //max 16383 DIV_BY*GET_POINT_NUM
reg [7:0]   Sawtooth_Cnt; //max 1024  for frame counts
reg [10:0]  Time_Cnt;     //max 2048

//-----稳定外部SAWTOOTH_DSYNC信号,必要---//
reg SAWTOOTH_DSYNC_BUFF;
always@(posedge ADC_clk or negedge rst_n)begin
	if(!rst_n)
	   SAWTOOTH_DSYNC_BUFF <= 1'd0;
	else begin
		SAWTOOTH_DSYNC_BUFF <= SAWTOOTH_DSYNC;
	end
end
parameter IDLE = 3'd0,DEALY = 3'd1,A = 3'd2,B = 3'd3,C = 3'd4,D = 3'd5,E = 3'd6,F = 3'd7;
always@(negedge ADC_clk or negedge rst_n)begin//negedge ADC_clk 差半个ADC_clk!
   if(!rst_n)
   begin
    STATE         <=  IDLE;
    Time_Cnt      <=  11'd0;
    Ponit_Cnt     <=  14'd0;
    Sawtooth_Cnt  <=  8'd0;
    FIFO_ADDR     <=  1'd0;
    FIFO_rst      <=  1'd0;
   end
   else begin
      case(STATE)
      IDLE: //wait next SAWTOOTH
         begin
            FIFO_wr_en <= 1'd0;//disable fifo
            if(SAWTOOTH_DSYNC_BUFF)//use SAWTOOTH_DSYNC as start signal
               begin
                  STATE     <= DEALY;
                  FIFO_ADDR <= ~FIFO_ADDR;//change cy pingpong fifo addr
               end
            else begin
               STATE <= IDLE ;
					FIFO_ADDR <= FIFO_ADDR;
			   end
         end
      DEALY:
         begin
         if(Time_Cnt >= ECHO_DELAY_TIME_US*ADC_CLK_FREQ/1000_000-1)begin
               STATE    <= A;
               FIFO_rst <= 0;
               Time_Cnt <= 11'd0; 
               end
            else begin
               Time_Cnt <= Time_Cnt + 1'd1; 
               STATE    <= DEALY ;
               FIFO_rst <= 1;//reset this cy pingpong fifo
               end
         end
      A: //A
         begin
            if(ADC_DSYNC)begin
               STATE        <= B;
               FIFO_wr_en   <= 1;//enable fifo             
               if(Ponit_Cnt == 14'd0)
                  ADC_DATA_OUT <= {4'hE,ADC_DATA};//start flag
               else
                  ADC_DATA_OUT <= {4'h1,/*12'h001*/ADC_DATA};
               end 
            else
               STATE <= A ;
         end
      B: //B
         begin
            STATE <= C;
            if(Ponit_Cnt == 14'd0)
               ADC_DATA_OUT <= {Sawtooth_Cnt[7:4],/*12'h002*/ADC_DATA};//frame cnt high
            else
               ADC_DATA_OUT <= {4'h2,/*12'h002*/ADC_DATA};
         end
      C: //C
         begin 
            STATE <= D;
            if(Ponit_Cnt == 14'd0)
               ADC_DATA_OUT <= {Sawtooth_Cnt[3:0],/*12'h003*/ADC_DATA};//frame cnt low
            else
               ADC_DATA_OUT <= {4'h3,/*12'h002*/ADC_DATA};
         end
      D: //D
         begin          
            STATE <= E;
            ADC_DATA_OUT <= {4'h4,/*12'habc*/ADC_DATA};
         end
      E: //E
         begin
            STATE <= F;
            ADC_DATA_OUT <= {4'h5,/*12'habc*/ADC_DATA};
         end
      F: //F
         begin
            if(Ponit_Cnt >= GET_POINT_NUM*DIV_BY-DIV_BY/*DIV_BY*GET_POINT_NUM-1*/)//一帧(一个有效采样周期)结束
            begin
                ADC_DATA_OUT <= {4'hf,/*12'habc*/ADC_DATA};//sawtooth end flag
            end else begin
                ADC_DATA_OUT <= {4'h6,/*12'habc*/ADC_DATA};
            end
            if(Ponit_Cnt >= DIV_BY*GET_POINT_NUM-1)//one frame finish
            begin
               STATE          <= IDLE;
               Ponit_Cnt      <= 14'd0;
               Sawtooth_Cnt   <= Sawtooth_Cnt + 8'd1;
            end
            else
            begin
               Ponit_Cnt    <= Ponit_Cnt + 14'd1;
               STATE        <= A;
            end
         end   
      default:STATE  <= IDLE;
      endcase
   end
end
endmodule
