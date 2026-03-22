/*
 * MobileMash – 3D-printable cradle for Pixel 10 Pro
 *
 * Two SG90 micro servos mount on the right-side rail and press the
 * power button and volume-down button.
 *
 * Phone dimensions (Pixel 10 Pro):
 *   152.8 x 72 x 8.6 mm
 *
 * Button layout (right side, measured from top of phone):
 *   Power button center:      ~40 mm from top
 *   Volume-down button center: ~60 mm from top
 *   (Both buttons are ~12 mm long)
 *
 * SG90 servo body: 22.2 x 11.8 x 22.7 mm
 * SG90 mounting tabs: 32.5 mm total width (tab-to-tab)
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

// Phone dimensions (with ~1 mm clearance each side)
phone_w   = 72;      // width  (X)
phone_h   = 152.8;   // height (Y)
phone_d   = 8.6;     // depth/thickness (Z)

clearance = 1.0;     // extra room around the phone

// Cradle wall thickness
wall = 2.5;

// How tall the side walls rise above the phone bottom surface
lip_h = 15;          // enough to grip the phone securely

// How far the cradle extends along the phone height (Y).
// We only need to cover the button region, not the whole phone.
cradle_len = 90;     // covers ~30–80 mm from top (power + vol buttons)
cradle_y_offset = 20; // start 20 mm from the top of the phone

// ── SG90 servo dimensions ───────────────────────────────────────────────
sg90_body_w  = 22.7;  // along the phone height axis
sg90_body_d  = 11.8;  // depth (away from phone)
sg90_body_h  = 22.2;  // height (perpendicular to phone face)
sg90_tab_w   = 32.5;  // tab-to-tab width
sg90_tab_h   = 2.5;   // tab thickness
sg90_shaft_offset = 6; // shaft center offset from one end of body

// Button positions from top of phone (Y direction, positive downward)
power_btn_y = 40;
voldn_btn_y = 60;

// Servo mount: M2 screw holes in the tabs
m2_hole_d = 2.2;

// ── Derived values ──────────────────────────────────────────────────────
inner_w = phone_w + 2 * clearance;
inner_d = phone_d + clearance;

outer_w = inner_w + 2 * wall;
outer_d = inner_d + wall;     // wall only on the bottom (phone back)

// ── Modules ─────────────────────────────────────────────────────────────

module cradle_base() {
    // U-shaped tray: bottom + two side walls
    difference() {
        // Outer block
        cube([outer_w, cradle_len, lip_h + wall]);

        // Inner pocket for the phone (open top)
        translate([wall, -0.1, wall])
            cube([inner_w, cradle_len + 0.2, lip_h + 1]);
    }
}

// The SG90 shaft is NOT centered on the body — it's offset 6 mm from
// one end.  We need the shaft (not the body center) over the button, so
// shift the body so shaft_center == btn_y in cradle coords.
//   shaft_center = body_start + sg90_shaft_offset
//   body_start   = local_y - sg90_shaft_offset
sg90_body_y_shift = sg90_body_w / 2 - sg90_shaft_offset;  // 5.35 mm

module servo_pocket(btn_y) {
    local_y = btn_y - cradle_y_offset;

    // Pocket shifted so the shaft aligns with the button center.
    translate([outer_w - wall - 0.1,
               local_y - sg90_shaft_offset,
               wall])
        cube([wall + 0.2, sg90_body_w, sg90_body_h]);
}

module servo_mount_holes(btn_y) {
    // Two screw holes for the SG90 mounting tabs.
    // Holes are relative to the shaft position (== button center),
    // and the tab screw holes sit ~2 mm inward from each tab edge.
    local_y = btn_y - cradle_y_offset;
    body_start = local_y - sg90_shaft_offset;

    // Tab hole positions measured from body_start:
    //   lower tab hole: body_start - (tab_extent - 2)
    //   upper tab hole: body_start + sg90_body_w + (tab_extent - 2)
    tab_extent = (sg90_tab_w - sg90_body_w) / 2;
    for (hole_y = [body_start - tab_extent + 2,
                   body_start + sg90_body_w + tab_extent - 2]) {
        translate([outer_w - wall/2,
                   hole_y,
                   wall + sg90_body_h/2])
            rotate([0, 90, 0])
                cylinder(h = wall + 2, d = m2_hole_d, center = true, $fn = 20);
    }
}

module servo_tab_shelf(btn_y) {
    // Ledge for the servo tabs, shifted to match body offset.
    // Starts from the inner wall face so it's fully bonded.
    // The cable channel is split to avoid cutting through here.
    local_y = btn_y - cradle_y_offset;
    body_start = local_y - sg90_shaft_offset;
    tab_start  = body_start - (sg90_tab_w - sg90_body_w) / 2;

    translate([outer_w - wall, tab_start, wall])
        cube([wall + 3, sg90_tab_w, sg90_tab_h]);
}

// Helper: compute tab_start Y for a given button position
function servo_tab_start(btn_y) =
    (btn_y - cradle_y_offset) - sg90_shaft_offset
    - (sg90_tab_w - sg90_body_w) / 2;

module arm_slot(btn_y) {
    // Slot for the servo arm — centered on the shaft, which is now
    // aligned with the button center.
    local_y = btn_y - cradle_y_offset;

    translate([outer_w - wall - 0.1,
               local_y - 3,
               wall + sg90_body_h - 6])
        cube([wall + 0.2, 6, 8]);
}

module esp32_mount() {
    // Simple standoff posts on the left wall exterior for zip-tying
    // or screwing an ESP32 dev board.
    // Elegoo ESP32 DevKitV1: ~55 x 28 mm, mounting holes ~48 mm apart.
    for (dy = [10, 58]) {
        translate([-3, dy, wall])
            difference() {
                union() {
                    cylinder(h = 8, d = 6, $fn = 20);
                    // Bridge tab connecting post to left wall
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

        // Servo body pockets
        servo_pocket(power_btn_y);
        servo_pocket(voldn_btn_y);

        // Arm pass-through slots
        arm_slot(power_btn_y);
        arm_slot(voldn_btn_y);

        // Screw holes
        servo_mount_holes(power_btn_y);
        servo_mount_holes(voldn_btn_y);

        // Cable routing channel along right wall bottom, split to
        // avoid cutting through the servo tab shelves.
        cable_ch_x  = outer_w - wall - 0.1;
        cable_ch_xw = wall + 0.2;
        shelf1_start = servo_tab_start(power_btn_y);
        shelf2_end   = servo_tab_start(voldn_btn_y) + sg90_tab_w;
        // Segment before first shelf
        translate([cable_ch_x, 5, 1])
            cube([cable_ch_xw, shelf1_start - 5, 4]);
        // Segment after second shelf
        translate([cable_ch_x, shelf2_end, 1])
            cube([cable_ch_xw, cradle_len - 5 - shelf2_end, 4]);
    }
}

mobilemash_cradle();
