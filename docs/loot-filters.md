# Loot filters

Open **AI builds**, **Atlas**, or **Crafting**, then choose **Loot filter**. **Alt+5** opens it from any planning page.

The workspace has four pages:

- **Overview:** choose a profile and strictness, auto-adjust from the build, and preview a collection of drops.
- **Customize:** browse personal pickups or the complete base preset by category. Search for an item, then edit its colours, size, sound and icon. Editing a base rule creates a personal override. **Advanced conditions** opens its matching criteria.
- **Simulate:** generate example loot, select drops to inspect their results, configure an item, and show or hide hidden drops. These are deterministic examples, not a model of drop rates.
- **Style:** choose the palette used for new generated targets and explicitly restyle existing personal pickups. **Whole-filter appearance** raises declared label sizes to a selected minimum and controls alert volume (including mute) and beam visibility across personal pickups and the base preset. Blocks without a font directive retain inherited/default sizes, preserving `Continue` behaviour. Tier colours and pickup conditions stay intact; **Restore original** removes these settings. Imported `Import` files remain unresolved, so their external contents cannot be restyled.

**Profile tools** contains creation, duplication, import, account filters, audit/update and deletion. Keep profiles in the build before using normal **Save**. The [FilterBlade comparison](filterblade-comparison.md) records the reviewed feature set and remaining gaps.

Create campaign, early mapping and endgame profiles for Normal or Ruthless. In Ruthless mode, Hide blocks become Minimal blocks, matching the game format. Choose a NeverSink strictness and a style for newly generated rules. **Auto-adjust for this build** adds pickup rules from saved crafting starting items, planned gear bases, active gems and links, recognised budget resources and saved Atlas strategies. Generation replaces its previous generated rules while keeping personal rules. These are snapshots: regenerate after changing your build or plans. Gear-base rules do not identify hidden modifiers or distinguish unique variants sharing a base.

Select a rule to preview example properties. **Edit** opens its live appearance controls; **Advanced conditions** opens matching criteria. All conditions must match. Move rules up or down to change priority; the first matching rule decides unless it uses `Continue`. Editing a generated rule turns it into a personal rule so regeneration preserves the edit. Disable a rule to try the filter without deleting it.

The drop preview shows the label, border and beam, and explains the deciding rule and line. **Test sample properties** or **Configure an item** lets you test exact item properties, including 3.30's **Fated** and **UnidentifiedItemTier**. Missing properties, unsupported conditions or external `Import` files produce **unknown**. Flatten external imports for an exact preview. This simulator does not replace validation by the game. Numbered sound previews use original reference tones on Windows; the game's exact alert sounds play in game. Imported custom sound references are preserved, but their audio files are not bundled.

**Import** accepts exported `.filter` text. The original text stays in the build, separate from personal rules. The compiler adapts GGG's announced 3.30 BaseType renames and removals and adds Show rules for new items. If removing old items empties a BaseType list, it discards that entire block instead of broadening it. **Audit / update** lists migrations and parser diagnostics. New items remain visible rather than receiving invented economy tiers.

**Keep in build** keeps all profiles; normal build **Save** persists them. Native XML, shared builds and complete planning bundles carry kept profiles. Working drafts survive planning-page navigation but must be kept before saving or sharing. There is no profile-count cap; a 2 MiB metadata guard protects build loading. Unreadable or future metadata is preserved unchanged.

**Export** copies compiled text or writes a UTF-8 `.filter` to your chosen directory. Existing files are preserved; choose another filename to export a replacement. **Save all seven strictnesses** writes `name-0.filter` through `name-6.filter`, carrying personal rules and global appearance into each preset. It checks every destination before writing and cancels the batch if any file exists. Imported filters have no strictness variants. Select the exported filter in Path of Exile. Export does not install, activate or silently replace game files.

**Account filters** supports listing/importing filters and explicit publication with server validation. The **Log in** action requests `account:item_filter` in addition to normal PoB scopes. GGG must permit that scope for the registered OAuth client; ordinary character-import authentication is not sufficient. If permission is unavailable, use local export. A second review names the destination before creating a private filter or replacing a selected filter. No account changes occur through MCP. Pending processing, validation errors and uncertain write outcomes are reported without automatic retries. Live account sync has not been verified with a filter-authorised account.

## AI tools

- **get_loot_filters:** read kept profiles.
- **generate_loot_filter:** derive a separate draft from build plans.
- **test_loot_filter:** evaluate a supplied drop with exact filter property names.
- **export_loot_filter:** return compiled text and diagnostics; never write files.
- **propose_loot_filters:** submit profiles for native desktop review. Read and preserve existing profiles before replacing them.

Generation, testing and compilation return request IDs. Poll **get_proposal_status** and match the ID. Only native **Apply** keeps a proposed change; normal **Save** persists it. The existing 256 KiB MCP request guard applies to imported templates as well; larger imports can use the native editor.

## Sources and updates

The seven bundled templates are [NeverSink's filter](https://github.com/NeverSinkDev/NeverSink-Filter), pinned to commit `3ab00dd016b00c6be7acfa989baf498842973d54`. They are MIT-licensed; the copyright and permission notice is included in `src/Data/LootFilters/LICENSE-NeverSink.txt`. This is our native workspace, not the FilterBlade website or its hosted economy service.

GGG's [Covens of Umbra item-filter announcement](https://www.pathofexile.com/forum/view-thread/4013923) supplies the pinned 3.30 item additions, renames, removals and new keywords. [GGG's filter guide](https://www.pathofexile.com/item-filter/about) defines filter syntax; [the API reference](https://www.pathofexile.com/developer/docs/reference#itemfilters) documents account access and server validation.

Maintainers run `python tools/update_loot_filter_data.py --commit <immutable-commit>` to refresh templates and the announcement snapshot. Source URLs and SHA-256 hashes ship beside the data. Refreshes travel through fork releases; there is no live price feed or FilterBlade subscription. Profiles record their base revision and require an explicit **Audit / update** after the bundled template changes. Personal rules and original imported text are retained.
