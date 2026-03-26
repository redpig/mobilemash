/*
 * MobileMash – 3D-printable cradle for Pixel 10 Pro
 *
 * Two SG90 micro servos mount UPSIDE-DOWN (shaft pointing down) on
 * screw bosses outside the right wall.  A base shelf at tray level
 * connects the bosses to the wall.  Boss height is calculated so
 * the servo arm sweeps in XY at phone-button height.
 *
 * No print supports needed.  Sits flat.
 *
 * Phone dimensions (Pixel 10 Pro):
 *   152.8 x 72 x 8.6 mm
 *   Camera bump: 3 mm protrusion, starts 10 mm from top, ~23 mm tall,
 *                2 mm inset from each side edge.
 *
 * Button layout (right side, measured from top of phone):
 *   Power button center:      ~40 mm from top
 *   Volume-down button center: ~60 mm from top
 *   (Both buttons are ~12 mm long)
 *
 * SG90 servo body: 22.2 x 11.8 x 22.7 mm  (h x d x w)
 * SG90 mounting tabs: 32.5 mm total (tab-to-tab along body w)
 * Measured: 13 mm from tab screw-hole center to shaft tip.
 *
 * Print settings:
 *   Layer height: 0.2 mm
 *   Infill: 20%+
 *   Material: PLA or PETG
 *   Supports: NOT needed
 *
 * SPDX-License-Identifier: Apache-2.0
 */

// ── Tunables ────────────────────────────────────────────────────────────

phone_w   = 72;
phone_h   = 152.8;
phone_d   = 8.6;

clearance = 1.0;

wall = 2.5;
lip_h = 15;           // back to normal — no extra height needed

cradle_len = 90;
cradle_y_offset = 20;

// ── Camera bump (Pixel 10 Pro) ──────────────────────────────────────────
cam_bump_protrusion = 3;
cam_bump_from_top   = 10;
cam_bump_height     = 26;
cam_bump_inset      = 2;
cam_bump_y_start = max(0, cam_bump_from_top - cradle_y_offset);
cam_bump_y_end   = cam_bump_from_top + cam_bump_height - cradle_y_offset;
cam_bump_w       = phone_w - 2 * cam_bump_inset;

// ── SG90 servo dimensions ───────────────────────────────────────────────
sg90_body_w  = 22.7;
sg90_body_d  = 11.8;
sg90_body_h  = 22.2;
sg90_tab_w   = 32.5;
sg90_tab_h   = 2.5;
sg90_shaft_offset = 6;

sg90_flipped_tab_z = 6.7;   // tab ears from gear-housing face (flipped)
sg90_shaft_protrusion = 5;
sg90_arm_drop = 4;           // arm center below gear-housing face

power_btn_y = 40;
voldn_btn_y = 60;

m2_hole_d = 2.2;

// ── Derived values ──────────────────────────────────────────────────────
inner_w = phone_w + 2 * clearance;
outer_w = inner_w + 2 * wall;
wall_top = wall + lip_h;    // ≈ 17.5

// Target arm Z — middle of the phone's side face.
arm_z = wall + phone_d / 2;   // ≈ 6.8

// Gear-housing face.
servo_bottom_z = arm_z + sg90_arm_drop;   // ≈ 10.8

// Boss height: from base (z=0) to the tab bottom surface, where
// the servo tabs rest on the boss tops.
// tab_bottom = servo_bottom_z + sg90_flipped_tab_z = 17.5
boss_height = servo_bottom_z + sg90_flipped_tab_z;  // ≈ 17.5

// Boss X position — centered on the servo body depth.
boss_x = outer_w + sg90_body_d / 2;

// ── Modules ─────────────────────────────────────────────────────────────

module cradle_base() {
    difference() {
        cube([outer_w, cradle_len, wall_top]);

        translate([wall, -0.1, wall])
            cube([inner_w, cradle_len + 0.2, lip_h + 1]);

        // Camera bump relief
        if (cam_bump_y_end > 0) {
            translate([wall + clearance + cam_bump_inset,
                       cam_bump_y_start,
                       -0.1])
                cube([cam_bump_w,
                      cam_bump_y_end - cam_bump_y_start,
                      wall + 0.2]);
        }
    }
}

module servo_cutout(btn_y) {
    // Single cutout through the right wall for the servo body AND arm.
    // Extends from arm_z - 3 to the wall top — no separate pocket
    // and arm slot.
    local_y = btn_y - cradle_y_offset;
    body_start_y = local_y - sg90_shaft_offset;
    tab_extent = (sg90_tab_w - sg90_body_w) / 2;

    // Use the full tab span in Y so bosses don't block the opening.
    cutout_y_start = body_start_y - tab_extent;
    cutout_y_end   = body_start_y + sg90_body_w + tab_extent;

    translate([outer_w - wall - 0.1,
               cutout_y_start,
               arm_z - 3])
        cube([wall + 0.2,
              cutout_y_end - cutout_y_start,
              wall_top - (arm_z - 3) + 0.1]);
}

module servo_mount(btn_y) {
    // Base shelf + screw bosses for one servo.
    //
    // Shelf: horizontal plate at z=0, flush with the tray base,
    //        extending from the wall outward to the boss positions.
    // Bosses: vertical cylinders from z=0 up to boss_height.
    //         The servo tabs rest on the boss tops.
    //         Prints as simple pillars — no supports.
    local_y = btn_y - cradle_y_offset;
    body_start_y = local_y - sg90_shaft_offset;
    tab_extent = (sg90_tab_w - sg90_body_w) / 2;

    // Base shelf connecting bosses to the wall
    shelf_x_start = outer_w - wall;
    shelf_x_end   = boss_x + 4;  // past the boss edge
    shelf_w = shelf_x_end - shelf_x_start;
    tab_start = body_start_y - tab_extent;

    translate([shelf_x_start, tab_start, 0])
        cube([shelf_w, sg90_tab_w, wall]);

    // Screw bosses — one at each tab-ear position
    for (hole_y = [body_start_y - tab_extent + 2,
                   body_start_y + sg90_body_w + tab_extent - 2]) {
        translate([boss_x, hole_y, 0])
            cylinder(h = boss_height, d = 6, $fn = 20);
    }
}

module servo_mount_holes(btn_y) {
    // Pilot holes down from the boss tops for vertical M2 screws.
    local_y = btn_y - cradle_y_offset;
    body_start_y = local_y - sg90_shaft_offset;
    tab_extent = (sg90_tab_w - sg90_body_w) / 2;

    for (hole_y = [body_start_y - tab_extent + 2,
                   body_start_y + sg90_body_w + tab_extent - 2]) {
        translate([boss_x, hole_y, boss_height - 8])
            cylinder(h = 8.1, d = m2_hole_d, $fn = 20);
    }
}

module esp32_mount() {
    for (dy = [10, 58]) {
        translate([-3, dy, 0])
            difference() {
                union() {
                    cylinder(h = wall + 8, d = 6, $fn = 20);
                    translate([0, -3, 0])
                        cube([3, 6, wall + 8]);
                }
                translate([0, 0, wall])
                    cylinder(h = 9, d = m2_hole_d, $fn = 20);
            }
    }
}

// ── Assembly ────────────────────────────────────────────────────────────

module mobilemash_cradle() {
    difference() {
        union() {
            cradle_base();
            servo_mount(power_btn_y);
            servo_mount(voldn_btn_y);
            esp32_mount();
        }

        servo_cutout(power_btn_y);
        servo_cutout(voldn_btn_y);

        servo_mount_holes(power_btn_y);
        servo_mount_holes(voldn_btn_y);
    }
}

mobilemash_cradle();
