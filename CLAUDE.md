# Bitweaver-lsces Project Context

## Stack
- PHP 8.5.7 / Firebird 5 / adodb / Smarty
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

`ssh root@srv9` / `ssh root@srv10` work directly from the desktop (key-based, no password) —
use this for anything needing live server state: nginx/fail2ban config verification, log
inspection, service reload/restart, etc. No sudo needed once connected.

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
- **mapper "unbalanced tree" (document.write() elimination) — done 2026-07-29.** Every file
  fixed, deployed, verified on srv9+srv10; German→English pass done alongside. Full detail in
  `mapper/CLAUDE.md`.
- **mapper OS-Data mapsets — built + deployed 2026-07-31, srv9 storage tidied 2026-08-03.** Real
  mapsets built from the archived OS-Data library (`meridian_2014`/`_2016`, `minisc_2019`/`_2026`,
  `opmplc_2020`/`_2026`, `vmdvec_2020`/`_2026`, `over_gb`, `zoomstack_2026`) — deployed to srv9
  (full archive, `storage/mapper` now symlinks throughout, no physical duplicates left) and to
  srv10 as a deliberately smaller real-copy subset (single-disk hardware, no `/media3`/`/media4`
  equivalent to symlink from — confirmed fine to leave as-is, not pending). Access properly gated
  behind the mapper permission system, which turned out to have never been enforced at all before
  this work. `OS250.map` removed entirely (dead scaffolding, never had real tile data behind its
  tileindexes). Full detail in `mapper/CLAUDE.md`. OSRM routing replacement still dead, no
  running instance anywhere — unscoped. **Paused here — next mapper session starts a different
  approach, not a continuation of this thread.**

### Pending
- webtrees data/images separation (buried in app, needs separating like bitweaver storage)
- externals/composer halfway-house — ckeditor and util-type dependencies
- `/srv/git/bitweaver` → nginx wiring (infrastructure thread, separate from code work)
- contact + stock: audit `expunge` permission gating on xref item templates — some delete
  actions (expunge=1/-1) push to history rather than hard-delete, so should gate on
  `_update` not `_expunge`. Trace `edit_xref.php` for each `expunge` value: if it sets a
  deleted flag rather than `DELETE FROM`, move to `p_contact_update` / `p_stock_update`.
  Stock xref deletes currently gate on `$xrefAllowEdit` only — need `p_stock_expunge` added.
- icon set — current tango icons for stock/contact menus are placeholder; proper custom
  icons needed for assemblies, components, movements, requisitions, add-person, add-business
- `wordpress_hacks.conf` — consider adding common junk scanner filenames as an explicit match
  (e.g. `this_is_a_new_hello_world.php`, `lp6.php`, `clasa99.php`, `ph33w.php`, `errw.php` — the
  mass-scan "throw random PHP filenames at the root" pattern visible in myhomecloud's goaccess
  Not Found report). Currently these are generic 404s on `access.log`, not routed through
  `attempts.log` since they don't match the existing wp-/xmlrpc/etc. regex. Deliberately deferred
  2026-07-27 — myhomecloud's report shows ~10MB of this "dross" against ~1.7GB of real traffic,
  under 1%, not worth chasing yet. Revisit once the ratio grows or other domains' reports get
  reviewed. Do not action until asked — needs a real filename sample first, not a guessed list.

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
Cookie name = `bit-user-{site_title_stripped}` (lowercase, alphanum only) — compute from
`kernel_config.site_title` (strip non-alnum, lowercase).
Login stores PHP `session_id()` in `users_cnxn.cookie` mapped to `user_id`.
Subsequent requests look up the cookie value in `users_cnxn` to identify the user —
this is separate from PHP's own session mechanism (though they share the same cookie name).

**Testing authenticated flows without a password**: `INSERT INTO users_cnxn (user_id, cookie,
ip, last_get, connect_time, get_count) VALUES (<user_id>, '<random hex>', '127.0.0.1', <epoch>,
<epoch>, 1)`, then send that same value as the `bit-user-{site}` cookie in curl. Confirmed
working 2026-07-31 (smoke-testing a wiki save fix end-to-end). Clean up the row afterward
(`DELETE FROM users_cnxn WHERE cookie = '...'`) — it's not session-expiring on its own.

**Don't dig for these — they're predictable, simple expansions of each domain's short name**
(the same short form used as the Firebird DB alias, e.g. `lsces` for `lsces.uk`, `medw`, `merg`):
- **DB alias** = bare domain name, no TLD. Same alias on desktop (local dev copy), srv9, srv10.
- **Cookie name** = `bit-user-<shortname>mainsite` — e.g. `bit-user-lscesmainsite` for lsces.
  This is `BitSystem`'s computed value from `site_title`, cached on disk in
  `config/kernel/auth_config.php` (`session_name(...)`) if you ever need to confirm it exactly
  rather than deriving it — no need to query `kernel_config` via isql for this.
- **Test user for the `users_cnxn` trick**: use `user_id = 3` on the target site's DB, not `1` —
  `1` is `root`, a placeholder account, not a real login with normal role assignments.
- **Reaching each environment over HTTPS with the real domain**: srv10 is production, answers on
  the bare domain (`https://lsces.uk`) — this is also what public DNS resolves to. srv9 (test/DR)
  answers on the same domain with `:8443` appended (`https://lsces.uk:8443`) via a manual router
  port-forward that's toggled off overnight (see `project_srv9_8443_schedule` memory) — if that's
  off, or you're already SSH'd into srv9 and want to bypass DNS/the router entirely, use `curl -k
  --resolve <domain>:443:127.0.0.1 https://<domain>/...` run from srv9 itself (see
  `reference_srv9_web_testing` memory). Desktop uses the bare short name with no domain/port at
  all (its own local vhost + local DB copy) when working from the desktop directly.

See `themes/CLAUDE.md` for: navbar menu, CSS load order, Smarty notes, module/layout
system, site-specific theme overrides.

### Package-specific notes
Detail for individual packages lives in their own `CLAUDE.md` files:
- `themes/CLAUDE.md` — navbar menu, CSS load order, Smarty notes, module/layout, site overrides
- `liberty/CLAUDE.md` — xref machinery (LibertyXrefType, dual-guid schema, display path,
  parseDataHash, storeXref, owner change, Firebird GROUP BY)
- `contact/CLAUDE.md` — person/business model, ContactPerson/ContactBusiness plan, SCREF,
  load() cleanup, delete/expunge
- `stock/CLAUDE.md` — file naming, movement model (REQN/PBLD/TRANS/ORDER), template
  structure, multi-user kitelf filtering, getList() enriched fields
- `wiki/CLAUDE.md` — BitPage::store() missing RollbackTrans bug (intermittent "page not found")
- `mapper/CLAUDE.md` — MapServer viewer, frame/JS context split, selectable mapsets
  (script.php/mapsets_inc.php), storage/maps vs storage/mapper, CGI param semantics
- `protector/CLAUDE.md` — permission-check-unreachable bug (fixed 2026-08-02): anonymous/
  unauthorized access to protector-restricted content fell through to a generic "page not
  found" instead of the login/permission-denied prompt

## Infrastructure
Detail lives in `/etc/webstack/CLAUDE.md` — its own repo, own `CLAUDE.md`, same pattern as the
bitweaver packages above (`themes/CLAUDE.md` etc). Covers: site folder structure and symlink
layout, `/etc/webstack` itself, the Firebird backup/DR mirror between srv9 and srv10, nginx log
structure and logrotate gotchas, fail2ban (jails, known limitations), and nginx-stats/goaccess.

## Session Management
At the end of each productive session, append discoveries, decisions, and completed items to this file.
Use `/clear` to reset context when it gets bloated — this file re-orients the session.

### 2026-08-04 (cont'd, 2) — OSM tile server prototype built + wired into the mapper viewer
Built a full slippy-map tile server on desktop from scratch (PostGIS/osm2pgsql/Mapnik/renderd,
OS-atlas road-colour styling per the earlier-flagged direction) and, after proving each piece
standalone, wired it into the existing `mapper` viewer as a new selectable mapset
(`osm_tiles_iom`) rather than a separate page — confirmed working live by the user. Real
measured IOM tile-cache size (145MB, z6-18) answered the earlier "how much disk space" question
with actual numbers instead of a guess. Found and fixed two real bugs along the way: a 9x
disk-space blowup from naively flattening metatiles to individual files (avoided by writing a
small PHP script that reads tiles straight out of renderd's metatiles instead, path-hash formula
reverse-engineered from real files, not guessed), and a `render_list --all` bbox-mode coverage
gap at the extent boundary (fixed by computing exact tile ranges directly rather than trusting
its lat/lon bbox math). Also found desktop's local `lsces` vhost resolves mapfiles against
`bitweaver5/mapper/map/` directly, not `lsces/mapper/map/` like the real servers - none of the
other private mapsets had ever actually been exercised through desktop's own vhost before this.
Full detail in `mapper/CLAUDE.md` and the `project_osm_tile_server` memory. Deliberately stopped
at desktop-only — committed to the webstack and mapper package repos, not yet pushed to
srv9/srv10, picking back up next session.

### 2026-08-04 (cont'd) — osm_gb_2012/osm_iom_2012 historic mapsets built + deployed to srv9
Built the first actual mapsets from the 2012 OSM planet dump acquired earlier today, using
`osm_gb`/`osm_iom`'s exact recipe (gpkg build, coastline reuse, registry wiring). Deliberately
built on desktop rather than srv9 — noticeably faster hardware, GB gpkg took 2m22s vs. ~50min for
the much bigger current-day build. `osm_iom_2012` requested and built alongside `osm_gb_2012` in
the same pass. Coastline layer and reference thumbnails both reuse the existing current-day
assets outright rather than rebuilding — real coastlines don't move in 12 years. Verified live via
`mode=browse` and an authenticated registry-resolution check (caught a real test-methodology trap
along the way: `lsces.uk` resolves to production/srv10, not srv9 — `curl --resolve` needed to
actually test srv9 directly, now in `[[reference_srv9_web_testing]]`). Deployed to srv9 only, not
promoted to srv10. Full detail in `mapper/CLAUDE.md`.

### 2026-08-04 — mapper OSM coastline+historic-dumps work, media3/media4 drift fixed, fail2ban root-caused and two jails retired
**mapper:** `osm_iom.map`/`osm_gb.map` coastline layers (real OSM water-polygon data, dissolved
+ flood-filled reference thumbnails), a real `GROUP`/layer-`NAME` collision bug found+fixed, and
first steps into OSM historic planet dumps (2012 acquired+archived+GB-clipped, 2020 downloading).
Full detail in `mapper/CLAUDE.md`.

**fail2ban:** root-caused a 90s shutdown delay back to `nginx-444`'s ban backlog + the default
banaction; switched to an `ipset`-backed action (two more real bugs found along the way), then
retired both `nginx-444` and `nginx-botsearch` outright as redundant/no-longer-needed rather than
just patching them. Also fixed a media3/media4 archive drift (Films, an OS-Data set, the
`osm-update` cron mirror). Full detail in `/etc/webstack/CLAUDE.md`.

**Desktop toolchain cleanup:** traced pdfarranger/ocrmypdf/img2pdf breakage to a dead October-2024
pip environment shadowing the real installs; removed it plus the orphaned `python312` RPM stack
and unused `recoll`/`python311`. No CLAUDE.md of its own — desktop-local housekeeping, not
project code.

### 2026-08-03 — error.tpl login-box misalignment fixed, srv9 firebird-restore run, post-login redirect port bug fixed
Resolved the "NEXT SESSION FIRST" login frame/box CSS issue carried over from 2026-08-02:
root cause was `kernel/templates/error.tpl` being the only template site-wide with
`class="body row"` on its outer wrapper, plus a second `<div class="row">` wrapping
`{include file=$template}` — both spurious Bootstrap `.row`s (each contributing -15px margin)
stacked and pushed the inline login form left past the container edge. Fixed by stripping both
`row` classes (confirmed live — space restored, aligned with the module frames). Deployed to
the `kernel` package repo and pulled to srv9.

Ran `firebird-restore` on srv9 to mirror srv10's database + storage (a wiki page existed on
srv10 but not srv9). Verified first: srv10 had a current same-day backup; srv9's own
`storage/backup/` was stale (last 2026-07-29) but the script's own rsync step pulls through the
latest before running `gbak`, and `storage/mapper` is excluded from that rsync regardless of its
physical-folder/symlink mix (see mapper tidy-up below). Restore ran clean across all 9 domains;
`lsces.fdb` rebuilt from the same-day backup, old db kept as `.fdb.old`.

Found + fixed a real bug while testing the above via srv9's `:8443` DR-failover port:
`users/validate.php`'s post-login redirect compared `$_SERVER['HTTP_HOST']` (includes the port
on non-standard ports) directly against `parse_url($_SERVER['HTTP_REFERER'])`'s `host` (never
includes the port) — so on non-standard-port access the comparison silently failed,
`$_SESSION['loginfrom']` never got set, and login fell back to the user's home page instead of
the originally-requested page. Confirmed this is specific to non-standard-port access — normal
desktop and srv10 traffic (standard `:443`) was never actually affected, despite an initial
suspicion it might be a wider "unlogged hole"; only srv9's `:8443` forward ever exercised it.
Fixed with `strtok( $_SERVER['HTTP_HOST'], ':' )`; deployed to the `users` package repo and
pulled to both srv9 and srv10.

While sanity-checking the restore, also found and tidied two lingering physical (non-symlink)
directories in srv9's `storage/mapper/` — `meridian_2014` and `iom_years` — now matching
desktop's all-symlinked pattern. Full detail in `mapper/CLAUDE.md`.

### 2026-08-02 — protector permission-check-unreachable bug found + fixed site-wide
Making a wiki page private via Protector showed anonymous users a generic "page cannot be
found" (410) instead of a login prompt. Root cause: `protector_content_verify_access()` —
which already correctly calls `fatalPermission()` for anonymous/unauthorized users — was
never actually reachable. Two compounding bugs, both fixed within protector's own logic per
the reference above: every `content_load_sql_function` call site except `LibertyComment`
omitted the object argument to `getServicesSql()`, so protector's hook always got `null`
and gave up; and protector's own guard trusted each content type's `isValid()`, which for
`BitPage` checks `mPageId` (only set after a successful load) rather than `mContentId`
(already valid beforehand) — fixed to check `mContentId` directly. Confirmed via direct code
reads and live testing (not just an Explore agent's report) that `mContentId` is reliably
pre-populated on the normal content-resolution path (`getLibertyObject()` →
`new $class(null, $contentId)`), so this holds generally, not just for wiki. Fixed at 7
call sites across wiki, blogs, fisheye, stock, and users (all mirroring the one already-
correct `LibertyComment` pattern) plus the protector guard itself. Verified live on desktop
for all three permission states, then on srv9 and srv10 for the real reported page. Full
detail in `protector/CLAUDE.md`.

### 2026-08-01 — mapper MapFrame scrollbar/clipped-arrows bug found + fixed
Once the permission fix (below) made the newer mapsets actually viewable in a real browser, a
real display bug surfaced: a vertical scrollbar inside `MapFrame`, clipping the pan arrows.
Chased through several wrong turns first - dynamic frame resizing, a suspected mapfile `SIZE`
vs frame-size mismatch (confirmed via `html/map_init.html` that MapServer always renders at
whatever size the frame requests dynamically, so this wasn't it), and a full hand-trace of
`common.js`'s absolutely-positioned layer math (confirmed correct by construction, verified live
via browser console). Actual cause: `scripts/layer.js`'s layer-creation functions used
`overflow:inherit` instead of `overflow:hidden`, so a few pixels of inline-`<img>`
baseline-alignment "phantom space" bled out past each layer's box and accumulated into a real
page-level scrollbar. Fixed with `overflow:hidden` (layer.js) + `display:block` on every injected
`<img>` in `map.html` (removes the offset at the source - needed both, since `overflow:hidden`
alone clipped the 8px-tall North/South pan buttons almost entirely). Deployed to srv9 and srv10;
also caught and fixed a real deploy gap along the way (an earlier `resizeMapFrame()` revert had
only ever been made locally on desktop, never pushed, so the servers were still running a stale
version even after the "real" fix was deployed - worth remembering that reverts need pushing too,
not just forward changes). Full detail, including the wrong turns and a testing gotcha (browser
reload button mangles this frameset's load choreography - use the address bar instead) in
`mapper/CLAUDE.md`.

### 2026-07-31 — mapper OS-Data mapsets built + deployed, permission system fixed, mapfile path bugs found+fixed
Worked through the archived OS-Data library into real mapsets rather than leaving it speculative:
`meridian` renamed to `meridian_2014` (confirmed true vintage via file mtimes) with
`meridian_2016` added alongside — both kept, not swapped, per the never-replace-historic-editions
principle (see `[[feedback_mapper_historic_no_replace]]`). New mapsets: `minisc_2019`/`_2026` (OS
MiniScale raster), `opmplc_2020`/`_2026` (OS Open Map Local, GeoPackage vector),
`vmdvec_2020`/`_2026` (OS VectorMap District), `over_gb` (GB overview raster, both editions
combined into one mapset), `zoomstack_2026` (OS Open Zoomstack, all 21 layers). `omlras_gtfc_gb`
(raster tiles, 10,591 files) and `pancon_gb_2016` (DXF contours) investigated but set aside — the
former superseded by the simpler GeoPackage vector route, the latter deferred (no embedded CRS,
would need a tileindex). `mapper_mapsets.php` gained a `dataDir` gate so the same registry file
deploys to both srv9 (full archive) and srv10 (cherry-picked subset) without duplication.

Found and fixed two real bugs along the way, both invisible until today because nobody could
actually reach the affected code paths before: (1) `display_map.php` passed the raw, unvalidated
mapset key to `script.php`'s `scriptURL` instead of the resolved one, breaking the whole frame
choreography on a stale link; (2) the mapper package's 5 permissions were declared in
`schema_inc.php` but never actually synced to the database, so the entire module — including the
public demo — was open to anonymous users with zero access control. Fixed properly via the admin
installer's own permission-cleanup mechanism (not hand-written SQL — see
`[[feedback_installer_permission_cleanup]]`), then wired up `verifyPermission()` calls plus a
graceful demo fallback instead of a login wall for a bare URL.

Separately chased down why `test_rlp.map` (the one public/portable demo mapfile) worked on
desktop but not on either server: `lsces/mapper` is a symlink to the shared `_bw5/mapper`
checkout, and MapServer resolves relative paths against that *real* location, not the apparent
per-site path — so a relative path can never correctly reach site-specific storage. Fixed with
`git update-index --skip-worktree` so GitHub/desktop keep the clean portable version while each
server carries its own local, un-synced override. `OS250.map` (same hardcoded-path bugs, plus
invalid syntax, plus tile data that was never actually downloaded) removed entirely as dead
scaffolding, along with a pile of superseded untracked data in `mapper/data/`. srv10 cherry-pick
started: `meridian_2014`, `minisc_2026`, `over_gb` copied over directly (no `/media3` archive on
srv10's single-disk hardware, real copies not symlinks). Found but not fixed: `MapFrame`'s
iframe height is hardcoded 731px, not dynamic like `NaviFrame`/`FormFrame` already are - most of
today's mapsets are taller than that, forcing a scrollbar that clips the pan-arrow overlay
controls. Full detail — every mapset's layer/scale choices, exact bug mechanics, skip-worktree
setup, the MapFrame follow-up — in `mapper/CLAUDE.md`.

### 2026-07-29 (cont'd) — mapper document.write() elimination completed, merg onboarded, infra cleanup
**mapper:** corrected the "unbalanced tree" misreading (see Active thread above), then eliminated
`document.write()`/`writeln()` across all of `html/`, `theme/noFeature.html`, and `script.php`
(plus `scripts/layer.js`, whose cross-frame functions did map.html's actual drawing). Found and
fixed a real bug along the way: `navi.html`'s `<form name="navi">` opened mid-table instead of
wrapping it — worked before only via a legacy backward-compat parsing quirk that a single-string
`insertAdjacentHTML` doesn't trigger the same way live `document.write()` did; broke the identify
tool and layer checkboxes until fixed. Followed by a German→English pass (visible text + internal
identifiers/comments) — see `mapper/CLAUDE.md` for full detail on both, kept terse here per
[[feedback_doc_terseness_mechanical]].

**PHP-FPM/infra cleanup:** chased a "sluggish mapper" report through two false leads (wrong
systemd unit theory, wrong pool-size theory) before landing on the real explanation — mapper's
frameset does 2 full kernel bootstraps per page view, inherent to the architecture, not a
misconfig; APCu enabled to help (srv9 first, then srv10, since srv9 showed nothing else going on).
Along the way: removed a genuinely dead `php8/fpm/php-fpm.d/www.conf` (never `include`d),
decommissioned `php84-fpm` everywhere (a deliberately-retained pre-`zypper dup` build, now fully
unreferenced — see [[project_php_version_retention]] for why this pattern will recur at php8.6),
and removed two stale desktop-only vhosts (`local-bitweaver`, `local-webtrees` — the latter
pointed at a directory that no longer exists).

**merg.rdm1.uk onboarded properly:** was live with zero Firebird DR coverage — added to both
`firebird-backup` and `firebird-restore`, ran the full chain once manually to confirm (not just
added on paper). Also found `lsces`/`medw`/`merg` had all lost their `config_inc.php` symlinks
(edited directly on the server, likely Kate defeating the symlink on save — see
[[reference_config_symlink_breakage]]) — restored all three, fixing a stale `IS_LIVE=false` on
two and a stale `BIT_CACHE_OBJECTS=false` on the third along the way. Added merg to `nginx-stats`
and, while there, found+fixed a real bug: the `rdm1` report's grep pattern was unanchored and had
been silently absorbing `merg.rdm1.uk`/`git.rdm1.uk` traffic (~761k lines of it vs ~94k genuine
`rdm1.uk` hits) — anchored it to exclude subdomains. Separately widened `wordpress_hacks.conf`'s
wp-/xmlrpc filter to catch scanner requests that guess a subdirectory first
(`/blog/wp-includes/`, `/wordpress/wp-includes/`, etc.) — confirmed via real log data this was
missing ~6,500 requests across every domain, not just merg.

### 2026-07-29 — mapper live on srv10, mapper/CLAUDE.md added, unbalanced-tree cleanup started
Deployed mapper to srv10 (`zypper install mapserver`, package clone + `chown nginx:nginx`,
`/etc/mapserver.conf` + mapfile symlinks from webstack, `setup-site-links.sh lsces`, nginx/
php-fpm reload) — repeated the srv9 sequence, verified identically via curl (pages 200,
default mapset resolves to lsces's 5-layer `iom` set, `storage/mapper` 403s, a real `mapserv`
CGI render returns a valid PNG). srv9 also re-verified end-to-end against the final
script.php/mapsets_inc.php architecture. `https://lsces.uk/wiki/Mapping+Index` now links to a
working map. Added `mapper/CLAUDE.md` (frame/JS-context split, mapset architecture, storage
layout, CGI semantics) and linked it from this file's package-notes list; fixed a missing
`/mapper/` entry in `~/Development/bitweaver-lsces/.gitignore`. Verified `switch-site`'s
`storage/maps` symlink handling on desktop (no-op when correct, leaves it alone for domains
without their own `storage/maps`, backs up rather than deletes a real directory in the way).
Full detail in `project_mapper_osrm_revival` memory. Next: mapper "unbalanced tree" cleanup,
step 1 — see Active work threads above.

### 2026-07-27 — Firebird DR mirror cleanup, desktop firebird-restore enablement
Chased down a "myhomecloud grown to 500MB but srv9 copy is 19MB" alarm — turned out to be normal
Firebird behaviour (`.fdb` files never shrink on their own; only a `gbak` backup/restore cycle
reclaims space) plus Dolphin mangling the filename shown inside `.fbk.gz` archives (the actual
gzip-embedded name was correct in every case checked — don't trust Dolphin's archive preview for
this, verify with `gzip -l` or a raw header read instead). Row-count comparison confirmed no data
loss between srv10 live and srv9 restored. Cleaned stray uncompressed `<domain>.fbk` and stale
`<domain>.fdb.old` snapshots (leftover from a 17/05/26 batch operation) out of `/srv/firebird/`
for all 8 backed-up domains on srv9 and srv10, and off desktop (user did desktop's cleanup by
hand, including a pile of obsolete dev-version `.fdb`/`.fbk` clutter — `domain2/3/4` variants,
webtrees version snapshots — that didn't match the server pattern). Found desktop was missing
the `/opt/firebird/SYSDBA.password` → `/etc/webstack/firebird/SYSDBA.password` symlink that
srv9/srv10 both have (same class of gap as the goaccess/cron.daily parity issues from the
previous session) — fixed, so `firebird-restore` should now be runnable from desktop too
(untested — still needs `sudo` there since desktop isn't a root shell like srv9/10). Noted but
not actioned: `merg` (merg.rdm1.uk) is a live domain not in `firebird-backup`'s 8-domain list —
no automated backup/DR coverage yet; webtrees firebird dir on desktop needs sorting through
multiple version-named `.fdb` files. Full detail in `/etc/webstack/CLAUDE.md`.

### 2026-07-27 — nginx log consolidation, orphaned file cleanup, firebird-restore for srv9
Fixed a stuck-file logrotate bug and a fail2ban blind spot (default_server catch-all traffic was
invisible to any jail); consolidated all "blind attempt" logging into one top-level
`attempts.log`. Swept ~970MB of orphaned log files off both servers. Fixed `nginx-stats` to
parse `rdm1.uk` like every other domain, and brought `goaccess.conf` under webstack tracking
(srv9 never had it configured at all). Documented, not fixed, a fail2ban `maxretry` timing
limitation. Built `firebird-restore` — a manual (not automated) script for refreshing srv9's DR
mirror (database + full storage tree) from srv10, after discovering `firebird-backup` had been
silently not running on srv9 for ~3 months (srv9's `/etc/cron.daily/` turned out to be empty,
not a timing issue as first assumed). Full detail in `/etc/webstack/CLAUDE.md` and the
`reference_fail2ban_gotchas` memory.

### 2026-06-14 — Stock multi-user kitelf filtering + PBLD prebuild type
Stock template cleanup; kitelf `user_id` filtering across list pages; PBLD movement type;
owner change on assembly/movement edit pages. Detail in `stock/CLAUDE.md`.

### 2026-06-22/23 — Per-site JS loader pattern + banner/footer tidies
rainbowdigitalmedia scrolling banner restored after config/images removal; roundabout and
haccordion JS moved out of global bit_setup_inc.php into per-site theme_setup_inc.php files
managed via webstack. setup-site-links.sh updated to auto-symlink them. Detail in `themes/CLAUDE.md`.

### 2026-06-17/18 — Theme/asset cleanup + site structure rationalisation
Config folders cleaned to `kernel/` + `themes/` only; generic config parts (`admin/`, `icons/`,
`includes/`, `index.php`) now symlinked from `_bw5/config/` via `setup-site-links.sh`.
Site `index.php` replaced with symlink to `_bw5/index.php`. `config/` package repo cleaned.
Full detail in `themes/CLAUDE.md`.

## CC Limitations
For execution-order bugs and session/config state problems, 
use xdebug rather than asking CC to trace — static analysis 
cannot follow runtime state reliably.