# -*- coding: utf-8 -*-
#
#   Name        :radar lib for get data and simple test the device
#   Origin      :171204
#   Author      :helrori
#
import numpy as np
import sys
import threading
import usb.core
import usb.util
from matplotlib import pyplot as plt
import scipy.signal as signal
class RadarProcess(object):
    def __init__(self,usbdev = None,FFT_LENGTH = 256,CHANNEL_NUM = 4):
        self.dev = usbdev
        self.FFT_LENGTH = FFT_LENGTH
        self.CHANNEL_NUM = CHANNEL_NUM
        self.window = np.hanning(FFT_LENGTH)
    def two_comp_to_offset_binary(self,channel_data):
        if (channel_data>>11)==0x01:
            channel_data -= 1
            channel_data = ~channel_data
            channel_data &=0x0fff
            return   0-channel_data
        else:
            return channel_data
    def data_trans(self,all_data,FFT_LENGTH,CHANNEL_NUM):
        WORD_DAT_LENGTH=FFT_LENGTH*CHANNEL_NUM
        BYTE_DAT_LENGTH=2*WORD_DAT_LENGTH
        true_data      = np.array([0]*(BYTE_DAT_LENGTH//2))
        A_channel_data = np.array([0]*FFT_LENGTH)
        B_channel_data = np.array([0]*FFT_LENGTH)
        C_channel_data = np.array([0]*FFT_LENGTH)
        D_channel_data = np.array([0]*FFT_LENGTH)
        for i in range(0,WORD_DAT_LENGTH):
            true_data[i] =  all_data[2*i] + ((all_data[2*i+1]&0x0f)<<8)    
        for i in range(0,WORD_DAT_LENGTH,4):
            A_channel_data[i//4] =  self.two_comp_to_offset_binary(true_data[i])
        for i in range(1,WORD_DAT_LENGTH,4):
            B_channel_data[i//4] =  self.two_comp_to_offset_binary(true_data[i])
        for i in range(2,WORD_DAT_LENGTH,4):
            C_channel_data[i//4] =  self.two_comp_to_offset_binary(true_data[i])
        for i in range(3,WORD_DAT_LENGTH,4):
            D_channel_data[i//4] =  self.two_comp_to_offset_binary(true_data[i])
        return A_channel_data,B_channel_data,C_channel_data,D_channel_data
    #    print(A_channel_data[0],B_channel_data[0],C_channel_data[0],D_channel_data[0])
    #    return np.array type

    def get_frames(self,Nframes = 1):
        frame_head_flag_fail = 0
        BYTE_DAT_LENGTH = 2*self.FFT_LENGTH*self.CHANNEL_NUM
        i = 0
        if Nframes==1:# Sure that data from ADC is useful
            while 1:
                while 1:
                    frist_data = self.dev.read(0x86,512)
                    if (frist_data[1]//16) == 0xe and (frist_data[7]//16) != (frist_data[9]//16):
                        frame_head_flag_fail = 0
                        break
                    else:
                        frame_head_flag_fail +=1
                        if frame_head_flag_fail == 100:
                            print('Time out : frame_head_flag_fail 100 times')
                            sys.exit(1)
                other_data = self.dev.read(0x86,BYTE_DAT_LENGTH-512)
                all_data = frist_data + other_data
                if all_data[BYTE_DAT_LENGTH-1]//16 == 0xf: #有结束标志
                    frame_end_flag_fail = 0
                    break
            return  self.data_trans(all_data,self.FFT_LENGTH,self.CHANNEL_NUM)
        else:# NOT sure that data from ADC is CONTINUOUS but is useful
            AIBQ_buff = np.zeros(shape=(Nframes,self.FFT_LENGTH),dtype=complex)
            CIDQ_buff = np.zeros(shape=(Nframes,self.FFT_LENGTH),dtype=complex)
            all_data_all_frames = np.ones((Nframes,BYTE_DAT_LENGTH),dtype=int)
            frame = [0]*Nframes
            while i<Nframes:
                while 1:
                    frist_data = self.dev.read(0x86,512)
                    if (frist_data[1]//16) == 0xe and (frist_data[7]//16) != (frist_data[9]//16):
                        frame_head_flag_fail = 0
                        break
#                    else:
#                        frame_head_flag_fail +=1
#                        if frame_head_flag_fail == 50:
#                            print('Time out : frame_head_flag_fail 50 times')
#                            sys.exit(1)
                all_data = frist_data + self.dev.read(0x86,BYTE_DAT_LENGTH-512)
                # One frame Success
                if all_data[BYTE_DAT_LENGTH-1]//16 == 0xf:
                    frame[i] = (all_data[3]>>4)*16+(all_data[5]>>4)
                    all_data_all_frames[i,:] = all_data[:]
                    i+=1
            for i in range(0,Nframes):
                A_I,B_Q,C_I,D_Q = self.data_trans(all_data_all_frames[i,:],self.FFT_LENGTH,self.CHANNEL_NUM)
                #every channel use hamming window
                AIBQ_buff[i,:] = self.window*A_I[:] + 1j*(B_Q[:]*self.window)
                CIDQ_buff[i,:] = self.window*C_I[:] + 1j*(D_Q[:]*self.window)
            # return complex 2d (array([[x x x...FFT_LENGTH],[],...]),array([[x x x...FFT_LENGTH],[],...]))
            return AIBQ_buff,CIDQ_buff,frame

    def getMAXPositon(self,a):
        return np.where(a == np.max(a))
    def getMAX5Position(self,a):
        x,y = np.where(a == np.max(a))       
        buff = a[x,y]
        a[x,y] = 0 # caution !!!!!!!
        x2,y2 = np.where(a == np.max(a))        
        buff2 = a[x2,y2]
        a[x2,y2] = 0 # caution !!!!!!!
        x3,y3 = np.where(a == np.max(a))
        buff3 = a[x3,y3]
        a[x3,y3] = 0 # caution !!!!!!!
        x4,y4 = np.where(a == np.max(a))
        buff4 = a[x4,y4]
        a[x4,y4] = 0 # caution !!!!!!!
        x5,y5 = np.where(a == np.max(a))
        a[x,y] = buff
        a[x2,y2] = buff2
        a[x3,y3] = buff3
        a[x4,y4] = buff4
        return x,y,x2,y2,x3,y3,x4,y4,x5,y5
if __name__ == "__main__":
    print('Radar Device Test:')
    idVendor  = 0x04b4
    idProduct = 0x1003 #new pid the old one is 0x1003
    print('idVendor idProduct :')
    print(hex(idVendor),hex(idProduct))
    FFT_LENGTH   = 256
    FFT2D_LENGTH = 256
    CHANNEL_NUM  = 4
    dev = usb.core.find(idVendor=idVendor, idProduct=idProduct)#指定PID VID
    if dev is None:
        raise ValueError('Device not found')
    dev.set_configuration()
    dev.read(0x86,512*4)#清空CYUSB FIFO 4*512
    rp = RadarProcess(dev,FFT_LENGTH = FFT_LENGTH,CHANNEL_NUM = CHANNEL_NUM)
    print('Getting frames',FFT2D_LENGTH,'...')
    AB,CD,frame= rp.get_frames(FFT2D_LENGTH)
#
#   Process
#
    #短时间瀑布图测试
#    plt.specgram(AB.flatten(), NFFT=256, Fs=1000000,cmap=plt.cm.bwr)
#    plt.xlabel("Time[s]")
#    plt.ylabel("Frequency[Hz]")
#    plt.show()

    #FFT2D
    #AB = np.fromfile('1.bin',dtype = complex)
    AB.tofile('x.bin')
    fig = plt.figure()
    data = np.abs(np.fft.fft2(AB))
    buff = np.log10(np.fft.fftshift(data))

    
    x,y = rp.getMAXPositon(buff[:])
    print(x,y)
    x,y,x2,y2,x3,y3,x4,y4,x5,y5 = rp.getMAX5Position(buff[:])
    print(x,y,x2,y2,x3,y3,x4,y4,x5,y5)
    im = plt.imshow(buff,cmap=plt.cm.jet)#[FFT_LENGTH//2:,FFT2D_LENGTH//2:]
    plt.colorbar(im)
    plt.show()
    

#    data = np.ones((256,256))
#    for i in range(0,256):
#        data[i ,:] = np.abs(np.fft.fftshift(np.fft.fft(AB[i,:])))
#    fig = plt.figure()
#    im = plt.imshow(np.log10(data))#[FFT_LENGTH//2:,FFT2D_LENGTH//2:]
#    plt.colorbar(im)
#    plt.show()
    
#    plt.psd(AB[0,:], NFFT=2048, Fs=2000000)
#    plt.show() 

#    plt.scatter(np.real(AB[1,:]), np.imag(AB[1,:]))
#    plt.show()

#    Fs = 2000000
#    fc = np.exp(-1.0j*2.0*np.pi* 50000/Fs*np.arange(len(AB[0,:])))
# Try plotting this complex exponential with a scatter plot of the complex plan - 
# what do you expect it to look like?
#    y = AB[0,:] * fc
# How has our PSD changed?
#    plt.psd(AB[0,:], NFFT=1024, Fs=Fs, color="blue")  # original
#    plt.psd(y, NFFT=1024, Fs=Fs, color="green")  # translated
#    plt.title("PSD of 'signal' loaded from file")
#    plt.show()


# What happens when you filter your data with a lowpass filter?
#    f_bw = 60000
#    Fs  = 300000
#    n_taps = 64 
#    lpf = signal.remez(n_taps, [0, f_bw, f_bw+(Fs/2-f_bw)/4, Fs/2], [1,0], Hz=Fs)
# Plot your filter's frequency response:
 #   w, h = signal.freqz(lpf)
 #   plt.plot(w, 20 * np.log10(abs(h)))
 #   plt.xscale('log')
 #   plt.title('Filter frequency response')
 #   plt.xlabel('Frequency')
 #   plt.ylabel('Amplitude')
 #   plt.margins(0, 0.1)
 #   plt.grid(which='both', axis='both')
 #   plt.show()
#    y = signal.lfilter(lpf, 1.0, AB[0,:])
# How has our PSD changed?
#    plt.psd(AB[0,:], NFFT=1024, Fs=300000, color="blue")  # original
#    plt.psd(y, NFFT=1024, Fs=300000, color="green")  # filtered
#    plt.title("PSD of 'signal' loaded from file")
#    plt.show()

#    f_bw = 500000
#    Fs = 2000000
#    dec_rate = int(Fs / f_bw)
#    z = signal.decimate(y, dec_rate)
#    Fs_z = Fs/dec_rate
# New PSD - now with new Fs
#    plt.psd(z, NFFT=1024, Fs=Fs_z, color="blue")
#    plt.show()


#
#   Process end
#
  
    print(frame)
    not_streaming_count = 0
    frame_place = []
    for i in range(0,FFT2D_LENGTH-1):
        if frame[i] == 255:
            if frame[i+1] != 0:
                not_streaming_count+=1
                frame_place.append(frame[i])
        else:
            if frame[i]!=frame[i+1]-1 :
                not_streaming_count+=1
                frame_place.append(frame[i])
    print('Streaming fail numbers :',not_streaming_count)
    print('Fail frame place       :',frame_place)
    print('Test done')
    input()
