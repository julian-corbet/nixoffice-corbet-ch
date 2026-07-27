# Checks every non-null nixpkgs attribute in lib/tools.nix resolves.
#   nix-instantiate --eval --strict experiments/validate-nixpkgs-names.nix -A missing   # => [ ]
{ nixpkgs ? <nixpkgs> }:
let
  pkgs = import nixpkgs { config.allowUnfree = true; };
  lib = pkgs.lib;
  cat = import ../lib/tools.nix { };
  all = lib.flatten (map lib.attrValues (lib.attrValues cat));
  named = lib.filter (t: t.nixpkgs != null) all;
in
{
  checked = builtins.length named;
  missing = map (t: t.nixpkgs) (lib.filter (t: !(lib.hasAttrByPath (lib.splitString "." t.nixpkgs) pkgs)) named);
}
