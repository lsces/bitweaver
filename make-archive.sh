#!/bin/bash
#
# Build the base download of a release: the core, the default content packages (wiki, fisheye) and the external libraries of tag TAG,
# in one self-contained tree laid out as a wrapper checkout, without git history. Every other package is a secondary download
# (get-packages.sh fetches them by name).
#
#   ./make-archive.sh V5.1.0                    -> bitweaver-V5.1.0.zip and bitweaver-V5.1.0.tar.gz in the current directory
#   ./make-archive.sh V5.1.0 --out DIR          put them in DIR
#   ./make-archive.sh V5.1.0 --lint             also run `php -l` over every PHP file and report syntax errors
#   ./make-archive.sh V5.1.0 --org URL          fetch from somewhere else than https://github.com/lsces
#
# It fetches from the public repositories exactly as a user would (`get-packages.sh --ref TAG`), so building an archive is also a test
# that the tag can be fetched. Legacy test directories are left out (EXCLUDE below). Needs git, python3 and tar; `zip` is not required.
set -eu
TAG=${1:-}; shift || true
OUT=$(pwd); ORG=https://github.com/lsces; LINT=0
while [ $# -gt 0 ]; do case "$1" in --out) OUT=$(cd "$2" && pwd); shift ;; --org) ORG=${2%/}; shift ;; --lint) LINT=1 ;; *) echo "unknown option $1" >&2; exit 2 ;; esac; shift; done
[ -n "$TAG" ] || { sed -n 3,14p "$0" | sed 's/^# \{0,1\}//'; exit 2; }

NAME=bitweaver-$TAG
# directories of tests that a release does not need (kernel/test is old SimpleTest code; the videojs one is the library's own tests)
EXCLUDE="kernel/test themes/js/videojs/test"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
case "$ORG" in /*) WRAP="$ORG/bitweaver" ;; *) WRAP="$ORG/bitweaver.git" ;; esac

echo "== wrapper at $TAG"
git clone -q --depth 1 --branch "$TAG" "$WRAP" "$WORK/$NAME"
cd "$WORK/$NAME"
echo "== base packages and externals at $TAG"
./get-packages.sh --ref "$TAG" --org "$ORG" 2>&1 | grep -v "^warning" | sed 's/^/   /' | grep -E "clone|skipped|fatal|error|Unknown" || true

echo "== checks"
PROBLEMS=0
problem() { echo "   PROBLEM: $*"; PROBLEMS=$((PROBLEMS+1)); }
for f in index.php README.md LICENSE packages.txt get-packages.sh config/index.php storage/README; do [ -e "$f" ] || problem "missing $f"; done
BASE=$(grep -v '^#' packages.txt | awk 'NF && ($2=="core" || $2=="default"){print $1}')
for n in $BASE; do [ -d "$n" ] || problem "package $n was not fetched"; done
for n in $(grep -v '^#' packages.txt | awk 'NF && $2=="optional"{print $1}'); do [ -d "$n" ] && problem "optional package $n is in the base"; done
for e in adodb smarty htmlpurifier; do [ -d "externals/$e" ] || problem "externals/$e was not fetched"; done
[ -f externals/adodb/adodb.inc.php ] || problem "externals/adodb/adodb.inc.php missing"
[ -f externals/smarty/src/Smarty.php ] || problem "externals/smarty/src/Smarty.php missing"
# what each checkout is at, then drop the git metadata
for d in $BASE externals/adodb externals/smarty externals/htmlpurifier; do
  [ -d "$d/.git" ] || continue
  at=$(git -C "$d" describe --tags --exact-match 2>/dev/null || echo "NOT AT A TAG ($(git -C "$d" rev-parse --short HEAD))")
  case "$d" in externals/htmlpurifier) want=v4.19.0 ;; *) want=$TAG ;; esac
  [ "$at" = "$want" ] || problem "$d is at $at, expected $want"
done
find . -name .git -prune -exec rm -rf {} +
for x in $EXCLUDE; do rm -rf "./$x"; done
# repository and tool housekeeping files a download does not need (the third-party libraries under externals/ are left as their authors ship them)
find . -not -path './externals/*' \( -name .gitignore -o -name .gitattributes -o -name .hgignore -o -name .hgtags -o -name .cvsignore -o -name .php-cs-fixer.php -o -name .editorconfig -o -name .github \) -prune -exec rm -rf {} +
[ -z "$(find . -name .git | head -1)" ] || problem "git metadata left behind"

if [ "$LINT" = 1 ]; then
  echo "== php -l over every PHP file"
  # php -l checks ONE file per call, and a failing file must not stop the rest: one call per file, several at a time
  bad=$(find . -name '*.php' -not -path './externals/*' -print0 | xargs -0 -n 1 -P 6 sh -c 'php -d xdebug.mode=off -l "$1" 2>&1 | grep -v "^No syntax errors" | grep -v "^$" | grep -v "^Stack trace" | grep -v "^#0" ; true' _ | head -40)
  if [ -n "$bad" ]; then echo "$bad" | sed 's/^/   /'; problem "PHP syntax errors above"; else echo "   no syntax errors"; fi
fi

echo "== packing"
cd "$WORK"
python3 -I - "$NAME" "$OUT/$NAME.zip" <<'PY'
import os, sys, zipfile, stat
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
tar -czf "$OUT/$NAME.tar.gz" "$NAME"
for f in "$OUT/$NAME.zip" "$OUT/$NAME.tar.gz"; do printf '   %-32s %6s MB\n' "$(basename "$f")" "$(( $(stat -c %s "$f") / 1048576 ))"; done
echo "   files: $(find "$NAME" -type f | wc -l)  dirs at top: $(ls -d "$NAME"/*/ | wc -l)"
echo
[ "$PROBLEMS" = 0 ] && echo "No problems found." || echo "$PROBLEMS problem(s) found - see above."
exit 0
