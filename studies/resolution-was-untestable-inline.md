# A bug survived because its only test input didn't exist

**Finding:** when a module's logic can only be driven through a fixed data table, that table's
gaps become blind spots no amount of test thoroughness closes. Splitting the logic out so it can
be driven with fixtures is not test scaffolding — it is what makes a whole class of bug
*expressible* as a test at all.

## The bug

`nixoffice.unavailableOnNixos` reports selections that have no nixpkgs equivalent, so a NixOS host
warns instead of silently installing less than was declared. It shipped as:

```nix
unavailableOnNixos = lib.unique (map (t: t.arch)
  (lib.filter (t: t.arch != null && t.nixpkgs == null) selected));
```

It reported entries by their **pacman package name**. An entry with no pacman name has no such
name to report, so the filter excluded it with `t.arch != null` — which is defensible in isolation
(otherwise the list would contain a literal `null`) and wrong in aggregate: a Flatpak-only entry
with no nixpkgs attribute is precisely the population the option exists to describe, and it was
the one shape the option could not report.

## Why no test written against the catalogue could have caught it

Every entry in `lib/tools.nix` has a nixpkgs name. Against that table the broken filter and the
correct one both return `[ ]` — identically, for every selection that can be expressed. The inputs
that distinguish them are not in the catalogue and, being a catalogue rather than a fixture set,
were never going to be: it holds what is actually wanted on a real host, not one instance of each
shape the code must handle.

The option types make this airtight rather than merely likely. Each group is
`listOf (enum (attrNames table))` — a selection can only ever name a catalogue key, so no
consumer, and no test, can introduce an entry the table does not already contain.

## The fix that mattered

Not the filter — the seam. `lib/resolve.nix` now holds the four channel resolutions as pure
functions of a list of entries, and `checks/default.nix` drives them with fixture tables carrying
every shape, including `{ arch = null; nixpkgs = null; flatpak = "..."; }`. Verified non-vacuous:
restoring the old filter fails `resolve/unavailable-reports-a-flatpak-only-entry` and
`resolve/unavailable-reports-the-catalogue-key-not-a-package-name`, both with `got: []`.

The filter itself then becomes obvious — gate on the missing nixpkgs attribute and nothing else,
since which other channels an entry carries says nothing about whether NixOS can install it.

## The generalisable part

**Report by identity, never by an attribute that is allowed to be absent.** The root cause was
naming entries by a package name; every delivery channel is independently nullable, so no channel
can serve as identity. Entries now carry the catalogue key they were selected by, which is the one
thing every entry has.

The same smell reads as a checklist item elsewhere: any `map (t: t.<field>)` over a filtered set
where `<field>` is nullable is either dropping members or emitting nulls, and the filter that
prevents the second usually causes the first.
