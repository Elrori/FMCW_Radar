# FMCW_Radar

FMCW Radar verilog project,24GHz调频连续波雷达中频采样上传模块verilog描述. 

测试硬件：ADC AD8285 CFK110A1T2R K-band 微波雷达模组(ADF4159+ADF5901+?) , xilinx artix-7 , CY7C68013A.斜坡长度ms级，采样率200K，2D FFT 256x256，最远距离100m。

测试中为了快速验证，包含两个python程序，用于测试硬件和简单的2D FFT绘图，csharp程序依此进行编写。

PC image show 2d fft plot with csharp project
![Image](https://github.com/Elrori/FMCW_Radar/blob/master/xx.png)

