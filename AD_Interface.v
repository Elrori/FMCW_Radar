
/*********************************************************
*	Name		:	AD interface 
*	Origin	:	171118
*					171201
*	Important:	Only for AD8283,Initialize device and get data 				
*	Author	:	Helrori
**********************************************************/
module AD_interface
#(
	parameter  GET_POINT_NUM = 256*20,ADC_VALUE_CHANNEL_CNT = 4//2-8191*2

)
(
	input		clk_50M,
	input 	rst_n, 
	//ADF4158 port 
	input		SAWTOOTH_DSYNC,
	//ADC data port in
	input		ADC_clk,//单端 single end 48Mhz 连接�? ADC差分时钟脚转单单�?
	input		ADC_DSYNC,
	input		[11:0]ADC_DATA,
	//output to cyusb_interface
	output	reg FIFO_ADDR,
	output	reg FIFO_rst,
	output	reg [15:0]ADC_DATA_OUT,
	output	FIFO_wr_en_buff,
	output	FIFO_wr_clk,
	output	FIFO_data_prepare_ok
	
);
`define ADC_CLK_FREQ 			36_000_000 //frequence of ADC_clk
`define ADC_CHANNEL_CNT			6 
`define ECHO_DELAY_TIME_US 	25
`define SINGLE_CHANNEL_CLK_FREQ `ADC_CLK_FREQ/`ADC_CHANNEL_CNT
`define SAWTOOTH_LONG_MS		1
`define ONE_SAWTOOTH_MAX_SAMPLE_POINT `SINGLE_CHANNEL_CLK_FREQ*`SAWTOOTH_LONG_MS/1000 - `SINGLE_CHANNEL_CLK_FREQ*`ECHO_DELAY_TIME_US/1000_000//8000-40
`define ADC_FIFO_LENGTH    GET_POINT_NUM*ADC_VALUE_CHANNEL_CNT
reg FIFO_wr_en;
wire FIFO_wr_en_en;
assign FIFO_data_prepare_ok = ((Ponit_Cnt >= 1) && (Ponit_Cnt <= 2200))?1'd1:1'd0;
assign FIFO_wr_en_buff = (Ponit_Cnt%14'd20 == 14'd0)?FIFO_wr_en:1'd0;
assign FIFO_wr_clk = ADC_clk;
reg [2:0]STATE;
reg [13:0]Ponit_Cnt;		//max 16383 GET_POINT_NUM
reg [7:0]Sawtooth_Cnt;	//max 1024  for frame counts
reg [10:0]Time_Cnt;		//max 2048

initial begin
	STATE			  = 3'd0	;
	Time_Cnt		  = 11'd0;
	Ponit_Cnt	  = 14'd0;
	Sawtooth_Cnt  = 8'd0;
	FIFO_wr_en	  = 1'd0;
	FIFO_rst	  	  = 1'd0;
	FIFO_ADDR 	  = 1'd0; 
end
//always at rst_n init device
//AD8283_SPI_send #(15) AD8283_SPI_send_U1
//
//(
//	.clk_50M(clk_50M),
//	.rst_n(rst_n),	
//	.CSB(ADC_CSB),
//	.SCLK(ADC_SCLK),
//	.SDIO(ADC_DIO),
//	.ALL_DONE(ALL_DONE),
//	
//	.LAN_PGA_16DB_n(),//not use
//	.LAN_PGA_22DB_n(),//not use
//	.LAN_PGA_28DB_n(),//not use
//	.LAN_PGA_34DB_n(),//not use
//);
always@(negedge ADC_clk or negedge rst_n)begin
	if(!rst_n)
	begin
		STATE			  <= 3'd0;
	end
	else begin
		case(STATE)
		4'd0://wait next SAWTOOTH
			begin
				if(SAWTOOTH_DSYNC)//use SAWTOOTH_DSYNC as start signal
					begin
						STATE	<= STATE + 3'd1;
						FIFO_ADDR <= ~FIFO_ADDR;//change cy pingpong fifo addr
//						FIFO_rst <= 1;
					end
				else
					STATE	<= STATE ;
			end
//DelayTime bigger than echo delay*************************************************
		4'd1:
			begin			
			if(Time_Cnt >= `ECHO_DELAY_TIME_US*`ADC_CLK_FREQ/1000_000-1)begin
					STATE	<= STATE + 3'd1;
					//FIFO_rst <= 0;
					Time_Cnt <= 11'd0; 
					end
				else begin
					Time_Cnt <= Time_Cnt + 11'd1; 
					STATE	<= STATE ;
					//FIFO_rst <= 1;//reset this cy pingpong fifo
					end
			if(Time_Cnt >= `ECHO_DELAY_TIME_US*`ADC_CLK_FREQ/2000_000-1)begin
					FIFO_rst <= 0;			        
			end  
			else begin
			        FIFO_rst <= 1;		
			end
			end
//One point start	********************************************************		
		4'd2://A
			begin
				if(ADC_DSYNC)begin
					STATE	<= STATE + 3'd1;
					FIFO_wr_en <= 1;//enable fifo					
					if(Ponit_Cnt == 14'd0)
						ADC_DATA_OUT <= {4'hE,ADC_DATA};//start flag
					else
						ADC_DATA_OUT <= {4'h1,/*12'h001*/ADC_DATA};
					end 
				else
					STATE	<= STATE ;
			end
		4'd3://B
			begin
				STATE	<= STATE + 3'd1;
				if(Ponit_Cnt == 14'd0)
					ADC_DATA_OUT <= {Sawtooth_Cnt[7:4],/*12'h002*/ADC_DATA};//frame cnt high
				else
					ADC_DATA_OUT <= {4'h2,/*12'h002*/ADC_DATA};
			end
		4'd4://C
			begin 
				STATE	<= STATE + 3'd1;
				if(Ponit_Cnt == 14'd0)
					ADC_DATA_OUT <= {Sawtooth_Cnt[3:0],/*12'h003*/ADC_DATA};//frame cnt low
				else
					ADC_DATA_OUT <= {4'h3,/*12'h002*/ADC_DATA};
			end
		4'd5://D
			begin				
				STATE	<= STATE + 3'd1;
				if(Ponit_Cnt >= 256*20-20-1/*GET_POINT_NUM-1*/)//�?�?(�?个有效采样周�?)结束
				begin
					ADC_DATA_OUT <= {4'hf,/*12'habc*/ADC_DATA};//sawtooth end flag
				end
				else begin
					ADC_DATA_OUT <= {4'h4,/*12'habc*/ADC_DATA};
				end
			end
		4'd6://E
			begin
				FIFO_wr_en <= 0;//disable fifo,only want ABCD channel
				STATE	<= STATE + 3'd1;
			end
		4'd7://F
			begin
				if(Ponit_Cnt >= GET_POINT_NUM-1)//one frame finish
				begin
					STATE				<= 3'd0;
					Ponit_Cnt 		<= 14'd0;
					Sawtooth_Cnt   <= Sawtooth_Cnt + 8'd1;
				end
				else
				begin
					Ponit_Cnt <= Ponit_Cnt + 14'd1;
					STATE	<= 3'd2;
				end
			end	
		default:STATE	<= 3 'd0;
//One point end	********************************************************	
		endcase
	end
end
endmodule
