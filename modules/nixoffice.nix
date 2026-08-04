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
  resolve = import ../lib/resolve.nix { inherit lib; };

  mkGroup = what: table: lib.mkOption {
    type = lib.types.listOf (lib.types.enum (lib.attrNames table));
    default = [ ];
    description = "Which ${what}. Available: ${lib.concatStringsSep ", " (lib.attrNames table)}.";
  };

  # Each resolved entry carries the catalogue KEY it was selected by. Without it an entry has no
  # identity of its own -- only its per-channel package names -- so anything reporting about a
  # selection has to pick one of those names to report it BY, and every channel is nullable. That
  # is how `unavailableOnNixos` came to filter on `arch != null`: it reported the pacman name, so
  # it could only report entries that had one, and a Flatpak-only entry with no nixpkgs attribute
  # (the exact case the option exists for) fell out of its own warning silently.
  withName = group: table: map (k: table.${k} // { name = k; }) group;

  selected = lib.flatten [
    (withName cfg.suite cat.suite)
    (withName cfg.authoring cat.authoring)
    (withName cfg.editors cat.editors)
    (withName cfg.viewers cat.viewers)
    (withName cfg.apps cat.apps)
  ];
in
{
  options.nixoffice = {
    suite = mkGroup "office suites" cat.suite;
    authoring = mkGroup "authoring and typesetting tools" cat.authoring;
    editors = mkGroup "prose editors" cat.editors;
    viewers = mkGroup "document viewers" cat.viewers;
    apps = mkGroup "documents-adjacent applications" cat.apps;

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

    aurPackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = ''
        Selections that live in the AUR rather than an official repo, kept SEPARATE because
        `pacman -S` cannot resolve them -- it fails the whole transaction with "target not found",
        which takes the rest of the converge down with it. Wire them to the AUR side:

          nixarch.packages.aur = config.nixoffice.aurPackages;

        With no `aurUser` configured the reconciler skips them with a warning, which is the right
        failure mode: the packages stay as they are and nothing else breaks.
      '';
    };

    flatpakApps = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      readOnly = true;
      description = ''
        Selections whose only delivery is Flatpak, as `{ id; remoteName; remoteUrl; }`.

        Id and remote travel TOGETHER rather than as two lists, because "the remote" is not
        always Flathub and a bare id cannot say where it came from -- a consumer that assumes
        Flathub installs the wrong app or fails outright. A caller wanting only ids:
        `map (a: a.id) config.nixoffice.flatpakApps`.

        Nothing here installs them: Flatpak is neither pacman nor nixpkgs, so the host wires
        these to whatever runs `flatpak install`.
      '';
    };

    unavailableOnNixos = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = ''
        Selections with no nixpkgs equivalent, surfaced rather than silently dropped, named by
        their catalogue key -- the one identity every selection has regardless of which delivery
        channels it does or does not carry.
      '';
    };
  };

  # The four resolutions are ../lib/resolve.nix's, not written out here, so ../checks/default.nix
  # can drive them with fixture tables containing entry shapes the real catalogue does not happen
  # to have. See that file's own header for the bug that distinction is not hypothetical about.
  config = {
    nixoffice.want = selected;
    nixoffice.archPackages = resolve.archPackages selected;
    nixoffice.aurPackages = resolve.aurPackages selected;
    nixoffice.flatpakApps = resolve.flatpakApps selected;
    nixoffice.unavailableOnNixos = resolve.unavailableOnNixos selected;
  };
}
