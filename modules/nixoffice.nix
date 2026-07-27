#
# nixoffice — the documents half of a workstation, declared.
#
# SCOPE, stated as a test rather than a list: this module owns what a PERSON CONSUMES VISUALLY.
# A suite you click around in, a typesetter whose output you read, an editor you write prose in,
# a viewer you open a PDF with. Anything you only ever script against is nixdev's, however
# document-shaped it looks -- pypdf and pdfplumber are libraries, not documents.
#
# That test is worth stating because "office" otherwise expands until it means "files", and a
# module that means everything constrains nothing.
{ config, lib, ... }:
let
  cfg = config.nixoffice;
  cat = import ../lib/tools.nix { };

  mkGroup = what: table: lib.mkOption {
    type = lib.types.listOf (lib.types.enum (lib.attrNames table));
    default = [ ];
    description = "Which ${what}. Available: ${lib.concatStringsSep ", " (lib.attrNames table)}.";
  };

  selected = lib.flatten [
    (map (k: cat.suite.${k}) cfg.suite)
    (map (k: cat.authoring.${k}) cfg.authoring)
    (map (k: cat.editors.${k}) cfg.editors)
    (map (k: cat.viewers.${k}) cfg.viewers)
  ];
in
{
  options.nixoffice = {
    suite = mkGroup "office suites" cat.suite;
    authoring = mkGroup "authoring and typesetting tools" cat.authoring;
    editors = mkGroup "prose editors" cat.editors;
    viewers = mkGroup "document viewers" cat.viewers;

    want = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      readOnly = true;
      internal = true;
      description = "Resolved entries; the contract a platform backend consumes.";
    };

    archPackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = "Selections as pacman names, for the host's own reconciler: nixarch.packages.pacman = config.nixoffice.archPackages;";
    };

    unavailableOnNixos = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = "Selections with no nixpkgs equivalent, surfaced rather than silently dropped.";
    };
  };

  config = {
    nixoffice.want = selected;
    nixoffice.archPackages = lib.unique (map (t: t.arch) selected);
    nixoffice.unavailableOnNixos =
      lib.unique (map (t: t.arch) (lib.filter (t: t.nixpkgs == null) selected));
  };
}
