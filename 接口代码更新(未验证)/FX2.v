/*****************************************************
*  Name         :   cyusb
*  Important    :   ADC输入到此的数据不连续，
*                   但数据时间间隔固定,以适配高速ADC和低速
*                   USB设备,允许USB读ADC RAM的时间由
*                   RAM_RD_ALLOW确定
*  Origin       :   180225
*  Author       :   helrori2011@gmail.com
******************************************************/
module FX2
(
   input            REF_CLK,//from pll,The same clock as the ADC
   input            REF_CLK_180,//from pll,for FX2 slave fifo write clk
   input            RST_N,
   //直接从ADC取得的数据,数据不连续,RAM_RD_ALLOW时序在ADC模块内有注释
   input [15:0]     RAM_DATA,
   input            RAM_RD_ALLOW,
   output   reg    [ADC_RAM_WIDTHAD-1:0]RAM_ADDR,
   //从FIR后面取得的连续数据
   input [31:0]      ST_DATA,//{[15:0]I,[15:0]Q}
   input             ST_DATA_CLK,//sample rate of data
   //receive data from PC
   output   reg [31:0]LO32bit,
   //cyusb outside
   inout [15:0]      CY_DATA,
   output   reg [1:0]CY_ADDR,
   output   reg      CY_SLRD_N,
   output   reg      CY_SLWR_N,
   output   reg      CY_PKTEND,
   output   reg      CY_SLOE_N,
   input             CY_FLAGA,
   input             CY_FLAGB,
   output            CY_IFCLK,
   output   reg      CY_tell_cy_ifclk_is_OK
);
`define EP2_NOTHING  (CY_FLAGA==1'd0)
`define EP6_FULL     (CY_FLAGB==1'd0)
//-----------------------------------------------------
parameter   ADC_RAM_WIDTHAD   =  10;//2^10=1024,1024*12BIT
//-----------------------------------------------------
//PLLCLK2PIN PLLCLK2PIN_U0(.PLLCLK(REF_CLK_180),.PIN(CY_IFCLK));
assign CY_IFCLK  = REF_CLK_180;

reg   usb_data_source_select_adc_or_fir = 0;
wire  cy_data_output_en;
wire  [15:0]CY_DATA__;
wire  [15:0]FIR_DATA;
assign   cy_data_output_en = ~CY_SLWR_N;
assign   CY_DATA = (cy_data_output_en)?CY_DATA__:16'bz;
assign   CY_DATA__ = (usb_data_source_select_adc_or_fir)?FIR_DATA:RAM_DATA;
/*****************************************************
*  generate RAM_ADDR_II;Data from FIR
*****************************************************/
//pingpong_ram16 
//#(
// .PINGPONG_RAM_WIDTHAD(8)//2^8/50000==5.12ms
//)
//pingpong_ram16_u1
//(
// .ST_DATA_IN(ST_DATA),
// .ST_DATA_IN_CLK(ST_DATA_CLK),
// 
// 
// .ST_DATA_OUT(FIR_DATA)
//);
/*****************************************************
*  generate RAM_ADDR;Direct data from ADC
*****************************************************/
reg   frist_frames_state = 0;
always@(posedge REF_CLK_180 or negedge RST_N)begin
   if(!RST_N)begin
      RAM_ADDR <= 0;
      frist_frames_state   <= 0;
   end else if(RAM_RD_ALLOW && current_state == st_in && (!frist_frames_state))begin
      RAM_ADDR <= RAM_ADDR +  1'd1;
   end else if(current_state == st_in && (!frist_frames_state))begin//not in the allow time to read
      frist_frames_state   <= 1;
   end else if(frist_frames_state) begin
      if(current_state != st_in)begin//失败帧结束
        frist_frames_state <= 0;
         RAM_ADDR <= 0;
      end
      else
         frist_frames_state   <= frist_frames_state;
   end else begin
      RAM_ADDR <= RAM_ADDR;
   end
end
/*****************************************************
*  CY_tell_cy_ifclk_is_OK
*****************************************************/
always@(posedge REF_CLK_180 or negedge RST_N)begin
   if(!RST_N)
      CY_tell_cy_ifclk_is_OK <= 1'd0;
   else
      CY_tell_cy_ifclk_is_OK <= 1'd1;     
end
/*****************************************************
*  ep2 in, data capture
*****************************************************/
reg [63:0]recv;
always@(posedge REF_CLK_180 or negedge RST_N)begin
   if(!RST_N)begin
      recv  <= 32'd0;
      usb_data_source_select_adc_or_fir   <= 0;
   end else if(CY_SLRD_N == 0 && time_cnt <= 32'd4)begin//receive  64bit
      recv  <= {recv[47:0],CY_DATA};
   end else if(CY_SLRD_N == 0 && time_cnt == 32'd4+1)begin
      if({recv[47:32],recv[63:48]} == "FREQ")//FREQ
         LO32bit  <= {recv[15:0],recv[31:16]};
      else if({recv[47:32],recv[63:48]} == "ADCI")begin//ADCI
         usb_data_source_select_adc_or_fir   <= 0;
      end else if({recv[47:32],recv[63:48]} == "FIRI")begin//FIRI
         usb_data_source_select_adc_or_fir   <= 1;
      end
   end
end

/*****************************************************
*  state mechine
*****************************************************/
parameter   delay = 3'd0,idle_wait_st_in = 3'd1,st_in = 3'd2,pk_end = 3'd3;
parameter   idle_wait_st_out = 3'd4,st_out = 3'd5;
reg   [2:0] current_state,next_state;
reg   [31:0]   time_cnt;
always@(posedge REF_CLK or negedge RST_N)begin
   if(!RST_N)
      current_state  <= delay;
   else
      current_state  <= next_state;
end
always@(*)begin
   next_state  =  current_state;
   case(current_state)
      delay:begin// delay after power on,wait CYUSB set IFCLKconfig done.
         if(time_cnt > 32'd40_000_000)
            next_state = idle_wait_st_in;
         else
            next_state = delay;
      end
      idle_wait_st_in:begin
         if(!`EP6_FULL)//ep6 in not full of data
            next_state = st_in;
         else
            next_state = idle_wait_st_out;
      end
      st_in:begin
         if(time_cnt >= 32'd256)//send 512 bytes fixed
            next_state = pk_end;
         else
            next_state = st_in;
      end
      pk_end:begin
         next_state = idle_wait_st_out;
      end
      idle_wait_st_out:begin
         if(!`EP2_NOTHING)//ep2 have the data,from PC
            next_state = st_out;
         else
            next_state = idle_wait_st_in;
      end
      st_out:begin
         if(time_cnt >= 32'd256)//receive 512 bytes fixed
            next_state = idle_wait_st_in;
         else
            next_state = st_out;
      end
      default:next_state = delay;
   endcase
end
always@(posedge REF_CLK or negedge RST_N)begin
   if(!RST_N)begin
      time_cnt    <= 32'd0;      
      CY_PKTEND   <= 1;
   end
   else
   case(next_state)
      delay:begin
         time_cnt    <= time_cnt + 1'd1;
      end
      idle_wait_st_in:begin//idle_wait_st_in ==> st_in,idle_wait_st_out
         CY_SLRD_N   <= 1;//read disable 
         CY_SLOE_N   <= 1;//output disable   
         CY_SLWR_N   <= 1;       
         time_cnt    <= 0;
         CY_ADDR     <= 2'b10;//select ep6
      end
      st_in:begin //st_in ==> st_in,pk_end
         CY_SLWR_N   <= 0;//write enable 
         time_cnt    <= time_cnt + 1'd1;//counts from 1 to 256 end
      end
      pk_end:begin//pk_end ==> idle_wait_st_out
         CY_SLWR_N   <= 1;
         CY_PKTEND   <= 0;//enable pktend
         time_cnt    <= 0;
      end
      idle_wait_st_out:begin//idle_wait_st_out ==> st_out,idle_wait_st_in
         CY_PKTEND   <= 1;//disable pktend   
         CY_ADDR     <= 2'b00;//select ep2      
      end
      st_out:begin//st_out ==> st_out,idle_wait_st_in
         CY_SLRD_N   <= 0;//read enable 
         CY_SLOE_N   <= 0;//output enable
         time_cnt    <= time_cnt + 1'd1;//receive 512 bytes fixed
      end
   endcase
end
endmodule
/*********************************************************************************
*  Name        :  pingpong_ram;注意仅FX2内部调用!
*  Important   :  receive stream data from FIR and feed data to FX2
*  Origin      :  180304
*  Author      :  helrori2011@gmail.com
*********************************************************************************/
module   pingpong_ram16
(
   input a,
   output   b
);
//-----------------------------------------------------
parameter   PINGPONG_RAM_WIDTHAD =  8;
//-----------------------------------------------------
assign   b  =  a;
endmodule
