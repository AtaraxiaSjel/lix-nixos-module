{
  # fixme: use the forgejo address
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  inputs.lix = {
    url = "git+ssh://gerrit.lix.systems:2022/lix";
    flake = false;
  };
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.flake-compat.url = "git+ssh://git@git.lix.systems/lix-project/flake-compat";

  outputs = { self, nixpkgs, lix, flake-utils, ... }: {
    nixosModules.default = import ./module.nix { inherit lix; };
    overlays.default = import ./overlay.nix { inherit lix; };
  } // flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ self.overlays.default ];
      };
    in
    {
      inherit pkgs;
      packages.default = pkgs.nixVersions.nix_2_18;
      packages.nix-doc = pkgs.nix-doc;
    });
}
