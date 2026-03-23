/*
 * MobileMash – 3D-printable cradle for Pixel 10 Pro
 *
 * Two SG90 micro servos mount UPSIDE-DOWN on the right-side rail so the
 * shaft (and arm) is at phone-button height.  The arm sweeps in XY to
 * press the power and volume-down buttons.
 *
 * Phone dimensions (Pixel 10 Pro):
 *   152.8 x 72 x 8.6 mm
 *
 * Button layout (right side, measured from top of phone):
 *   Power button center:      ~40 mm from top
 *   Volume-down button center: ~60 mm from top
 *   (Both buttons are ~12 mm long)
 *
 * SG90 servo body: 22.2 x 11.8 x 22.7 mm  (h x d x w)
 * SG90 mounting tabs: 32.5 mm total width (tab-to-tab along body w)
 *
 * Print settings:
 *   Layer height: 0.2 mm
 *   Infill: 20%+
 *   Material: PLA or PETG
 *   Supports: not needed
 *
 * SPDX-License-Identifier: Apache-2.0
 */

// ── Tunables ────────────────────────────────────────────────────────────

phone_w   = 72;      // width  (X)
phone_h   = 152.8;   // height (Y)
phone_d   = 8.6;     // depth/thickness (Z)

clearance = 1.0;

wall = 2.5;
lip_h = 15;

cradle_len = 90;
cradle_y_offset = 20;

// ── SG90 servo dimensions ───────────────────────────────────────────────
sg90_body_w  = 22.7;  // body length (along Y in cradle)
sg90_body_d  = 11.8;  // body depth  (along X, away from phone)
sg90_body_h  = 22.2;  // body height (along Z when upright)
sg90_tab_w   = 32.5;  // tab-to-tab span along Y
sg90_tab_h   = 2.5;   // tab thickness (Z)
sg90_shaft_offset = 6; // shaft center from one end of body along Y

// When the servo is flipped upside-down the mounting-tab ears are
// approximately 6.7 mm above the new bottom (gear-housing face).
sg90_flipped_tab_z = 6.7;

// Button positions from top of phone
power_btn_y = 40;
voldn_btn_y = 60;

m2_hole_d = 2.2;

// ── Derived values ──────────────────────────────────────────────────────
inner_w = phone_w + 2 * clearance;
inner_d = phone_d + clearance;
outer_w = inner_w + 2 * wall;

// Target arm Z — the arm sweeps in XY at this height, which should
// coincide with the middle of the phone's side face (where buttons are).
arm_z = wall + phone_d / 2;   // ≈ 6.8 mm

// The flipped servo body sits with its gear-housing face (shaft end)
// at the bottom.  The shaft/arm is at approximately arm_z.
servo_bottom_z = arm_z;

// ── Modules ─────────────────────────────────────────────────────────────

module cradle_base() {
    difference() {
        cube([outer_w, cradle_len, lip_h + wall]);

        translate([wall, -0.1, wall])
            cube([inner_w, cradle_len + 0.2, lip_h + 1]);
    }
}

// Shaft (and arm) aligns with the button center in Y.
// body_start_y = local_y - sg90_shaft_offset  (so shaft is at local_y).

module servo_pocket(btn_y) {
    // Cut the right wall where the servo body overlaps it.
    // Only the portion of the body within wall height needs a pocket.
    local_y = btn_y - cradle_y_offset;
    body_start_y = local_y - sg90_shaft_offset;

    pocket_z_top = min(servo_bottom_z + sg90_body_h, lip_h + wall);

    translate([outer_w - wall - 0.1,
               body_start_y,
               servo_bottom_z])
        cube([wall + 0.2,
              sg90_body_w,
              pocket_z_top - servo_bottom_z + 0.1]);
}

module arm_slot(btn_y) {
    // Horizontal slot through the right wall at arm height so the
    // servo arm can swing through and press the phone button.
    local_y = btn_y - cradle_y_offset;

    translate([outer_w - wall - 0.1,
               local_y - 5,
               arm_z - 4])
        cube([wall + 0.2, 10, 6]);
}

module servo_mount_holes(btn_y) {
    // Screw holes through the right wall at the flipped-servo tab
    // positions.  Two screws per servo (one per tab ear).
    local_y = btn_y - cradle_y_offset;
    body_start_y = local_y - sg90_shaft_offset;
    tab_extent = (sg90_tab_w - sg90_body_w) / 2;

    tab_z = servo_bottom_z + sg90_flipped_tab_z + sg90_tab_h / 2;

    for (hole_y = [body_start_y - tab_extent + 2,
                   body_start_y + sg90_body_w + tab_extent - 2]) {
        translate([outer_w - wall / 2,
                   hole_y,
                   tab_z])
            rotate([0, 90, 0])
                cylinder(h = wall + 2, d = m2_hole_d, center = true, $fn = 20);
    }
}

module servo_tab_shelf(btn_y) {
    // Small ledge on the outside of the right wall for the flipped
    // servo tabs to rest on.
    local_y = btn_y - cradle_y_offset;
    body_start_y = local_y - sg90_shaft_offset;
    tab_start = body_start_y - (sg90_tab_w - sg90_body_w) / 2;

    tab_z = servo_bottom_z + sg90_flipped_tab_z;

    // Shelf sits on the outer wall face at the tab Z height.
    // At this Z the wall is intact (pocket is above arm_z, shelf is
    // within the pocket range but the tab-ear portions of the shelf
    // are outside the pocket's Y range, so they bond to intact wall).
    translate([outer_w - wall, tab_start, tab_z])
        cube([wall + 3, sg90_tab_w, sg90_tab_h]);
}

function servo_tab_start(btn_y) =
    (btn_y - cradle_y_offset) - sg90_shaft_offset
    - (sg90_tab_w - sg90_body_w) / 2;

module esp32_mount() {
    // Elegoo ESP32 DevKitV1: ~55 x 28 mm, mounting holes ~48 mm apart.
    for (dy = [10, 58]) {
        translate([-3, dy, wall])
            difference() {
                union() {
                    cylinder(h = 8, d = 6, $fn = 20);
                    translate([0, -3, 0])
                        cube([3, 6, 8]);
                }
                cylinder(h = 9, d = m2_hole_d, $fn = 20);
            }
    }
}

// ── Assembly ────────────────────────────────────────────────────────────

module mobilemash_cradle() {
    difference() {
        union() {
            cradle_base();
            servo_tab_shelf(power_btn_y);
            servo_tab_shelf(voldn_btn_y);
            esp32_mount();
        }

        servo_pocket(power_btn_y);
        servo_pocket(voldn_btn_y);

        arm_slot(power_btn_y);
        arm_slot(voldn_btn_y);

        servo_mount_holes(power_btn_y);
        servo_mount_holes(voldn_btn_y);

        // Cable routing channel — split to skip the servo tab shelves.
        cable_ch_x  = outer_w - wall - 0.1;
        cable_ch_xw = wall + 0.2;
        shelf1_start = servo_tab_start(power_btn_y);
        shelf2_end   = servo_tab_start(voldn_btn_y) + sg90_tab_w;

        translate([cable_ch_x, 5, 1])
            cube([cable_ch_xw, shelf1_start - 5, 4]);
        translate([cable_ch_x, shelf2_end, 1])
            cube([cable_ch_xw, cradle_len - 5 - shelf2_end, 4]);
    }
}

mobilemash_cradle();
