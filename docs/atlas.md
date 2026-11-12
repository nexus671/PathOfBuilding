# Atlas planner

Open **Atlas** beside **AI builds**, or switch to **Atlas** in the planning workspace.

1. Choose the exact tree version. We bundle the official **Standard 3.27.0 and 3.29.1** graphs. League variants and Ruthless are not included.
2. Enter a name and the number of Atlas points you have earned. The initial budget is the tree's maximum; it does not read account progression.
3. Search names or stat text. Select a result, or click a node on the graph, then **Connect path**. The planner adds a shortest connecting path.
4. Use the mouse wheel to zoom and drag empty space to pan. **Fit tree** resets the view. The canvas uses the official background, node icons, frames and mechanic emblems. Allocated paths are gold; avoided nodes have red frames. Hover for modifier descriptions. Double click a node to connect it, or remove it if allocated.
5. **Avoid selected** excludes a node from future paths. Avoided nodes are session preferences, cleared by importing or opening another plan. **Remove branch** also removes nodes that lose their connection to the start. **Undo** restores the previous allocation draft.
6. Open **Notes & sharing** for farming notes and import/export. Choose **Keep plan** to keep the draft in this build. This changes unsaved metadata. Use the normal build **Save** to persist it. Up to eight named plans can be kept with each build; **Saved plans** opens or deletes them.

**Allocated stats** lists selected modifier text, repeated-line counts, notables and keystones. Counts are not effective totals: increased effect, conditional modifiers, blocking and keystone interactions are not simulated. Atlas allocations do not change character DPS, EHP or encounter assumptions.

## Sharing

**Copy plan** exports JSON with the exact patch version, point budget, allocations and notes. **Paste plan** imports that JSON into the current draft. Review it before keeping it.

**Official link** copies a version-six `pathofexile.com/fullscreen-atlas-skill-tree/` URL. These URLs do not contain a patch version. For an official URL import, first select its original patch and budget, then use **Paste plan**. The importer rejects unknown, disconnected and over-budget nodes. Node IDs can survive between patches while changing meaning, so a successful import is not proof that the selected patch is correct. Use our JSON format for reliable versioned sharing.

Other planners' proprietary links, old URL formats and shortened links are not imported. Export an official Atlas URL from that planner first. The official website may display a different patch from an older saved plan.

## AI tools

Reconnect the MCP client after updating. Enable build proposals in **AI builds**.

- `get_atlas_plans`: read saved plans, bundled versions and the build revision.
- `search_atlas_nodes`: search a selected official graph for native node IDs and text.
- `plan_atlas_tree`: connect up to thirty desired IDs to a plan, optionally avoiding nodes. Returns a separate draft, added nodes, point accounting, stat text and an official link.
- `propose_atlas_plan`: submit that plan for normal desktop review. Only the desktop **Apply** button commits the candidate; build **Save** persists it.

Search and routing are queued. Poll `get_proposal_status` and match the returned request ID. Neither tool applies changes. Routing uses deterministic shortest connections in target order; it is a greedy heuristic, not a globally optimal multi-target solver. Gateways use the official graph links. Granted Atlas points are counted in the final budget.

Example request: “Use my Atlas version and a 90-point budget. Find Essence and map-sustain nodes, avoid mechanics I dislike, and propose a connected farming plan. Explain the keystones and tradeoffs before I apply it.”

This first version does not fetch character Atlas completion, scrape community trees, provide popularity heatmaps, price scarabs or predict farming income. Maps, scarabs and strategy steps can be recorded in notes.

## Sources and maintenance

Node names, stats, links, positions, point limits, granted points and artwork come from [GGG's official Atlas export](https://github.com/grindinggear/atlastree-export). Each bundled graph records its immutable source URL, commit and SHA-256. Decorative mastery icons are excluded from allocation. Artwork is bundled from the same pinned official export; planning works offline. No third-party planner code or artwork is bundled.

`python tools/update_atlas_data.py` regenerates the graphs from pinned official exports. Updating versions also requires changing the native and MCP version allowlists, testing changed rules and budgets, and publishing the new files in the updater manifest. There is no silent network update of saved plans.

Feature research: [Path of Pathing](https://pathofpathing.com/) offers desired/avoided-node routing and exports; [poe.ninja](https://poe.ninja/posts/atlas-trees) offers community-tree filters, heatmaps and stat breakdowns. Our planner provides local versioned planning and AI review; those broader discovery tools remain useful alongside it.
