# FilterBlade feature review

Reviewed the live [PoE 1 FilterBlade site](https://www.filterblade.xyz/?game=Poe1) on November 12, 2026: Start, Overview, Customize (including currency tier lists), Simulate, Themes, Advanced, campaign auto-adjust and the anonymous export flow. Login, saved cloud content and paid background services were not exercised. The site's current preset was still labelled 3.29 Allflame; our 3.30 additions remain sourced from GGG.

This is a comparison, not a claim of FilterBlade parity. Its website, customizer definitions, economy service and cloud systems are separate from the MIT-licensed NeverSink filter files.

| FilterBlade capability | Our fork after this redesign | Remaining work |
| --- | --- | --- |
| Guided start page | Campaign, early mapping and endgame cards | More character-specific starter presets |
| Strictness presets | Seven pinned NeverSink levels | Updated through fork releases |
| Game modes | Normal and Ruthless | No PoE 2 support; Softcore/Hardcore economy tiers are separate work |
| Build auto-adjust | Reads saved crafts, planned gear, gems, resources and Atlas plans | More stage-specific vendor recipes |
| Campaign weapon selection | Eighteen native families, equipped-family selection and progressive base-level windows | More character-specific class presets |
| Campaign armour selection | Armour/evasion/ES combinations and Ward, with native base art | More starter presets |
| Campaign vendor rares | Base preset rules plus level-bounded linked-colour, six-socket/link and quality-gem policies | More vendor recipes; no proceeds model |
| Endgame build adjustment | Exact saved targets and Atlas pickups | Trade/SSF-specific policies |
| Item overview and colour examples | Live scene using the compiled filter | Explanatory galleries for every item family |
| Hierarchical customizer | Category sidebar, search, personal/base/policy scope and collapsible compiled sections | Human-edited subcategories |
| Base-filter rule browsing | Full parsed preset catalogue with styled examples | Human-edited descriptions for every source rule |
| Category coverage | Sixteen families including cards, flasks, tinctures, jewels, recipes and special currency | Deeper nested sections |
| Rule editing | Stable override identities across catalogue, matched rules and structure; provable shadowing diagnostics | Broader predicate-overlap analysis |
| Show/hide toggles | Personal enable/disable; action editor | Per-category inclusion policies |
| Rule order | Move personal rules up/down; base order preserved | Drag-and-drop ordering UI |
| Currency tier lists | Custom/preset tier browsing, exact item movement, drag/drop, tier creation/removal/order | Economy-driven automatic reassignment |
| Stacked currency tiering | Existing stack conditions are preserved and editable | Uniform/adjusted stacked-tier controls |
| Economy-based tiers | Pinned NeverSink snapshot | Live pricing, outlier handling and recalculation |
| Global search | Searches names and raw condition/action text | Cross-page command palette |
| Loot generator | Deterministic example scenes and build-target samples | Representative drop distributions and encounter presets |
| Hidden-drop display | Simulator toggle | Dedicated hidden-drop statistics |
| Click a simulated item | Explains results and opens matched blocks for editing | More unknown-property guidance |
| Item configuration | Editable properties and native game-clipboard import | Hidden identities are never inferred |
| Item history | Dedicated session sample-history browser | Persisted named sample sets |
| Generator level settings | Shared area/item-level controls | Encounter-specific samples |
| Expensive-drop generation | Currency scene and exact custom samples | A separate expensive-item mode based on verified tiers |
| Preview background | Stone, dark and light scenes | Additional environments |
| Individual colours | Swatches, RGBA input and live preview | Full colour wheel and saved palettes |
| Font size | Live size slider | Additional typography presets |
| Alert sound selection | All 16 numbered IDs plus silence; custom references preserved | Exact game audio preview and custom sound pack management |
| Minimap icons | All twelve shapes, colour/size selection and native geometry previews | Exact game-texture rendering |
| Themes | Generated-target palettes, personal restyling and whole-filter decorators | Saved custom palettes and colour wheel |
| Global one-click edits | Reversible declared font/colour, alert identity/volume, icon visibility and beam controls | More selective category transformations |
| Shared modules | Portable named snapshots, cross-profile copy and explicit updates | Public discovery and module dependency graphs |
| Review changes | Before/after rule and item-list review, priority-conflict diagnostics, undo/redo | Full source-file diff for imported bases |
| Filter structure | Dedicated compiled section/family tree, priority conflicts, exact block text and editing | Full source-file diff |
| Test local filter | Original imported text retained; simulator evaluates it | Resolve external Import files explicitly |
| Save/resume | Native Save/bundles, page drafts and two-slot local draft recovery | Further crash/restart field testing |
| Cloud saved filters | Account list/import UI | FilterBlade cloud saves are not connected |
| Share filters/modules | Build sharing and portable bundles | Dedicated public filter/module catalogue |
| One-time PoE upload | Explicit reviewed API publication | Live verification with a filter-authorised account |
| Automatic uploads | Not implemented | Requires a separately operated update service |
| Frequent economy refresh | Not connected | FilterBlade's hosted economy feed is not bundled |
| Single-filter download | Copy/export `.filter`, preserving existing files | Optional replacement workflow |
| Export all strictnesses | Each profile can select any strictness; batch export includes personal edits | Seven strictness files with collision checks; ZIP packaging remains |
| Validation | Native parser checks and account-server validation when authorised | Broader syntax coverage and live game validation |
| Mobile layout | Desktop layouts tested at 960, 1024 and 1280 widths | Native PoB is not a mobile web app |

The remaining offline depth includes selective bulk transformations, named sample sets, saved palettes and a full source-file diff view. Hosted economy updates remain separate service work. The release checklist tracks implementation and repeated workflow verification.

Reference screenshots were captured outside the repository during the review. Third-party advertising scripts logged browser errors; the main anonymous customizer and simulator remained usable. No login, publication, purchase or subscription was performed.
