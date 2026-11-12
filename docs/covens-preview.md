# Covens of Umbra tree preview

The fork bundles GGG's pinned **3.30 passive tree preview** and **3.30 Atlas preview 2** from November 12, 2026. These are opt-in previews. Existing builds and the default passive tree remain on their saved/stable versions.

## Passive tree

In **Tree > Version**, choose **3.30 preview** and review the native conversion dialog. Keep a separate tree spec when you want to compare versions. The preview includes the published nodes, mastery choices, bloodlines and bundled sprite artwork.

The tree warning and AI build analysis identify the preview. Items, gems and new league mechanics still use the current calculation engine; adding the tree does not establish full 3.30 calculation support. Review unsupported modifiers before relying on a result.

## Atlas

Choose **3.30.0-preview** in Atlas. New Atlas plans on a preview character select that version automatically. The official base point limit is **150**, with granted points accounted for separately. Search, routing, strategy stages, native saving, bundles and MCP proposals preserve the exact preview version.

GGG's Standard and Covens Atlas exports have identical graph data at this pinned revision; the generator checks this and records both source hashes. Ruthless Atlas data is not bundled. Stable **3.29.3** is also available, while 3.29.1 and 3.27.0 remain available for existing plans.

## Sources

- [Passive tree preview, commit 550fb34](https://github.com/grindinggear/skilltree-export/commit/550fb34ae7fca9ec4d760a2ac845bb2ba1032ec3)
- [Atlas preview 2, commit d225501](https://github.com/grindinggear/atlastree-export/commit/d225501d7a3e52c991309116473908c284075e89)
- [Stable Atlas 3.29.3, commit dcb2a00](https://github.com/grindinggear/atlastree-export/commit/dcb2a006b68740f3ecbd317775c262fc6ed7b8af)

`python tools/update_passive_preview.py` regenerates the passive preview using the existing ascendancy-position preprocessor. `python tools/update_atlas_data.py --version 3.30.0-preview` regenerates the Atlas preview. Both use immutable source commits and bundle artwork for offline use. Provenance and asset SHA-256 hashes are stored beside the generated data.

After changing bundled artwork, run `python tools/update_headless_image_sizes.py` to refresh image dimensions used by headless rendering. The UI suite uses real dimensions and sprite UVs for passive-tree screenshots, including textured connectors and repeated backgrounds.
