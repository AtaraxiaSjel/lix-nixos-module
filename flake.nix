{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  inputs.lix = {
    url = "git+ssh://git@git.lix.systems/lix-project/lix.git";
    flake = false;
  };
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.flake-compat.url = "git+ssh://git@git.lix.systems/lix-project/flake-compat";
  inputs.flakey-profile.url = "https://github.com/lf-/flakey-profile";

  outputs = inputs@{ self, nixpkgs, lix, flake-utils, flakey-profile, ... }: {
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

      packages.system-profile = import ./system-profile.nix { inherit pkgs flakey-profile; };
    });
}
