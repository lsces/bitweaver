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

### Site folder structure
Each live site at `/srv/website/<site>/` contains only two static directories:
- `config/kernel/` — site-specific DB connection (`config_inc.php`), auth config
- `config/themes/` — symlinks to `/etc/webstack/domains/<site>/themes/<site>/` and shared themes
- `storage/` — site-specific uploaded files and attachments

Everything else is symlinked:
- All packages (`wiki`, `liberty`, `fisheye`, etc.) → `../_bw5/<pkg>`
- `externals/` → `../externals`
- `index.php`, `sitemap.php` → `../_bw5/` equivalents
- `config/admin`, `config/icons`, `config/includes`, `config/index.php` → `../../_bw5/config/`

Use `/etc/webstack/scripts/setup-site-links.sh [site]` to create or repair all symlinks
for all sites (or one named site). Auto-discovers packages from `_bw5/`. Safe to re-run.

**Desktop** (`bitweaver5/`) is a single unified root — not a site folder. Switch between
sites by changing `config/kernel/config_inc.php` to point at a different database. All
site themes are available because `config/themes/` has symlinks to all webstack domains.

`_bw5/config/` on servers holds the generic config package (admin, icons, includes,
index.php guard) deployed via `server-pull-all.sh config`. Per-site `config/` folders
are NOT managed by that script — they are static per-server.

### /etc/webstack
Single git repo replicated across desktop, srv9, and srv10. Push to `/srv/git/webstack.git`
before pulling on servers — servers pull from the desktop copy, not GitHub.
Contains: nginx vhost configs, logrotate, cron scripts, per-domain theme files, PHP/Firebird config, setup scripts.
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

### 2026-06-14 — Stock multi-user kitelf filtering + PBLD prebuild type
Stock template cleanup; kitelf `user_id` filtering across list pages; PBLD movement type;
owner change on assembly/movement edit pages. Detail in `stock/CLAUDE.md`.

### 2026-06-17/18 — Theme/asset cleanup + site structure rationalisation
Config folders cleaned to `kernel/` + `themes/` only; generic config parts (`admin/`, `icons/`,
`includes/`, `index.php`) now symlinked from `_bw5/config/` via `setup-site-links.sh`.
Site `index.php` replaced with symlink to `_bw5/index.php`. `config/` package repo cleaned.
Full detail in `themes/CLAUDE.md`.

## CC Limitations
For execution-order bugs and session/config state problems, 
use xdebug rather than asking CC to trace — static analysis 
cannot follow runtime state reliably.