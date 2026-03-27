---
name: mobilemash
description: Send commands to the MobileMash ESP32 phone button presser via serial. Use when the user wants to press phone buttons, enter fastboot, or check servo status.
argument-hint: "<command> [args]"
allowed-tools: Bash(python3 *)
---

## MobileMash Serial Control

Send a command to the MobileMash ESP32 device connected via USB serial.

### Usage

`/mobilemash <command> [args]`

### Available commands

- `PRESS_POWER <ms>` — Press power button for given milliseconds
- `PRESS_VOLDN <ms>` — Press volume-down button for given milliseconds
- `RELEASE_ALL` — Release all buttons immediately
- `FASTBOOT [shutdown_ms] [combo_ms]` — Full fastboot entry sequence (default: 30s shutdown + 5s combo)
- `PING` — Health check (responds PONG)
- `STATUS` — Show current button states

### Implementation

Run the following to send the command and display the response:

```bash
python3 -c "
import serial, time, sys

cmd = '$ARGUMENTS'
if not cmd.strip():
    print('Usage: /mobilemash <command> [args]')
    print('Commands: PRESS_POWER <ms>, PRESS_VOLDN <ms>, RELEASE_ALL, FASTBOOT, PING, STATUS')
    sys.exit(0)

ser = serial.Serial()
ser.port = '/dev/ttyUSB1'
ser.baudrate = 115200
ser.timeout = 5
ser.dtr = False
ser.rts = False
ser.open()
time.sleep(0.1)
ser.flushInput()
ser.write((cmd + '\n').encode())

# Wait for response — longer for FASTBOOT
wait = 35 if 'FASTBOOT' in cmd else 3
deadline = time.time() + wait
lines = []
while time.time() < deadline:
    if ser.in_waiting:
        line = ser.readline().decode(errors='replace').strip()
        if line:
            print(line)
            lines.append(line)
            if 'complete' in line or 'released' in line or 'PONG' in line or 'STATE' in line or 'ERR' in line:
                break
    time.sleep(0.05)
ser.close()
if not lines:
    print('No response from device')
"
```
