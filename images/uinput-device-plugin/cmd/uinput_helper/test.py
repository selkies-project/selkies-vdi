# /tmp/.uinput/uinput-helper -logtostderr &
import uinput
import time

d = uinput.Device([uinput.BTN_LEFT, uinput.BTN_RIGHT, uinput.REL_X, uinput.REL_Y], name="uinput test mouse")

time.sleep(2)

d.emit(uinput.BTN_LEFT, 1)
time.sleep(0.2)
d.emit(uinput.BTN_LEFT, 0)

del d

# python3 -c 'import uinput; import time; d = uinput.Device([uinput.BTN_LEFT, uinput.BTN_RIGHT, uinput.REL_X, uinput.REL_Y], name="uinput test mouse"); time.sleep(2); d.emit(uinput.BTN_LEFT, 1); time.sleep(0.2); d.emit(uinput.BTN_LEFT, 0); del d'