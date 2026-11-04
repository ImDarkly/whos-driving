# Retro Car With Interior — asset provenance

Author: Bricchi Games / Bruno Bricchi.
Source: https://bricchi-games.itch.io/retro-car-with-interior
Downloaded free, without sign-in or payment, 2026-11-04: `Retro Car1.0.zip`.
Archive SHA-256: c49eb574245b316171c484088fec9c2b28faecffefa4fe7fda7f4a7ca3210e8f

## Creator's stated terms (verbatim)

> Retro car pack from the 80s for your game - Free under Creative Commons License (commercial use allowed and attribution required).

Creator's license comment on the same page (verbatim):

> it's under CC 4.0, do whatever you want with it, just credit me somewhere 😃

No license file was supplied in either archive. The exact Creative Commons variant is unspecified; this is not a claim of CC BY 4.0 or any other precise variant. Oleksandr approved incorporation on these stated terms on 2026-11-04. No standalone license text or version has been invented. The in-game room panel credits Bricchi Games.

## Modifications

Parked-car variants recolour blue body texels in a runtime copy of the existing atlas and rebuild mipmaps. Non-body atlas texels, glass materials and emissive light maps are retained. These generated textures stay in memory; no new third-party art files are tracked.

Converted the supplied Blend to embedded-texture glTF/GLB using installed Blender 5.2.1 LTS. Rebuilt missing diffuse/emissive references using the supplied blue body texture and emissive map; simplified glass to transparent tinted material supported by Godot Compatibility; retained opaque interior, roof and doors with double-sided surfaces. Baked coordinate conversion and body fit to the existing 2.24 × 3.6 m gameplay footprint, with longitudinal adjustment around the existing axle positions. Recentered four visual wheels on unchanged force positions and retained their fixed orientation. Added editable seat markers in the separate visual scene. Doors, steering wheel, hood and trunk are static. No original license document existed to alter or omit.

The derived GLB, Godot-extracted textures and import metadata are now local-only and ignored, along with car-containing cabin preview renders, under the repository distribution decision in `docs/SPEC.md`. This supersedes the earlier decision to include them in Git. Our visual scene/seat markers and this attribution remain tracked. Restore requirements are in `docs/KNOWLEDGE.md`. Source textures are embedded in the GLB; Godot extracts project-local copies on import. No author-machine paths or Blender installation are required at runtime. Original archives and conversion scratch files stay in ignored build storage.
