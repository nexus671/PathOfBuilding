# Planning polish

The planning workspace now groups Atlas, crafting and AI tools behind the same navigation. These changes stay on `dev` until released; they do not update an already running installation.

| # | Improvement | Where to use it |
| --- | --- | --- |
| 1 | Item-centered crafting | Click the item to apply a currency; click an affix for relevant actions. |
| 2 | Searchable currency palette | Craft → Find currencies; filter categories and favorite actions. |
| 3 | Currency explanations | Hover a currency; inspect prerequisites and the selected action hint. |
| 4 | Affix details | Click an affix or use Settings → Inspect affixes and slots. |
| 5 | Modifier distinctions | Item labels distinguish implicit, enchanted, natural, crafted and fractured modifiers; influences appear on the card. |
| 6 | Visual crafting history | Craft → Item history; preview and restore an earlier item. |
| 7 | Item differences | History shows each transition; Settings → Before / after compares with the starting item. |
| 8 | Target modifier picker | Targets → Find target modifiers; search text and tags and inspect ranges. |
| 9 | Crafting comparisons | Simulate → Compare recipes; compare bounded trials and supplied prices. |
| 10 | Crafting coverage | Coverage; search implemented actions and model assumptions. |
| 11 | Atlas mechanic filters | Find nodes → category; selecting a result highlights its mechanic. |
| 12 | Atlas search list | Find nodes; results show added point costs. |
| 13 | Route alternatives | Routes; Plan tools can set a preferred waypoint. |
| 14 | Atlas minimap | Click the overview in the canvas corner to move the camera. |
| 15 | Atlas node details | Hover for a tooltip; select to pin details and a route preview. |
| 16 | Atlas plan comparison | Plan tools → Compare with a saved plan. |
| 17 | Atlas starting routes | Plan tools → Strategy starting points; editable mechanic routes from the bundled version. |
| 18 | Atlas sharing | Notes & sharing; official links accept query strings and trailing slashes, with clearer unsupported-link errors. |
| 19 | Atlas history | Undo / Redo, or Plan tools → Change history; includes exclusions and committed budget edits. |
| 20 | Atlas bonus summary | Allocated stats; searchable bonus text grouped by mechanic. |
| 21 | Shared layout | Common tabs, actions, spacing, colors and navigation. |
| 22 | Resizable panels | Drag the divider in Atlas or the crafting workbench. |
| 23 | Smaller windows | Tested at 960×640 as well as larger sizes; encounter charts compress to available height. |
| 24 | Keyboard navigation | Tab / Shift+Tab, Enter, focus outlines, Escape, Alt+1/2/3, Atlas Ctrl+F and planning undo shortcuts. |
| 25 | Helpful empty states | Pickers explain empty results; projects, targets, simulations and AI views show the next action. |
| 26 | Responsive work | Cancellable cooperative crafting, smaller work slices, cached picker details and chart summaries, visible-row text rendering. |
| 27 | AI comparison | Review → Summary; changes appear beside current and proposed metrics. |
| 28 | Calculation explanations | Review → Explain; measured pool, mitigation, avoidance and recovery changes with attribution limits. |
| 29 | Survival charts | AI builds → Survival charts; scenario presets, legends, hover values and event ticks. |
| 30 | UI regression coverage | Native input tests and rendered audits cover 225 states at three sizes, long titles, scrolling, resizing and restoration. |

Crafting remains a bounded model, and Atlas bonus text is not a farming-income simulator. Recipe costs need supplied prices. Calculation explanations report measured changes for the whole proposal; they do not prove which individual change caused an improvement.

Headless frames use native PoB draw commands, bundled fonts and artwork. They do not verify the native GPU renderer, operating-system dialogs or the running desktop installation. Desktop rendering remains a separate verification step.
