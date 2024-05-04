{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  inputs.lix = {
    url = "git+ssh://git@git.lix.systems/lix-project/lix.git";
    flake = false;
  };
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.flakey-profile.url = "github:lf-/flakey-profile";

  outputs = inputs@{ self, nixpkgs, lix, flake-utils, flakey-profile, ... }:
    let versionSuffix = "pre${builtins.substring 0 8 lix.lastModifiedDate}-${lix.shortRev}";
    in {
      inherit inputs;
      nixosModules.default = import ./module.nix { inherit lix versionSuffix; };
      overlays.default = import ./overlay.nix { inherit lix versionSuffix; };
    } // flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
        };
      in
      {
        inherit pkgs;
        packages = {
          default = pkgs.nixVersions.nix_2_18;
          inherit (pkgs) nix-doc nix-eval-jobs;
        };

        packages.system-profile = import ./system-profile.nix { inherit pkgs flakey-profile; };

        nixosTests = pkgs.recurseIntoAttrs (pkgs.callPackage ./test-nixos.nix { lix-module = self.nixosModules.default; });

        checks = {
          inherit (self.nixosTests.${system}) it-builds;
          inherit (self.packages.${system}) default nix-eval-jobs;
        };
      });
}
