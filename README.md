# bitweaver

A personal fork of [bitweaver](http://www.bitweaver.org/) — a PHP CMS and application framework
originally derived from TikiWiki. This organisation holds one repository per package, plus this
wrapper repo tying them together. A real site symlinks each package it needs from a checkout of
this wrapper into its own web root — all packages share one codebase, deployed together.

Having used bitweaver for many years across several live sites, this fork has been carried forward
into a modern stack: PHP 8.5, Firebird 5, Smarty 5 with namespaces, and adodb on a custom branch.
It is published here in the hope that parts of it are useful to others.

---

## Stack

| Layer | Technology |
|---|---|
| Language | PHP 8.5 |
| Database | Firebird 5 via adodb (`v5.22.11-lsc` branch) |
| Templates | Smarty 5 |
| CSS/JS | Bootstrap 3, jQuery — no npm, no Node.js |
| Web server | nginx + php-fpm |

---

## Architecture Overview

Bitweaver is built around a **package system**. Every feature area (articles, blogs, contact,
stock, etc.) is a self-contained directory under the web root. Packages are loosely coupled
through a small set of global objects and a shared database.

### Packages

Each package directory follows this layout:

```
<package>/
  admin/               package administration pages
  includes/
    bit_setup_inc.php  package self-registration (always loaded)
    classes/           PHP classes for this package
    config_defaults_inc.php  package-level config defaults (optional)
  templates/           Smarty templates (.tpl)
  modules/             sidebar/layout module templates
  index.php            package landing page
  *.php                entry-point pages (list, edit, view, add…)
```

`bit_setup_inc.php` is the only file loaded unconditionally for every request. It calls
`$gBitSystem->registerPackage()` to declare the package and `$gBitSystem->registerAppMenu()`
to add a navbar dropdown.

### Request Lifecycle

1. `index.php` (web root) → `kernel/includes/setup_inc.php`
2. `setup_inc.php` initialises global objects (`$gBitDb`, `$gBitSystem`, `$gBitSmarty`,
   `$gBitUser`), detoxifies `$_GET`, and loads `bit_setup_inc.php` for every active package.
3. The requested page file runs: loads a content object, does DB work, assigns Smarty
   variables, calls `$gBitSmarty->display( 'bitpackage:pkg/template.tpl' )`.
4. Smarty renders through `kernel/templates/html.tpl` → layout columns → modules → page body.

---

## Class Hierarchy

```
BitBase  (kernel — abstract, DB-aware base)
└── LibertyBase  (liberty — adds mContentId, mContentTypeGuid)
    └── LibertyContent  (liberty — full content lifecycle: store, load, expunge)
        └── <Package class>  e.g. Contact, StockAssembly, StockComponent, StockMovement
```

Additional kernel classes (not in the content hierarchy):

- **`BitSystem`** (`$gBitSystem`) — package registry, config store, menu registration,
  layout, error handling.
- **`BitDbAdodb`** (`$gBitDb`) — thin adodb wrapper; all DB access goes through this.
- **`BitSingleton`** — base for objects that must exist once (BitSystem inherits from this).
- **`KernelTools`** — static utility methods: `tra()` (translation), `detoxify()`, etc.
- **`RolePermUser`** (`$gBitUser`) — the logged-in user; holds roles, permissions, preferences.

---

## Key Globals

| Variable | Class | Purpose |
|---|---|---|
| `$gBitDb` | `BitDbAdodb` | Database connection |
| `$gBitSystem` | `BitSystem` | Package registry, config, menus |
| `$gBitSmarty` | Smarty subclass | Template engine |
| `$gBitUser` | `RolePermUser` | Current user (anonymous or authenticated) |
| `$gContent` | `LibertyContent` subclass | The content object for the current page |

---

## Database Layer

All queries use **adodb** — no raw PDO or mysqli. The wrapper is `BitDbAdodb` in
`kernel/includes/classes/BitDbAdodb.php`.

Key adodb methods used throughout the codebase:

| Method | Purpose |
|---|---|
| `getArray($sql, $vals)` | Returns all rows as a numerically-indexed array |
| `getAssoc($sql, $vals)` | Returns rows keyed by the first column |
| `getOne($sql, $vals)` | Returns a single scalar value |
| `getRow($sql, $vals)` | Returns a single row as an associative array |
| `query($sql, $vals)` | Execute; returns a recordset (iterate with `fetchRow()`) |
| `executeQuery($sql, $vals, $numrows, $offset)` | Paginated query |

Placeholders are always positional `?`. Named binds are not used.

The database is **Firebird 5**. Firebird is stricter than MySQL in several ways that matter:
- Every non-aggregate `SELECT` column must appear in `GROUP BY`.
- `IN ()` with an empty list is a syntax error — always guard with a fallback.
- `FIRST n` / `ROWS n` for limiting result sets (not `LIMIT`).
- `LOCALTIMESTAMP` / `CURRENT_TIMESTAMP` as default expressions behave differently from MySQL.

---

## Template System (Smarty)

Templates live in `<package>/templates/`. The `bitpackage:` Smarty resource prefix resolves
templates through a search path that allows per-site overrides:

1. `config/themes/<site>/` (symlink to `/etc/webstack/domains/<site>/themes/<site>/`)
2. `<package>/templates/`

This means dropping a template file into the site-specific path silently overrides the
package default — useful for site-specific customisation without forking the package.

**Important Smarty conventions in this codebase:**

- `{tr}...{/tr}` for user-visible strings (maps to `KernelTools::tra()`).
  `"string"|tra` is **not** a valid Smarty modifier and will throw a compiler error.
- `{form}...{/form}` block plugin auto-injects the CSRF ticket hidden field.
- `{strip}` removes inter-tag whitespace; keep content like `&bull;` inside valid elements.
- Per-site footer scripts go in `kernel/footer_inc.tpl`, not `kernel/footer.tpl`.
  `footer_inc.tpl` is loaded via the `mAuxFiles` loop in `html.tpl` and is reliable.
  `footer.tpl` as a theme override only loads when the active style name matches exactly.

---

## Permission / Role System

Roles are stored in the `users_roles` table. Default role IDs:

| role_id | Name | perm_level |
|---|---|---|
| 1 | Administrators | admin |
| 2 | Editors | editors |
| 3 | Registered | registered |
| -1 | Anonymous | basic |

Permissions are declared in `<package>/admin/schema_inc.php` and stored in
`users_role_permissions`. `$gBitUser->hasPermission('p_pkg_action')` is the standard check.

When writing role-filter queries, guard the `IN()` list with:
```php
array_keys($gBitUser->mRoles ?? []) ?: [-1]
```
Firebird rejects `IN ()` with an empty list.

---

## Liberty Content System

The **liberty** package is the content engine. All content types (pages, articles, contacts,
stock items, movements, …) share a single `liberty_content` table row identified by a
`content_id` and a `content_type_guid` string.

A package registers its content type in `schema_inc.php` and provides a class that extends
`LibertyContent`. The class overrides `store()`, `load()`, and `expunge()` to handle its
own additional tables/xrefs on top of the base liberty row.

### XRef System

`liberty_xref` is a flexible key-value extension table attached to any content item.
Rows are grouped by `x_group` and typed by `item`. The OOP layer wraps this:

- **`LibertyXrefType`** — describes one xref slot (group, item key, cardinality, etc.)
- **`LibertyXref`** — one populated xref row
- **`LibertyXrefGroup`** — a collection of xref rows sharing an `x_group`
- **`LibertyXrefInfo`** — the full set of xref groups for a content item

**Loading pattern** (display and edit pages):
```php
$gContent->loadXrefInfo();
$gBitSmarty->assign('gXrefInfo', $gContent->mXrefInfo);
```

**Template pattern**:
```smarty
{foreach $gXrefInfo->mGroups as $xrefGroup}
    {include file=$gContent->getXrefListTemplate($xrefGroup->mTemplate)
        xrefGroup=$xrefGroup allow_edit=false}
{/foreach}
```

Group templates receive `$xrefGroup` (a `LibertyXrefGroup` object). The first two lines
of every group template set local flags:
```smarty
{assign var=xrefAllowEdit value=$allow_edit|default:false}
{assign var=isHistory value=($xrefGroup->mXGroup eq 'history')}
```

---

## Session / Authentication

Cookie name: `bit-user-{site_title_stripped}` (lowercase alphanumeric).

Login stores the PHP `session_id()` in `users_cnxn.cookie` mapped to `user_id`. Subsequent
requests look up the cookie value in `users_cnxn` to identify the user. This is independent
of PHP's own session mechanism even though they share the same cookie name.

---

## Deploy Path

Each package is a self-contained directory under this wrapper repo (own git repo, own GitHub
remote) — developed directly in place, no separate build or copy step. Edit under `<package>/`,
commit in that package's own repo, `git push`.

Getting changes onto a live server (pulling, clearing Smarty's template cache, restarting
php-fpm) is your own infrastructure's job — nothing here prescribes a specific server setup. If
you run staging and production instances, the general-purpose advice is the obvious one: prove
structural changes on staging before production, small already-verified fixes can go straight to
both.

---

## Packages in This Organisation

| Package | Content type | Notes |
|---|---|---|
| kernel | — | Bootstrap, globals, BitSystem, BitBase |
| liberty | `liberty_content` | Content engine, xref system |
| users | — | Auth, roles, permissions |
| themes | — | Layout, CSS loading, module system |
| languages | — | Translations, `tra()` string lookup |
| config | — | Site-level overrides (CSS, templates) |
| util | — | Shared JavaScript, icons, cross-package utilities |
| storage | — | Shared attachment/icon storage support |
| install | — | Installer / upgrader |
| protector | — | Row-level content permission enforcement, hooks into liberty |
| contact | `contact`, `contactperson`, `contactbusiness` | Person and business contacts, CSV import |
| stock | `stockassembly`, `stockcomponent`, `stockmovement` | BOM, stock levels, movement CSV import |
| food | `foodcomponent`, `foodassembly`, `foodmovement` | Nutrition/pantry tracking, Samsung Health CSV import |
| health | `healthday` | Samsung Health / HealthForYou vitals import (weight, BP, pulse, SpO2, temperature, sleep, steps) |
| mapper | `map` | MapServer-based GIS viewer, on-demand tile caching |
| articles | `article` | — |
| blogs | `blog`, `blogpost` | — |
| boards | — | Message boards / forum |
| calendar | — | Month/week/day grid over other packages' dated content |
| fisheye | `fisheye` | Image gallery |
| wiki | `wiki page` | — |
| feed | — | Per-user activity feed, built on liberty's action log |
| messages | — | Internal user-to-user messaging |
| newsletters | — | Email newsletters to site users |
| nexus | — | Multi-level dropdown menu builder |
| rss | — | RSS feed reader/generator |
| search | — | Site-wide content search |
| stats | — | Site usage statistics |
| tags | — | Cross-package content tagging |
| ckeditor | — | Vendored WYSIWYG editor (CKEditor 4) |
