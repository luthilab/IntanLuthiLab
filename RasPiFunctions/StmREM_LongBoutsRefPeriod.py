import RPi.GPIO as GPIO
import time
from multiprocessing import Process
from random import randint
import numpy as np 


inREM = [5,13,19,26] 
inNREM = [25,24,23,22]

out = [12,16,20,21]

GPIO.setwarnings(False)

import RPi.GPIO as GPIO
import time
from multiprocessing import Process
from random import randint
import numpy as np 


inREM = [5,13,19,26] 
inNREM = [25,24,23,22]

out = [12,16,20,21]

GPIO.setwarnings(False)

GPIO.setmode(GPIO.BCM)
GPIO.setup(inREM,GPIO.IN, pull_up_down=GPIO.PUD_DOWN)
GPIO.setup(inNREM,GPIO.IN, pull_up_down=GPIO.PUD_DOWN)
GPIO.setup(out, GPIO.OUT)
GPIO.output(out,GPIO.LOW)

## Defining counters
inuse = np.array([0,0,0,0]) # if the led is on 
REMCounter = np.array([0,0,0,0]) 
TimeCalculated = np.array([0,0,0,0])
CounterNoREMAfterLongREM = np.array([0,0,0,0])
MACounter = np.array([0,0,0,0])
LongRemDetected = np.array([0,0,0,0])
TimeNoREMtoWait = np.array([0,0,0,0])
StmTime = np.array([0,0,0,0]);
PostStim = np.array([0,0,0,0]);
REMCounterBuffer= np.array([0,0,0,0]);
jitter = np.array([0,0,0,0]);

v_State = ['Looking','Looking','Looking','Looking'];

inputREM = np.array([0,0,0,0]);
inputNREM = np.array([0,0,0,0]);

totalrecording=0;

if __name__ == '__main__':
    while True:
        
        time.sleep(1)
        
        totalrecording += 1;
        if  totalrecording >= 48*3600:
            GPIO.output(out,GPIO.LOW)
            break;
        
        
        for x in range(4):
            ## Get the inputs             
            inputREM[x] = GPIO.input(inREM[x])
            inputNREM[x] = GPIO.input(inNREM[x])
            
            ## If it is in stimulation 
                
            
            
            if inuse[x] == 1 and StmTime[x]  < 60*20:
                
                StmTime[x] += 1
                continue;
                                
            if inuse[x] == 1 and StmTime[x]  == 60*20:
                
                print('In Post-stimulation animal '+str(x+1))
                v_State[x] = 'Post';
                GPIO.output(out[x] ,GPIO.LOW)
                MACounter[x]  = 0
                REMCounter[x]  = 0
                LongRemDetected[x]  = 0
                CounterNoREMAfterLongREM[x]  = 0
                PostStim[x] = 1          
                StmTime[x] = 0
                inuse[x] = 0
            
            ## It is in poststimulation period            
                
            if PostStim[x] > 60*40:
                PostStim[x]=0;                
                TimeCalculated[x] = 0
                print('Looking for long REM animal '+str(x+1))
                v_State[x] = 'Looking';
                continue;
        
            if PostStim[x] > 0:
                PostStim[x] += 1
                continue;
            
            
            ## Counting Microarousals
            if inputREM[x] == 0 and inputNREM[x] == 0:            
                MACounter[x] +=1
                if MACounter[x]>5:
                    REMCounter[x] = 0                    
                continue;
                
            ## Detection of long bouts of REM
            if inputREM[x] == 1:
                
                if MACounter[x] <= 5 and MACounter[x]>0:
                    REMCounter[x] = REMCounter[x] + MACounter[x];
                    MACounter[x] = 0;
                    
                else:
                    if MACounter[x] > 5:
                        MACounter[x] =0;
                    
                REMCounter[x] += 1
                
                print('in')
                
                # change for 150
                if REMCounter[x] >= 120:
                    
                    LongRemDetected[x] = 1              
                    CounterNoREMAfterLongREM[x] = 0
                    TimeCalculated[x] = 0
                    print('detected Long REM A('+str(x+1)+')')
                    v_State[x] = 'Detected';
                    REMCounterBuffer[x] = REMCounter[x] 
                
            else:
                if LongRemDetected[x] ==1 and TimeCalculated[x] == 0:
                    
                   print(REMCounterBuffer[x])
                   
                   jitter[x] = randint(50,100)
                
                   TimeNoREMtoWait[x] = jitter[x] 
                    
                   TimeCalculated[x]  = 1

                
                   print('Length of REM detected: ('+str(x+1)+') is: ' + str( REMCounterBuffer[x]))
                   print('Jitter: ('+str(x+1)+') is: ' + str( jitter[x]))
                   print('Time to wait for animal ('+str(x+1)+') is: ' + str( TimeNoREMtoWait[x]))
                              
                REMCounter[x] = 0
                  
            
            ## Start counting NREM and start stimulation
            
            if LongRemDetected[x] == 1 and inputNREM[x] ==1:
                
                if MACounter[x] <= 5 and MACounter[x]>0:
                    CounterNoREMAfterLongREM[x] = CounterNoREMAfterLongREM[x] + MACounter[x];
                    MACounter[x] = 0;
                else:
                    if MACounter[x] > 5:
                        MACounter[x] =0;
                
                CounterNoREMAfterLongREM[x] += 1
                
                print('Length of REM detected: ('+str(x+1)+') is: ' + str( REMCounterBuffer[x]))
                print('Jitter: ('+str(x+1)+') is: ' + str( jitter[x]))
                print('Time to wait for animal ('+str(x+1)+') is: ' + str( TimeNoREMtoWait[x]))
                
            
                if CounterNoREMAfterLongREM[x] > TimeNoREMtoWait[x] and inuse[x] == 0:
                    GPIO.output(out[x],GPIO.HIGH)
                    inuse[x] = 1
                    CounterNoREMAfterLongREM[x]=0;
                    print('Start Stimulation REM A('+str(x+1)+')')
                    v_State[x] = 'Stm';
            
                
        #print('Counters')  
        print('State: A1-' + v_State[0]+', A2-'+v_State[1]+', A3-'+v_State[2]+', A4-'+v_State[3])        
        print('REM: A1-' + str(REMCounter[0])+', A2-'+str(REMCounter[1])+', A3-'+str(REMCounter[2])+', A4-'+str(REMCounter[3]))        
        print('NoREM: A1-' + str(CounterNoREMAfterLongREM[0])+', A2-'+str(CounterNoREMAfterLongREM[1])+', A3-'+str(CounterNoREMAfterLongREM[2])+', A4-'+str(CounterNoREMAfterLongREM[3]))        
        print('Stim: A1-' + str(StmTime[0])+', A2-'+str(StmTime[1])+', A3-'+str(StmTime[2])+', A4-'+str(StmTime[3]))        
        print('PostStim: A1-' + str(PostStim[0])+', A2-'+str(PostStim[1])+', A3-'+str(PostStim[2])+', A4-'+str(PostStim[3]))        

