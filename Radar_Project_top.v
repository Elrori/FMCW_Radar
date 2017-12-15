/**************************************************************************************
*	Name		:Radar Project top
*	Important	:Only transport data from FMCW radar'S ADC to PC.
*				 2d fft 256*256 points
*				 T = 1ms;Fs = 300KHz 
*	Origin		:171122
*				 171201
*	Author		:Helrori2011@gmail.com
***************************************************************************************/
module Radar_Project_top
(
	input   _clk_100M,
	input	_rst_n,
	//ADF4158 port 
	input	SAWTOOTH_DSYNC,
	//ADC data port in
	input	ADC_clk,//single end 48Mhz 
	input	ADC_DSYNC,
	input	[11:0]ADC_DATA,
	//CYUSB port FPGA only use ep6_in,mean that FPGA ignore data from PC
	output	[15:0]CY_DATA,
	output	[1:0]CY_ADDR,
	output	CY_SLRD_N,
	output	CY_SLWR_N,
	output	PKTEND,
	output	CY_SLOE_N,
	input	CY_FLAGA,
	input	CY_FLAGB,
	output	CY_IFCLK,
	output	CY_tell_cy_ifclk_is_OK,
	
	output GND0,
    output GND1,
    output GND2,
    output GND3
);
`define EP2_NOTHING     		(CY_FLAGA==1'd0)
`define EP6_FULL       		 	(CY_FLAGB==1'd0)
`define FFT1D_LENGTH      		256
`define ADC_VALUE_CHANNEL_CNT	4
wire clk_48M,clk_48M_180,clk_50M,clk_200M,rst_n;
wire [9:0] used_0,used_1;
reg [17:0]Time_Cnt_II;
reg [31:0]Time_Cnt;
wire fifo_data_prepare_ok;
wire sawtooth_dsync; 
assign GND0 = 1'b0;
assign GND1 = 1'b0;
assign GND2 = 1'b0;
assign GND3 = 1'b0;
initial begin
	Time_Cnt 			= 32'd0;
	Time_Cnt_II 		= 18'd0;
end
clk_wiz_0 clk_wiz_0_U1
(
	.reset(!_rst_n),
	.inclk0(_clk_100M),//100Mhz
	.c0(clk_50M),		//50Mhz
	.c1(clk_200M),		//200Mhz
	.c2(clk_48M),		//48Mhz
	.c3(clk_48M_180),
	.locked(rst_n)
);

always@(posedge clk_50M or negedge rst_n)begin
	if(!rst_n)
		Time_Cnt_II <= 18'd0;
	else if(Time_Cnt_II >= 18'd50_000 -1)
		Time_Cnt_II <= 18'd0;
	else
		Time_Cnt_II <= Time_Cnt_II + 18'd1;
end
assign sawtooth_dsync = (Time_Cnt_II < 1250)?1'd1:1'd0;//0.025ms\\1ms//sawtooth_dsync only for inside test
/********************************************************
*	ADC8283 PART
*********************************************************/
wire FIFO_ADDR,FIFO_rst,FIFO_wr_en,FIFO_data_prepare_ok,FIFO_wr_clk;
wire [15:0]FIFO_DATA_IN;
AD_interface #(256*20,`ADC_VALUE_CHANNEL_CNT)
AD_interface_U1
(
	.clk_50M(clk_50M),
	.rst_n(rst_n),		//init the device
	//ADF4158 port 
	.SAWTOOTH_DSYNC( SAWTOOTH_DSYNC ),
	//ADC data port in
	.ADC_clk(ADC_clk),//single end 48Mhz 
	.ADC_DSYNC(ADC_DSYNC),
	.ADC_DATA(ADC_DATA),
	//output	
	.FIFO_ADDR(FIFO_ADDR),
	.FIFO_rst(FIFO_rst),
	.ADC_DATA_OUT(FIFO_DATA_IN),
	.FIFO_wr_en_buff(FIFO_wr_en),
	.FIFO_wr_clk(FIFO_wr_clk),
	.FIFO_data_prepare_ok(FIFO_data_prepare_ok)

);
/********************************************************
*	CYUSB PART
*********************************************************/
CYUSB_interface 
#(	`FFT1D_LENGTH*`ADC_VALUE_CHANNEL_CNT*2)
CYUSB_interface_U1
(
	//Base
	.clk_48M(clk_48M),
	.clk_48M_180(clk_48M_180),
	.rst_n(rst_n),
	//CYUSB in side
	.FIFO_ADDR(FIFO_ADDR),
	.FIFO_rst(FIFO_rst),
	.FIFO_DATA_IN(FIFO_DATA_IN),
	.FIFO_wr_en(FIFO_wr_en),
	.FIFO_wr_clk(FIFO_wr_clk),
	.FIFO_data_prepare_ok(FIFO_data_prepare_ok),	
	//CYUSB out side 
	.CY_DATA(CY_DATA),
	.CY_ADDR(CY_ADDR),
	.CY_SLRD_N(CY_SLRD_N),
	.CY_SLWR_N(CY_SLWR_N),
	.CY_PKTEND(PKTEND),
	.CY_SLOE_N(CY_SLOE_N),
	.CY_FLAGA(CY_FLAGA),
	.CY_FLAGB(CY_FLAGB),
	.CY_IFCLK(CY_IFCLK),
	.CY_tell_cy_ifclk_is_OK(CY_tell_cy_ifclk_is_OK),
	//test
	.used_0(used_0),
	.used_1(used_1)


);

endmodule
