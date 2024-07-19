# This function checks the state of four TTL entries from the Intan/OpenEphys system (one per animal) and activates a process of 1 Hz-30 ms TTL signal to drive a LED for optogenetic stimulation. This function is only activated in the first 20 mins of each clock hour.

import RPi.GPIO as GPIO
import time
import datetime
from multiprocessing import Process
from random import randint

in1 = 5
in2 = 6
in3 = 13
in4 = 19

out1 = 12
out2 = 16
out3 = 20
out4 = 21

GPIO.setwarnings(False)

GPIO.setmode(GPIO.BCM)
GPIO.setup((in1, in2, in3, in4), GPIO.IN, pull_up_down=GPIO.PUD_DOWN)
GPIO.setup((out1, out2, out3, out4), GPIO.OUT)


## Stimulation process, this process produces a 1 Hz stimulation of 30 ms per pulse.
def stimulation(out):
    time.sleep(1)
    while True:
        GPIO.output(out, GPIO.HIGH)
        time.sleep(.03)
        GPIO.output(out, GPIO.LOW)
        time.sleep(.7)
        
       
## Main block      
inuse1 = 0
inuse2 = 0
inuse3 = 0
inuse4 = 0
idxNR1 = 0
idxNR2 = 0
idxNR3 = 0
idxNR4 = 0
idxOther1 = 0
idxOther2 = 0
idxOther3 = 0
idxOther4 = 0
                

if __name__ == '__main__':
    while True:
        
        time.sleep(1)
        
        input1 = GPIO.input(in1)
        input2 = GPIO.input(in2)
        input3 = GPIO.input(in3)
        input4 = GPIO.input(in4)
        
        print(str(input1)+str(input2)+str(input3)+str(input4))
        
        CurrTime = datetime.datetime.now().strftime("%H:%M:%S");
        print("Minute:" , CurrTime[3:5]);
        
        # Check the current clock time, if the time corresponds to the first 20 min of each hour, check the state of the input TTL for each animal and activate the corresponding output process (See stimulation process) if the input is high (Digital 1). Stop the stimulation process if the TTL input is low (Digital 0) for more than 3 seconds.
                
        if int(CurrTime[3:5])>=00 and int(CurrTime[3:5])<=20:
            
            print('Stimulation period')
            ## Animal1stimulation
            if input1 == 1:
                idxNR1=idxNR1+1;
                idxOther1=0;
            else:
                idxOther1 = idxOther1+1;
                if idxOther1 >=3:
                    idxNR1=0;
                    
            if idxNR1>=10 and inuse1 == 0:
                p1 = Process(target=stimulation, args=(out1,))
                p1.start()
                inuse1 = 1
                
            elif idxNR1 == 0 and inuse1 == 1:           
                p1.terminate()
                p1.join()
                GPIO.output(out1,GPIO.LOW)
                inuse1 = 0
            
            ## Animal2
            if input2 == 1:
                idxNR2=idxNR2+1;
                idxOther2=0;
            else:
                idxOther2 = idxOther2+1;
                if idxOther2 >=3:
                    idxNR2=0;
                    
            if idxNR2>=10 and inuse2 == 0:
                p2 = Process(target=stimulation, args=(out2,))
                p2.start()
                inuse2 = 1
                
            elif idxNR2 == 0 and inuse2 == 1:           
                p2.terminate()
                p2.join()
                GPIO.output(out2,GPIO.LOW)
                inuse2 = 0
        
            ## Animal3
            if input3 == 1:
                idxNR3=idxNR3+1;
                idxOther3=0;
            else:
                idxOther3 = idxOther3+1;
                if idxOther3 >=3:
                    idxNR3=0;
                    
            if idxNR3>=10 and inuse3 == 0:
                p3 = Process(target=stimulation, args=(out3,))
                p3.start()
                inuse3 = 1
                
            elif idxNR3 == 0 and inuse3 == 1:           
                p3.terminate()
                p3.join()
                GPIO.output(out3,GPIO.LOW)
                inuse3 = 0
            
            ## Animal4
            if input4 == 1:
                idxNR4=idxNR4+1;
                idxOther4=0;
            else:
                idxOther4 = idxOther4+1;
                if idxOther4 >=3:
                    idxNR4=0;
                    
            if idxNR4>=10 and inuse4 == 0:
                p4 = Process(target=stimulation, args=(out4,))
                p4.start()
                inuse4 = 1
                
            elif idxNR4 == 0 and inuse4 == 1:           
                p4.terminate()
                p4.join()
                GPIO.output(out4,GPIO.LOW)
                inuse4 = 0
        else:
            print('Resting period')
            if inuse1 ==1:
                GPIO.output(out1,GPIO.LOW)
                inuse1 = 0;
                idxNR1 = 0;
                p1.terminate()
                p1.join()
            
            if inuse2 ==1:
                GPIO.output(out2,GPIO.LOW)
                inuse2 = 0;
                idxNR2 = 0;
                p2.terminate()
                p2.join()
            
            if inuse3 ==1:
                GPIO.output(out3,GPIO.LOW)
                inuse3 = 0;
                idxNR3 = 0;
                p3.terminate()
                p3.join()
            
            if inuse4 ==1:
                GPIO.output(out4,GPIO.LOW)
                inuse4 = 0;
                idxNR4 = 0;
                p4.terminate()
                p4.join()
            
        