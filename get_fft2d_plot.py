# -*- coding: utf-8 -*-
#
#   Name : fft2d plot
#   Origin:171202
#   Author:helrori
#
import sys
import threading
import numpy as np
import scipy as sp
import pylab as pyl
import matplotlib.pyplot as plt
import matplotlib.animation as animation
import matplotlib.lines as line
from matplotlib.mlab import psd
import usb.core
import usb.util
from radar_data_transform_lib import *
idVendor  = 0x04b4
idProduct = 0x1003
FFT_LENGTH   = 256
FFT2D_LENGTH = 256
CHANNEL_NUM  = 4
WORD_DAT_LENGTH   = FFT_LENGTH*CHANNEL_NUM
BYTE_DAT_LENGTH   = 2*WORD_DAT_LENGTH
DISPLAY_POINT_NUM = FFT_LENGTH

class FFT2DAnimation(object):
    keyboard_buffer = []
    shift_key_down = False
    image_buffer = -100*np.ones((FFT_LENGTH, FFT2D_LENGTH//2))
    #image_buffer = -100*np.ones((FFT_LENGTH//2, FFT2D_LENGTH))
    xy = [0]*10
    def __init__(self, rp=None, fig=None):
        self.fig = fig if fig else pyl.figure() 
        self.rp = rp 
        self.init_plot()   
    def init_plot(self):
        self.ax = self.fig.add_subplot(1,1,1)
        #self.image = self.ax.imshow(self.image_buffer, aspect='auto',\
        #                            interpolation='nearest', vmin=3, vmax=9,cmap=plt.cm.jet)
        self.image = self.ax.imshow(self.image_buffer,  aspect='auto',interpolation='nearest',vmin=3, vmax=8000000,cmap=plt.cm.jet)
        self.fig.colorbar(self.image)
        self.ax.set_xlabel('Distence[0.703m/ponit]')
        self.ax.set_ylabel('Velocity[+-0.012(m/s)/point]')
        

    def update(self, *args):
        self.image.set_array(self.image_buffer)
        return self.image,
    
    def init_func(self):
        self.ax.text(self.xy[3],self.xy[2],(self.xy[2],self.xy[3]),color = 'm')
        return self.ax,
    
    def start(self):
        if sys.platform == 'darwin':
            blit = False
        else:
            blit = True
        t = threading.Thread(target=self.data_capture_and_trans_thread, name='LoopThread')
        t.start()
        ani = animation.FuncAnimation(self.fig, self.update, interval=100,blit=blit)#init_func=self.init_func,
        pyl.show()
        return
    def data_capture_and_trans_thread(self):
        ABfft2dImage = np.ones((FFT_LENGTH,FFT2D_LENGTH))
        complexbuff = np.ones((FFT_LENGTH,FFT2D_LENGTH),dtype=complex)
        while True:
            AB,CD,frame  = self.rp.get_frames(FFT2D_LENGTH)           
#            ABfft2dImage = np.log10(np.abs(np.fft.fftshift(np.fft.fft2(AB))))
            for i in range(0,256):
                complexbuff[i,:] = np.fft.fft(AB[i,:])
            for i in range(0,256):
                asum = np.sum(complexbuff[:,i])
                asum = asum/256
                complexbuff[:,i] = complexbuff[:,i] - asum
            for i in range(0,256):
                ABfft2dImage[:,i] = (np.abs(np.fft.fft(np.hanning(FFT2D_LENGTH)*complexbuff[:,i])))
            ABfft2dImage  =np.fft.fftshift(ABfft2dImage)           
            self.image_buffer = ABfft2dImage[:,0:128] 
            #AB.tofile('3.bin')
            x1,y1,x2,y2,x3,y3,x4,y4,x5,y5 = self.rp.getMAX5Position(ABfft2dImage[:,0:FFT2D_LENGTH//2])
            range1 = 0.6*(128-y1)
            range2 = 0.6*(128-y1)
            range3 = 0.6*(128-y1)
            range4 = 0.6*(128-y1)
            range5 = 0.6*(128-y1)
            if x1<128:
                print('V1:%.2fm/s'%(-0.012*(127-x1)))
            else:
                print('V1:%.2fm/s'%(0.012*(x1-128)))
            print('1%5.1fm  2%5.1fm  3%5.1fm  4%5.1fm  5%5.1fm'%(range1,range2,range3,range4,range5))
if __name__ == "__main__":
    dev = usb.core.find(idVendor=idVendor, idProduct=idProduct)#指定PID VID
    if dev is None:
        raise ValueError('Device not found')
    dev.set_configuration()
    dev.read(0x86,512*4)#清空CYUSB FIFO 4*512
    rp = RadarProcess(dev,FFT_LENGTH = FFT_LENGTH,CHANNEL_NUM = CHANNEL_NUM)
    fft2d = FFT2DAnimation(rp)
    fft2d.start()

