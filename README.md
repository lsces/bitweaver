# bitweaver

**Bitweaver for modern PHP.** [Bitweaver](http://www.bitweaver.org/) is a PHP CMS and application
framework descended from TikiWiki. This is a long-running fork, used on several live sites, that has
been carried onto a current stack: PHP 8.5 with namespaces, Smarty 5 and ADOdb, with no npm or
Node.js dependency. It is published here in the hope that parts of it are useful to others.

The code is split into one repository per package (kernel, liberty, fisheye and so on, listed
[below](#packages-in-this-organisation)). This wrapper repository ties them together: a real site
symlinks each package it needs from a checkout of the wrapper into its own web root, and all the
packages share one codebase.

## What is different from classic bitweaver

- **Modern PHP.** Namespaced PHP 8.5 code throughout, with typed signatures where they help.
- **Smarty 5** templates, still resolved through bitweaver's `bitpackage:` search path so a site can
  override any template.
- **Database portability kept.** The database layer is written to ADOdb, as in classic bitweaver, so
  it is not tied to one engine. This fork is developed and run on Firebird 5; the installer still offers
  the other engines classic bitweaver supported, but they are not exercised here.
- **New packages** built on the Liberty content engine and its `xref` (key-value extension) system:
  `fisheyemedia` (films, TV, music, a book library, documents and tutorials), plus `stock`, `food`,
  `health`, `mapper` and `contact`.
- **No build step.** Bootstrap 3 and jQuery as plain files; nothing to compile.

---

## Stack

| Layer | Technology |
|---|---|
| Language | PHP 8.5 |
| Database | [ADOdb](https://github.com/lsces/ADOdb) (`v5.22.11-lsc` branch); developed and run on Firebird 5 |
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

This fork runs on **Firebird 5**. The code is written to ADOdb, so other engines the installer offers
(MySQL, PostgreSQL and the like) remain the original options, though only Firebird is exercised here.
Firebird is stricter than MySQL in several ways that matter, so code written for it is also the safe
choice elsewhere:
- Every non-aggregate `SELECT` column must appear in `GROUP BY`.
- `IN ()` with an empty list is a syntax error — always guard with a fallback.
- `FIRST n` / `ROWS n` for limiting result sets (not `LIMIT`).
- `LOCALTIMESTAMP` / `CURRENT_TIMESTAMP` as default expressions behave differently from MySQL.

---

## Template System (Smarty)

Templates live in `<package>/templates/`. The `bitpackage:` Smarty resource prefix resolves
templates through a search path that allows per-site overrides:

1. `config/themes/<site>/` (the site's own overrides)
2. `<package>/templates/`

This means dropping a template file into the site-specific path silently overrides the
package default — useful for site-specific customisation without forking the package.

A style (theme) lives in `config/themes/<name>/` and is chosen by the `style` setting. The release carries
one, `config/themes/BlueSky/` (a Bootstrap 3 based colour theme), as the fallback that `default_style` names;
further themes are meant to be separate optional packages that unpack into `config/themes/`. Its logo rule
points at `config/images/logo.png`, which a site supplies.

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

## Getting started

Bitweaver is meant to be taken in pieces: a small **base**, plus whichever packages a site wants. Each
package is its own repository (this wrapper does not use git submodules).

### Download

| File | What it is |
|---|---|
| `bitweaver-V5.1.1.zip` / `.tar.gz` | **The base**: core, wiki, fisheye and the external libraries — one self-contained tree |

That is the only bundle, because it spans many repositories. **Every other package is its own
repository, and GitHub makes the archive of a release tag for you:**

```
https://github.com/lsces/<package>/archive/refs/tags/V5.1.1.zip     (or .tar.gz)
```

Each package's row in the tables below has the link. A GitHub archive unpacks into a folder named
`<package>-5.1.1`: **rename it to `<package>`** and put it in the base next to `wiki/` and `fisheye/`.
(It also contains the repository's own `.gitignore`, which you can delete.) Packages are optional on
their own, except that `food` and `stock` need `contact`, and the two media packages (`contactwiki`
and `fisheyemedia`) need `contact` and each other; the tables say so.

### Or with git

```bash
git clone https://github.com/lsces/bitweaver.git
cd bitweaver
./get-packages.sh                    # the base: core + wiki + fisheye + the external libraries
./get-packages.sh blogs search       # ... plus these (and anything they say they need)
./get-packages.sh --group extensions # ... plus a whole group
```

`./get-packages.sh --list` shows the groups; `--all` fetches every released package; `--ref V5.1.1`
fetches exactly that release (every package and the patched ADOdb and Smarty at one tag); `--full`
keeps the whole history; `--update` brings what you already have up to date. Naming a package also
fetches the packages it declares it needs (`food` pulls in `contact`; either media package pulls in
the other and `contact`). `config/` and `storage/` are part of this wrapper and need no fetching. The
external libraries land in `externals/`: [ADOdb](https://github.com/lsces/ADOdb) (the `v5.22.11-lsc`
branch), [Smarty](https://github.com/lsces/smarty) and [HTMLPurifier](https://github.com/ezyang/htmlpurifier).

A site then symlinks the packages it needs from this checkout into its web root, and the browser
installer in `install/` creates the database and the tables for the packages you chose.

The current release is **V5.1.1**.

---

## Packages in This Organisation

Every package is its own public repository at `https://github.com/lsces/<package>`. They fall into
groups (`packages.txt`), and `get-packages.sh` fetches them by group.

### Core

Always needed. `config/` and `storage/` are part of this wrapper repository itself.

| Package | Content type | Notes |
|---|---|---|
| kernel | — | Bootstrap, globals, BitSystem, BitBase |
| liberty | `liberty_content` | Content engine, xref system |
| users | — | Auth, roles, permissions |
| themes | — | Layout, CSS loading, module system |
| languages | — | Translations, `tra()` string lookup |
| util | — | Shared JavaScript, icons, cross-package utilities |
| install | — | Installer / upgrader |
| protector | — | Row-level content permission enforcement, hooks into liberty |
| ckeditor | — | Vendored WYSIWYG editor (CKEditor 4) |
| config | — | Site-level overrides (CSS, templates) — in this repository |
| storage | — | Shared attachment/icon storage support — in this repository |

### Default content

What a basic site is built from; part of the base download.

| Package | Content type | Notes |
|---|---|---|
| wiki | `wiki page` | Wiki pages and books |
| fisheye | `fisheye` | Image galleries |

### Features

Site features; each is optional on its own.

| Package | Content type | Notes | Download |
|---|---|---|---|
| articles | `article` | Articles | [zip](https://github.com/lsces/articles/archive/refs/tags/V5.1.1.zip) |
| blogs | `blog`, `blogpost` | Blogs and posts | [zip](https://github.com/lsces/blogs/archive/refs/tags/V5.1.1.zip) |
| boards | — | Message boards / forum | [zip](https://github.com/lsces/boards/archive/refs/tags/V5.1.1.zip) |
| calendar | — | Month/week/day grid over other packages' dated content | [zip](https://github.com/lsces/calendar/archive/refs/tags/V5.1.1.zip) |
| rss | — | RSS feed reader/generator | [zip](https://github.com/lsces/rss/archive/refs/tags/V5.1.1.zip) |
| search | — | Site-wide content search | [zip](https://github.com/lsces/search/archive/refs/tags/V5.1.1.zip) |

### Extensions

Functional extensions; each is optional on its own.

| Package | Content type | Notes | Download |
|---|---|---|---|
| contact | `contact`, `contactperson`, `contactbusiness` | Person and business contacts, CSV import | [zip](https://github.com/lsces/contact/archive/refs/tags/V5.1.1.zip) |
| food | `foodcomponent`, `foodassembly`, `foodmovement` | Nutrition/pantry tracking, Samsung Health CSV import (needs `contact`) | [zip](https://github.com/lsces/food/archive/refs/tags/V5.1.1.zip) |
| health | `healthday` | Samsung Health / HealthForYou vitals import (weight, BP, pulse, SpO2, temperature, sleep, steps) | [zip](https://github.com/lsces/health/archive/refs/tags/V5.1.1.zip) |
| mapper | `map` | MapServer-based GIS viewer, on-demand tile caching | [zip](https://github.com/lsces/mapper/archive/refs/tags/V5.1.1.zip) |
| stock | `stockassembly`, `stockcomponent`, `stockmovement` | BOM, stock levels, movement CSV import (needs `contact`) | [zip](https://github.com/lsces/stock/archive/refs/tags/V5.1.1.zip) |

### Media

The media management upgrade. It needs `contact`, and **both** packages together.

| Package | Content type | Notes | Download |
|---|---|---|---|
| contactwiki | — | Wiki pages for contacts (needs `contact` and `fisheyemedia`) | [zip](https://github.com/lsces/contactwiki/archive/refs/tags/V5.1.1.zip) |
| fisheyemedia | `fisheyemediagal`, `fisheyebook`, ... | Films, TV, music, a book Library with series and authors, documents (PDF and epub, with text search) and tutorials, built on fisheye (needs `fisheye`, `contact` and `contactwiki`) | [zip](https://github.com/lsces/fisheyemedia/archive/refs/tags/V5.1.1.zip) |

### Experimental

Not yet reviewed or adopted, and not part of any release: there is no release tag and no download,
and `get-packages.sh` fetches them from `master` with a notice. Use them knowing that.

feed (per-user activity feed over the action log), messages (user-to-user messaging), newsletters
(email newsletters), nexus (dropdown menu builder), stats (site usage statistics; the Search Statistics page belongs to `search` and needs no other package),
tags (content tagging).

---

## License

Licensed under the GNU Lesser General Public License, version 2.1 — see [LICENSE](LICENSE). The
source files carry the same notice in their headers.
