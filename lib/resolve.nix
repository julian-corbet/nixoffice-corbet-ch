#
# The channel resolution: pure functions from a list of selected catalogue entries to the
# per-channel outputs a platform backend consumes.
#
# WHY THESE ARE NOT INLINE IN modules/nixoffice.nix, where they lived until now. Inline, the only
# input they could ever be tested against was the REAL catalogue in ./tools.nix -- and a
# catalogue is a table of what happens to be selected today, not a set of fixtures chosen to
# exercise every branch. That gap was not theoretical: `unavailableOnNixos` shipped with a filter
# that could not report a Flatpak-only entry (it named entries by their pacman package, so it had
# to exclude entries that had none -- exactly the shape the option exists for). Every entry in the
# real catalogue has a nixpkgs name, so the broken version and the fixed one produce an identical
# empty list against it. No test written against ./tools.nix could have caught it, at any level of
# thoroughness, because the distinguishing input does not exist there.
#
# Split out, ../checks/default.nix feeds these fixture tables containing exactly the entry shapes
# the catalogue lacks, and the regression is pinned.
#
# EVERY DELIVERY CHANNEL IS INDEPENDENTLY NULLABLE, which is the rule the functions below are
# written around: an entry may have a pacman name and no Flatpak id, a Flatpak id and no pacman
# name, or a nixpkgs attribute and neither. So no channel's package name can serve as the entry's
# IDENTITY -- that is what `name` (the catalogue key it was selected by) is for, and why anything
# REPORTING about an entry reports that rather than one of its package names.
{ lib }:
rec {
  # The default remote. An entry naming no `flatpakRemote` is on Flathub; one that names its own
  # is not, and Threema's desktop client in the sibling nixmsg catalogue is the standing proof
  # that "not on Flathub" is a real case rather than a hypothetical.
  flathub = {
    name = "flathub";
    url = "https://flathub.org/repo/flathub.flatpakrepo";
  };

  # Official-repo pacman names. `aur = true` entries are held back for aurPackages below: `pacman
  # -S` cannot resolve an AUR name and fails the WHOLE transaction on "target not found", taking
  # every other package in the same converge with it.
  archPackages = selected:
    lib.unique (map (t: t.arch)
      (lib.filter (t: (t.arch or null) != null && !(t.aur or false)) selected));

  aurPackages = selected:
    lib.unique (map (t: t.arch)
      (lib.filter (t: (t.arch or null) != null && (t.aur or false)) selected));

  # Flatpak is the channel of LAST resort here, not a parallel one: an entry is Flatpak's only if
  # it has no pacman name at all. Anything with both is installed by the host's own package
  # manager, which is cheaper, updates with the rest of the system, and needs no sandbox.
  #
  # Id and remote travel TOGETHER in each element rather than as two lists a consumer indexes back
  # together -- two lists that must stay in step are two lists that can fall out of step the
  # moment either gains or loses an entry alone.
  flatpakApps = selected:
    map
      (t: {
        id = t.flatpak;
        remoteName = (t.flatpakRemote or null).name or flathub.name;
        remoteUrl = (t.flatpakRemote or null).url or flathub.url;
      })
      (lib.filter (t: (t.flatpak or null) != null && (t.arch or null) == null) selected);

  # Gated on the missing nixpkgs attribute and NOTHING else. Which other channels a selection
  # happens to carry says nothing about whether NixOS can install it, so nothing about them
  # belongs in this filter -- see this file's own header for the bug that reasoning corrects.
  unavailableOnNixos = selected:
    lib.unique (map (t: t.name) (lib.filter (t: (t.nixpkgs or null) == null) selected));
}
