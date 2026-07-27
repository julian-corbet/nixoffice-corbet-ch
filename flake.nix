{
  description = "nixoffice — the documents half of a workstation: suites, typesetting, prose editors and viewers";

  # NO INPUTS. Options and a name table; pkgs comes from the consumer's evaluation.

  outputs = { self }: {
    nixosModules.nixoffice = ./modules/nixoffice.nix;
    nixosModules.default = ./modules/nixos.nix;
    nixosModules.install = ./modules/nixos.nix;

    systemManagerModules.nixoffice = ./modules/arch.nix;
    systemManagerModules.default = ./modules/arch.nix;

    lib.catalogue = import ./lib/tools.nix { };
  };
}
