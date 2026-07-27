# NixOS backend — installs via environment.systemPackages.
{ config, lib, pkgs, ... }:
let
  cfg = config.nixoffice;
  named = lib.filter (t: t.nixpkgs != null) cfg.want;
  resolves = t: lib.hasAttrByPath (lib.splitString "." t.nixpkgs) pkgs;
in
{
  imports = [ ./nixoffice.nix ];
  config = {
    environment.systemPackages =
      map (t: lib.getAttrFromPath (lib.splitString "." t.nixpkgs) pkgs) (lib.filter resolves named);
    warnings =
      lib.optional (cfg.unavailableOnNixos != [ ])
        "nixoffice: no nixpkgs equivalent for: ${lib.concatStringsSep ", " cfg.unavailableOnNixos}"
      ++ lib.optional (lib.any (t: !(resolves t)) named)
        "nixoffice: nixpkgs attribute missing for: ${lib.concatStringsSep ", " (map (t: t.nixpkgs) (lib.filter (t: !(resolves t)) named))}. Fix lib/tools.nix rather than pinning around it.";
  };
}
