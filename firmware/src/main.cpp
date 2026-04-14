/*
 * MobileMash – ESP32 phone-button presser firmware
 *
 * Drives two SG90 servos (power button, volume-down button) via simple
 * ASCII commands over USB serial.  Primary use case: programmatic fastboot
 * entry for Pixel phones.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include <Arduino.h>
#include <ESP32Servo.h>
#include "config.h"

// ── Servos ──────────────────────────────────────────────────────────────
Servo servoPower;
Servo servoVolDn;

static bool powerPressed = false;
static bool volDnPressed = false;

// ── Helpers ─────────────────────────────────────────────────────────────
// Attach a servo, move it, wait for it to settle, then detach to stop
// drawing current.  SG90 servos hold position via gear friction.

static const unsigned long SETTLE_MS = 300;  // time for servo to reach target

static void moveAndDetach(Servo &servo, int pin, int angle) {
    servo.attach(pin, 500, 2400);
    servo.write(angle);
    delay(SETTLE_MS);
    servo.detach();
}

// Gradually ramp a servo to target angle in small steps to limit inrush current.
static void slowMove(Servo &servo, int pin, int from, int to) {
    servo.attach(pin, 500, 2400);
    int step = (to > from) ? 3 : -3;
    for (int a = from; (step > 0) ? (a < to) : (a > to); a += step) {
        servo.write(a);
        delay(20);
    }
    servo.write(to);
    delay(SETTLE_MS);
    servo.detach();
}

static void pressPower() {
    moveAndDetach(servoPower, PIN_SERVO_POWER, ANGLE_POWER_PRESSED);
    powerPressed = true;
}
static void releasePower() {
    moveAndDetach(servoPower, PIN_SERVO_POWER, ANGLE_POWER_RELEASED);
    powerPressed = false;
}
static void pressVolDn() {
    moveAndDetach(servoVolDn, PIN_SERVO_VOLDN, ANGLE_VOLDN_PRESSED);
    volDnPressed = true;
}
static void releaseVolDn() {
    moveAndDetach(servoVolDn, PIN_SERVO_VOLDN, ANGLE_VOLDN_RELEASED);
    volDnPressed = false;
}
static void releaseAll() {
    releasePower();
    releaseVolDn();  // sequential — never two servos at once
}

// Block while holding, but keep reading serial for an early-release command.
// Returns true if we were interrupted by RELEASE_ALL, false if the duration
// expired normally.
static bool holdWithInterrupt(unsigned long durationMs) {
    unsigned long start = millis();
    while (millis() - start < durationMs) {
        if (Serial.available()) {
            String line = Serial.readStringUntil('\n');
            line.trim();
            if (line == "RELEASE_ALL") {
                releaseAll();
                Serial.println("OK RELEASE_ALL (interrupted hold)");
                return true;
            }
        }
        delay(10);
    }
    return false;
}

// ── Command handlers ────────────────────────────────────────────────────

// Attach a servo and hold it at an angle with active PWM (for long holds
// like power-off).  Caller must detach when done.
static void attachAndHold(Servo &servo, int pin, int angle) {
    servo.attach(pin, 500, 2400);
    servo.write(angle);
}

static void cmdPressButton(void (*press)(), void (*release)(),
                           const char *name, unsigned long ms) {
    if (ms == 0 || ms > SAFETY_TIMEOUT_MS) {
        Serial.printf("ERR duration out of range (1-%lu)\n", SAFETY_TIMEOUT_MS);
        return;
    }
    Serial.printf("OK pressing %s for %lu ms\n", name, ms);
    press();
    bool interrupted = holdWithInterrupt(ms);
    if (!interrupted) {
        release();
        Serial.printf("OK released %s\n", name);
    }
}

static void cmdFastboot(unsigned long shutdownMs, unsigned long comboMs) {
    if (shutdownMs > SAFETY_TIMEOUT_MS) shutdownMs = SAFETY_TIMEOUT_MS;
    if (comboMs > SAFETY_TIMEOUT_MS)    comboMs    = SAFETY_TIMEOUT_MS;

    // Phase 1: force-shutdown by holding power.
    // Need active PWM for the long hold (physical button resistance).
    Serial.printf("OK FASTBOOT phase1: holding power %lu ms\n", shutdownMs);
    attachAndHold(servoPower, PIN_SERVO_POWER, ANGLE_POWER_PRESSED);
    powerPressed = true;
    bool interrupted = holdWithInterrupt(shutdownMs);
    if (interrupted) return;
    releasePower();   // move-and-detach
    Serial.println("OK FASTBOOT phase1 done (power released)");

    // Brief pause to let the phone fully shut down
    delay(1000);

    // Phase 2: hold volume-down with active PWM, let cap recharge,
    // then detach vol-down and immediately tap power.
    Serial.printf("OK FASTBOOT phase2: vol-down + power tap (%lu ms window)\n",
                  comboMs);
    // Both servos held with active PWM — dedicated power supply handles the load.
    attachAndHold(servoVolDn, PIN_SERVO_VOLDN, ANGLE_VOLDN_PRESSED);
    volDnPressed = true;
    delay(500);
    attachAndHold(servoPower, PIN_SERVO_POWER, ANGLE_POWER_PRESSED);
    powerPressed = true;

    // Both servos now held with active PWM.
    // Wait for tap duration.
    unsigned long tapStart = millis();
    while (millis() - tapStart < POWER_TAP_MS) {
        if (Serial.available()) {
            String line = Serial.readStringUntil('\n');
            line.trim();
            if (line == "RELEASE_ALL") {
                releaseAll();
                Serial.println("OK RELEASE_ALL (fastboot interrupted)");
                return;
            }
        }
        delay(10);
    }
    releasePower();
    Serial.println("OK FASTBOOT power released, holding vol-down 5000 ms");
    // vol-down is still attached from above — no re-engage needed

    bool postHoldInterrupted = holdWithInterrupt(5000);

    if (!postHoldInterrupted) {
        releaseAll();
        Serial.println("OK FASTBOOT complete");
    }
}

static void cmdStatus() {
    Serial.printf("STATE {\"power\":%s,\"voldn\":%s}\n",
                  powerPressed ? "true" : "false",
                  volDnPressed ? "true" : "false");
}

// ── Parse & dispatch ────────────────────────────────────────────────────

static unsigned long parseULong(const String &s, unsigned long defaultVal) {
    if (s.length() == 0) return defaultVal;
    return strtoul(s.c_str(), nullptr, 10);
}

static void processLine(String &line) {
    line.trim();
    if (line.length() == 0) return;

    if (line == "PING") {
        Serial.println("PONG");
        return;
    }
    if (line == "STATUS") {
        cmdStatus();
        return;
    }
    if (line == "RELEASE_ALL") {
        releaseAll();
        Serial.println("OK RELEASE_ALL");
        return;
    }

    // Commands with arguments: split on first space
    int sp = line.indexOf(' ');
    String cmd = (sp > 0) ? line.substring(0, sp) : line;
    String arg = (sp > 0) ? line.substring(sp + 1) : "";
    arg.trim();

    if (cmd == "PRESS_POWER") {
        unsigned long ms = parseULong(arg, 0);
        if (ms == 0) { Serial.println("ERR usage: PRESS_POWER <ms>"); return; }
        cmdPressButton(pressPower, releasePower, "power", ms);
    } else if (cmd == "PRESS_VOLDN") {
        unsigned long ms = parseULong(arg, 0);
        if (ms == 0) { Serial.println("ERR usage: PRESS_VOLDN <ms>"); return; }
        cmdPressButton(pressVolDn, releaseVolDn, "voldn", ms);
    } else if (cmd == "FASTBOOT") {
        // FASTBOOT [shutdown_ms] [combo_ms]
        unsigned long shutMs  = DEFAULT_SHUTDOWN_HOLD_MS;
        unsigned long comboMs = DEFAULT_FASTBOOT_COMBO_MS;
        if (arg.length() > 0) {
            int sp2 = arg.indexOf(' ');
            if (sp2 > 0) {
                shutMs  = parseULong(arg.substring(0, sp2), shutMs);
                comboMs = parseULong(arg.substring(sp2 + 1), comboMs);
            } else {
                shutMs = parseULong(arg, shutMs);
            }
        }
        cmdFastboot(shutMs, comboMs);
    } else if (cmd == "ANGLE_POWER") {
        int a = arg.toInt();
        if (a < 0 || a > 180) { Serial.println("ERR angle 0-180"); return; }
        moveAndDetach(servoPower, PIN_SERVO_POWER, a);
        Serial.printf("OK power angle %d\n", a);
    } else if (cmd == "ANGLE_VOLDN") {
        int a = arg.toInt();
        if (a < 0 || a > 180) { Serial.println("ERR angle 0-180"); return; }
        moveAndDetach(servoVolDn, PIN_SERVO_VOLDN, a);
        Serial.printf("OK voldn angle %d\n", a);
    } else {
        Serial.printf("ERR unknown command: %s\n", cmd.c_str());
    }
}

// ── Arduino entry points ────────────────────────────────────────────────

void setup() {
    Serial.begin(SERIAL_BAUD);
    while (!Serial) { delay(10); }

    ESP32PWM::allocateTimer(0);
    ESP32PWM::allocateTimer(1);

    servoPower.setPeriodHertz(50);
    servoVolDn.setPeriodHertz(50);

    // Let power rail stabilize before touching servos
    delay(500);

    // Move each servo to released position one at a time, then detach
    releasePower();
    delay(200);
    releaseVolDn();

    Serial.println("OK MobileMash ready");
}

void loop() {
    if (Serial.available()) {
        String line = Serial.readStringUntil('\n');
        processLine(line);
    }
}
