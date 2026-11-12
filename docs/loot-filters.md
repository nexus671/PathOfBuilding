# Loot filters

Open **AI builds**, **Atlas**, or **Crafting**, then choose **Loot filter**. **Alt+5** opens it from any planning page.

Create campaign, early mapping and endgame profiles for Normal or Ruthless. In Ruthless mode, Hide blocks become Minimal blocks, matching the game format. Choose a NeverSink strictness and a style for newly generated rules. **Use build targets** adds pickup rules from saved crafting starting items, planned gear bases, active gems and links, recognised budget resources and saved Atlas strategies. Generation replaces its previous generated rules while keeping personal rules. These are snapshots: regenerate after changing your build or plans. Gear-base rules do not identify hidden modifiers or distinguish unique variants sharing a base.

Select a rule to preview a matching example. **Edit** opens graphical condition, appearance and sound controls. All conditions must match. Move rules up or down to change priority; the first matching rule decides unless it uses `Continue`. Editing a generated rule turns it into a personal rule so regeneration preserves the edit. Disable a rule to try the filter without deleting it.

The drop preview shows the label, border and beam, and explains the deciding rule and line. **Sample properties** lets you test exact item properties, including 3.30's **Fated** and **UnidentifiedItemTier**. Missing properties, unsupported conditions or external `Import` files produce **unknown**. Flatten external imports for an exact preview. This simulator does not replace validation by the game. Numbered sound previews use original reference tones on Windows; the game's exact alert sounds play in game. Imported custom sound references are preserved, but their audio files are not bundled.

**Import** accepts exported `.filter` text. The original text stays in the build, separate from personal rules. The compiler adapts GGG's announced 3.30 BaseType renames and removals and adds Show rules for new items. If removing old items empties a BaseType list, it discards that entire block instead of broadening it. **Audit / update** lists migrations and parser diagnostics. New items remain visible rather than receiving invented economy tiers.

**Keep in build** keeps all profiles; normal build **Save** persists them. Native XML, shared builds and complete planning bundles carry kept profiles. Working drafts survive planning-page navigation but must be kept before saving or sharing. There is no profile-count cap; a 2 MiB metadata guard protects build loading. Unreadable or future metadata is preserved unchanged.

**Export** copies compiled text or writes a UTF-8 `.filter` to your chosen directory. Existing files are preserved; choose another filename to export a replacement. Select the exported filter in Path of Exile. Export does not install, activate or silently replace game files.

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
