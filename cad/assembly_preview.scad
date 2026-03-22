/*
 * Assembly preview — cradle + phone + servos + ESP32
 * Uses $t (0–1) for animation rotation.
 */

use <pixel10pro_cradle.scad>

// ── Phone ───────────────────────────────────────────────────────────────
phone_w = 72;
phone_h = 152.8;
phone_d = 8.6;
clearance = 1.0;
wall = 2.5;
cradle_len = 90;
cradle_y_offset = 20;

// ── SG90 dimensions (duplicated for standalone use) ─────────────────────
sg90_body_w  = 22.7;
sg90_body_d  = 11.8;
sg90_body_h  = 22.2;
sg90_tab_w   = 32.5;
sg90_tab_h   = 2.5;
sg90_shaft_offset = 6;

inner_w = phone_w + 2 * clearance;
outer_w = inner_w + 2 * wall;

power_btn_y = 40;
voldn_btn_y = 60;

// ── Colors ──────────────────────────────────────────────────────────────

module phone() {
    color([0.15, 0.15, 0.15, 0.7])
        translate([wall + clearance,
                   -cradle_y_offset,  // phone top at y=0 in phone coords
                   wall])
            cube([phone_w, phone_h, phone_d]);
}

module sg90_servo(btn_y) {
    local_y = btn_y - cradle_y_offset;
    body_start = local_y - sg90_shaft_offset;

    // Body
    color([0.2, 0.4, 0.8, 0.85])
        translate([outer_w, body_start, wall])
            cube([sg90_body_d, sg90_body_w, sg90_body_h]);

    // Mounting tabs
    tab_extent = (sg90_tab_w - sg90_body_w) / 2;
    color([0.2, 0.4, 0.8, 0.85])
        translate([outer_w,
                   body_start - tab_extent,
                   wall + sg90_body_h/2 - sg90_tab_h/2])
            cube([sg90_body_d, sg90_tab_w, sg90_tab_h]);

    // Shaft nub
    color([1, 1, 1])
        translate([outer_w + sg90_body_d/2,
                   body_start + sg90_shaft_offset,
                   wall + sg90_body_h])
            cylinder(h = 4, d = 5, $fn = 20);

    // Arm (in pressed-ish position, angled toward phone)
    color([1, 1, 1])
        translate([outer_w + sg90_body_d/2,
                   body_start + sg90_shaft_offset,
                   wall + sg90_body_h + 2])
            rotate([0, -45, 0])
                translate([-1.5, -1, 0])
                    cube([3, 2, 18]);
}

module esp32_board() {
    // Elegoo ESP32 DevKitV1: ~55 x 28 mm
    color([0.0, 0.5, 0.0, 0.85])
        translate([-3 - 14, 10, wall + 8])
            cube([28, 55, 1.6]);

    // USB connector
    color([0.7, 0.7, 0.7])
        translate([-3 - 5, 10 - 2, wall + 8])
            cube([10, 8, 4]);

    // ESP32 module (metal shield)
    color([0.7, 0.7, 0.7])
        translate([-3 - 10, 10 + 35, wall + 9.6])
            cube([18, 18, 3]);
}

// ── Animated assembly ───────────────────────────────────────────────────

// Camera orbits around the model center
rot = $t * 360;

rotate([0, 0, rot])
translate([-outer_w/2, -cradle_len/2, -(17.5)/2]) {
    mobilemash_cradle();
    phone();
    sg90_servo(power_btn_y);
    sg90_servo(voldn_btn_y);
    esp32_board();
}
