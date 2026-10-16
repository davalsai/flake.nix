{
  description = "University development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";
  };

  outputs =
    inputs@{ nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      perSystem = { pkgs, ... }: {
        formatter = pkgs.nixfmt-tree;
        devShells.default = import ./shell.nix {
          inherit pkgs;
        };
      };

      systems = import inputs.systems;
    };
}
