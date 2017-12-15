/**********************************************************
*	Name			:	CYUSB_interface
*	Important		:	Only for cy7c68013's EP6_IN endpoint
*	Origin			:	171206
*	Author			:	Helrori
**********************************************************/
module CYUSB_interface
#(
	parameter BYTE_EVERY_FRAME = 256*4*2
)
(
	//Base
	input clk_48M,
	input clk_48M_180,
	input rst_n,
	//CYUSB in side
	input	FIFO_ADDR,
	input	FIFO_rst,
	input	[15:0]FIFO_DATA_IN,
	input	FIFO_wr_en,
	input	FIFO_wr_clk,
	input	FIFO_data_prepare_ok,	
	//CYUSB out side 
	output	[15:0]CY_DATA,
	output	[1:0]CY_ADDR,
	output	CY_SLRD_N,
	output	reg CY_SLWR_N,
	output	reg CY_PKTEND,
	output	CY_SLOE_N,
	input		CY_FLAGA,
	input		CY_FLAGB,
	output	CY_IFCLK,
	output	reg CY_tell_cy_ifclk_is_OK,
	//test
	output 	[9:0]used_0,
	output 	[9:0]used_1
);
reg [31:0]Time_Cnt;//wait CY_FLAGB stable
reg [7:0]usefull_after_cnt;
wire [15:0]CY_DATA_0,CY_DATA_1;
reg FIFO_rd_en_en;
reg fifo_0_rd_en,fifo_1_rd_en;
wire CY_SLWR_N_buff;
assign CY_SLWR_N_buff = (FIFO_rd_en_en)?CY_SLWR_N:1'd1;
assign CY_DATA = (FIFO_ADDR == 1'd1)?CY_DATA_0:CY_DATA_1;

assign CY_ADDR   = 2'b10;//ep6
assign CY_SLRD_N = 1'd1;
assign CY_SLOE_N = 1'd1;
assign CY_IFCLK  = clk_48M_180;
initial begin
	Time_Cnt 			= 32'd0;
	CY_PKTEND 			= 1'd1;
	CY_SLWR_N 			= 1'd1;
	FIFO_rd_en_en 		= 1'd0;
	usefull_after_cnt 	= 8'd0;
	CY_tell_cy_ifclk_is_OK = 1'd0;
end

always@(posedge CY_IFCLK or negedge rst_n)begin
	if(!rst_n)
		CY_tell_cy_ifclk_is_OK <= 1'd0;
	else
		CY_tell_cy_ifclk_is_OK <= 1'd1;
end
always@(posedge clk_48M or negedge rst_n)begin
	if(!rst_n)
		Time_Cnt <= 32'd0;
	else if(Time_Cnt < 48_000_000)//after FLAGB==0 delay 0.8s
		Time_Cnt <= Time_Cnt + 32'd1;
end
always@(posedge CY_FLAGB or negedge rst_n)begin
	if(!rst_n)
		FIFO_rd_en_en <= 1'd0;
	else if(Time_Cnt>=40000000)begin
		if(FIFO_data_prepare_ok || ((usefull_after_cnt > 8'd0) && (usefull_after_cnt <= BYTE_EVERY_FRAME/512 - 1)))begin//
			FIFO_rd_en_en <= 1'd1;
			usefull_after_cnt <= usefull_after_cnt + 8'd1;
		end else begin
			FIFO_rd_en_en <= 1'd0;
			usefull_after_cnt <= 8'd0;
		end
	end
		
end
//CYUSB in side
reg fifo_0_rst,fifo_1_rst;
reg [15:0]fifo_0_data_in,fifo_1_data_in;
reg fifo_0_wr_en,fifo_1_wr_en;
always@(*)begin
	case(FIFO_ADDR)
		1'd0:fifo_0_rst = FIFO_rst;
		1'd1:fifo_1_rst = FIFO_rst;
	endcase

end
always@(*)begin
	case(FIFO_ADDR)
		1'd0:fifo_0_data_in = FIFO_DATA_IN;
		1'd1:fifo_1_data_in = FIFO_DATA_IN;
	endcase
end 
always@(*)begin
	case(FIFO_ADDR)
		1'd0:fifo_0_wr_en = FIFO_wr_en;
		1'd1:fifo_1_wr_en = FIFO_wr_en;
	endcase
end
always@(*)begin
	case(FIFO_ADDR)
		1'd0:fifo_1_rd_en = ~CY_SLWR_N_buff;
		1'd1:fifo_0_rd_en = ~CY_SLWR_N_buff;
	endcase
end
//
CY_FIFO_0 CY_FIFO_0_U1(
    .rst(fifo_0_rst),
    .wr_clk(FIFO_wr_clk),
    .rd_clk(clk_48M),
    .din(fifo_0_data_in),
    .wr_en(fifo_0_wr_en),
    .rd_en(fifo_0_rd_en),
    .dout(CY_DATA_0),
    .full(),
    .empty(),
    .rd_data_count(),
    .wr_data_count(used_0),
    .wr_rst_busy(),
    .rd_rst_busy()
);

CY_FIFO_1 CY_FIFO_1_U1(
    .rst(fifo_1_rst),
    .wr_clk(FIFO_wr_clk),
    .rd_clk(clk_48M),
    .din(fifo_1_data_in),
    .wr_en(fifo_1_wr_en),
    .rd_en(fifo_1_rd_en),
    .dout(CY_DATA_1),
    .full(),
    .empty(),
    .rd_data_count(),
    .wr_data_count(used_1),
    .wr_rst_busy(),
    .rd_rst_busy()
);

/********************************************************
*	CYUSB STATE MECHINE
*	new cyusb EP6_IN state mechine 256x16bit 
*********************************************************/
reg [1:0]ep6_state;
reg [7:0]Send_Cnt;
reg [9:0]Time_Cnt_III;
initial begin
	ep6_state = 2'd0;
	Send_Cnt = 8'd0;
	Time_Cnt_III = 10'd0;
end
always@(negedge CY_IFCLK or negedge rst_n)begin
	if(!rst_n)begin
		ep6_state <= 2'd0;
		Send_Cnt  <= 8'd0;
		CY_PKTEND <= 1'd1;
		CY_SLWR_N <= 1'd1;
	end
	else begin
		case(ep6_state)
		2'd0:begin// delay after power on,wait CYUSB set IFCLKconfig done.
				if(Time_Cnt>=40000000)
					ep6_state <= ep6_state + 2'd1;
				else
					ep6_state <= ep6_state;
		end
		2'd1:begin
			if(CY_FLAGB==1'd1)begin
				CY_SLWR_N <= 1'd0;
				ep6_state <= ep6_state + 2'd1;
			end
			else
				ep6_state <= ep6_state;
		end
		2'd2:begin
			if(Send_Cnt >= 256 - 1)begin//512 bytes
				CY_SLWR_N <= 1'd1;
				CY_PKTEND	 <= 1'd0;
				Send_Cnt <= 8'd0;
				ep6_state <= ep6_state + 2'd1;
			end
			else begin
				Send_Cnt <= Send_Cnt + 8'd1;
			end
		end
		2'd3:begin//delay 11 clk
			CY_PKTEND	 <= 1'd1;
			if(Time_Cnt_III >= 10'd10-1 )begin
				Time_Cnt_III <= 10'd0;
				ep6_state <= 2'd0;
			end
			else begin
				Time_Cnt_III <= Time_Cnt_III + 10'd1;
			end
		end
		default:ep6_state <= 2'd0;
		endcase
	end
end

endmodule
