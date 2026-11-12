# Your build journey

Open **AI builds**, **Atlas**, or **Crafting**, then choose **Journey**. Alt+4 opens it from any planning page.

- **Overview:** next tasks, reasons for blockers and current character checks. Ready tasks appear first, followed by your priority (1 first). This order is a planning aid, not a calculated upgrade score.
- **Roadmap:** milestones for passives, gems, quests, ascendancy, gear, crafts and Atlas progression. Choose linked plans from the menus. Prerequisites use milestone IDs shown in their details. Complete prerequisites before completing a dependent milestone. Reopening a prerequisite also reopens completed dependents.
- **Gear:** see current equipment and record next, final or alternative upgrades. Choose buying, crafting or farming, link a craft and optionally reserve its estimated cost. Mark an acquired goal owned to release its reservation. Estimates are supplied by you or your AI, not live prices.
- **Budget:** add each currency, material or owned base as a resource, then record holdings and spending. Transactions can link to a craft. Resources remain separate; there is no assumed exchange rate. Spending cannot exceed recorded holdings. Correct a mistaken transaction with an explicit balancing record and note.
- **Leveling:** write a readable guide with gems and links, passives, gear, ascendancy, quests and transition conditions. The **...** buttons open multiline editors. In **AI builds > Candidates**, **Keep leveling guide** saves all calculated leveling stages without applying them. Recalculate stale candidates first; captured guide text does not automatically update when the character changes.

In the crafting workbench, **Keep working craft** records the current item, action and undo history, targets, seed and settings. Reopening the project resumes that checkpoint. Further experiments remain a session draft until you keep it again. Checkpoints and simulations do not deduct from the budget; record actual spending separately.

Use the normal **Save** command to persist everything in the build. Exported builds carry the journey and crafting checkpoints. There is no entry-count limit; each metadata section has a 2 MiB size guard. Unreadable or newer metadata is preserved unchanged.

The local MCP server exposes **get_build_journey** and **propose_journey_plan**. An AI can read the roadmap, budget and explained next actions, then propose changes through the existing desktop review. It must read and preserve existing entries when proposing a replacement. These tools do not import your stash, fetch live prices, apply builds or save files automatically.
