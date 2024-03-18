{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  inputs.lix = {
    url = "git+ssh://git@git.lix.systems/lix-project/lix.git";
    flake = false;
  };
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.flake-compat.url = "git+ssh://git@git.lix.systems/lix-project/flake-compat";

  outputs = inputs@{ self, nixpkgs, lix, flake-utils, ... }: {
    inherit inputs;
    nixosModules.default = import ./module.nix { inherit lix; };
    overlays.default = import ./overlay.nix {
      inherit lix;
      versionSuffix = "pre${builtins.substring 0 8 lix.lastModifiedDate}-${lix.shortRev}";
    };
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
