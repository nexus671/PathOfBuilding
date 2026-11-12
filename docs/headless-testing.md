# Headless testing

Calculations, build edits and UI control checks can run without opening PoB or sending desktop input. Use an isolated build loaded through `src/HeadlessWrapper.lua`; saved player builds do not need to be changed.

The wrapper uses real zlib compression for imports and compressed jewel data. Windows uses the bundled `runtime/zlib1.dll`; Linux needs the system zlib library. Headless jewel loading leaves binary caches untouched unless caching is explicitly requested.

Run the calculation suite with `busted --lua=luajit`, and the MCP protocol suite with `node --test spec/AI/*.test.cjs`.

## Render and exercise controls

Install Pillow for Python, then run from the repository root:

```sh
python tools/check_headless_ui.py --lua luajit
```

On Windows, pass the full path to a LuaJIT executable if it is outside PATH. The runner configures the repository's Lua modules and runtime DLLs automatically.

Each run produces a fresh directory under `artifacts/headless-ui` containing PNG frames, draw records, contrast, clipping and overlap audits, input logs and source hashes. CI runs the same checks and uploads this evidence.

The 102 rendered states cover native build-tab navigation, AI goals and connection controls, candidate review/apply/undo, Atlas search, allocation/removal/avoidance, pan/zoom, version switching, notes, sharing, live resizing, route previews, crafting project creation and working-item persistence, the graphical workbench, currency selection, item-click crafting and undo, Allflame settings and choices, manual item editing, target conditions, simulation results, cancellation, distributions and the recovery timeline at two window sizes. Clicks, dropdown selection and text entry go through native control input handlers. Deliberately unreadable/clipped text and overlapping controls must fail the audit's self-test.

`Modules.HeadlessUI` provides the reusable drawing/input adapter for additional control scenarios. It uses PoB's bundled bitmap-font metrics and glyph atlases. Bundled textures loaded during a scenario are rendered with their draw tint. Older untracked textures and non-ASCII glyphs are recorded as placeholders, so these frames validate control layout and text including the official Atlas sprite crops, rather than GPU rendering or operating-system dialogs. Clipboard operations remain inside the test process.

Recovery performance can also be tested without a desktop: `CalcsTab:BuildOutput(true)` queues the same background work used after desktop edits; `Modules.RecoveryTasks.tick` advances it. The ordinary headless calculation path stays synchronous for deterministic build and AI tests.
