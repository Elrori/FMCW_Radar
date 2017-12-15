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
        
#        self.ax.set_xticks(np.linspace(0,89.984,128)) 
#        self.ax.set_xticklabels( ('90', '80', '70', '60', '50',  '40',  '30',  '20', '10'))
#        self.ax.set_yticklabels( ('1', '1.536', '0.9216', '0.3072', '-0.3072','-0.9216','-1.536','8','9','10','11'))  #('1.536', '1.152', '0.768', '0.384', '0',  '-0.384',  '-0.768',  '-1.152', '-1.536')
#        self.ax.get_yaxis().set_visible(False)

#        self.fig.canvas.mpl_connect('scroll_event', self.on_scroll)
#        self.fig.canvas.mpl_connect('key_press_event', self.on_key_press)
#        self.fig.canvas.mpl_connect('key_release_event', self.on_key_release)

#    def update_plot_labels(self):
#        fc = self.sdr.fc
#        rs = self.sdr.rs
#        freq_range = (fc - rs/2)/1e6, (fc + rs*(NUM_SCANS_PER_SWEEP - 0.5))/1e6
#        self.image.set_extent(freq_range + (0, 1))
#        self.fig.canvas.draw_idle()

#    def on_scroll(self, event):
#        if event.button == 'up':
#            self.sdr.fc += FREQ_INC_FINE if self.shift_key_down else FREQ_INC_COARSE
#            self.update_plot_labels()
#        elif event.button == 'down':
#            self.sdr.fc -= FREQ_INC_FINE if self.shift_key_down else FREQ_INC_COARSE
#            self.update_plot_labels()

#    def on_key_press(self, event):
#        if event.key == '+':
#            self.sdr.gain += GAIN_INC
#        elif event.key == '-':
#            self.sdr.gain -= GAIN_INC
#        elif event.key == ' ':
#            self.sdr.gain = 'auto'
#        elif event.key == 'shift':
#            self.shift_key_down = True
#        elif event.key == 'right':
#            self.sdr.fc += FREQ_INC_FINE if self.shift_key_down else FREQ_INC_COARSE
#            self.update_plot_labels()
#        elif event.key == 'left':
#            self.sdr.fc -= FREQ_INC_FINE if self.shift_key_down else FREQ_INC_COARSE
#            self.update_plot_labels()
#        elif event.key == 'enter':
#            # see if valid frequency was entered, then change center frequency
#            try:
#                # join individual key presses into a string
#                input = ''.join(self.keyboard_buffer)
#
#                # if we're doing multiple adjacent scans, we need to figure out
#                # the appropriate center freq for the leftmost scan
#                center_freq = float(input)*1e6 + (self.sdr.rs/2)*(1 - NUM_SCANS_PER_SWEEP)
#                self.sdr.fc = center_freq
#
#                self.update_plot_labels()
#            except ValueError:
#                pass
#
#            self.keyboard_buffer = []
#        else:
#            self.keyboard_buffer.append(event.key)

#    def on_key_release(self, event):
#        if event.key == 'shift':
#            self.shift_key_down = False

    def update(self, *args):
        # save center freq. since we're gonna be changing it
#        start_fc = self.sdr.fc

        # prepare space in buffer
        # TODO: use indexing to avoid recreating buffer each time
#        self.image_buffer = np.roll(self.image_buffer, 1, axis=0)

#        for scan_num, start_ind in enumerate(range(0, NUM_SCANS_PER_SWEEP*NFFT, NFFT)):
#            self.sdr.fc += self.sdr.rs*scan_num

            # estimate PSD for one scan
#            samples = self.sdr.read_samples(NUM_SAMPLES_PER_SCAN)
#            psd_scan, f = psd(samples, NFFT=NFFT)

#            self.image_buffer[0, start_ind: start_ind+NFFT] = 10*np.log10(psd_scan)


#        AB,CD,frame  = self.rp.get_frames(FFT2D_LENGTH)
#        ABfft2dImage = np.log10(np.abs(np.fft.fft2(AB)))
#        self.image_buffer = ABfft2dImage
#        self.data_capture_thread()
        self.image.set_array(self.image_buffer)
        
#        x,y,x2,y2,x3,y3,x4,y4,x5,y5 = self.rp.getMAX5Position(ABfft2dImage)
#        self.ax.scatter(self.xy[3],self.xy[2],marker = 'x', color = 'm', s = 30)
#        self.ax.text(self.xy[3],self.xy[2],'x',color = 'm',fontsize=8)
#        self.fig.text(0.12,0.05,self.xy[3])
        return self.image,
    
    def init_func(self):
        self.ax.text(self.xy[3],self.xy[2],(self.xy[2],self.xy[3]),color = 'm')
        return self.ax,
    
    def start(self):
#        self.update_plot_labels()
        if sys.platform == 'darwin':
            # Disable blitting. The matplotlib.animation's restore_region()
            # method is only implemented for the Agg-based backends,
            # which the macosx backend is not.
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

