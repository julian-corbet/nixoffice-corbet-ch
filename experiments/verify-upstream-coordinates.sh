#!/usr/bin/env bash
# Verify every image coordinate in ../lib/applications.nix against the registry that serves it --
# and, with --tags, show what upstream is actually shipping.
#
# WHAT THIS EXISTS TO CATCH. The cluster catalogue names container image REPOSITORIES and
# deliberately no versions at all: a version is a value, supplied by whoever declares a workload. So
# there is nothing here that a Nix evaluation could check. What can go stale is the coordinate
# itself -- a project moves its images to a different registry, publishes under a second name, or
# stops publishing one -- and every one of those is a fact about the world that changes without this
# repository changing.
#
# IT MATTERS MORE HERE THAN IN THE SIBLINGS, for a reason that belongs to this subject rather than
# to registries. Several of these applications RUN SCHEMA MIGRATIONS on first start, against a
# database this repository does not own -- so the version a consumer declares is what decides whether
# a restart is a restart or a migration, and the tag list is the only place to find out what the
# choices are. One of them publishes its tags WITHOUT the leading letter the obvious guess would use,
# and the obvious guess is a four-oh-four rather than an error anybody would recognise.
#
# Reads the coordinates out of the catalogue rather than a second hand-kept list, which is the whole
# reason this is a script and not a checklist.
#
# Usage:
#   ./verify-upstream-coordinates.sh            # every coordinate, reachable or not
#   ./verify-upstream-coordinates.sh --tags 8   # ... and the last eight tags of each
#
# Needs: nix, jq, and skopeo.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
catalogue="$here/../lib/applications.nix"

tags=0
case "${1:-}" in
  --tags) tags="${2:-8}" ;;
  "") ;;
  *) echo "usage: $0 [--tags N]" >&2; exit 2 ;;
esac

have() { command -v "$1" >/dev/null 2>&1; }

for tool in nix jq; do
  have "$tool" || { echo "missing required tool: $tool" >&2; exit 2; }
done
have skopeo || echo "note: skopeo is not installed -- every coordinate will be reported as UNCHECKED"

# group/name/image, flattened out of the catalogue itself. Written with builtins only: the catalogue
# is a plain data file, and pulling nixpkgs in just to reach `lib.concatMap` would make this script
# depend on a channel being configured.
#
# `engines` is skipped rather than special-cased in the loop below: it is the table of ENGINE KINDS,
# which are the things this repository names and refuses to run, so there is no image to check and
# never will be.
rows="$(nix eval --json --file "$catalogue" --apply '
  f:
    let
      cat = f { };
      groups = builtins.filter (g: g != "engines") (builtins.attrNames cat);
      row = g: n: { group = g; name = n; image = cat.${g}.${n}.image; };
    in
    builtins.concatLists
      (map (g: map (row g) (builtins.attrNames cat.${g})) groups)
')" || {
  echo "could not evaluate $catalogue" >&2
  exit 1
}

ok=0; bad=0; unchecked=0

report() { printf '  %-9s %s\n' "$1" "$2"; }

list_tags() {
  # The LAST tags a registry lists. The order is the registry's own and is not sorted here on
  # purpose: imposing an order on tags that are not all versions is how a project's real release
  # line gets hidden behind whatever happens to sort highest.
  skopeo list-tags "docker://$1" 2>/dev/null | jq -r '.Tags[]' | tail -n "$tags" | sed 's/^/            /'
}

check_image() {
  local ref="$1"
  if ! have skopeo; then
    report UNCHECKED "image -> $ref (no skopeo)"; unchecked=$((unchecked + 1)); return
  fi
  if skopeo list-tags "docker://$ref" >/dev/null 2>&1; then
    local n
    n="$(skopeo list-tags "docker://$ref" 2>/dev/null | jq -r '.Tags | length')"
    report OK "image -> $ref ($n tags)"; ok=$((ok + 1))
    [ "$tags" -gt 0 ] && list_tags "$ref"
  else
    report FAIL "image -> $ref (the registry did not answer, or the repository is gone)"
    bad=$((bad + 1))
  fi
}

# Into an array rather than through a pipe: a `while read` on the right-hand side of a pipeline runs
# in a subshell, and every counter incremented in it would be discarded at the end.
mapfile -t parsed < <(printf '%s' "$rows" | jq -c '.[]')

for row in "${parsed[@]}"; do
  group=$(printf '%s' "$row" | jq -r .group)
  name=$(printf '%s' "$row" | jq -r .name)
  image=$(printf '%s' "$row" | jq -r '.image // empty')

  echo "$group.$name"

  if [ -z "$image" ]; then
    report FAIL "no image coordinate is recorded, and every entry here is delivered as one"
    bad=$((bad + 1))
  else
    check_image "$image"
  fi
done

echo
echo "checked: $ok ok, $bad failed, $unchecked unchecked"
echo
echo "A FAIL is not automatically a bug in the catalogue -- a registry that is down looks exactly like"
echo "one that moved. Re-run before changing a coordinate, and change it only for a repository that is"
echo "genuinely gone."
echo
echo "--tags prints the registry's OWN ordering, which is neither chronological nor sorted. Read the"
echo "whole list before concluding anything about what a project is on -- and remember that the tag"
echo "you pick is what decides whether a restart runs a migration."
[ "$bad" -eq 0 ]
