/*
 * Assembly preview — cradle + phone + servos + ESP32
 * Uses $t (0–1) for animation rotation.
 */

use <pixel10pro_cradle.scad>

// ── Dimensions (duplicated for standalone use) ──────────────────────────
phone_w = 72;
phone_h = 152.8;
phone_d = 8.6;
clearance = 1.0;
wall = 2.5;
cradle_len = 90;
cradle_y_offset = 20;

sg90_body_w  = 22.7;
sg90_body_d  = 11.8;
sg90_body_h  = 22.2;
sg90_tab_w   = 32.5;
sg90_tab_h   = 2.5;
sg90_shaft_offset = 6;
sg90_arm_drop = 3;

inner_w = phone_w + 2 * clearance;
outer_w = inner_w + 2 * wall;

power_btn_y = 40;
voldn_btn_y = 60;

arm_z = wall + phone_d / 2;
servo_bottom_z = arm_z + sg90_arm_drop;

// ── Component models ────────────────────────────────────────────────────

module phone() {
    // Phone body
    color([0.15, 0.15, 0.15, 0.7])
        translate([wall + clearance,
                   -cradle_y_offset,
                   wall])
            cube([phone_w, phone_h, phone_d]);

    // Camera bump on the back (protrudes below the phone)
    color([0.1, 0.1, 0.1, 0.8])
        translate([wall + clearance + 2,      // 2 mm inset
                   -cradle_y_offset + 10,     // 10 mm from phone top
                   wall - 3])                 // 3 mm below phone back
            cube([phone_w - 4, 26, 3]);
}

module sg90_servo(btn_y) {
    local_y = btn_y - cradle_y_offset;
    body_start_y = local_y - sg90_shaft_offset;

    servo_x = outer_w;
    // Body — flipped, gear housing at bottom
    color([0.2, 0.4, 0.8, 0.85])
        translate([servo_x, body_start_y, servo_bottom_z])
            cube([sg90_body_d, sg90_body_w, sg90_body_h]);

    // Mounting tabs
    tab_extent = (sg90_tab_w - sg90_body_w) / 2;
    tab_z = servo_bottom_z + 6.7;
    color([0.2, 0.4, 0.8, 0.85])
        translate([servo_x,
                   body_start_y - tab_extent,
                   tab_z])
            cube([sg90_body_d, sg90_tab_w, sg90_tab_h]);

    // Shaft nub — below gear housing
    shaft_x = servo_x + sg90_body_d / 2;
    shaft_y = local_y;
    color([1, 1, 1])
        translate([shaft_x, shaft_y, servo_bottom_z - 4])
            cylinder(h = 4, d = 5, $fn = 20);

    // Arm — sweeps in XY at arm_z, shown in ~30° pressed position
    arm_len = 17;
    press_angle = 30;
    arm_tip_x = shaft_x - arm_len * cos(press_angle);
    arm_tip_y = shaft_y - arm_len * sin(press_angle);
    color([1, 1, 1])
        translate([0, 0, arm_z - 1])
            hull() {
                translate([shaft_x, shaft_y, 0])
                    cylinder(h = 2, d = 4, $fn = 16);
                translate([arm_tip_x, arm_tip_y, 0])
                    cylinder(h = 2, d = 3, $fn = 16);
            }
}

module esp32_board() {
    board_x = -3 - 25;
    color([0.0, 0.5, 0.0, 0.85])
        translate([board_x, 10, wall + 8])
            cube([28, 55, 1.6]);
    color([0.7, 0.7, 0.7])
        translate([board_x + 9, 10 - 1, wall + 9.6])
            cube([10, 8, 3.5]);
    color([0.7, 0.7, 0.7])
        translate([board_x + 5, 10 + 36, wall + 9.6])
            cube([18, 16, 3]);
}

// ── Animated assembly ───────────────────────────────────────────────────

rot = $t * 360;

rotate([0, 0, rot])
translate([-outer_w / 2, -cradle_len / 2, -(17.5) / 2]) {
    mobilemash_cradle();
    phone();
    sg90_servo(power_btn_y);
    sg90_servo(voldn_btn_y);
    esp32_board();
}
