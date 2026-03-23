/*
 * MobileMash – 3D-printable cradle for Pixel 10 Pro
 *
 * Two SG90 micro servos mount UPSIDE-DOWN on the right-side rail so the
 * shaft (and arm) is at phone-button height.  The arm sweeps in XY to
 * press the power and volume-down buttons.
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
 * SG90 shaft protrusion below gear housing: ~4 mm
 * SG90 arm center when flipped: ~3 mm below gear housing face
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

// ── Camera bump (Pixel 10 Pro) ──────────────────────────────────────────
// Measured from the phone back surface.
cam_bump_protrusion = 3;     // mm above back surface
cam_bump_from_top   = 10;    // mm from top of phone to bump start
cam_bump_height     = 26;    // mm tall (23 mm + margin)
cam_bump_inset      = 2;     // mm inset from each side edge
// In cradle coords the bump spans Y = (cam_bump_from_top - cradle_y_offset)
// to Y = (cam_bump_from_top + cam_bump_height - cradle_y_offset).
// If cam_bump_from_top < cradle_y_offset the bump starts before the
// cradle, but we still need to cut any overlap.
cam_bump_y_start = max(0, cam_bump_from_top - cradle_y_offset);
cam_bump_y_end   = cam_bump_from_top + cam_bump_height - cradle_y_offset;
cam_bump_w       = phone_w - 2 * cam_bump_inset;

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

// Shaft protrudes ~4 mm below the gear housing face.
// Arm horn center sits ~3 mm below the gear housing face.
sg90_shaft_protrusion = 4;
sg90_arm_drop = 3;    // arm center below gear-housing face

// Shelf depth below the tab for vertical M2 screws to bite into.
shelf_depth = 5;

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

// The gear-housing face must be sg90_arm_drop above arm_z so the arm
// ends up at the correct height.
servo_bottom_z = arm_z + sg90_arm_drop;   // ≈ 9.8 mm

// ── Modules ─────────────────────────────────────────────────────────────

module cradle_base() {
    difference() {
        cube([outer_w, cradle_len, lip_h + wall]);

        // Inner pocket for the phone (open top)
        translate([wall, -0.1, wall])
            cube([inner_w, cradle_len + 0.2, lip_h + 1]);

        // Camera bump relief — cut all the way through the base
        // so the bump can protrude below.
        if (cam_bump_y_end > 0) {
            translate([wall + clearance + cam_bump_inset,
                       cam_bump_y_start,
                       -0.1])
                cube([cam_bump_w, cam_bump_y_end - cam_bump_y_start, wall + 0.2]);
        }
    }
}

// Shaft (and arm) aligns with the button center in Y.
// body_start_y = local_y - sg90_shaft_offset  (so shaft is at local_y).

module servo_pocket(btn_y) {
    // Cut the right wall where the servo body overlaps it.
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

    // Slot centered on arm_z, tall enough for arm clearance.
    translate([outer_w - wall - 0.1,
               local_y - 5,
               arm_z - 3])
        cube([wall + 0.2, 10, 6]);
}

module servo_mount_holes(btn_y) {
    // Vertical screw holes (Z direction) through the bosses and shelf,
    // matching the SG90 tab holes which are parallel to the shaft axis.
    local_y = btn_y - cradle_y_offset;
    body_start_y = local_y - sg90_shaft_offset;
    tab_extent = (sg90_tab_w - sg90_body_w) / 2;

    tab_z = servo_bottom_z + sg90_flipped_tab_z;
    boss_x = outer_w + sg90_body_d / 2;

    for (hole_y = [body_start_y - tab_extent + 2,
                   body_start_y + sg90_body_w + tab_extent - 2]) {
        translate([boss_x,
                   hole_y,
                   tab_z - shelf_depth - 0.1])
            cylinder(h = shelf_depth + sg90_tab_h + 2,
                     d = m2_hole_d, $fn = 20);
    }
}

module servo_tab_shelf(btn_y) {
    // Thin shelf for the tabs to rest on, plus screw bosses at the
    // two tab-ear positions for vertical M2 screw engagement.
    // The shelf is only sg90_tab_h thick so the body can hang below
    // freely without collision.
    local_y = btn_y - cradle_y_offset;
    body_start_y = local_y - sg90_shaft_offset;
    tab_start = body_start_y - (sg90_tab_w - sg90_body_w) / 2;
    tab_extent = (sg90_tab_w - sg90_body_w) / 2;

    tab_z = servo_bottom_z + sg90_flipped_tab_z;
    shelf_x = outer_w - wall;
    shelf_w = wall + sg90_body_d + 2;

    // Thin resting shelf (full tab width)
    translate([shelf_x, tab_start, tab_z])
        cube([shelf_w, sg90_tab_w, sg90_tab_h]);

    // Screw bosses — cylindrical columns below each tab ear,
    // extending shelf_depth below the shelf for screw bite.
    // Positioned in the tab ears (outside the body Y range)
    // so they don't block the body.
    boss_x = outer_w + sg90_body_d / 2;
    for (hole_y = [body_start_y - tab_extent + 2,
                   body_start_y + sg90_body_w + tab_extent - 2]) {
        translate([boss_x, hole_y, tab_z - shelf_depth])
            cylinder(h = shelf_depth, d = 6, $fn = 20);
    }
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
