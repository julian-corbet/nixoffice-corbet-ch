# Arch backend — publishes the list; the host reconciler installs it.
#   nixarch.packages.pacman = config.nixoffice.archPackages;
{ ... }:
{
  imports = [ ./nixoffice.nix ];
}
