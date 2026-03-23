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

    // Body — sits in the wall pocket, protruding outward
    servo_x = outer_w - wall;
    color([0.2, 0.4, 0.8, 0.85])
        translate([servo_x, body_start, wall])
            cube([sg90_body_d, sg90_body_w, sg90_body_h]);

    // Mounting tabs
    tab_extent = (sg90_tab_w - sg90_body_w) / 2;
    color([0.2, 0.4, 0.8, 0.85])
        translate([servo_x,
                   body_start - tab_extent,
                   wall + sg90_body_h/2 - sg90_tab_h/2])
            cube([sg90_body_d, sg90_tab_w, sg90_tab_h]);

    // Shaft nub — on top of body, offset from one end
    shaft_x = servo_x + sg90_body_d/2;
    shaft_y = body_start + sg90_shaft_offset;
    shaft_z = wall + sg90_body_h;
    color([1, 1, 1])
        translate([shaft_x, shaft_y, shaft_z])
            cylinder(h = 4, d = 5, $fn = 20);

    // Arm — straight bar from shaft toward the phone (-X),
    // parallel to the body top face
    color([1, 1, 1])
        translate([shaft_x - 18, shaft_y - 1, shaft_z + 2])
            cube([18, 2, 2]);
}

module esp32_board() {
    // Elegoo ESP32 DevKitV1: ~55 x 28 mm
    // Sits on mount posts (at x=-3) entirely outside the left wall.
    // Board centered on posts, extending in -X direction.
    board_x = -3 - 25;  // board from x=-28 to x=0
    color([0.0, 0.5, 0.0, 0.85])
        translate([board_x, 10, wall + 8])
            cube([28, 55, 1.6]);

    // USB connector (at one end of the board)
    color([0.7, 0.7, 0.7])
        translate([board_x + 9, 10 - 1, wall + 9.6])
            cube([10, 8, 3.5]);

    // ESP32 module (metal shield, near other end)
    color([0.7, 0.7, 0.7])
        translate([board_x + 5, 10 + 36, wall + 9.6])
            cube([18, 16, 3]);
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
