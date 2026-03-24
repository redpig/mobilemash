/*
 * MobileMash – 3D-printable cradle for Pixel 10 Pro
 *
 * Two SG90 micro servos mount UPSIDE-DOWN on the right-side rail.
 * The servo hangs below a shelf at the wall top, with the shaft/arm
 * at phone-button height.  The arm sweeps in XY to press the power
 * and volume-down buttons.
 *
 * The shelf is on TOP of the wall (faces up), so no print supports
 * are needed.  Vertical support columns from the base hold up the
 * shelf where it extends beyond the wall.
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

phone_w   = 72;      // width  (X)
phone_h   = 152.8;   // height (Y)
phone_d   = 8.6;     // depth/thickness (Z)

clearance = 1.0;

wall = 2.5;

cradle_len = 90;
cradle_y_offset = 20;

// ── Camera bump (Pixel 10 Pro) ──────────────────────────────────────────
cam_bump_protrusion = 3;
cam_bump_from_top   = 10;
cam_bump_height     = 26;    // 23 mm + margin
cam_bump_inset      = 2;
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

// When flipped upside-down the tab ears are ~6.7 mm above the gear-housing face.
sg90_flipped_tab_z = 6.7;

// Measured: 13 mm from tab screw-hole center to shaft tip.
sg90_shaft_protrusion = 5;
sg90_arm_drop = 4;    // arm center below gear-housing face

// Shelf thickness on top of the wall for screw engagement.
shelf_thickness = 5;

// Button positions from top of phone
power_btn_y = 40;
voldn_btn_y = 60;

m2_hole_d = 2.2;

// ── Derived values ──────────────────────────────────────────────────────
inner_w = phone_w + 2 * clearance;
inner_d = phone_d + clearance;
outer_w = inner_w + 2 * wall;

// Target arm Z — middle of the phone's side face.
arm_z = wall + phone_d / 2;   // ≈ 6.8 mm

// Gear-housing face (bottom of flipped servo).
servo_bottom_z = arm_z + sg90_arm_drop;   // ≈ 10.8 mm

// The shelf sits ON TOP of the wall.  The servo tab tops press up
// against the shelf underside.  Calculate the required wall height
// so the tab tops are flush with the wall top.
//   wall_top = servo_bottom_z + sg90_flipped_tab_z + sg90_tab_h
//            = 10.8 + 6.7 + 2.5 = 20.0
lip_h = servo_bottom_z + sg90_flipped_tab_z + sg90_tab_h - wall;  // ≈ 17.5

wall_top = wall + lip_h;  // ≈ 20.0

// ── Modules ─────────────────────────────────────────────────────────────

module cradle_base() {
    difference() {
        cube([outer_w, cradle_len, wall_top]);

        // Inner pocket for the phone (open top)
        translate([wall, -0.1, wall])
            cube([inner_w, cradle_len + 0.2, lip_h + 1]);

        // Camera bump relief
        if (cam_bump_y_end > 0) {
            translate([wall + clearance + cam_bump_inset,
                       cam_bump_y_start,
                       -0.1])
                cube([cam_bump_w, cam_bump_y_end - cam_bump_y_start, wall + 0.2]);
        }
    }
}

module servo_pocket(btn_y) {
    // Cut the right wall where the servo body sits.
    local_y = btn_y - cradle_y_offset;
    body_start_y = local_y - sg90_shaft_offset;

    translate([outer_w - wall - 0.1,
               body_start_y,
               servo_bottom_z])
        cube([wall + 0.2,
              sg90_body_w,
              wall_top - servo_bottom_z + 0.1]);
}

module arm_slot(btn_y) {
    // Slot through the right wall for the servo arm.
    local_y = btn_y - cradle_y_offset;

    translate([outer_w - wall - 0.1,
               local_y - 5,
               arm_z - 3])
        cube([wall + 0.2, 10, 6]);
}

module servo_shelf(btn_y) {
    // Shelf on TOP of the wall.  The servo tabs press up against
    // the underside; screws go down from above into the tab holes.
    //
    // The shelf extends outward (in X) beyond the wall to cover the
    // servo body width.  Vertical support columns from the base hold
    // up the cantilevered portion — no print supports needed.
    local_y = btn_y - cradle_y_offset;
    body_start_y = local_y - sg90_shaft_offset;
    tab_start = body_start_y - (sg90_tab_w - sg90_body_w) / 2;
    tab_extent = (sg90_tab_w - sg90_body_w) / 2;

    shelf_x = outer_w - wall;
    shelf_w = wall + sg90_body_d + 2;  // extends past servo body

    // Shelf plate on wall top
    translate([shelf_x, tab_start, wall_top])
        cube([shelf_w, sg90_tab_w, shelf_thickness]);

    // Support columns from base to shelf at each screw-hole position.
    // These are outside the body Y range (in the tab-ear zones) so
    // they don't block the servo body.  They print as simple vertical
    // pillars — no supports needed.
    col_x = outer_w + sg90_body_d / 2;
    for (hole_y = [body_start_y - tab_extent + 2,
                   body_start_y + sg90_body_w + tab_extent - 2]) {
        translate([col_x, hole_y, 0])
            cylinder(h = wall_top, d = 6, $fn = 20);
    }
}

module servo_mount_holes(btn_y) {
    // Vertical screw holes down through the shelf into the tab ears.
    local_y = btn_y - cradle_y_offset;
    body_start_y = local_y - sg90_shaft_offset;
    tab_extent = (sg90_tab_w - sg90_body_w) / 2;

    col_x = outer_w + sg90_body_d / 2;

    for (hole_y = [body_start_y - tab_extent + 2,
                   body_start_y + sg90_body_w + tab_extent - 2]) {
        translate([col_x,
                   hole_y,
                   wall_top - 0.1])
            cylinder(h = shelf_thickness + 0.2,
                     d = m2_hole_d, $fn = 20);
    }
}

function servo_tab_start(btn_y) =
    (btn_y - cradle_y_offset) - sg90_shaft_offset
    - (sg90_tab_w - sg90_body_w) / 2;

module esp32_mount() {
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
            servo_shelf(power_btn_y);
            servo_shelf(voldn_btn_y);
            esp32_mount();
        }

        servo_pocket(power_btn_y);
        servo_pocket(voldn_btn_y);

        arm_slot(power_btn_y);
        arm_slot(voldn_btn_y);

        servo_mount_holes(power_btn_y);
        servo_mount_holes(voldn_btn_y);

        // Cable routing channel — split to skip the servo shelf zones.
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
