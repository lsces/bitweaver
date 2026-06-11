# Bitweaver-lsces Project Context

## Stack
- PHP 8.6 / Firebird 5 / adodb / Smarty
- One repo per package (bitweaver-lsces organisation)
- webtrees used as an additional package with illuminate-firebird providing Firebird DB driver (personal fork)
- externals/ holds actively-developed third-party dependencies
- No npm, no Node.js — ever

## Philosophy
- Fix root causes, not symptoms
- Self-hosted, document everything
- Internal stays internal
- Clean diffs matter more than PSR compliance for its own sake

## Deploy Path
Code is edited and tested in `/srv/website/bitweaver5` (xdebug available).
Each bitweaver package is a self-contained directory under `bitweaver5/`, with its
own **individual git repo** under `~/Development/bitweaver-lsces/<package>/`.
Proven changes are copied to the matching package repo — normally by CC directly,
with BeyondCompare used for manual review when needed.

Deploy steps:
1. Copy changed files to `~/Development/bitweaver-lsces/<package>/`
2. Commit in that package's git repo
3. `git push` — updates GitHub (publish-only, not part of the deploy chain)
4. `/etc/webstack/scripts/server-pull-all.sh <package>` — pulls to srv9 and srv10 from the desktop's local copy

Servers do NOT pull from GitHub — they pull from the desktop's local copy.
After pulling on a server, clear the Smarty template cache and restart php-fpm.

Server configuration (nginx, PHP, Firebird) lives in `/etc/webstack/` — a separate
git repo replicated across desktop, srv9, and srv10. Never look in `/etc/nginx` or
`/etc/php*` — they are not the source of truth.
`/etc/webstack` pushes to the bare repo at `/srv/git/webstack.git` (not GitHub) — always
`git push` there before pulling on servers, otherwise servers see stale state.

> NOTE: `/srv/git/bitweaver` → nginx is not yet wired up (infrastructure thread — do not action).

Test all changes on srv9 first (including `zypper dup` before system updates).
srv10 is production — only gets changes proven on srv9.

## Scope
Focus exclusively on Bitweaver code in the current working package.
Do not roam into other packages unless explicitly asked.

**Ignore completely:**
- `webtrees/` — separate application, has its own work thread
- `vendor/` — composer-managed, do not touch
- `externals/` — third-party libs, treat as read-only unless explicitly asked
- `~/Development/` — not relevant to in-place editing
- `/etc/nginx`, `/etc/php*` — not the source of truth, see /srv/webstack

## Patterns & Conventions
- Tabs, not spaces
- Short array syntax `[]` throughout
- Double quotes preferred (interpolation available)
- adodb for all DB access — Firebird 5
- No composer autoload changes without explicit discussion
- No framework magic — keep it explicit and traceable

## PHP-CS-Fixer
Config at project root. Rules in use:
- `array_syntax` short
- `indentation_type` (tabs)
- `no_trailing_whitespace`, `no_whitespace_in_blank_line`
- `ternary_to_null_coalescing` — `isset($x) ? $x : $y` → `$x ?? $y`
- `get_class_to_class_keyword` — `get_class($x)` → `$x::class`
- `modernize_types_casting` — `intval()` → `(int)` etc (risky — verify output)
- `use_arrow_functions` — eligible closures → `fn()` (risky — verify scoping)
- `no_unused_imports`, `no_useless_else`, `no_useless_return`
- `trailing_comma_in_multiline`
- `blank_line_after_namespace`
- `no_extra_blank_lines`

**Removed (noise, no value):**
- `single_quote` — double quotes are fine, interpolation is useful
- `ordered_imports` — pure pedantry, clutters diffs

Fixer has been run across 741 files. Any future run should use `--dry-run --diff` first.

## Current Work Threads
stock and contact packages 

### Active
- hauth/facebook login — keep option open; not culling
- JavaScript tidy — other areas beyond util/javascript

### Pending
- webtrees data/images separation (buried in app, needs separating like bitweaver storage)
- externals/composer halfway-house — ckeditor and util-type dependencies
- `/srv/git/bitweaver` → nginx wiring (infrastructure thread, separate from code work)
- phpsurgery theme: currently using BlueSky — needs a proper site-specific theme tidy
- contact + stock: audit `expunge` permission gating on xref item templates — some delete
  actions (expunge=1/-1) push to history rather than hard-delete, so should gate on
  `_update` not `_expunge`. Trace `edit_xref.php` for each `expunge` value: if it sets a
  deleted flag rather than `DELETE FROM`, move to `p_contact_update` / `p_stock_update`.
  Stock xref deletes currently gate on `$xrefAllowEdit` only — need `p_stock_expunge` added.
- icon set — current tango icons for stock/contact menus are placeholder; proper custom
  icons needed for assemblies, components, movements, requisitions, add-person, add-business

## Bitweaver Structure Notes

### Permission / Role system
Default role_id values (ANONYMOUS_TEAM_ID = -1):
- `1` Administrators — perm_level `admin`
- `2` Editors — perm_level `editors`
- `3` Registered — perm_level `registered`
- `-1` Anonymous — perm_level `basic`

Permissions assigned in `*/admin/schema_inc.php`. Role assignments stored in
`users_role_permissions`. When writing xref role-filter queries, guard `mRoles`
with `array_keys($gBitUser->mRoles ?? []) ?: [-1]` — Firebird rejects empty `IN()`.

### Session / Auth cookie
Cookie name = `bit-user-{site_title_stripped}` (lowercase, alphanum only).
Login stores PHP `session_id()` in `users_cnxn.cookie` mapped to `user_id`.
Subsequent requests look up the cookie value in `users_cnxn` to identify the user —
this is separate from PHP's own session mechanism (though they share the same cookie name).

### Top navbar menu
Each package self-registers via `$gBitSystem->registerAppMenu()` in its `bit_setup_inc.php`.
Rendered by `kernel/templates/top_bar.tpl` — no built-in role gate at the dropdown level.
Config switches (stored in kernel_config, set via Themes > Admin > Menus):
- `menu_$pkg = 'n'` — disable dropdown for all users
- `${pkg}_menu_text` — custom dropdown label
- `${pkg}_menu_position` — sort position
For role-based visibility, override `top_bar.tpl` in `config/themes/merg/kernel/`.

### CSS load order
`BitThemes::loadStyleData()` loads CSS in this order:
1. Package CSS (around position 300) — each package's `html_head_inc.tpl`
2. Style CSS (`getStyleCssFile()`, position 998) — the active theme's main CSS
3. Browser CSS (`getBrowserStyleCssFile()`, position 999)
4. `themes/css/config.css` — loaded last; use this for global overrides (Bootstrap tweaks etc.)

Site-specific CSS lives in `/etc/webstack/domains/{site}/themes/{site}/{site}.css` and is
the active theme file for that site (position 998). Site theme images go in
`themes/{site}/images/` within that domain dir — referenced via `{$gBitThemes->getStyleUrl()}images/`.

### Smarty notes
- `{tr}...{/tr}` for translation in templates; `KernelTools::tra()` in PHP
- `tra` is NOT a Smarty modifier — `"string"|tra` will throw a compiler error
- `{form}` block plugin auto-injects `<input type="hidden" name="tk">` (CSRF ticket)
- **`form-search` hides Bootstrap submit buttons** — Bootstrap 2 `.form-search` suppresses
  the submit control. Use `class="minifind"` alone on floaticon filter forms; never add `form-search`.
- `{strip}` removes whitespace between HTML tags; keep `&bull;` separators inside
  valid `<li>` elements to avoid detachment
- Per-site footer scripts belong in `kernel/footer_inc.tpl`, NOT `kernel/footer.tpl`.
  `footer_inc.tpl` is picked up by the `mAuxFiles` loop in `html.tpl` reliably.
  `footer.tpl` as a theme override only loads if the active style matches exactly —
  fragile and easy to miss.

### Module / Layout system
Modules are placed in layout areas via the `THEMES_LAYOUTS` table:
- `LAYOUT_AREA` — column position: `t` (top), `l` (left), `r` (right), `b` (bottom)
- `POS` — sort order within the column
- `MODULE_RSRC` — the Smarty template to render, e.g. `bitpackage:kernel/mod_top_banner.tpl`
- `ROLES` — role_id that can see this module (empty = all users); use `-1` for anonymous-only

The 't' column is rendered inside `<header id="bw-main-header">` via `displayLayoutColumn('t')`.
Bootstrap grid columns (`col-sm-*`) inside modules MUST be wrapped in a `clearfix` parent;
without it, subsequent modules in the same column float up and overlay earlier ones.

Managed via Admin > Themes > Layout. Template includes resolve via `bitpackage:` prefix.

Column visibility is controlled by feature flags in `kernel_config` checked in `BitThemes::loadLayout()`:
- `{display_mode}_hide_{area}_col` (e.g. `edit_hide_left_col`)
- `{package}_hide_{area}_col`
- `{package}_{display_mode}_hide_{area}_col`
The old hardcoded `display_mode != 'edit'` guard in `html.tpl` has been removed — columns now always
follow these flags. All flags off = columns show on all pages including edit pages.

### Site-specific theme overrides (/etc/webstack/domains)
Each vhosted site has its theme overrides at `/etc/webstack/domains/{site}/themes/{site}/`.
These are symlinked into `bitweaver5/config/themes/{site}` — e.g.:
```
/srv/website/bitweaver5/config/themes/merg -> /etc/webstack/domains/merg/themes/merg
```
Typical contents: `kernel/` (top_bar.tpl, top_banner.tpl, etc.), `images/`, site CSS, favicon.
Any template in this path overrides the package default via Smarty's `bitpackage:` resource lookup.
`config/themes/medw` and `config/themes/merg` are both symlinks — never edit the config/themes
path directly; edit the source in `/etc/webstack/domains/`.

### Contact package — Person vs Business model

Two distinct contact types, entered via separate pages:
- `add_person.php` — auto-injects `$00` type; name stored pipe-separated (`prefix|forename|surname|suffix`) in `liberty_xref.xkey_ext` of the `$00` record; `lc.title` = surname; redirects to `edit.php` for further detail
- `add_business.php` — no `$00`; user picks from `$02`+ subtypes (Supplier, Manufacturer etc., expandable via DB); `lc.title` = organisation name; redirects to `edit.php`

Type codes in `liberty_xref_item` (`content_type_guid='contact'`, `x_group='type'`, `sort_order=0`):
- `$00` Person — triggers name fields in edit/display; never shown as a checkbox in UI
- `$01` Organisation — deprecated, not used in new UI
- `$02`+ Business subtypes — shown as checkboxes in `add_business.php` and `edit.php`

`edit.php` detects person via `contact_types[0].content_id` → `$isPerson` flag:
- Person: name fields shown, Contact Types section hidden, Organisation hidden
- Business: org field shown, Contact Types (`$02`+) shown, name fields hidden

`display_contact.tpl` heading = "Personal Contact" / "Business Contact" from `contact_types.0.content_id`.
Name loaded from `$00` xref `xkey_ext` via SQL join in `Contact::load()` (`x00.xkey_ext AS name`).

xref item templates gate dates and edit actions on `{$xrefAllowEdit}` (pass `allow_edit=false` in view, `allow_edit=true` in edit).

#### Planned: ContactPerson / ContactBusiness subclasses

The current `$isPerson` detection via `$00` xref presence is a hack. The plan replaces it
with proper subclasses following the dual-guid xref pattern (as per stock):

- `ContactPerson extends Contact` — `mContentTypeGuid = 'contactperson'`, `mPackageGuid = 'contact'`
- `ContactBusiness extends Contact` — `mContentTypeGuid = 'contactbusiness'`, `mPackageGuid = 'contact'`

Shared schema (addresses, SCREF etc.) stays at `content_type_guid='contact'`.
Person-specific types (`$00` default, kitelf, committee member etc.) at `contactperson` level.
Business subtypes (`$02`+: Supplier, Manufacturer etc.) at `contactbusiness` level.
`$isPerson` flag disappears — the class IS the distinction.
Template resolution already works via `mContentTypeGuid` path lookup in LibertyContent.

**Not yet implemented.** Development/testing on `rainbowdigitalmedia` first.
Upgrade script `contact/admin/upgrades/5.0.3.php` will:
1. Register `contactperson` and `contactbusiness` content types
2. `UPDATE liberty_content SET content_type_guid = 'contactperson'` for records with a `$00` xref
3. Remaining `content_type_guid='contact'` records become `contactbusiness`

**SCREF** — short reference code for a contact, stored in `liberty_xref.xkey` where `item='SCREF'`.
Used as the `from` value in stock movement CSVs to identify the supplier/source contact.
`contact/includes/lookup_contact.php` provides JSON autocomplete searching by `lc.title` or SCREF `xkey`.

### Stock package — file naming convention
Entry points follow `verb_contenttype.php` pattern:
- `view_assembly.php`, `edit_assembly.php`
- `view_component.php`, `edit_component.php`
- `view_movement.php`, `edit_movement.php`
- `list_assemblies.php`, `list_components.php`, `list_movements.php`
- `add_supplier.php` — specialist add page (no generic add_assembly/add_component yet)
- `add_order.php` — draft ORDER movement from shortages list; pre-populates lines with
  shortage qty, supplier autocomplete, editable qty/delete per line before creating movement

`view.php` and `edit.php` removed.
`list_stock.php` — stock levels from movement xrefs. Shortages filter (`?shortages=1`) works
on both main list (level < 0) and BOM view (remaining < 0). Shortages view has floaticon icons
for Print, CSV export (`?format=csv`, part_number + qty, skips blanks), and Create Order.

### Firebird GROUP BY strictness
Firebird requires every non-aggregate column in SELECT to appear in GROUP BY — including `lc.data`, `lc.title` etc. Correlated scalar subqueries in SELECT (e.g. `SELECT FIRST 1 ...`) are exempt. MySQL is more lenient; Firebird is not.

### Stock movement model
Movement = pure `liberty_content` record (`content_type_guid='stockmovement'`). No `stock_movement` table.

**Direction** inferred from `reference` xref group (x_group='reference', sort_order=1):
- `REQN` = outbound (to kitlocker)
- `TRANS` = inbound from another elf
- `ORDER` = inbound from supplier

**Status** = `lc.event_time` (BIGINT, Unix seconds) — `0` = placed/open, positive = received/fulfilled.
`StockMovement::markReceived()` sets it to `time()`. `isReceived()` uses `!empty()` so 0 = not received.

**Reference xref** (x_group='reference', sort_order=1), one row per movement:
- `item` = REQN/TRANS/ORDER
- `xkey` = reference number/key
- `data` = free-text "from" (fallback if no contact linked)
- `xref` = contact content_id (linked supplier/source — looked up via SCREF xkey)
- `start_date` (TIMESTAMP) = order date (from CSV col 3 or manual entry)

**Items** = `quantity` xref group (x_group='quantity', sort_order=2), `multiple=1`, one xref row per component line:
- `item` = SGL/PCK/SHT/VOL — quantity type
- `xref` = component content_id
- `xkey` = quantity value
- `xorder` = line sequence (managed explicitly, NOT via `fAddXref` — `multiple=0` on these items for other content types)

**CSV format** (one movement per file): line 1 = `from(SCREF), ref, order_date(dd/mm/yy), received_date(dd/mm/yy optional)`; lines 2+ = `component_title, quantity, [optional qty type]`. Qty type defaults to component's existing xref type if not specified.

Uploaded CSVs are saved to `STOCK_IMPORT_PATH` (`storage/stock/`) as `<origname>_move_<content_id>.csv` for audit. BOM uploads save as `<origname>_bom_<content_id>.csv`.

**`storeXref()` always needs a named variable** — it takes `&$pParamHash` by reference; passing a literal array is a fatal error.

### LibertyXref / xorder
`liberty_xref.xorder` — used for BOM grouping and sort. Must be explicitly selected
in queries; it is not auto-included in standard SELECT lists.

### LibertyXrefType — instance class
`LibertyXrefType` is an **instance class**, not a bag of statics. Construct with
`new LibertyXrefType( $contentTypeGuid, $packageGuid = null )`. In page/class code,
always access it via `LibertyContent::xrefType()` which lazily creates and caches the
instance. The five runtime query methods (`getDisplayGroups`, `getTypeMarkers`,
`getAvailableItems`, `getTemplateFormats`, `getContentTypeMarkers`) are instance methods.
Admin cross-type queries (`getXrefTypeList`, `getContentTypeGuids`, `getGroupList`)
remain static.

### Dual-guid xref schema (package-level + content-type-level)
A package with multiple content types can define xref groups/items at two levels:
- **Package-level** — groups shared across all content types in the package, keyed by the package guid
- **Content-type-level** — groups specific to one content type, keyed by the content type guid

**Stock is the reference implementation:**
- Package-level (`'stock'`): `stgrp`, `supplier`, `kitlocker` — apply to both assemblies and components
- Content-type-level (`'stockcomponent'`): `quantity`, `values`; (`'stockassembly'`): `quantity`

To support this, pass `$packageGuid` when constructing `LibertyXrefType` or `LibertyXrefInfo`
(both accept it as an optional second argument). The `mPackageGuid` property on `LibertyContent`
is set automatically by `registerContentType()` when `handler_package` differs from the content
type guid — so subclasses get it for free.

When writing xref JOIN queries that span both levels, always join item↔group on
`t.content_type_guid = s.content_type_guid` (self-consistent); apply the guid `IN()` filter
only in the WHERE clause on `s`. Putting the filter in the JOIN ON instead causes
cross-matching when two guids share an `x_group` name.

### LibertyXrefGroup display path (contact + stock)

**PHP pattern** — display and edit pages:
```php
$gContent->loadXrefInfo();
$gBitSmarty->assign( 'gXrefInfo', $gContent->mXrefInfo );
```

**Template pattern** — view and edit templates:
```smarty
{foreach $gXrefInfo->mGroups as $xrefGroup}
    {include file=$gContent->getXrefListTemplate($xrefGroup->mTemplate)
        xrefGroup=$xrefGroup allow_edit=false}   {* true for edit pages *}
{/foreach}
```

Group templates receive `$xrefGroup` (LibertyXrefGroup object). First two lines must be:
```smarty
{assign var=xrefAllowEdit value=$allow_edit|default:false}
{assign var=isHistory value=($xrefGroup->mXGroup eq 'history')}
```

Fallback for groups with no specific template → `liberty/list_xref.tpl`.

**Floaticon placement** — on list pages the floaticon div goes inside the `<div class="floaticon">`
inside the assembly view's header. On view/edit pages it goes inside the `.header` div before
the `<h1>`. Forms in the floaticon use `class="minifind"` for correct spacing (see Smarty notes).
`assembly_icons_inc.tpl` is included in every assembly view layout's header — put assembly-level
icons there rather than in `view_assembly.tpl` directly.

**Kitlocker tab visibility** — `edit_component.php` and `view_component.php` detect kitlocker
components via a KLID xref presence check and assign `$isKitlocker`. In templates, stash the
`kitlocker` and `stgrp` groups during the normal foreach and render them at the end only when
`$isKitlocker` is true:
```smarty
{assign var=klGroup value=null}{assign var=sgGroup value=null}
{foreach $gXrefInfo->mGroups as $xrefGroup}
    {if $xrefGroup->mXGroup eq 'kitlocker'}{assign var=klGroup value=$xrefGroup}
    {elseif $xrefGroup->mXGroup eq 'stgrp'}{assign var=sgGroup value=$xrefGroup}
    {else}{include file=... xrefGroup=$xrefGroup ...}{/if}
{/foreach}
{if $isKitlocker && $klGroup}{include ...}{/if}
{if $isKitlocker && $sgGroup}{include ...}{/if}
```

**movement edit_movement.php** filters 'reference' group in template:
`{if $xrefGroup->mXGroup neq 'reference'}` — reference is rendered directly in the form.

**CSV import xorder** — `ImportContactCSV.php` explicitly sets xorder: 0 for single items,
1 for #P/#F (multiple=1) - will need to address when more than one record needed.

**`contact_types` in Contact** — separate from the display path. Populated by
`loadXrefTypeList()` which queries sort_order=0 items (the 'type' group: `$00`, `$02`+).
Used for `$isPerson` detection in `edit.php` and display templates. `loadXrefInfo()`
deliberately excludes sort_order=0, so there is no overlap.

**Raw LEFT JOINs in `Contact::load()`** — joins `liberty_xref` directly for `$00`
(person name), `#S` (service address), `#L` (location), `IMG` (gallery). `IMG`, `#S`,
`#L` have no live data.

**Pending: Contact::load() cleanup** — remove the three commented-out dead joins; replace
the active raw xref joins with the proper path: `$00` name from `loadXrefTypeList()` with
`xkey_ext` added; `#S`/`#L`/`ap` from `loadXrefInfo()` address group (postcode join
already present in `LibertyXrefGroup::loadXrefs()`); gallery association needs rethinking
separately from the xref mechanism.

View pages pass `allow_edit=false` (or omit), edit pages pass `allow_edit=true`.

### Contact delete / expunge
`edit.php` handles `expunge=1`: checks `p_contact_expunge`, calls `$gContent->expunge()`,
redirects to `list_contacts.php`. `contact_date_bar.tpl` uses
`{smartlink ... ifile="edit.php" expunge=1}`. `Contact::expunge()` deletes liberty_xref rows
then calls `LibertyContent::expunge()`.

## Infrastructure

### /etc/webstack
Single git repo replicated across desktop, srv9, and srv10. Push to `/srv/git/webstack.git`
before pulling on servers — servers pull from the desktop copy, not GitHub.
Contains: nginx vhost configs, logrotate, cron scripts, domain theme symlinks, PHP/Firebird config.
`/etc/logrotate.d/nginx` is a **hard link** to `/etc/webstack/logrotate.d/nginx` — one config,
not two competing ones. Never edit via `/etc/logrotate.d/` directly.

### Nginx log structure
Central combined log: `/var/log/nginx/access.log` — every request from all vhosts, domain name
appended at end of each line by nginx log format.
Per-domain dirs: `/var/log/nginx/{domain}/` — contain `access.log` (filtered, rebuilt nightly),
`80.access.log` (port 80, written directly by nginx), and `error.log`. All are covered by the
domain logrotate stanza (`size=+8M`, `rotate 7`). The filtered `access.log` is always small so
`notifempty` skips it; the stanza exists for `80.access.log` and `error.log`.

Logrotate on Tumbleweed is a **crontab entry**, not a cron.daily script — ordering tricks
(renaming files in cron.daily) do not affect when logrotate runs relative to nginx-stats.

Raw log rotation (parent only): `size=+16M`, `rotate 14`, `maxage 30`, `delaycompress`.
At current traffic (~7 MB/day) this gives ~30 days of history across ~14 archives.
Compressed archives use `.xz` or `.gz` depending on when they were created.

### nginx-stats / goaccess
Script: `/etc/webstack/cron.daily/nginx-stats`

Runs nightly. Builds `/tmp/nginx-combined.log` from the current `access.log` plus all
parent archives (decompressing `.xz`/`.gz` inline), then greps per domain into
`/var/log/nginx/{domain}/access.log`, runs goaccess, publishes
`/srv/website/{domain}/stats-rep.html`. Cleans up `combined.log` on exit.

Domain `access.log` files are ephemeral outputs — rebuilt from parent archives each run.
History lives entirely in the parent archive chain; no domain-level archives are created.

## Session Management
At the end of each productive session, append discoveries, decisions, and completed items to this file.
Use `/clear` to reset context when it gets bloated — this file re-orients the session.

## CC Limitations
For execution-order bugs and session/config state problems, 
use xdebug rather than asking CC to trace — static analysis 
cannot follow runtime state reliably.