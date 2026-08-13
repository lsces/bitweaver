# Bitweaver-lsces Project Context

## Stack
- PHP 8.5.7 / Firebird 5 / adodb / Smarty
- One repo per package (`lsces` GitHub organisation)
- webtrees used as an additional package with illuminate-firebird providing Firebird DB driver (personal fork)
- externals/ holds actively-developed third-party dependencies
- No npm, no Node.js — ever

## Deploy Path
**Updated 2026-08-13 — directory renamed `bitweaver-lsces` → `bitweaver`**, matching the GitHub
repo name (`lsces/bitweaver.git`) — `bitweaver-lsces` was only ever a local placeholder name, used
in documentation, not something anything functional depended on. `/srv/website/_bw5` repointed to
match; see the dated log entry below for what else got fixed along the way.

**Updated 2026-08-11 — `bitweaver5` retired as the edit copy.** `/srv/website/_bw5` now symlinks
straight to `~/Development/bitweaver` — code is edited and tested directly there (xdebug
still available), no more copy-then-commit step. `/srv/website/bitweaver5` itself has since been
moved to `/srv/archive/bitweaver5` — it no longer exists at its old path, nothing points at it.

Each bitweaver package is a self-contained directory under `~/Development/bitweaver/`, with
its own **individual git repo**. That top-level directory is **itself** also a git repo (own
`.git`, pushes to `github.com:lsces/bitweaver.git`) — separate from every per-package repo living
inside it as a subdirectory. This top-level `CLAUDE.md` (and anything else cross-package/org-level,
not belonging to one specific package) lives there directly now — edit it in place, commit+push in
that repo, same as any package. Don't confuse this with `/srv/git/bitweaver` (a bare repo for
nginx-serving, unrelated, not yet wired up) or with `/etc/webstack`'s own separate repo (server
config, different bare repo entirely).

Deploy steps:
1. Edit directly in `~/Development/bitweaver/<package>/`
2. Commit in that package's git repo
3. `git push` — updates GitHub (publish-only, not part of the deploy chain)
4. `/etc/webstack/scripts/server-pull-all.sh <package>` — pulls to srv9 and srv10 from the desktop's local copy (run via `ssh root@srv9`/`srv10`, not directly from desktop)

Servers do NOT pull from GitHub — they pull from the desktop's local copy. After pulling on a
server, clear the Smarty template cache and restart php-fpm.

**Server topology, general deploy/ops philosophy, machine access, and the session-start sanity
check now live one level up in `/srv/website/CLAUDE.md`** — read that first when starting a fresh
session. Server configuration detail (nginx, PHP, Firebird, fail2ban, logging) is in
`/etc/webstack/CLAUDE.md`, linked again from "Infrastructure" below.

## Scope
Focus exclusively on Bitweaver code in the current working package.
Do not roam into other packages unless explicitly asked.

**Ignore completely:**
- `webtrees/` — separate application, has its own work thread
- `vendor/` — composer-managed, do not touch
- `externals/` — third-party libs, treat as read-only unless explicitly asked
- `bitweaver5` — retired 2026-08-11, moved to `/srv/archive/bitweaver5`; edit in `~/Development/bitweaver` instead
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
- enquirysolve: real content/user recovery from `enquirysolve4.fdb` (old bw4-era DB, renamed
  aside) — parked, needs a dedicated session. Web side (symlinks, config, `es.rdm1.uk` vhost/cert)
  is done and live on a phpsurgery-copy DB in the meantime.
- medw: 3 stray `bitboard` rows, confirmed nobody wants them — awaiting go-ahead to delete.
- articles package: listing page doesn't find existing content (seen on both lsces and medw
  despite real `bitarticle` rows) — parked, needs its own debugging session.
- garage-press / graham-ovenden: `package_articles=y` in `kernel_config` despite zero content and
  no actual need — deactivate via the installer, not urgent.

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
- `mapper/CLAUDE.md` — session log (decisions, bugs found, open follow-ups); `mapper/MANUAL.md` —
  current-state reference (architecture, Map content object/xref schema, tile caching, pretty
  URLs, permissions, deployment topology incl. `rdmcloud.uk`) — read MANUAL.md first for "how
  does this work", CLAUDE.md for "why is it built this way"
- `protector/CLAUDE.md` — permission-check-unreachable bug (fixed 2026-08-02): anonymous/
  unauthorized access to protector-restricted content fell through to a generic "page not
  found" instead of the login/permission-denied prompt

## Infrastructure
Detail lives in `/etc/webstack/CLAUDE.md` — its own repo, own `CLAUDE.md`, same pattern as the
bitweaver packages above (`themes/CLAUDE.md` etc). Covers: site folder structure and symlink
layout, `/etc/webstack` itself, the Firebird backup/DR mirror between srv9 and srv10, nginx log
structure and logrotate gotchas, fail2ban (jails, known limitations), and nginx-stats/goaccess.

## Session Management
At the end of each productive session, append discoveries, decisions, and completed items to this
file. Use `/clear` to reset context when it gets bloated — this file re-orients the session.
Entries for closed, deployed, verified threads are kept as one-liners — full detail lives in the
relevant package `CLAUDE.md`, the linked memory, or git history, not duplicated here. Pruned to
one-liners 2026-08-10 (was 3 dated entries deep per topic); nothing here was lost, see git history
of this file for the fuller prose if ever needed.

### Sanity check
Moved to `/srv/website/CLAUDE.md` (2026-08-13) — applies to the whole server stack, not just
Bitweaver work, so it now lives one level up. Run it there at the start of any new session
following a `/clear` or a machine restart/reboot.

- **2026-08-11** — Morning sanity check all green (backups, certs, fail2ban, services, status.php).
  Found the 2026-08-10 FlameRobin fix was itself broken: `pkill -x flamerobin` (SIGTERM) reports
  success but FlameRobin ignores it and keeps running; fixed to `pkill -9 -x` in `srv9-backup`.
  `srv10-backup` extended to also restore desktop's *and* srv9's `.fdb` for its 9 domains (not
  just refresh `storage/backup/`) — srv9 was previously left deliberately stale on a since-
  invalidated theory; the rolling 10-backup history is the real hack-recovery protection, a DR
  standby needs current data to be useful. **Second thread, same day** — desktop multi-site
  brainwave: confirmed every `local-<site>` vhost still roots at the shared `bitweaver5` (only one
  site "live" at a time); found and repaired real symlink drift across all 9 desktop site folders
  (`stock` missing everywhere, `medw` missing `contact`, stale real-file `index.php` on 5 domains,
  `install` dangling at nonexistent `../_bw4/`) via `setup-site-links.sh`, now safe to use post-
  `_bw5` (2026-08-08). Found+removed a 1.2GB genuinely-obsolete standalone 2014-era mapper install
  under `lsces/` (verified byte-identical against `/home/media1/Maps/iom_years/` first); copied
  (not moved — srv10 still has them) `lsces/cgi-viewer`+`cgi-demos` to `rdmcloud` as a first step
  toward consolidating MapServer test/demo content there. **Third thread, chasing an APCu tangent** — dug
  into whether `BitSystem`'s APCu object cache does anything useful; found and fixed a real,
  already-live production bug along the way: `BitBase::__destruct()` unset `mDb` before
  `storeInCache()` needed it, crashing `Contact`/`Stock*::isValid()` (4032 + 13 occurrences in
  srv10's current log, since 2026-08-10's `isValid()` fix first gave `getCacheKey()` a reason to
  need `mDb`) — fixed and deployed to srv9+srv10, confirmed no new occurrences after. `BIT_CACHE_OBJECTS`
  itself confirmed genuinely working via xdebug (a `Hits: 0` reading that looked like "cache never
  read back" was actually just a display artifact of always-overwrite). **Fourth thread, same
  day — desktop multi-site actually finished.** `IS_LIVE`/`BIT_CACHE_OBJECTS`/`$smarty_force_compile`
  made machine-aware (new shared `_machine_inc.php`, `gethostname()`-based) across all 9 domains'
  webstack-source `config_inc.php`, desktop's copies converted from diverging real files to real
  symlinks at the source, matching servers. All 9 `local-<site>.vhosts.conf` repointed from the
  shared `bitweaver5` root to their own `/srv/website/<site>/` (3 hardcoded paths per file: root,
  PHP-location root, attachments alias). Hit and fixed a real `externals/` divergence along the
  way — `bitweaver5/externals` (actively used) had silently diverged from the sibling
  `/srv/website/externals` (what every site's symlink actually pointed to, never exercised until
  now) — different adodb version entirely, missing several packages. Archived the stale sibling,
  promoted `bitweaver5/externals` to take its place. Also found+removed a small identical-content
  `_bw5/externals/bootstrap-3.2` duplicate on both srv9 and srv10 while there. **All 9 desktop
  domains now serve genuinely distinct content simultaneously** — `switch-site.sh` and the old
  one-site-at-a-time model are obsolete. **Fifth thread, same day — theme/config tidy-up +
  stragglers.** `config/themes/BlueSky` (fallback theme) was a real, independently-drifted copy in
  every site directory on all three machines despite `/etc/webstack/site-config/themes/BlueSky`
  already existing as the intended shared source — root cause was the shared source itself having
  gone stale, not the copies; fixed by updating it to match live content, then symlinking all 10
  domains (desktop/srv9/srv10) to it. Per-domain theme folders (`config/themes/<site>`) similarly
  discarded and symlinked straight to the webstack source — bonus fix: this also resolved a real
  broken-CSS bug on `garage-press`/`graham-ovenden` (absolute filesystem path in a CSS href,
  stylesheets never actually loading despite 200 responses). Old pre-restructuring cruft under
  `config/` (`css`/`fonts`/`images`/`js`/`bit_setup_inc.php`, confirmed absent from servers first)
  removed from all 9. Two gaps caught only by re-sweeping *every* domain rather than trusting the
  first pass: `rdmcloud`'s vhost had been skipped entirely from the repointing work (still pointed
  at `bitweaver5`); none of the 10 site vhosts had an HTTP→HTTPS redirect at all (only `rdm1`
  listened on port 80, silently becoming the catch-all for every domain, producing "file not
  found" on any `http://<domain>/` hit) — added the same `listen 80; return 301 https://...;`
  block every server vhost already has. Desktop's `config/` now byte-for-byte matches srv10's.
  Detail `reference_desktop_site_architecture` (fully rewritten) and
  `project_theme_symlink_consolidation` memories. **Separately, unrelated to any of the above**: a
  live post-deploy check surfaced a real, likely long-standing gap on `myhomecloud.uk` — floaticons
  render empty and the Administration menu's dropdown-submenu doesn't appear for either active
  admin user, despite both having `role_id=1` correctly assigned. Not caused by this session
  (myhomecloud doesn't use `BlueSky`, nothing else touched it) — parked for a dedicated session,
  now testable on desktop instead of live. **Resolved same day, sixth thread** — see below.
- **Sixth thread, same day — myhomecloud floaticon/dropdown bug fixed; base.css made generic;
  colourstrap retired.** Root cause: `.dropdown-submenu` nested-dropdown CSS was hand-copied into 8
  site theme CSS files (never generic), and `myhomecloud.css` simply never got the copy-paste;
  separately, `myhomecloud.css`'s own `.floaticon img.icon` padding was wildly oversized, pushing
  icons out of the visible area while they stayed clickable. Fixed at the root rather than
  per-site-patched: `base.css` (the file that had the generic rules all along, just never loaded
  reliably) now loads unconditionally for every site via a new `BitThemes.php` call at CSS position
  301, right after `config.css` — no per-site `@import` opt-in needed any more. The 8 duplicate
  `.dropdown-submenu` copies and 4 now-redundant `@import base.css` lines removed. Standalone
  `colourstrap` theme (legacy, ~500 files, unused by any live domain) deleted; `BlueSky`'s own hacked
  `colourstrap.css` copy also removed in favour of loading `bootstrap.css` directly. Deployed both
  the themes package and `/etc/webstack` repos to srv9 then srv10, confirmed live. Two minor
  regressions surfaced by the colourstrap removal (a dropdown colour loss, a `pkg_`-icon oversizing
  issue) deliberately deferred — back-burner theme spring-clean, not actioned. Detail
  `themes/CLAUDE.md`, `project_colourstrap_cleanup` memory. Separately, found+committed the
  Fourth-thread machine-awareness `config_inc.php` changes above, which had been sitting
  completed-but-uncommitted in `/etc/webstack` since earlier that session.
- **Seventh thread, same day — `bitweaver5` retired, `_bw5` repointed straight at
  `bitweaver-lsces`.** Desktop was the last piece still using a non-git manual-copy edit workflow;
  servers already pulled git-direct. Cleared two real blockers first: `geo`/`quota`/`pigeonholes`
  (confirmed dead — no table in any of 11 site DBs, `geo` had zero symlinks anywhere) archived to
  a new `~/Development/bitweaver-archive/` with git history intact, their symlinks/folders removed
  from both servers; `webtrees` (not a git repo, not in `bitweaver-lsces` at all, but symlinked
  from every site) decoupled entirely — real copy kept only under `myhomecloud` (matching what
  srv9/srv10 already did natively), removed from the other 9. Repointed `_bw5`, hit one more
  blocker (`/home/lester` was `700`, blocking nginx traversal — fixed with `chmod o+x`, minimal/
  traverse-only), verified working. Along the way found and fixed a real authorization bypass:
  `config/kernel/auth_check.php` was supposed to symlink to the shared `_bw5` copy everywhere
  (already correct on servers) but every desktop site had a stale real copy instead — `merg`'s had
  drifted into both branches of its role check returning 200 unconditionally, i.e. no actual
  attachment protection. Fixed on all 10 sites, `setup-site-links.sh` now covers this
  automatically. Separately onboarded `enquirysolve` (previously fully dangling on the dead `_bw4`
  codebase, domain `enquirysolve.uk` also gone) to the same pattern, now live as `es.rdm1.uk` on
  srv9+srv10 and `enquirysolve` on desktop — schema-upgrade lockout sidestepped by swapping in a
  phpsurgery-copy DB rather than running the bw4→bw5 installer against real data; real data
  recovery parked. Full detail `project_retire_bitweaver5`, `project_rdmcloud`,
  `feedback_desktop_copies_never_autoupdate` memories.
- **2026-08-10** — Morning system check found desktop's `rdmcloud.fdb` missing (FlameRobin left
  open blocked the nightly restore); `firebird-restore` made safe-swap so a failed restore can
  never wipe a domain's `.fdb` again, `srv9-backup` now kills FlameRobin first. Also pruned this
  file and `/etc/webstack/CLAUDE.md`'s session logs (~41% smaller combined). Detail
  `/etc/webstack/CLAUDE.md`. **Second session, same day** — full overnight-rollover check (backups,
  disk, SMART/temps, fail2ban, services, `status.php` on all three machines): all green, nothing
  to action. Corrected stale memory along the way: `rdmcloud-backup` cron was renamed to
  `srv9-backup` back on 2026-08-08 (memory still said the old name); acme.sh cert renewal actually
  fires at 11:43 daily, not overnight, so it's out of scope for this check; desktop's `status.php`
  is reached via any local-\* vhost domain except the `.uk`-suffixed real ones (e.g.
  `https://rdmcloud/status.php`), not the HTTP-only `rdm1` vhost. **Third session, same
  day** — stock/contact package work: fixed a Date-sort crash in `list_movements`, built
  per-assembly BOM tabs + `entry_date`-based multi-assembly line grouping, a working
  PBLD→REQN conversion, an `isValid()` black-hole fix in stock+contact (a `LibertyContent`-
  wide version was tried and reverted — real risk found in `storePreference()`/user
  registration), and browser upload for the Kitlocker stock-predict sync. Renamed
  `contact/display_contact.php` → `view.php`, deleted dead `list1.php`/`list2.php`.
  Consolidated desktop's independently-drifted per-vhost nginx rewrite blocks into one
  shared include (production's shared file also gained the contact/stock rules it never
  had). Detail `stock/CLAUDE.md`, `contact/CLAUDE.md`, `liberty/CLAUDE.md`,
  `/etc/webstack/CLAUDE.md`.
- **2026-08-08** — rdmcloud DR/dev topology completed across desktop/srv9/srv10 (`rdmcloud-backup`
  cron, srv10 passive standby, desktop real copy); `cert-sync-reload.sh` desktop-push gap fixed;
  a near-miss srv10 vhost-exposure risk caught before going live. Detail `/etc/webstack/CLAUDE.md`.
- **2026-08-04** — OSM slippy-map tile server built + wired into mapper as `osm_tiles_iom`
  (metatile-flattening and bbox-coverage bugs fixed along the way); `osm_gb_2012`/`osm_iom_2012`
  historic mapsets built from the 2012 planet dump; mapper OSM coastline layers; fail2ban 90s
  shutdown delay root-caused (ipset banaction), `nginx-444`/`nginx-botsearch` retired; desktop
  pdfarranger/ocrmypdf toolchain fixed (dead pip env shadowing real installs). Detail
  `mapper/CLAUDE.md`, `/etc/webstack/CLAUDE.md`, `project_osm_tile_server` memory.
- **2026-08-03** — `error.tpl` login-box CSS misalignment fixed (spurious Bootstrap `.row`s);
  post-login redirect port bug fixed (`HTTP_HOST` vs referer host on non-standard ports); srv9
  `firebird-restore` run to pick up a missing wiki page.
- **2026-08-02** — Protector permission-check-unreachable bug fixed site-wide (7 call sites +
  protector's own `isValid()` guard) — anonymous access to protected content showed a generic 404
  instead of a login prompt. Detail `protector/CLAUDE.md`.
- **2026-08-01** — mapper `MapFrame` scrollbar/clipped-pan-arrows bug fixed
  (`overflow:hidden`/`display:block` in layer.js/map.html). Detail `mapper/CLAUDE.md`.
- **2026-07-31** — mapper OS-Data mapsets built + deployed (meridian/minisc/opmplc/vmdvec/
  over_gb/zoomstack); mapper's permission system found never actually enforced, fixed;
  `test_rlp.map`/`OS250.map` mapfile path bugs fixed. Detail `mapper/CLAUDE.md`.
- **2026-07-29** — mapper `document.write()` elimination completed + German→English pass; mapper
  deployed live on srv10, `mapper/CLAUDE.md` added; merg.rdm1.uk onboarded (Firebird DR, config
  symlink, nginx-stats); PHP-FPM "sluggish mapper" root-caused to inherent double-bootstrap
  (APCu enabled); `wordpress_hacks.conf` widened for subdirectory-guessing scanners. Detail
  `mapper/CLAUDE.md`, `project_mapper_osrm_revival` memory.
- **2026-07-27** — Firebird DR mirror cleanup (`.fdb` non-shrinking behaviour documented, stray
  backup files cleaned); desktop enabled as a `firebird-restore` target; nginx log consolidation
  into `attempts.log`; stuck-file logrotate bug + a fail2ban blind spot fixed; `firebird-restore`
  built for srv9 after its backups turned out to have silently not run for ~3 months. Detail
  `/etc/webstack/CLAUDE.md`.
- **2026-06-14** — Stock multi-user kitelf filtering + PBLD prebuild type. Detail `stock/CLAUDE.md`.
- **2026-06-17 to 06-23** — Theme/asset cleanup + site structure rationalisation (generic config
  symlinked from `_bw5/config/`); per-site JS loader pattern for banner/footer scripts. Detail
  `themes/CLAUDE.md`.
- **2026-08-13** — CLAUDE.md reorg: generic/cross-cutting content (philosophy, server topology,
  machine access, sanity check, CC limitations note) moved to a new `/srv/website/CLAUDE.md` — this
  file trimmed to Bitweaver-project-specific content only. Read `/srv/website/CLAUDE.md` first when
  starting a fresh session; this file is now purely "how Bitweaver code itself works." **Same day,
  second thread** — directory renamed `~/Development/bitweaver-lsces` → `~/Development/bitweaver`,
  matching the GitHub repo name (`lsces/bitweaver.git`); the `-lsces` suffix was only ever a local
  placeholder used in documentation, nothing functional depended on the literal name. `mv`'d, then
  `/srv/website/_bw5` repointed to the new path (the only symlink pointing directly at it — every
  site's package symlinks go via `_bw5` relatively, so nothing else needed touching); verified
  live with a smoke-test request before moving on. Also fixed: `/etc/webstack/scripts/
  package-tag.sh`'s hardcoded path, and every doc reference across this file,
  `/srv/website/CLAUDE.md`, `/etc/webstack/CLAUDE.md`, and this repo's `README.md` (dated log
  entries describing the pre-rename state left as `bitweaver-lsces`, since that was the real name
  at the time).