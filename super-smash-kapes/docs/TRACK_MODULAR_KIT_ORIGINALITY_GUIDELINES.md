# Track Modular Kit Originality Guidelines

Reference archive location:

`references/track/block_previews/Block Previews.zip`

That archive is **reference material only**.

## Allowed use

We use filenames and (when needed) preview images to understand:

- block taxonomy / families
- modular track-building vocabulary
- useful piece categories that recur across environments
- general proportions at the level of “tight hairpin vs wide sweeper”
- how elevation, borders, and specials sit relative to a driving surface

The output of that work is **our own** generator, dimensions, and art.

## Forbidden

We will not:

- extract or copy proprietary meshes into `res://assets/`
- copy proprietary textures, logos, branded signage, or decorative compositions
- recreate copyrighted Trackmania / Nadeo artwork
- import the preview PNGs as runtime Godot textures
- make gameplay logic depend on third-party filenames

`.gdignore` is in place so the zip and inventory stay out of the Godot import pipeline.

## Geometry rule

V1 pieces are generated from **our** contract:

- road width 11.0 m
- shoulder 0.7 m each side
- guardrail height 0.9 m
- Godot forward −Z, up +Y, road centered on X = 0
- ENTRY / EXIT connectors

A Blender function plus JSON config is the source of truth, not a traced screenshot.

## Visual rule

Shared materials live under `res://assets/track/materials/` (future). Modules do not bake unique copied atlases. Themes (Asunción night, Costanera, etc.) wrap the same geometry later.

## Review question

If a piece would only exist because a preview looks like a specific proprietary decoration, drop it from V1.
