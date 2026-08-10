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

`~/Development/bitweaver-lsces/` **itself** is *also* a git repo (own `.git`, pushes to
`github.com:lsces/bitweaver.git`) — separate from every per-package repo living inside it as a
subdirectory. This top-level `CLAUDE.md` (and anything else cross-package/org-level, not
belonging to one specific package) lives there — copy to `~/Development/bitweaver-lsces/CLAUDE.md`
directly, commit+push in that repo, same as any package. Don't confuse this with `/srv/git/bitweaver`
(a bare repo for nginx-serving, unrelated, not yet wired up — see the NOTE below) or with
`/etc/webstack`'s own separate repo (server config, different bare repo entirely).

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

- **2026-08-10** — Morning system check found desktop's `rdmcloud.fdb` missing (FlameRobin left
  open blocked the nightly restore); `firebird-restore` made safe-swap so a failed restore can
  never wipe a domain's `.fdb` again, `srv9-backup` now kills FlameRobin first. Also pruned this
  file and `/etc/webstack/CLAUDE.md`'s session logs (~41% smaller combined). Detail
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

## CC Limitations
For execution-order bugs and session/config state problems, 
use xdebug rather than asking CC to trace — static analysis 
cannot follow runtime state reliably.