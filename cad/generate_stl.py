#!/usr/bin/env python3
"""
Generate MobileMash cradle STL for Pixel 10 Pro.

Uses trimesh + manifold3d for proper CSG boolean operations, producing
a watertight manifold mesh suitable for 3D printing.

SPDX-License-Identifier: Apache-2.0
"""

import numpy as np
import trimesh

# ── Dimensions (mm) ──────────────────────────────────────────────────────
phone_w = 72.0
phone_h = 152.8
phone_d = 8.6
clearance = 1.0
wall = 2.5
lip_h = 15.0

cradle_len = 90.0
cradle_y_offset = 20.0

# SG90 servo body
sg90_body_w = 22.7
sg90_body_d = 11.8
sg90_body_h = 22.2
sg90_tab_w = 32.5
sg90_tab_h = 2.5

# Button positions from top of phone (in cradle-local Y)
power_btn_y = 40.0 - cradle_y_offset  # 20.0
voldn_btn_y = 60.0 - cradle_y_offset  # 40.0

# Arm slot
arm_slot_h = 8.0
arm_slot_w = 6.0

# Derived
inner_w = phone_w + 2 * clearance
outer_w = inner_w + 2 * wall


def box(extents, center):
    """Create an axis-aligned box mesh."""
    return trimesh.primitives.Box(
        extents=extents,
        transform=trimesh.transformations.translation_matrix(center),
    ).to_mesh()


def build_cradle():
    parts = []

    # ── Base plate ───────────────────────────────────────────────────
    parts.append(box(
        [outer_w, cradle_len, wall],
        [outer_w / 2, cradle_len / 2, wall / 2],
    ))

    # ── Left wall ────────────────────────────────────────────────────
    parts.append(box(
        [wall, cradle_len, lip_h],
        [wall / 2, cradle_len / 2, wall + lip_h / 2],
    ))

    # ── Right wall (solid, we'll subtract servo pockets) ─────────────
    rw_cx = outer_w - wall / 2
    parts.append(box(
        [wall, cradle_len, lip_h],
        [rw_cx, cradle_len / 2, wall + lip_h / 2],
    ))

    # ── Front lip ────────────────────────────────────────────────────
    parts.append(box(
        [inner_w, wall, lip_h],
        [outer_w / 2, wall / 2, wall + lip_h / 2],
    ))

    # ── Back lip ─────────────────────────────────────────────────────
    parts.append(box(
        [inner_w, wall, lip_h],
        [outer_w / 2, cradle_len - wall / 2, wall + lip_h / 2],
    ))

    # ── Servo tab shelves (outside right wall) ───────────────────────
    shelf_depth = 3.0
    for btn_y in [power_btn_y, voldn_btn_y]:
        parts.append(box(
            [shelf_depth, sg90_tab_w, sg90_tab_h],
            [outer_w + shelf_depth / 2, btn_y, wall + sg90_tab_h / 2],
        ))

    # ── ESP32 mount posts (left side exterior) ───────────────────────
    post_d = 6.0
    post_h = 8.0
    for dy in [15, 55]:
        cyl = trimesh.primitives.Cylinder(
            radius=post_d / 2, height=post_h, sections=16,
            transform=trimesh.transformations.translation_matrix(
                [-post_d / 2, dy, wall + post_h / 2]
            ),
        ).to_mesh()
        parts.append(cyl)

    # ── Union all positive geometry ──────────────────────────────────
    solid = parts[0]
    for p in parts[1:]:
        solid = solid.union(p)

    # ── Subtract servo pockets and arm slots from right wall ─────────
    cuts = []
    for btn_y in [power_btn_y, voldn_btn_y]:
        # Servo body pocket (through-pocket in right wall)
        cuts.append(box(
            [wall + 2, sg90_body_w, sg90_body_h],
            [rw_cx, btn_y, wall + sg90_body_h / 2],
        ))
        # Arm slot (narrower, higher, passes through wall)
        arm_z_center = wall + sg90_body_h - 6 + arm_slot_h / 2
        cuts.append(box(
            [wall + 2, arm_slot_w, arm_slot_h],
            [rw_cx, btn_y, arm_z_center],
        ))

    for c in cuts:
        solid = solid.difference(c)

    return solid


def main():
    solid = build_cradle()

    out_path = "/home/user/mobilemash/cad/pixel10pro_cradle.stl"
    solid.export(out_path)

    print(f"Saved STL to {out_path}")
    print(f"  Triangles: {len(solid.faces)}")
    print(f"  Watertight: {solid.is_watertight}")
    print(f"  Volume: {solid.volume:.1f} mm³ ({solid.volume/1000:.1f} cm³)")
    dims = solid.extents
    print(f"  Bounding box: {dims[0]:.1f} x {dims[1]:.1f} x {dims[2]:.1f} mm")


if __name__ == "__main__":
    main()
