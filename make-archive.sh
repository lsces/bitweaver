#!/bin/bash
#
# Build the downloads of a release from its public tag:
#
#   bitweaver-TAG.zip / .tar.gz              the BASE: core + default packages (wiki, fisheye) + external libraries, as one self-contained tree
#   bitweaver-TAG-features.zip / .tar.gz     add-on: the features group (each package optional on its own)
#   bitweaver-TAG-extensions.zip / .tar.gz   add-on: the extensions group (each package optional on its own)
#   bitweaver-TAG-media.zip / .tar.gz        add-on: the media management upgrade (needs contact, and both its packages together)
#
# An add-on unpacks over the base (same top folder) and contains only its own packages plus ADDON.txt, which says what else it needs.
# The experimental group is never built. SHA256SUMS-TAG.txt lists every file made.
#
#   ./make-archive.sh V5.1.1                    all four, in the current directory
#   ./make-archive.sh V5.1.1 --out DIR          put them in DIR
#   ./make-archive.sh V5.1.1 --only media       just one (base, features, extensions or media; repeatable)
#   ./make-archive.sh V5.1.1 --lint             also run `php -l` over every PHP file and report syntax errors
#   ./make-archive.sh V5.1.1 --org URL          fetch the package repositories from somewhere else than https://github.com/lsces
#   ./make-archive.sh master --wrapper PATH     TAG may be a branch, and the wrapper itself can come from a local path (for a trial run)
#
# It fetches exactly as a user would (`get-packages.sh --ref TAG`), so building the downloads is also a test that the tag can be fetched.
# Legacy test directories and repository housekeeping files are left out. Needs git, python3 and tar; `zip` is not required.
set -eu
TAG=${1:-}; shift || true
OUT=$(pwd); ORG=https://github.com/lsces; LINT=0; WRAPSRC=""; ONLY=()
while [ $# -gt 0 ]; do case "$1" in
  --out) OUT=$(cd "$2" && pwd); shift ;; --org) ORG=${2%/}; shift ;; --wrapper) WRAPSRC=$2; shift ;; --lint) LINT=1 ;;
  --only) ONLY+=("$2"); shift ;; *) echo "unknown option $1" >&2; exit 2 ;; esac; shift; done
[ -n "$TAG" ] || { sed -n 3,24p "$0" | sed 's/^# \{0,1\}//'; exit 2; }
TARGETS=${ONLY[*]:-base features extensions media}

NAME=bitweaver-$TAG
# directories of tests that a release does not need (kernel/test is old SimpleTest code; the videojs one is the library's own tests)
EXCLUDE="kernel/test themes/js/videojs/test"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
if [ -z "$WRAPSRC" ]; then case "$ORG" in /*) WRAPSRC="$ORG/bitweaver" ;; *) WRAPSRC="$ORG/bitweaver.git" ;; esac; fi
PROBLEMS=0
problem() { echo "   PROBLEM: $*"; PROBLEMS=$((PROBLEMS+1)); }
ISTAG=0; case "$TAG" in V[0-9]*) ISTAG=1 ;; esac

echo "== wrapper at $TAG"
git clone -q --depth 1 --branch "$TAG" "$WRAPSRC" "$WORK/src/$NAME" 2>&1 | grep -v "^warning\|^Note: switching\|^$" | head -2 || true
PKGTXT="$WORK/src/$NAME/packages.txt"
members() { awk -v g="$1" '!/^#/ && NF && $2==g{print $1}' "$PKGTXT"; }
needs_of() { awk -v n="$1" '!/^#/ && NF && $1==n{ $1=""; $2=""; sub(/#.*/,""); print }' "$PKGTXT"; }
group_of() { awk -v n="$1" '!/^#/ && NF && $1==n{print $2}' "$PKGTXT"; }
BASE="$(members core) $(members default)"

tidy() {   # tidy TREE: drop git metadata, legacy tests and repository housekeeping files
  ( cd "$1"
    find . -name .git -prune -exec rm -rf {} +
    for x in $EXCLUDE; do rm -rf "./$x"; done
    find . -not -path './externals/*' \( -name .gitignore -o -name .gitattributes -o -name .hgignore -o -name .hgtags -o -name .cvsignore -o -name .php-cs-fixer.php -o -name .editorconfig -o -name .github \) -prune -exec rm -rf {} + )
  [ -z "$(find "$1" -name .git | head -1)" ] || problem "git metadata left behind in $1"
}
at_tag() {   # at_tag DIR WANT: the checkout is at the release tag
  [ "$ISTAG" = 1 ] || return 0
  local at; at=$(git -C "$1" describe --tags --exact-match 2>/dev/null || echo "NOT AT A TAG ($(git -C "$1" rev-parse --short HEAD))")
  [ "$at" = "$2" ] || problem "$(basename "$1") is at $at, expected $2"
}
lint() {   # lint TREE
  [ "$LINT" = 1 ] || return 0
  local bad
  # php -l checks ONE file per call, and a failing file must not stop the rest: one call per file, several at a time
  bad=$(cd "$1" && find . -name '*.php' -not -path './externals/*' -print0 | xargs -0 -n 1 -P 6 sh -c 'php -d xdebug.mode=off -l "$1" 2>&1 | grep -v "^No syntax errors" | grep -v "^$" | grep -v "^Stack trace" | grep -v "^#0" ; true' _ | head -40)
  if [ -n "$bad" ]; then echo "$bad" | sed 's/^/   /'; problem "PHP syntax errors in $1"; else echo "   no PHP syntax errors"; fi
}
pack() {   # pack TREEPARENT FILEBASE
  ( cd "$1"
    python3 -I - "$NAME" "$OUT/$2.zip" <<'PY'
import os, sys, zipfile
root, out = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for dp, dn, fn in os.walk(root):
        dn.sort()
        for f in sorted(fn):
            p = os.path.join(dp, f)
            if os.path.islink(p):
                continue
            zi = zipfile.ZipInfo.from_file(p, p)
            zi.compress_type = zipfile.ZIP_DEFLATED
            with open(p, 'rb') as fh:
                z.writestr(zi, fh.read(), compresslevel=9)
PY
    tar -czf "$OUT/$2.tar.gz" "$NAME" )
  for f in "$OUT/$2.zip" "$OUT/$2.tar.gz"; do printf '   %-40s %6s MB\n' "$(basename "$f")" "$(( $(stat -c %s "$f") / 1048576 ))"; done
  echo "   files: $(find "$1/$NAME" -type f | wc -l)  top-level folders: $(ls -d "$1/$NAME"/*/ | wc -l)"
}

: > "$OUT/SHA256SUMS-$TAG.txt"
for T in $TARGETS; do
  echo; echo "== $T"
  if [ "$T" = base ]; then
    TREE="$WORK/base"; mkdir -p "$TREE"; cp -r "$WORK/src/$NAME" "$TREE/$NAME"; cd "$TREE/$NAME"
    ./get-packages.sh --ref "$TAG" --org "$ORG" 2>&1 | grep -v "^warning" | sed 's/^/   /' | grep -E "clone|skipped|fatal|error|Unknown" || true
    for f in index.php README.md LICENSE packages.txt get-packages.sh config/index.php storage/README; do [ -e "$f" ] || problem "missing $f"; done
    for n in $BASE; do [ -d "$n" ] || problem "package $n was not fetched"; at_tag "$n" "$TAG"; done
    for g in features extensions media experimental; do for n in $(members $g); do [ -d "$n" ] && problem "$g package $n is in the base"; done; done
    for e in adodb smarty; do [ -d "externals/$e" ] || problem "externals/$e was not fetched"; at_tag "externals/$e" "$TAG"; done
    [ -d externals/htmlpurifier ] || problem "externals/htmlpurifier was not fetched"; at_tag externals/htmlpurifier v4.19.0
    [ -f externals/adodb/adodb.inc.php ] || problem "externals/adodb/adodb.inc.php missing"
    [ -f externals/smarty/src/Smarty.php ] || problem "externals/smarty/src/Smarty.php missing"
    cd "$WORK"; tidy "$TREE/$NAME"; lint "$TREE/$NAME"; FILEBASE=$NAME
  else
    case " features extensions media " in *" $T "*) ;; *) echo "   unknown target $T" >&2; exit 2 ;; esac
    TREE="$WORK/$T"; mkdir -p "$TREE/$NAME"; cp "$WORK/src/$NAME/get-packages.sh" "$WORK/src/$NAME/packages.txt" "$TREE/$NAME/"; cd "$TREE/$NAME"
    ./get-packages.sh --no-base --group "$T" --ref "$TAG" --org "$ORG" 2>&1 | grep -v "^warning" | sed 's/^/   /' | grep -E "clone|skipped|fatal|error|Unknown" || true
    MEM=$(echo $(members "$T"))     # one line, space separated: it is matched as " name " below
    for n in $MEM; do [ -d "$n" ] || problem "package $n was not fetched"; at_tag "$n" "$TAG"; done
    # a package pulled in only as a need from another group (media needs contact) is not part of this add-on
    for d in */; do d=${d%/}; case " $MEM " in *" $d "*) ;; *) rm -rf "$d" ;; esac; done
    NEEDS=$(for n in $MEM; do for d in $(needs_of "$n"); do case " $MEM " in *" $d "*) ;; *) echo "  $n needs $d ($(group_of "$d"))" ;; esac; done; done | sort -u)
    { echo "Add-on: $T (bitweaver $TAG)"; echo "Packages: $(echo $MEM)"; echo; echo "Unpack over the base download (same top folder). Needs:"
      [ -n "$NEEDS" ] && echo "$NEEDS" || echo "  nothing beyond the base download"
      if [ "$T" = media ]; then echo "  media: both packages are needed together, with contact (the extensions add-on)"; fi
      if [ "$T" != media ]; then echo; echo "Each package here is optional on its own: copy only the folders you want."; fi; } > ADDON.txt
    rm -f get-packages.sh packages.txt
    cd "$WORK"; tidy "$TREE/$NAME"; lint "$TREE/$NAME"; FILEBASE=$NAME-$T
    sed 's/^/   | /' "$TREE/$NAME/ADDON.txt"
  fi
  pack "$TREE" "$FILEBASE"
  ( cd "$OUT" && sha256sum "$FILEBASE.zip" "$FILEBASE.tar.gz" >> "SHA256SUMS-$TAG.txt" )
done
echo
[ "$PROBLEMS" = 0 ] && echo "No problems found." || echo "$PROBLEMS problem(s) found - see above."
exit 0
