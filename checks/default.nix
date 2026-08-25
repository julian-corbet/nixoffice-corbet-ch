# checks/default.nix
#
# EVAL-TIME checks. Two halves, deliberately:
#
#   1. ../lib/resolve.nix driven with FIXTURE entry tables — every branch of the channel
#      resolution, including entry shapes the real catalogue does not contain.
#   2. ../modules/nixoffice.nix evaluated against the REAL catalogue — that the option surface is
#      actually wired to those functions, and that the selections declared today resolve the way
#      the catalogue's own comments claim.
#
# Half 1 is why the resolution was split out of the module at all. `unavailableOnNixos` shipped
# with a filter that could not report a Flatpak-only entry: it named entries by their pacman
# package, so it excluded entries that had none, which is precisely the population the option is
# for. Every entry in ../lib/tools.nix has a nixpkgs name, so the broken and fixed versions return
# the same empty list against it — no amount of testing through the real catalogue distinguishes
# them. The `flatpakOnlyNoNixpkgs` fixture below is that missing input, and it is the one check
# here that fails against the old implementation.
#
# NON-VACUITY, verified rather than asserted: reverting `unavailableOnNixos` to its old filter
# (`t.arch != null && t.nixpkgs == null`, mapping `t.arch`) fails
# `resolve/unavailable-reports-a-flatpak-only-entry` — the entry drops out of the result entirely.
# Reverting the fixed `withName` alone fails it differently, on the missing `name` attribute. A
# check that survives both is testing nothing about this bug.
{ pkgs }:
let
  lib = pkgs.lib;
  resolve = import ../lib/resolve.nix { inherit lib; };
  cat = import ../lib/tools.nix { };

  check = name: ok: detail: { inherit name ok detail; };

  # ── Fixtures: one entry per shape the resolution must distinguish ──────────────────────────
  # `name` is present on all of them because the module attaches the catalogue key before calling
  # resolve; a fixture without it would be testing a shape the module never produces.
  repoApp = { name = "repoapp"; arch = "repoapp"; nixpkgs = "repoapp"; };
  aurApp = { name = "aurapp"; arch = "aurapp"; aur = true; nixpkgs = "aurapp"; };
  bothChannels = { name = "both"; arch = "both"; nixpkgs = "both"; flatpak = "org.example.Both"; };
  flatpakOnly = { name = "flatonly"; arch = null; nixpkgs = "flatonly"; flatpak = "org.example.FlatOnly"; };
  ownRemote = {
    name = "ownremote";
    arch = null;
    nixpkgs = "ownremote";
    flatpak = "com.example.OwnRemote";
    flatpakRemote = { name = "example"; url = "https://example.com/repo/example.flatpakrepo"; };
  };
  # The shape ../lib/tools.nix has no instance of, and the reason this file exists.
  flatpakOnlyNoNixpkgs = { name = "noNixpkgs"; arch = null; nixpkgs = null; flatpak = "org.example.NoNixpkgs"; };

  all = [ repoApp aurApp bothChannels flatpakOnly ownRemote flatpakOnlyNoNixpkgs ];

  # ── The real catalogue, evaluated through the module ───────────────────────────────────────
  evalMod = extraConfig: (lib.evalModules {
    modules = [ ../modules/nixoffice.nix extraConfig ];
  }).config;

  live = evalMod {
    nixoffice = {
      suite = [ "onlyoffice" ];
      authoring = [ "typst" "quarto" "pandoc" ];
      editors = [ "ghostwriter" "retext" "obsidian" ];
      viewers = [ "papers" "zathura" "xournalpp" ];
      apps = [ "diebahn" ];
    };
  };
  empty = evalMod { };

  results = [
    # ── resolve: pacman vs AUR ──────────────────────────────────────────────────────────────
    (check "resolve/arch-excludes-aur-entries"
      (resolve.archPackages all == [ "repoapp" "both" ])
      "got: ${builtins.toJSON (resolve.archPackages all)}")

    (check "resolve/aur-holds-only-aur-entries"
      (resolve.aurPackages all == [ "aurapp" ])
      "got: ${builtins.toJSON (resolve.aurPackages all)}")

    # A null pacman name must never reach a package list -- `pacman -S` would be handed a literal
    # "null" and fail the whole transaction, taking every other package in the converge with it.
    (check "resolve/arch-never-emits-a-null"
      (!(builtins.elem null (resolve.archPackages all))
        && !(builtins.elem null (resolve.aurPackages all)))
      "arch: ${builtins.toJSON (resolve.archPackages all)} aur: ${builtins.toJSON (resolve.aurPackages all)}")

    # ── resolve: Flatpak is last resort, not a parallel channel ─────────────────────────────
    (check "resolve/flatpak-skips-entries-that-have-a-pacman-name"
      (!(lib.any (a: a.id == "org.example.Both") (resolve.flatpakApps all)))
      "got: ${builtins.toJSON (resolve.flatpakApps all)}")

    (check "resolve/flatpak-takes-entries-with-no-pacman-name"
      (lib.any (a: a.id == "org.example.FlatOnly") (resolve.flatpakApps all))
      "got: ${builtins.toJSON (resolve.flatpakApps all)}")

    # ── resolve: the remote travels with the id, and is not assumed ─────────────────────────
    (check "resolve/defaults-to-flathub-when-no-remote-is-named"
      (lib.any
        (a: a.id == "org.example.FlatOnly"
          && a.remoteName == "flathub"
          && a.remoteUrl == "https://flathub.org/repo/flathub.flatpakrepo")
        (resolve.flatpakApps all))
      "got: ${builtins.toJSON (resolve.flatpakApps all)}")

    (check "resolve/uses-an-entrys-own-remote-when-it-names-one"
      (lib.any
        (a: a.id == "com.example.OwnRemote"
          && a.remoteName == "example"
          && a.remoteUrl == "https://example.com/repo/example.flatpakrepo")
        (resolve.flatpakApps all))
      "got: ${builtins.toJSON (resolve.flatpakApps all)}")

    # The other direction of the same property: an entry with its own remote must not ALSO be
    # claimed for Flathub. A resolution that added every known remote to every app would pass the
    # check above and still be wrong.
    (check "resolve/an-own-remote-entry-is-not-also-attributed-to-flathub"
      (!(lib.any (a: a.id == "com.example.OwnRemote" && a.remoteName == "flathub")
        (resolve.flatpakApps all)))
      "got: ${builtins.toJSON (resolve.flatpakApps all)}")

    # ── resolve: unavailableOnNixos — the regression this file exists for ───────────────────
    (check "resolve/unavailable-reports-a-flatpak-only-entry"
      (resolve.unavailableOnNixos all == [ "noNixpkgs" ])
      "got: ${builtins.toJSON (resolve.unavailableOnNixos all)}")

    (check "resolve/unavailable-reports-the-catalogue-key-not-a-package-name"
      (resolve.unavailableOnNixos [ flatpakOnlyNoNixpkgs ] == [ "noNixpkgs" ]
        && resolve.unavailableOnNixos [ flatpakOnlyNoNixpkgs ] != [ "org.example.NoNixpkgs" ])
      "got: ${builtins.toJSON (resolve.unavailableOnNixos [ flatpakOnlyNoNixpkgs ])}")

    (check "resolve/unavailable-ignores-entries-that-do-have-a-nixpkgs-name"
      (resolve.unavailableOnNixos [ repoApp bothChannels flatpakOnly ownRemote ] == [ ])
      "got: ${builtins.toJSON (resolve.unavailableOnNixos [ repoApp bothChannels flatpakOnly ownRemote ])}")

    # ── module: the option surface is wired to those functions ──────────────────────────────
    (check "module/diebahn-resolves-to-its-flatpak-id-on-flathub"
      (live.nixoffice.flatpakApps == [
        { id = "de.schmidhuberj.DieBahn"; remoteName = "flathub"; remoteUrl = "https://flathub.org/repo/flathub.flatpakrepo"; }
      ])
      "got: ${builtins.toJSON live.nixoffice.flatpakApps}")

    # diebahn has no pacman name at all -- if it ever appeared in either package list, the
    # reconciler would be handed a null and fail the entire converge.
    (check "module/diebahn-is-in-no-package-list"
      (!(builtins.elem null live.nixoffice.archPackages)
        && !(builtins.elem null live.nixoffice.aurPackages))
      "arch: ${builtins.toJSON live.nixoffice.archPackages} aur: ${builtins.toJSON live.nixoffice.aurPackages}")

    # onlyoffice's pacman name is `onlyoffice-bin`, NOT `onlyoffice` -- selections are catalogue
    # keys, package lists are package names, and this is the check that they are not the same set.
    (check "module/selection-keys-are-not-package-names"
      (builtins.elem "onlyoffice-bin" live.nixoffice.archPackages
        && !(builtins.elem "onlyoffice" live.nixoffice.archPackages))
      "got: ${builtins.toJSON live.nixoffice.archPackages}")

    # The Arch `zathura` package is only the viewer shell. Selecting the catalogue's PDF reader
    # must resolve to its MuPDF backend, which depends on and brings in that shell, rather than
    # producing an installed application that cannot open the document it was selected to read.
    (check "module/zathura-resolves-to-a-working-arch-pdf-viewer"
      (builtins.elem "zathura-pdf-mupdf" live.nixoffice.archPackages
        && !(builtins.elem "zathura" live.nixoffice.archPackages))
      "got: ${builtins.toJSON live.nixoffice.archPackages}")

    (check "module/every-live-selection-has-a-nixpkgs-name"
      (live.nixoffice.unavailableOnNixos == [ ])
      "got: ${builtins.toJSON live.nixoffice.unavailableOnNixos}")

    # ── module: selecting nothing produces nothing, not a default ───────────────────────────
    (check "module/empty-selection-resolves-to-empty-lists"
      (empty.nixoffice.want == [ ]
        && empty.nixoffice.archPackages == [ ]
        && empty.nixoffice.aurPackages == [ ]
        && empty.nixoffice.flatpakApps == [ ])
      "want: ${builtins.toJSON empty.nixoffice.want}")

    # ── the catalogue's own shape, so a future edit cannot silently break the above ─────────
    # Every entry must carry a `nixpkgs` key (possibly null) and, if it has no `arch`, a
    # `flatpak` id -- an entry with neither is deliverable by nothing and would resolve to
    # silence on every plane.
    (check "catalogue/no-entry-is-undeliverable"
      (let
        entries = lib.concatMap lib.attrValues [ cat.suite cat.authoring cat.editors cat.viewers cat.apps ];
        undeliverable = lib.filter (t: (t.arch or null) == null && (t.flatpak or null) == null && (t.nixpkgs or null) == null) entries;
      in undeliverable == [ ])
      "catalogue has entries with no channel at all")
  ];

  failed = lib.filter (r: !r.ok) results;
in
pkgs.runCommand "nixoffice-eval-checks"
{
  passthru.results = results;
} (
  if failed == [ ]
  then "echo '${toString (builtins.length results)} checks passed' > $out"
  else ''
    echo "FAILED:"
    ${lib.concatMapStringsSep "\n" (r: ''echo "  ${r.name}: ${r.detail}"'') failed}
    exit 1
  ''
)
