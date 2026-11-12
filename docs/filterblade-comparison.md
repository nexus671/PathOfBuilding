# FilterBlade feature review

Reviewed the live [PoE 1 FilterBlade site](https://www.filterblade.xyz/?game=Poe1) on November 12, 2026: Start, Overview, Customize (including currency tier lists), Simulate, Themes, Advanced, campaign auto-adjust and the anonymous export flow. Login, saved cloud content and paid background services were not exercised. The site's current preset was still labelled 3.29 Allflame; our 3.30 additions remain sourced from GGG.

This is a comparison, not a claim of FilterBlade parity. Its website, customizer definitions, economy service and cloud systems are separate from the MIT-licensed NeverSink filter files.

| FilterBlade capability | Our fork after this redesign | Remaining work |
| --- | --- | --- |
| Guided start page | Campaign, early mapping and endgame cards | More character-specific starter presets |
| Strictness presets | Seven pinned NeverSink levels | Updated through fork releases |
| Game modes | Normal and Ruthless | No PoE 2 support; Softcore/Hardcore economy tiers are separate work |
| Build auto-adjust | Reads saved crafts, planned gear, gems, resources and Atlas plans | Broader weapon/defence-family rules and stage-specific vendor recipes |
| Campaign weapon selection | Exact target bases and linked socket groups | Full weapon-family and class preset selector |
| Campaign armour selection | Exact target bases | Armour/evasion/ES family selection |
| Campaign vendor rares | Base preset rules retained | Stage-by-stage recipe management |
| Endgame build adjustment | Exact saved targets and Atlas pickups | Trade/SSF-specific policies |
| Item overview and colour examples | Live scene using the compiled filter | Explanatory galleries for every item family |
| Hierarchical customizer | Category sidebar, search, personal/base scope | Deeper subcategories and collapsible sections |
| Base-filter rule browsing | Full parsed preset catalogue with styled examples | Human-edited descriptions for every source rule |
| Category coverage | Currency, equipment, maps/fragments, gems, league items and other | Separate card, flask, tincture, recipe and exotic-currency subcategories |
| Rule editing | Base edits create personal overrides | Explicit management of overlapping base overrides |
| Show/hide toggles | Personal enable/disable; action editor | Per-category inclusion policies |
| Rule order | Move personal rules up/down; base order preserved | Drag-and-drop ordering UI |
| Currency tier lists | Can inspect and override individual tier rules | Drag items between tiers; add/remove tiers |
| Stacked currency tiering | Existing stack conditions are preserved and editable | Uniform/adjusted stacked-tier controls |
| Economy-based tiers | Pinned NeverSink snapshot | Live pricing, outlier handling and recalculation |
| Global search | Searches names and raw condition/action text | Cross-page command palette |
| Loot generator | Deterministic example scenes and build-target samples | Representative drop distributions and encounter presets |
| Hidden-drop display | Simulator toggle | Dedicated hidden-drop statistics |
| Click a simulated item | Selects it and explains its result | Jump directly to every matched base rule |
| Item configuration | Editable item properties and exact filter evaluation | Import directly from the game's clipboard format |
| Item history | Session selection and seed | A dedicated history browser |
| Generator level settings | Current example scenes use area level 83; item editor can change it | Visible shared area/item-level control |
| Expensive-drop generation | Currency scene and exact custom samples | A separate expensive-item mode based on verified tiers |
| Preview background | Native stone scene | Background selector |
| Individual colours | Swatches, RGBA input and live preview | Full colour wheel and saved palettes |
| Font size | Live size slider | Additional typography presets |
| Alert sound selection | All 16 numbered IDs plus silence; custom references preserved | Exact game audio preview and custom sound pack management |
| Minimap icons | Icon selection and live label/beam previews | Exact rendering and colour controls for every supported icon shape |
| Themes | Generated-target palette and personal-rule restyling | Minimum font size, common alert volume/mute and disabled beams apply across base and personal rules; full colour decorators remain |
| Global one-click edits | Explicit personal-rule restyle | Reversible whole-filter size, alert and beam settings; broader transformations remain |
| Shared modules | Individual build-owned profiles | Reusable modules across profiles, dependencies and sharing |
| Review changes | Patch migration audit and visible personal overrides | Full before/after diff and undo history |
| Filter structure | Searchable parsed base rules; raw export inspection | A dedicated structure tree |
| Test local filter | Original imported text retained; simulator evaluates it | Resolve external Import files explicitly |
| Save/resume | Native build Save, portable bundles and planning-page drafts | Recovery of unkept drafts after restart |
| Cloud saved filters | Account list/import UI | FilterBlade cloud saves are not connected |
| Share filters/modules | Build sharing and portable bundles | Dedicated public filter/module catalogue |
| One-time PoE upload | Explicit reviewed API publication | Live verification with a filter-authorised account |
| Automatic uploads | Not implemented | Requires a separately operated update service |
| Frequent economy refresh | Not connected | FilterBlade's hosted economy feed is not bundled |
| Single-filter download | Copy/export `.filter`, preserving existing files | Optional replacement workflow |
| Export all strictnesses | Each profile can select any strictness; batch export includes personal edits | Seven strictness files with collision checks; ZIP packaging remains |
| Validation | Native parser checks and account-server validation when authorised | Broader syntax coverage and live game validation |
| Mobile layout | Desktop layouts tested at 960, 1024 and 1280 widths | Native PoB is not a mobile web app |

The most useful next parity work is tier-list item movement, broader whole-filter decorators and shared modules. Hosted economy updates remain a separate service. These require separate data models and correctness tests; a visual redesign alone does not provide them.

Reference screenshots were captured outside the repository during the review. Third-party advertising scripts logged browser errors; the main anonymous customizer and simulator remained usable. No login, publication, purchase or subscription was performed.
