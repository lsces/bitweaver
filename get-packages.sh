#!/bin/bash
#
# Fetch bitweaver packages into this checkout. Every package is its own repository (this wrapper does not use
# git submodules), and a site needs only some of them - see packages.txt for the groups:
#
#   ./get-packages.sh                      core + the default content packages (wiki, fisheye) + the external libraries
#   ./get-packages.sh blogs search         ... plus these, and whatever they declare they need
#   ./get-packages.sh --core-only          just the core
#   ./get-packages.sh --all                every package
#   ./get-packages.sh --list               show the groups and exit
#
# Options:  --ref REF    a branch or tag to fetch (default master). Releases are tagged with the same name in every
#                        package repository, so --ref V5.1.0 fetches one consistent set.
#           --full       full history (default is a shallow clone, enough to run a site)
#           --update     fast-forward packages that are already here instead of skipping them
#           --org URL    where the package repositories are (default https://github.com/lsces; a local path works)
#
# Nothing is overwritten: a package directory that exists is skipped (or fast-forwarded with --update).
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
ORG=https://github.com/lsces
REF=master
DEPTH="--depth 1"
UPDATE=0; ALL=0; CORE_ONLY=0; LIST=0
WANT=()

while [ $# -gt 0 ]; do
  case "$1" in
    --ref)       REF=$2; shift ;;
    --full)      DEPTH="" ;;
    --update)    UPDATE=1 ;;
    --org)       ORG=${2%/}; shift ;;
    --all)       ALL=1 ;;
    --core-only) CORE_ONLY=1 ;;
    --list)      LIST=1 ;;
    -h|--help)   sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*)          echo "Unknown option: $1 (see --help)" >&2; exit 2 ;;
    *)           WANT+=("$1") ;;
  esac
  shift
done

declare -A GROUP NEEDS
ORDER=()
while read -r name group needs; do
  [ -z "${name:-}" ] && continue
  case "$name" in \#*) continue ;; esac
  needs=${needs%%#*}                 # trailing comment
  GROUP[$name]=$group; NEEDS[$name]=$needs; ORDER+=("$name")
done < "$HERE/packages.txt"

if [ "$LIST" = 1 ]; then
  for g in core default optional; do
    printf '%-9s' "$g"; for n in "${ORDER[@]}"; do [ "${GROUP[$n]}" = "$g" ] && printf ' %s' "$n"; done; echo
  done
  exit 0
fi

declare -A CHOSEN
CHOSEN_ORDER=()
add() {
  local n=$1
  [ -n "${GROUP[$n]:-}" ] || { echo "Unknown package: $n (see ./get-packages.sh --list)" >&2; exit 2; }
  [ -n "${CHOSEN[$n]:-}" ] && return
  CHOSEN[$n]=1; CHOSEN_ORDER+=("$n")
  for d in ${NEEDS[$n]}; do add "$d"; done
}
for n in "${ORDER[@]}"; do
  case "${GROUP[$n]}" in
    core)    add "$n" ;;
    default) [ "$CORE_ONLY" = 0 ] && add "$n" || true ;;
    optional) [ "$ALL" = 1 ] && add "$n" || true ;;
  esac
done
for n in "${WANT[@]}"; do add "$n"; done

url() { case "$ORG" in /*) echo "$ORG/$1" ;; *) echo "$ORG/$1.git" ;; esac; }

fetch() {   # fetch DIR URL REF
  local dir=$1 src=$2 ref=$3
  if [ -d "$HERE/$dir/.git" ]; then
    if [ "$UPDATE" = 1 ]; then
      echo "  update   $dir"; git -C "$HERE/$dir" pull --ff-only -q || echo "    (not fast-forwardable, left as it is)"
    else
      echo "  present  $dir"
    fi
  elif [ -e "$HERE/$dir" ]; then
    echo "  skipped  $dir (exists and is not a git checkout)"
  else
    echo "  clone    $dir  <- $src ($ref)"
    mkdir -p "$(dirname "$HERE/$dir")"
    git clone -q $DEPTH --branch "$ref" "$src" "$HERE/$dir"
  fi
}

echo "Packages (${REF}):"
for n in "${CHOSEN_ORDER[@]}"; do fetch "$n" "$(url "$n")" "$REF"; done

echo "External libraries (externals/):"
# ADOdb and Smarty are patched forks tagged with each release, like the packages; HTMLPurifier is upstream's, pinned by its own tag.
if [ "$REF" = master ]; then
  fetch externals/adodb        https://github.com/lsces/ADOdb.git          v5.22.11-lsc
  fetch externals/smarty       https://github.com/lsces/smarty.git         master
  fetch externals/htmlpurifier https://github.com/ezyang/htmlpurifier.git  master
else
  fetch externals/adodb        https://github.com/lsces/ADOdb.git          "$REF"
  fetch externals/smarty       https://github.com/lsces/smarty.git         "$REF"
  fetch externals/htmlpurifier https://github.com/ezyang/htmlpurifier.git  v4.19.0
fi

echo
echo "Done. Next: point a web root at this directory (a site symlinks the packages it needs) and run the installer in install/."
