#!/usr/bin/env python3
"""
Generate MobileMash cradle STL for Pixel 10 Pro.

Uses numpy-stl to create the geometry directly (no OpenSCAD needed).

SPDX-License-Identifier: Apache-2.0
"""

import numpy as np
from stl import mesh

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

# Button positions from top of phone
power_btn_y = 40.0
voldn_btn_y = 60.0

# Derived
inner_w = phone_w + 2 * clearance
inner_d = phone_d + clearance
outer_w = inner_w + 2 * wall
outer_d = inner_d + wall


def box_triangles(x, y, z, dx, dy, dz):
    """Return 12 triangles (faces) for an axis-aligned box."""
    v = np.array([
        [x,      y,      z],
        [x + dx, y,      z],
        [x + dx, y + dy, z],
        [x,      y + dy, z],
        [x,      y,      z + dz],
        [x + dx, y,      z + dz],
        [x + dx, y + dy, z + dz],
        [x,      y + dy, z + dz],
    ])
    # 12 triangles, 2 per face
    faces = [
        # bottom (z)
        [0, 2, 1], [0, 3, 2],
        # top (z+dz)
        [4, 5, 6], [4, 6, 7],
        # front (y)
        [0, 1, 5], [0, 5, 4],
        # back (y+dy)
        [2, 3, 7], [2, 7, 6],
        # left (x)
        [0, 4, 7], [0, 7, 3],
        # right (x+dx)
        [1, 2, 6], [1, 6, 5],
    ]
    return [(v[f[0]], v[f[1]], v[f[2]]) for f in faces]


def subtract_box_from_triangles(positive_boxes, negative_boxes):
    """
    Simple CSG: build mesh from positive boxes, then add negative boxes
    as inverted geometry. For 3D printing, we use a simpler approach:
    build the shape directly by computing the wall geometry.
    """
    pass  # We'll build geometry directly instead


def build_cradle():
    all_tris = []

    # ── Base tray (U-shape) ──────────────────────────────────────────
    # Bottom plate
    all_tris.extend(box_triangles(0, 0, 0, outer_w, cradle_len, wall))

    # Left wall
    all_tris.extend(box_triangles(0, 0, wall, wall, cradle_len, lip_h))

    # Right wall - built in segments around servo pockets and arm slots
    rw_x = outer_w - wall

    # Servo pocket and arm slot positions in cradle-local Y
    power_local_y = power_btn_y - cradle_y_offset
    voldn_local_y = voldn_btn_y - cradle_y_offset

    def right_wall_segments(btn_local_y):
        """Return Y-ranges to skip for a servo pocket + arm slot."""
        pocket_y0 = btn_local_y - sg90_body_w / 2
        pocket_y1 = btn_local_y + sg90_body_w / 2
        return (pocket_y0, pocket_y1)

    pwr_skip = right_wall_segments(power_local_y)
    vol_skip = right_wall_segments(voldn_local_y)

    # Sort skip ranges
    skips = sorted([pwr_skip, vol_skip], key=lambda s: s[0])

    # Build right wall segments between and around skip zones
    segments_y = []
    prev_end = 0
    for (s0, s1) in skips:
        if s0 > prev_end:
            segments_y.append((prev_end, s0))
        prev_end = s1
    if prev_end < cradle_len:
        segments_y.append((prev_end, cradle_len))

    for (y0, y1) in segments_y:
        all_tris.extend(box_triangles(rw_x, y0, wall, wall, y1 - y0, lip_h))

    # Right wall: fill above servo pockets (above sg90_body_h)
    for (s0, s1) in skips:
        if wall + sg90_body_h < wall + lip_h:
            remaining_h = lip_h - sg90_body_h
            if remaining_h > 0:
                all_tris.extend(box_triangles(
                    rw_x, s0, wall + sg90_body_h,
                    wall, s1 - s0, remaining_h))

    # Right wall: fill below arm slots (the lower part of the pocket area)
    arm_slot_h = 8.0
    arm_slot_w = 6.0
    for (s0, s1) in skips:
        btn_center = (s0 + s1) / 2
        arm_y0 = btn_center - arm_slot_w / 2
        arm_y1 = btn_center + arm_slot_w / 2
        arm_z0 = wall + sg90_body_h - 6
        arm_z1 = arm_z0 + arm_slot_h

        # Below arm slot in pocket area
        below_h = arm_z0 - wall
        if below_h > 0:
            all_tris.extend(box_triangles(rw_x, s0, wall, wall, s1 - s0, below_h))

        # Sides of arm slot (pocket area, beside the slot)
        # Left side of slot
        if arm_y0 > s0:
            all_tris.extend(box_triangles(
                rw_x, s0, arm_z0, wall, arm_y0 - s0, arm_slot_h))
        # Right side of slot
        if s1 > arm_y1:
            all_tris.extend(box_triangles(
                rw_x, arm_y1, arm_z0, wall, s1 - arm_y1, arm_slot_h))

    # ── Servo tab shelves (on outside of right wall) ─────────────────
    shelf_depth = 3.0
    for btn_y in [power_local_y, voldn_local_y]:
        all_tris.extend(box_triangles(
            outer_w, btn_y - sg90_tab_w / 2, wall,
            shelf_depth, sg90_tab_w, sg90_tab_h))

    # ── Front lip (short wall at the front for phone retention) ──────
    all_tris.extend(box_triangles(wall, 0, wall, inner_w, wall, lip_h))

    # ── Back lip ─────────────────────────────────────────────────────
    all_tris.extend(box_triangles(wall, cradle_len - wall, wall, inner_w, wall, lip_h))

    # ── ESP32 mount posts (left side exterior) ───────────────────────
    post_d = 6.0
    post_h = 8.0
    for dy in [15, 55]:
        # Approximate cylinder as octagonal prism
        cx = -post_d / 2
        cy = dy
        n_sides = 8
        r = post_d / 2
        for i in range(n_sides):
            a0 = 2 * np.pi * i / n_sides
            a1 = 2 * np.pi * (i + 1) / n_sides
            x0, y0 = cx + r * np.cos(a0), cy + r * np.sin(a0)
            x1, y1 = cx + r * np.cos(a1), cy + r * np.sin(a1)
            z_base = wall
            # Bottom triangle
            all_tris.append((
                np.array([cx, cy, z_base]),
                np.array([x0, y0, z_base]),
                np.array([x1, y1, z_base]),
            ))
            # Top triangle
            all_tris.append((
                np.array([cx, cy, z_base + post_h]),
                np.array([x1, y1, z_base + post_h]),
                np.array([x0, y0, z_base + post_h]),
            ))
            # Side quad (2 triangles)
            all_tris.append((
                np.array([x0, y0, z_base]),
                np.array([x1, y1, z_base]),
                np.array([x1, y1, z_base + post_h]),
            ))
            all_tris.append((
                np.array([x0, y0, z_base]),
                np.array([x1, y1, z_base + post_h]),
                np.array([x0, y0, z_base + post_h]),
            ))

    return all_tris


def main():
    tris = build_cradle()
    stl_mesh = mesh.Mesh(np.zeros(len(tris), dtype=mesh.Mesh.dtype))
    for i, (v0, v1, v2) in enumerate(tris):
        stl_mesh.vectors[i][0] = v0
        stl_mesh.vectors[i][1] = v1
        stl_mesh.vectors[i][2] = v2

    stl_mesh.update_normals()

    out_path = "/home/user/mobilemash/cad/pixel10pro_cradle.stl"
    stl_mesh.save(out_path)
    print(f"Saved STL to {out_path}")
    print(f"  Triangles: {len(tris)}")

    # Print bounding box
    mins = stl_mesh.vectors.reshape(-1, 3).min(axis=0)
    maxs = stl_mesh.vectors.reshape(-1, 3).max(axis=0)
    dims = maxs - mins
    print(f"  Bounding box: {dims[0]:.1f} x {dims[1]:.1f} x {dims[2]:.1f} mm")


if __name__ == "__main__":
    main()
