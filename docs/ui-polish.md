# Planning UI improvements

The twenty review items are implemented across the planning workspace. Normal build Save persists kept plans and checkpoints; working item drafts remain separate until kept.

The planning header keeps **Save**, **Save As**, the build name and save status visible. Choose **< Build** to edit character level, class, ascendancy or loadout. Those controls return when you leave the planning workspace.

| # | Change | Where to use it |
|---|---|---|
| 1 | Small-screen project dialog with a fixed footer and visible title | Crafting > New project |
| 2 | Separate working draft, kept and saved states | Workspace header; Keep working craft; normal Save |
| 3 | Consistent tool navigation with remembered page, focus and scroll state | Workspace navigation and Alt+1 through Alt+5 |
| 4 | Highlighted selections and keyboard list navigation | Journey, Atlas results, prerequisites, recipe cards; arrows to browse and Space to toggle checklists |
| 5 | Normal/large planning text preference | Aa in the workspace bar; retained in application settings |
| 6 | Collapsible item modifiers and a draggable item/details divider | Journey > Gear > Expand details; drag the horizontal handle |
| 7 | Direct empty-target actions | Journey > Gear > Paste, Equipped, Link craft |
| 8 | Specific requirement reasons and correction shortcuts | Journey > Gear > Why this needs review; Recalculate upgrades |
| 9 | Aligned wishlist comparison table | Journey > Gear > Compare all |
| 10 | Inline modifier differences and currency-change feedback | Equipped/target cards and the crafting workbench; + and - indicators accompany colors |
| 11 | Guided starting item, target, method/budget and review flow | Crafting project wizard |
| 12 | Selectable recipe step cards with currency artwork and explicit routes | Crafting > Simulate > Recipe routes |
| 13 | Success, actions, spending and uncertainty cards with a refinement action | Crafting > Simulate > Results / distribution > Run more trials |
| 14 | Named Atlas search results with mechanic and point cost | Atlas > Tree > Search |
| 15 | Persistent allocated mechanic counts and a recorded bonus | Beneath the Atlas canvas; Allocated stats opens the full list |
| 16 | Resource-balance grid with currency icons and dated transactions | Journey > Budget |
| 17 | Current-stage timeline, colored gem markers, readable sections and saved quest checklists | Journey > Leveling > Open leveling guide |
| 18 | Connection setup steps with actual client receipts, context-read confirmation and a round-trip test | AI builds > Connection |
| 19 | Friendly stat names, changed metrics first and optional unchanged rows | AI builds > Review proposal |
| 20 | Series toggles, actual/normalized values, empty-lane filtering and named event annotations | Survival charts |

The connection test needs the client to call `get_build_connection` after Test connection. Context synchronization is confirmed only after a successful `get_build_context` read. Client contacts expire after three minutes; enabling the desktop bridge alone does not confirm a connected client.

Chart controls change presentation only. Calculations and recorded events remain unchanged. The default view hides lanes with no data; Actual values uses a common value scale within each lane. Event annotations call out recharge, tincture, shroud and death events when present in the selected trace.

The native input suite exercises these flows at 960×640, 1024×768 and 1280×720. Render audits include dialog titles and bounds, contrast, clipping, overlapping controls, large text, and empty states. The isolated stdio MCP workflow also verifies client receipts, the round trip, proposal review, crafting, saving/reopening and checkpoint undo.
