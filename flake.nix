{
  description = "nixoffice — where the written work happens, declared: the office applications a fleet runs, and the documents half of a workstation";

  # NO INPUTS FOR CONSUMERS, the same convention the rest of this family uses. The modules take
  # `pkgs`/`config`/`lib` from whatever evaluation composes them and never reach for these inputs, so
  # a consumer's closure gains nothing from them — but `checks` needs a real package set to build a
  # derivation in, and a real renderer and a real app grammar to render the cluster module through,
  # and a flake cannot conjure any of them.
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # The renderer the cluster module defines into. A real input rather than a name in a comment:
    # without it there is no module system to evaluate the cluster side against, and `nix flake
    # check` would pass by checking nothing.
    nixidy = {
      url = "github:arnarg/nixidy";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # THE APP GRAMMAR THIS REPOSITORY CONSUMES. Also checks-only, and that is the point being proven
    # rather than a shortcut: a consumer imports the grammar itself, and this input exists so `nix
    # flake check` can render the cluster module through the REAL grammar and assert the manifests
    # that come out — rather than asserting that a module which merely mentions `nixk3s.apps`
    # evaluates.
    nixk3s = {
      url = "github:julian-corbet/nixk3s-corbet-ch";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixidy.follows = "nixidy";
    };
  };

  outputs = { self, nixpkgs, nixidy, nixk3s }:
    let
      lib = nixpkgs.lib;
      forAllSystems = lib.genAttrs [ "x86_64-linux" "aarch64-linux" ];
      pkgsFor = system: nixpkgs.legacyPackages.${system};
    in
    {
      # The cluster plane: the office applications a fleet runs. Composed into a nixidy environment
      # ALONGSIDE the app grammar, which declares the options this module defines into — see
      # modules/cluster.nix's own header.
      nixidyModules.nixoffice = ./modules/cluster.nix;
      nixidyModules.default = ./modules/cluster.nix;

      # The host plane: the documents half of a workstation.
      nixosModules.nixoffice = ./modules/nixoffice.nix;
      nixosModules.default = ./modules/nixos.nix;
      nixosModules.install = ./modules/nixos.nix;

      systemManagerModules.nixoffice = ./modules/arch.nix;
      systemManagerModules.default = ./modules/arch.nix;

      lib.catalogue = import ./lib/tools.nix { };
      lib.applications = import ./lib/applications.nix { };
      lib.resolve = import ./lib/resolve.nix { inherit (nixpkgs) lib; };
      lib.cluster = ./modules/cluster.nix;

      # `nix flake check` evaluates none of the module outputs on its own, so a green check on this
      # repository without these three files would cover nothing but flake syntax.
      checks = forAllSystems (system:
        let
          pkgs = pkgsFor system;

          # The cluster module, rendered through the real grammar and the real renderer, from the
          # placeholder values in examples/. Building the environment package forces the whole
          # manifest tree.
          env = nixidy.lib.mkEnv {
            inherit pkgs;
            modules = [
              nixk3s.nixidyModules.apps
              nixk3s.nixidyModules.addressing
              self.nixidyModules.nixoffice
              ./examples/all/values.nix
            ];
          };
        in
        {
          # 1. The host catalogue and its resolution, driven with fixture tables containing entry
          # shapes the real catalogue does not have — see checks/default.nix's own header for the
          # bug that distinction is not hypothetical about.
          eval-checks = import ./checks { inherit pkgs; };

          # 2. The cluster module's own resolution and every guard it makes, in BOTH directions: an
          # empty surface renders nothing at all, a declared one resolves, and each refusal gets a
          # declaration that must be refused — including the ones that are unknown options or
          # missing enum values rather than guards, which is the whole claim of the design.
          cluster-eval = import ./checks/cluster-eval.nix {
            inherit pkgs lib nixidy;
            appsModule = nixk3s.nixidyModules.apps;
            addressingModule = nixk3s.nixidyModules.addressing;
            clusterModule = self.nixidyModules.nixoffice;
          };

          # 3. The manifests this surface actually PRODUCED, parsed and asserted field by field. A
          # module that type-checks can still point an application at an engine it does not speak,
          # mount a corpus where the software does not write, or render a document host pattern that
          # matches nothing — none of that is an eval error and all of it is an outage.
          cluster-render = import ./checks/cluster-render.nix { inherit pkgs lib env; };
        });

      formatter = forAllSystems (system: (pkgsFor system).nixpkgs-fmt);
    };
}
