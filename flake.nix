{
  description = "nixoffice — the documents half of a workstation: suites, typesetting, prose editors and viewers";

  inputs = {
    # CHECKS ONLY, the same convention the rest of this family uses. The modules take `pkgs` from
    # whatever evaluation composes them and never reach for this input, so a consumer's closure
    # gains nothing from it — but `checks` needs a real package set to build a derivation in, and
    # a flake cannot conjure one. A consumer following its own nixpkgs here pays nothing either
    # way; unfollowed, this would be a second nixpkgs fetched for a test output.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ];
      pkgsFor = system: nixpkgs.legacyPackages.${system};
    in
    {
      nixosModules.nixoffice = ./modules/nixoffice.nix;
      nixosModules.default = ./modules/nixos.nix;
      nixosModules.install = ./modules/nixos.nix;

      systemManagerModules.nixoffice = ./modules/arch.nix;
      systemManagerModules.default = ./modules/arch.nix;

      lib.catalogue = import ./lib/tools.nix { };
      lib.resolve = import ./lib/resolve.nix { inherit (nixpkgs) lib; };

      # EVAL-TIME checks only — see checks/default.nix's own header for what is under test, and
      # for why the channel resolution had to leave modules/nixoffice.nix before it could be.
      checks = forAllSystems (system: { eval-checks = import ./checks { pkgs = pkgsFor system; }; });

      formatter = forAllSystems (system: (pkgsFor system).nixpkgs-fmt);
    };
}
