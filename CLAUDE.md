# Bitweaver-lsces Project Context

## Stack
- PHP 8.5.7 / Firebird 5 / adodb / Smarty
- One repo per package (`lsces` GitHub organisation)
- webtrees used as an additional package with illuminate-firebird providing Firebird DB driver (personal fork)
- externals/ holds actively-developed third-party dependencies
- No npm, no Node.js — ever

## Deploy Path

Each bitweaver package is a self-contained directory under `~/Development/bitweaver/`, with
its own **individual git repo**. That top-level directory is **itself** also a git repo (own
`.git`, pushes to `github.com:lsces/bitweaver.git`) — separate from every per-package repo living
inside it as a subdirectory. This top-level `CLAUDE.md` (and anything else cross-package/org-level,
not belonging to one specific package) lives there directly — edit it in place, commit+push in
that repo, same as any package.

Deploy steps:
1. Edit directly in `~/Development/bitweaver/<package>/`
2. Commit in that package's git repo
3. `git push` — updates GitHub (publish-only, not part of the deploy chain)
4. Pull the updated package onto your own server(s) from your own deploy tooling — this repo
   doesn't prescribe one; the maintainer's own setup uses a private, unpublished scripts repo (see
   below) that pulls from a local desktop copy rather than GitHub directly, but that's one
   possible approach, not a requirement of the software itself.

**Server topology, deploy/ops philosophy, machine access, and any site-specific deployment
tooling live in the maintainer's own separate, private notes/scripts repos** — not part of this
public checkout. If you're deploying this package on your own infrastructure, those repos won't
exist for you, and nothing in this public repo depends on their contents. Server configuration
detail (nginx, PHP, Firebird, fail2ban, logging, real site/credential specifics) is exactly the
kind of thing that belongs in your own private deployment config, not in a public package repo —
see "Infrastructure" below for the shape such a setup might take, described in general terms.

## Creating a New Package

Worked example: the `food` package (see `food/CLAUDE.md` for its own plan). This is the **how** —
mechanical steps to get a new package existing and installable; for **why** the registration
mechanism works the way it does (what `registerPackage()` actually does, the VS Code `define()`
bodge, dual-guid xref scoping, etc.), see `liberty/CLAUDE.md`'s "Package registration" section.

1. `mkdir -p <pkg>/includes/classes <pkg>/admin/upgrades <pkg>/templates` under
   `~/Development/bitweaver/`.
2. Write `<pkg>/includes/bit_setup_inc.php` — copy `stock/includes/bit_setup_inc.php`'s shape,
   swap the package name and the six `<PKG>_PKG_*` constant names/defines. This is the file that
   makes bitweaver recognize the directory as a package at all — nothing else works until it
   exists.
3. Write `<pkg>/admin/schema_inc.php` — can start with an **empty** `$tables` array (nothing to
   register yet); still needs `registerPackageInfo()` (description/license) and
   `registerPreferences()` with at least `<pkg>_menu_text`.
4. Write `<pkg>/templates/menu_<pkg>.tpl` — the top-bar dropdown template referenced by
   `bit_setup_inc.php`'s `registerAppMenu()` call; a single link to `index.php` is enough until
   real pages exist.
5. Write a minimal `<pkg>/index.php` placeholder (`require_once '../kernel/includes/setup_inc.php';
   $gBitSystem->verifyPackage('<pkg>');` + a stub message) so nothing fatals if visited early.
6. `git init -b master`, initial commit, in the new package directory itself.
7. `gh repo create lsces/<pkg> --description "..." --source=. --remote=origin --push` — every
   package repo lives under the `lsces` GitHub account/org (not the `lsces` *site*, which is a
   separate, legacy thing — don't confuse the two), same as `liberty`/`stock`/etc.
8. Add `/<pkg>/` to the **top-level** `~/Development/bitweaver/.gitignore` (alphabetical, matches
   every other package's entry) — the wrapper repo must not try to track the nested package repo.
   Commit + push in the wrapper repo itself.
9. Symlink the package into whichever site(s) actually need it — same relative-symlink pattern as
   every other package in that site directory.
10. Not yet installed — that's a separate step via the site's own Packages admin page, once
    there's real schema to install. A freshly-scaffolded package existing and being symlinked in
    is not the same as it being active.

## Scope
Focus exclusively on Bitweaver code in the current working package.
Do not roam into other packages unless explicitly asked.

**Ignore completely:**
- `webtrees/` — separate application, has its own work thread
- `vendor/` — composer-managed, do not touch
- `externals/` — third-party libs, treat as read-only unless explicitly asked

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

Any future fixer run should use `--dry-run --diff` first.

## Bitweaver Structure Notes

### Permission / Role system, Session / Auth cookie
See `users/CLAUDE.md` — role_id defaults, `users_role_permissions`, cookie naming/lookup
mechanics, and the role-model rationalisation history all live there.

**Site-identity conventions worth knowing**, predictable expansions of each site's short name:
- **DB alias** = bare domain name, no TLD (e.g. a site at `example.com` uses alias `example`).
- **Cookie name** = `bit-user-<shortname>mainsite`, `BitSystem`'s computed value from
  `site_title`, cached on disk in `config/kernel/auth_config.php` (`session_name(...)`).

See `themes/CLAUDE.md` for: navbar menu, CSS load order, Smarty notes, module/layout
system, site-specific theme overrides.

### Package-specific notes
Detail for individual packages lives in their own `CLAUDE.md` files:
- `kernel/CLAUDE.md` — transaction shutdown safety net (`bit_shutdown_handler()`, `transOff` vs
  `transCnt`), APCu object cache `__destruct()` bug, `BitDate` global-timezone-mutation fix
- `users/CLAUDE.md` — RolePermUser-only rationalisation history (group model deleted), role/
  permission reference, session/cookie mechanics
- `themes/CLAUDE.md` — navbar menu, CSS load order, Smarty notes, module/layout, site overrides;
  `themes/MANUAL.md` — same topics as current-state reference
- `liberty/CLAUDE.md` — xref machinery (LibertyXrefType, dual-guid schema, display path,
  parseDataHash, storeXref, owner change, Firebird GROUP BY); `liberty/MANUAL.md` — current
  xref-system reference
- `contact/CLAUDE.md` — person/business model, ContactPerson/ContactBusiness history, install
  saga; `contact/MANUAL.md` — current schema/mechanisms reference
- `stock/CLAUDE.md` — movement-model history, Firebird gotchas found; `stock/MANUAL.md` —
  current schema/mechanisms reference, kitlocker sync tooling
- `wiki/CLAUDE.md` — `BitPage::store()` missing-`RollbackTrans` bug and its generic fix
  (`kernel/CLAUDE.md`'s transaction shutdown safety net); `wiki/MANUAL.md` — current
  transaction-safety mechanism + stuck-transaction diagnostic
- `mapper/CLAUDE.md` — session log (decisions, bugs found, open follow-ups); `mapper/MANUAL.md` —
  current-state reference (architecture, Map content object/xref schema, tile caching, pretty
  URLs, permissions) — read MANUAL.md first for "how does this work", CLAUDE.md for "why is it
  built this way"
- `protector/CLAUDE.md` — permission-check-unreachable bug fix: anonymous/unauthorized access to
  protector-restricted content should fall through to a login/permission-denied prompt, not a
  generic "page not found"
- `food/CLAUDE.md` — architecture plan (FoodComponent/FoodAssembly/FoodMovement), nutrition xref
  design, CSV import strategy; `food/MANUAL.md` — current-state reference
- `health/CLAUDE.md` — companion package to `food`, same CSV-export-import pattern;
  `health/MANUAL.md` — architecture (detail-tier shape taxonomy, content model, CSV-tier-first
  v1 scope)

## Infrastructure
A real deployment needs server-side config (nginx, PHP-FPM, Firebird, fail2ban, logging, backup/
DR) that this public repo deliberately doesn't include — the maintainer's own version of that
lives in a **separate, private repo, structured the same way as the packages above (its own
`CLAUDE.md`) but pushed to a local bare repo only, never GitHub**. Build your own equivalent
scoped to your own site(s)/domain(s)/credentials; nothing here depends on its exact contents.

## Session Management
Keep this file scoped to what's needed to understand and deploy Bitweaver itself — package
architecture, conventions, cross-package mechanisms, the "how do I add a package" mechanics
above. Day-to-day operational history, real deployment incidents, and site-specific specifics
belong in the maintainer's own private notes repo, not here — this file isn't a running session
log. When a change here is genuinely architectural (a new cross-package convention, a package
added/removed), update the relevant section directly rather than appending a dated entry.
