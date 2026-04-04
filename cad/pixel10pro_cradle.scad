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
 *   Camera bump: 3 mm protrusion, starts 10 mm from top, ~25 mm tall,
 *                2 mm inset from each side edge.
 *
 * Button layout (right side of phone, measured from top):
 *   Power button center:      ~50 mm from top
 *   Volume-down button center: ~78 mm from top (50 + 28)
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

wall = 3.5;
lip_h = 15;

cradle_y_offset = 7;   // start 7 mm from phone top to fully enclose camera bump
cradle_len = 103;      // extended to maintain same coverage at bottom

// ── Camera bump (Pixel 10 Pro) ──────────────────────────────────────────
cam_bump_protrusion = 3;
cam_bump_from_top   = 10;
cam_bump_height     = 25;
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

sg90_screw_spacing = 27;

// Button positions from top of phone.
power_btn_y = 50;
voldn_btn_y = 78;

// Shift the power servo mount toward the top (lower Y) so both
// screw bosses have room.
power_mount_shift = -4;

m2_hole_d = 1.9;     // tighter hole for better screw grip
boss_d = 6;

// ── Derived values ──────────────────────────────────────────────────────
inner_w = phone_w + 2 * clearance;
outer_w = inner_w + 2 * wall;
wall_top = wall + lip_h;

arm_z = wall + phone_d / 2;
servo_bottom_z = arm_z + sg90_arm_drop;

// Boss height: +1.5 mm per user feedback.
boss_height = servo_bottom_z + sg90_flipped_tab_z + 1.5;

boss_x = -(sg90_body_d / 2);

// Clearance between boss inner face and servo body edge.
// Body is 22.7 mm; with 27 mm boss spacing, each boss inner face
// must be at least 22.7/2 = 11.35 mm from center.  Add 0.5 mm gap.
boss_inner_clearance = sg90_body_w / 2 + 0.5;  // 11.85 mm from servo center

// ── Modules ─────────────────────────────────────────────────────────────

module cradle_base() {
    difference() {
        cube([outer_w, cradle_len, wall_top]);

        translate([wall, -0.1, wall])
            cube([inner_w, cradle_len + 0.2, lip_h + 1]);

        // Camera bump through-hole — fully enclosed by base material on
        // all four sides.  Phone drops in from above; the bump passes
        // through the hole and the surrounding edges retain the phone
        // on both X and Y axes.
        if (cam_bump_y_end > cam_bump_y_start) {
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
    local_y = btn_y - cradle_y_offset;
    cutout_half = sg90_tab_w / 2;

    translate([-0.1,
               local_y - cutout_half,
               arm_z - 3])
        cube([wall + 0.2,
              sg90_tab_w,
              wall_top - (arm_z - 3) + 0.1]);
}

// D-shaped boss: cylinder with the inner face cut flat so the
// servo body (22.7 mm) fits between the two bosses.
module d_boss(center_y, mount_center_y) {
    is_lower = (center_y < mount_center_y);
    // Cut plane: inner face at boss_inner_clearance from mount center
    cut_y = is_lower
        ? mount_center_y - boss_inner_clearance
        : mount_center_y + boss_inner_clearance;

    difference() {
        translate([boss_x, center_y, 0])
            cylinder(h = boss_height, d = boss_d, $fn = 20);

        // Cut the inner half to make a flat face
        if (is_lower) {
            translate([boss_x - boss_d, cut_y, -0.1])
                cube([boss_d * 2, boss_d, boss_height + 0.2]);
        } else {
            translate([boss_x - boss_d, center_y - boss_d/2, -0.1])
                cube([boss_d * 2, cut_y - (center_y - boss_d/2), boss_height + 0.2]);
        }
    }
}

module servo_mount(btn_y, mount_shift=0) {
    local_y = btn_y - cradle_y_offset + mount_shift;

    // Base shelf — extends to meet the back wall
    shelf_x_start = boss_x - 5 - 2;  // align with back wall outer edge
    shelf_w = 0 - shelf_x_start;

    translate([shelf_x_start,
               local_y - sg90_tab_w / 2,
               0])
        cube([shelf_w, sg90_tab_w, wall]);

    // D-shaped screw bosses
    for (hole_y = [local_y - sg90_screw_spacing / 2,
                   local_y + sg90_screw_spacing / 2]) {
        d_boss(hole_y, local_y);
    }
}

module servo_mount_holes(btn_y, mount_shift=0) {
    local_y = btn_y - cradle_y_offset + mount_shift;

    for (hole_y = [local_y - sg90_screw_spacing / 2,
                   local_y + sg90_screw_spacing / 2]) {
        translate([boss_x, hole_y, boss_height - 8])
            cylinder(h = 8.1, d = m2_hole_d, $fn = 20);
    }
}

// Back wall behind each servo to resist torque that pulls
// the servo away from the cradle wall.
module servo_back_wall(btn_y, mount_shift=0) {
    local_y = btn_y - cradle_y_offset + mount_shift;
    back_w = sg90_tab_w;
    back_t = 2;          // thickness
    back_h = boss_height + sg90_body_h / 2; // extend up behind servo

    // Position inner face 5 mm from boss hole center (in X, away from wall)
    back_x = boss_x - 5;
    translate([back_x - back_t,
               local_y - back_w / 2,
               0])
        cube([back_t, back_w, back_h]);
}

module esp32_mount() {
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
            servo_mount(power_btn_y, power_mount_shift);
            servo_mount(voldn_btn_y);
            servo_back_wall(power_btn_y, power_mount_shift);
            servo_back_wall(voldn_btn_y);
            esp32_mount();
        }

        servo_cutout(power_btn_y);
        servo_cutout(voldn_btn_y);

        servo_mount_holes(power_btn_y, power_mount_shift);
        servo_mount_holes(voldn_btn_y);
    }
}

mobilemash_cradle();
