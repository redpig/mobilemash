#pragma once

// ---------- Servo GPIO pins ----------
#define PIN_SERVO_POWER   13
#define PIN_SERVO_VOLDN   14

// ---------- Servo angles (degrees) ----------
// "Released" = arm is away from the button.
// "Pressed"  = arm pushes the button.
// Tune these per-build until the arm cleanly presses the button.
#define ANGLE_POWER_RELEASED  0
#define ANGLE_POWER_PRESSED   75

#define ANGLE_VOLDN_RELEASED  0
#define ANGLE_VOLDN_PRESSED   55

// ---------- Timing defaults (ms) ----------
#define DEFAULT_SHUTDOWN_HOLD_MS   35000   // 35 s power hold for force-off
#define DEFAULT_FASTBOOT_COMBO_MS   5000   // 5 s vol-down + power tap
#define POWER_TAP_MS                1000   // brief power press in combo
#define SAFETY_TIMEOUT_MS          60000   // hard cap on any single hold

// ---------- Serial ----------
#define SERIAL_BAUD  115200
