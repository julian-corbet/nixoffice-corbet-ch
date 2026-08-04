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
    (map (k: cat.apps.${k}) cfg.apps)
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
      description = "Selections with no nixpkgs equivalent, surfaced rather than silently dropped.";
    };
  };

  config = {
    nixoffice.want = selected;
    nixoffice.archPackages = lib.unique (map (t: t.arch) (lib.filter (t: t.arch != null && !(t.aur or false)) selected));
    nixoffice.aurPackages = lib.unique (map (t: t.arch) (lib.filter (t: t.arch != null && (t.aur or false)) selected));
    nixoffice.flatpakApps =
      let flathub = { name = "flathub"; url = "https://flathub.org/repo/flathub.flatpakrepo"; };
      in map
        (t: {
          id = t.flatpak;
          remoteName = (t.flatpakRemote or null).name or flathub.name;
          remoteUrl = (t.flatpakRemote or null).url or flathub.url;
        })
        (lib.filter (t: (t.flatpak or null) != null && (t.arch or null) == null) selected);

    # `arch = null` means no pacman name exists -- those entries are Flatpak's, above, and must
    # not fall through into a package list as a literal "null" or an empty string.
    nixoffice.unavailableOnNixos =
      lib.unique (map (t: t.arch) (lib.filter (t: t.arch != null && t.nixpkgs == null) selected));
  };
}
