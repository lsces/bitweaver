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
Cookie name = `bit-user-{site_title_stripped}` (lowercase, alphanum only).
Login stores PHP `session_id()` in `users_cnxn.cookie` mapped to `user_id`.
Subsequent requests look up the cookie value in `users_cnxn` to identify the user —
this is separate from PHP's own session mechanism (though they share the same cookie name).

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

## Infrastructure
Detail lives in `/etc/webstack/CLAUDE.md` — its own repo, own `CLAUDE.md`, same pattern as the
bitweaver packages above (`themes/CLAUDE.md` etc). Covers: site folder structure and symlink
layout, `/etc/webstack` itself, the Firebird backup/DR mirror between srv9 and srv10, nginx log
structure and logrotate gotchas, fail2ban (jails, known limitations), and nginx-stats/goaccess.

## Session Management
At the end of each productive session, append discoveries, decisions, and completed items to this file.
Use `/clear` to reset context when it gets bloated — this file re-orients the session.

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