import RPi.GPIO as GPIO
import time
from datetime import datetime

insREM = (5,6,13,19)
insWake = (9,10,11,22)
outsMotors = (12,16,20,21)
outsLEDs = (7,8,25,24)

GPIO.setmode(GPIO.BCM)

GPIO.setup(insREM, GPIO.IN, pull_up_down=GPIO.PUD_DOWN) # receive information about REMS
GPIO.setup(insWake, GPIO.IN, pull_up_down=GPIO.PUD_DOWN) # receive information about REMS
GPIO.setup(outsMotors, GPIO.OUT) # drive the motors
GPIO.setup(outsLEDS, GPIO.OUT) # drive the motors


activity = [0,0,0,0]
running = 1
counters = [0,0,0,0]

while running == 1:
    
    time.sleep(1)
    
    now = datetime.now().strftime('%H:%M')
    if now == '15:01':
        print('Deprivation finished')
        running = 0
        for i in range(4):
            GPIO.output(outs[i], 0)
        
    for i in range(4):
        
        print('Mouse: ' + str(i+1) + ' stimulated ' + str(counters[i]) + ' times')
        st = GPIO.input(ins[i])
        if st == 1 and activity[i] == 0:
            activity[i] = 11
        if st == 1 and activity[i] == 9:
            # launch stim
            GPIO.output(outs[i], 1)
            time.sleep(2)
            GPIO.output(outs[i], 0)
            counters[i] += 1
        if activity[i] > 0:
            activity[i] = activity[i]-1
            
input("Press Enter to quit...")

        