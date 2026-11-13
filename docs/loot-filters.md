# Loot filters

Open **AI builds**, **Atlas**, or **Crafting**, then choose **Loot filter**. **Alt+5** opens it from any planning page.

The workspace has six pages:

- **Overview:** choose a profile and strictness, auto-adjust from the build, and preview a collection of drops.
- **Customize:** browse personal pickups or the complete base preset by category. Search for an item, then edit its colours, size, sound and icon. Editing a base rule creates a personal override. **Advanced conditions** opens its matching criteria.
- **Tiers:** copy a preset tier or create your own, then drag exact item names between custom tiers. Move tiers up/down to change priority. Existing class and stack conditions stay attached; incompatible exact classes cannot be mixed by dragging. Delete an override to return to the base preset.
- **Simulate:** generate example loot, select drops to inspect their results, configure an item, and show or hide hidden drops. Use Previous / Next to browse every example; hidden-drop filtering happens before paging. These are deterministic examples, not a model of drop rates.
- **Style:** choose generated-target palettes or restyle personal pickups. **Whole-filter appearance** controls declared font sizes, colour overrides, alerts, minimap visibility and beams across the compiled filter. Blank colours preserve tier palettes. Undeclared styles retain `Continue` inheritance; **Restore original** removes these settings. External `Import` contents remain unresolved.
- **Modules:** create a named snapshot of personal rules and tiers, copy it between profiles, or copy/paste a shared module. **Update copies in this build** explicitly refreshes matching snapshots. Modules follow personal rules and custom tiers in priority.

**Profile tools** includes profile management, **Review changes** and **Linked build targets**. Review compares the draft with kept profiles; Undo/Redo restores edits. Linked targets flag changed sources and open their craft, gear, resource or Atlas plan. **Tools → Recover local drafts** restores interrupted edits without applying them. Keep profiles before using normal **Save**.

**Campaign and base-family pickups** in Profile tools selects weapon/offhand families, armour defence combinations and recipe pickups. Use equipped selects families from the current gear. The area range limits these supplemental Show rules; the upgrade window raises the minimum base DropLevel in five-area bands. Set the window to 0 to retain every selected base. Recipe pickups use only the area range. Personal rules, custom tiers and modules keep priority. Customize → Policies previews the resulting blocks; no unrelated items are automatically hidden.

**Saved example sets** keeps exact test items with the profile. On Simulate, choose **Saved sets**, name the set, then capture the current item, tested history or generated examples. **Use selected** displays that set; its original item and area levels are preserved. A configured or pasted item appears as a separate current test beside the set; it does not overwrite the saved examples. Item levels and hover details distinguish examples sharing a base. Rename, replace and removal are staged until accepted. Keep in build and Save to share or reopen these tests. Missing properties remain unknown.

**Category appearance**, on Style or in Profile tools, changes declared colours, fonts, alerts and effects for one item family. Rules stay at their original priority. Whole-filter appearance applies last. The picker shows active block counts; categories follow preset labels and rule conditions, so check Customize when styling an imported rule. Restore original removes the category's settings.

Choose **Pick** beside a colour field to open the colour wheel. Drag the wheel, brightness or opacity bars, choose a quick colour, or enter exact hex/RGBA values. Arrow keys adjust a focused selector. **Keep colour** returns to the editor; **Cancel** leaves it unchanged. Ruthless text colours require alpha 80 or higher.

**Saved palettes**, on Style or in Profile tools, stores the current whole-filter appearance, category styles and generated-target theme. Name a snapshot, then use it on the profile later. Editing the active appearance does not overwrite the saved snapshot. Palette changes preserve pickup conditions. Libraries travel in native builds and planning bundles and have no collection-count cap within the shared metadata size guard.

**Filter structure and priority** shows every active compiled block under collapsible source sections and item families. Search exact source text or filter to hidden, Continue, conflict or warning blocks. Select a block to inspect its line, diagnostics and full text, copy it, or edit it. Non-personal blocks create stable personal overrides; reopening them from matched-rule inspection uses the same identity. Disabled personal rules stay in Customize. Unresolved external imports remain explicit.

Create campaign, early mapping and endgame profiles for Normal or Ruthless. In Ruthless mode, Hide blocks become Minimal blocks, matching the game format. Choose a NeverSink strictness and a style for newly generated rules. **Auto-adjust for this build** adds pickup rules from saved crafting starting items, planned gear bases, active gems and links, recognised budget resources and saved Atlas strategies. Generation replaces its previous generated rules while keeping personal rules. These are snapshots: regenerate after changing your build or plans. Gear-base rules do not identify hidden modifiers or distinguish unique variants sharing a base.

Select a rule to preview example properties. **Edit** opens its live appearance controls; **Advanced conditions** opens matching criteria. All conditions must match. Move rules up or down to change priority; the first matching rule decides unless it uses `Continue`. Editing a generated rule turns it into a personal rule so regeneration preserves the edit. Disable a rule to try the filter without deleting it.

The drop preview shows the label, border and beam, and explains the deciding rule and line. **Test sample properties** or **Configure an item** lets you test exact item properties, including 3.30's **Fated** and **UnidentifiedItemTier**. Missing properties, unsupported conditions or external `Import` files produce **unknown**. Flatten external imports for an exact preview. This simulator does not replace validation by the game. Numbered sound previews use original reference tones on Windows; the game's exact alert sounds play in game. Imported custom sound references are preserved, but their audio files are not bundled.

For socket conditions, enter linked groups separately in **SocketGroup** and all socket colours in **SocketColours**. A rule such as `SocketGroup >= 5GGG` requires at least five linked sockets and at least three green sockets; `==` requires an exact count of the named colours.

**Import** accepts exported `.filter` text. The original text stays in the build, separate from personal rules. The compiler adapts GGG's announced 3.30 BaseType renames and removals and adds Show rules for new items. If removing old items empties a BaseType list, it discards that entire block instead of broadening it. **Audit / update** lists migrations and parser diagnostics. New items remain visible rather than receiving invented economy tiers.

**Full file changes** compares the kept profile with the working draft. Switch between compiled output and original base text, search changes or inspect complete before/after views. Copy preserves full source text; long lines are abbreviated only on screen. Large or repeated changes can be grouped rather than reduced to a minimal patch. Detailed review is bounded to 100,000 lines; available full sources can still be copied if that guard is reached. External imports remain unresolved.

**Keep in build** keeps all profiles; normal build **Save** persists them. Native XML, shared builds and complete planning bundles carry kept profiles. Working drafts survive planning-page navigation but must be kept before saving or sharing. There is no profile-count cap; a 2 MiB metadata guard protects build loading. Unreadable or future metadata is preserved unchanged.

**Export** copies compiled text or writes a UTF-8 `.filter` to your chosen directory. Existing files are preserved; choose another filename to export a replacement. **Save all seven strictnesses** writes `name-0.filter` through `name-6.filter`, carrying personal rules and global appearance into each preset. It checks every destination before writing and cancels the batch if any file exists. Imported filters have no strictness variants. Select the exported filter in Path of Exile. Export does not install, activate or silently replace game files.

**Account filters** supports listing/importing filters and explicit publication with server validation. The **Log in** action requests `account:item_filter` in addition to normal PoB scopes. GGG must permit that scope for the registered OAuth client; ordinary character-import authentication is not sufficient. If permission is unavailable, use local export. A second review names the destination before creating a private filter or replacing a selected filter. No account changes occur through MCP. Pending processing, validation errors and uncertain write outcomes are reported without automatic retries. Live account sync has not been verified with a filter-authorised account.

## AI tools

On **Simulate**, **Paste item** reads visible properties from a game clipboard copy. **Scene settings** controls shared area/item levels and background; **History** revisits tested samples. **Matched rules** opens the deciding blocks for inspection and editing. **More sound, icon and beam options** includes all twelve icon shapes, colours, sizes, positional/custom alerts and temporary beams. Native previews approximate their geometry; custom audio files must accompany the exported filter.

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
