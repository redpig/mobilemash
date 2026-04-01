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

static void pressPower() {
    servoPower.write(ANGLE_POWER_PRESSED);
    powerPressed = true;
}
static void releasePower() {
    servoPower.write(ANGLE_POWER_RELEASED);
    powerPressed = false;
}
static void pressVolDn() {
    servoVolDn.write(ANGLE_VOLDN_PRESSED);
    volDnPressed = true;
}
static void releaseVolDn() {
    servoVolDn.write(ANGLE_VOLDN_RELEASED);
    volDnPressed = false;
}
static void releaseAll() {
    releasePower();
    releaseVolDn();
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

    // Phase 1: force-shutdown by holding power
    Serial.printf("OK FASTBOOT phase1: holding power %lu ms\n", shutdownMs);
    pressPower();
    bool interrupted = holdWithInterrupt(shutdownMs);
    if (interrupted) return;
    releasePower();
    Serial.println("OK FASTBOOT phase1 done (power released)");

    // Brief pause to let the phone fully shut down
    delay(1000);

    // Phase 2: hold volume-down, then tap power
    // Stagger servo movements and detach vol-down PWM before moving power
    // to avoid brownout from simultaneous current draw.  The vol-down servo
    // holds its position via gear friction while unpowered.
    Serial.printf("OK FASTBOOT phase2: vol-down + power tap (%lu ms window)\n",
                  comboMs);
    pressVolDn();
    delay(500);            // hold vol-down for 500ms before moving power
    servoVolDn.detach();   // stop PWM — servo holds via friction
    delay(100);
    pressPower();

    unsigned long tapStart = millis();

    // Keep power pressed for POWER_TAP_MS or until interrupted
    while (millis() - tapStart < POWER_TAP_MS) {
        if (Serial.available()) {
            String line = Serial.readStringUntil('\n');
            line.trim();
            if (line == "RELEASE_ALL") {
                servoVolDn.attach(PIN_SERVO_VOLDN, 500, 2400);
                releaseAll();
                Serial.println("OK RELEASE_ALL (fastboot interrupted)");
                return;
            }
        }
        delay(10);
    }
    releasePower();  // release power after tap
    Serial.println("OK FASTBOOT power released, holding vol-down 5000 ms");

    // Re-attach vol-down and keep holding it for 5000ms after power release
    servoVolDn.attach(PIN_SERVO_VOLDN, 500, 2400);
    pressVolDn();  // re-assert vol-down now that power servo is idle

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
        servoPower.write(a);
        Serial.printf("OK power angle %d\n", a);
    } else if (cmd == "ANGLE_VOLDN") {
        int a = arg.toInt();
        if (a < 0 || a > 180) { Serial.println("ERR angle 0-180"); return; }
        servoVolDn.write(a);
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

    servoPower.attach(PIN_SERVO_POWER, 500, 2400);
    servoVolDn.attach(PIN_SERVO_VOLDN, 500, 2400);

    releaseAll();

    Serial.println("OK MobileMash ready");
}

void loop() {
    if (Serial.available()) {
        String line = Serial.readStringUntil('\n');
        processLine(line);
    }
}
