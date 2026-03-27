/*
 * MobileMash – 3D-printable cradle for Pixel 10 Pro
 *
 * Two SG90 micro servos mount UPSIDE-DOWN (shaft pointing down) on
 * screw bosses outside the LEFT wall (phone is face-down, so the
 * right-side buttons face the left wall).
 *
 * A base shelf at tray level connects the bosses to the wall.
 * Boss height is calculated so the servo arm sweeps in XY at
 * phone-button height.
 *
 * No print supports needed.  Sits flat.
 *
 * Phone dimensions (Pixel 10 Pro):
 *   152.8 x 72 x 8.6 mm
 *   Camera bump: 3 mm protrusion, starts 10 mm from top, ~23 mm tall,
 *                2 mm inset from each side edge.
 *
 * Button layout (right side of phone, measured from top):
 *   Power button center:      ~40 mm from top
 *   Volume-down button center: ~60 mm from top
 *   (Both buttons are ~12 mm long)
 *
 * SG90 servo body: 22.2 x 11.8 x 22.7 mm  (h x d x w)
 * SG90 mounting tabs: 32.5 mm total (tab-to-tab along body w)
 * SG90 screw hole spacing: 27 mm (measured)
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

wall = 3.5;            // 1 mm thicker — camera bump (3 mm) no longer
                        // cuts all the way through the base.
lip_h = 15;

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

sg90_flipped_tab_z = 6.7;
sg90_shaft_protrusion = 5;
sg90_arm_drop = 4;

// Measured screw-hole to screw-hole distance on the servo tabs.
sg90_screw_spacing = 27;

power_btn_y = 40;
voldn_btn_y = 60;

m2_hole_d = 2.2;

// ── Derived values ──────────────────────────────────────────────────────
inner_w = phone_w + 2 * clearance;
outer_w = inner_w + 2 * wall;
wall_top = wall + lip_h;

arm_z = wall + phone_d / 2;
servo_bottom_z = arm_z + sg90_arm_drop;
boss_height = servo_bottom_z + sg90_flipped_tab_z;

// Boss X — on the LEFT side, outside the left wall.
// Left wall outer face is at x = 0.  Bosses extend in -X.
boss_x = -(sg90_body_d / 2);

// ── Modules ─────────────────────────────────────────────────────────────

module cradle_base() {
    difference() {
        cube([outer_w, cradle_len, wall_top]);

        translate([wall, -0.1, wall])
            cube([inner_w, cradle_len + 0.2, lip_h + 1]);

        // Camera bump relief — pocket in the base (no longer cuts
        // all the way through with the thicker base).
        if (cam_bump_y_end > 0) {
            translate([wall + clearance + cam_bump_inset,
                       cam_bump_y_start,
                       -0.1])
                cube([cam_bump_w,
                      cam_bump_y_end - cam_bump_y_start,
                      cam_bump_protrusion + 0.1]);
        }
    }
}

module servo_cutout(btn_y) {
    // Single cutout through the LEFT wall for the servo body and arm.
    local_y = btn_y - cradle_y_offset;
    body_center_y = local_y;

    // Span the full tab width in Y.
    cutout_half = sg90_tab_w / 2;

    translate([-0.1,
               body_center_y - cutout_half,
               arm_z - 3])
        cube([wall + 0.2,
              sg90_tab_w,
              wall_top - (arm_z - 3) + 0.1]);
}

module servo_mount(btn_y) {
    local_y = btn_y - cradle_y_offset;

    // Base shelf connecting bosses to the left wall
    shelf_x_end = 0;                       // left wall outer face
    shelf_x_start = boss_x - 4;           // past the boss edge
    shelf_w = shelf_x_end - shelf_x_start;

    translate([shelf_x_start,
               local_y - sg90_tab_w / 2,
               0])
        cube([shelf_w, sg90_tab_w, wall]);

    // Screw bosses at measured 27 mm spacing, centered on button Y.
    for (hole_y = [local_y - sg90_screw_spacing / 2,
                   local_y + sg90_screw_spacing / 2]) {
        translate([boss_x, hole_y, 0])
            cylinder(h = boss_height, d = 6, $fn = 20);
    }
}

module servo_mount_holes(btn_y) {
    local_y = btn_y - cradle_y_offset;

    for (hole_y = [local_y - sg90_screw_spacing / 2,
                   local_y + sg90_screw_spacing / 2]) {
        translate([boss_x, hole_y, boss_height - 8])
            cylinder(h = 8.1, d = m2_hole_d, $fn = 20);
    }
}

module esp32_mount() {
    // ESP32 mounts on the RIGHT wall exterior now (opposite the servos).
    for (dy = [10, 58]) {
        translate([outer_w + 3, dy, 0])
            difference() {
                union() {
                    cylinder(h = wall + 8, d = 6, $fn = 20);
                    translate([-3, -3, 0])
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
