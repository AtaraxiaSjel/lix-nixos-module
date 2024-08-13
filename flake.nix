{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  inputs.lix = {
    url = "https://git.lix.systems/lix-project/lix/archive/main.tar.gz";
    flake = false;
  };
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.flakey-profile.url = "github:lf-/flakey-profile";

  outputs = inputs@{ self, nixpkgs, lix, flake-utils, flakey-profile, ... }:
    let
      lixVersionJson = builtins.fromJSON (builtins.readFile (lix + "/version.json"));
      versionSuffix = nixpkgs.lib.optionalString (!lixVersionJson.official_release)
        "-pre${builtins.substring 0 8 lix.lastModifiedDate}-${lix.shortRev or lix.dirtyShortRev}";
    in
    {
      inherit inputs;
      nixosModules = {
        # Use a locally built Lix
        default = import ./module.nix { inherit lix versionSuffix; };

        # Use Lix from nixpkgs
        lixFromNixpkgs = import ./module.nix { lix = null; };
      };

      overlays = {
        # Use a locally built Lix
        default = import ./overlay.nix { inherit lix versionSuffix; };

        # Use Lix from nixpkgs
        lixFromNixpkgs = import ./overlay.nix { lix = null; };
      };
    } // flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
        };

        linux64BitSystems = [
          "x86_64-linux"
          "aarch64-linux"
        ];

        inherit (pkgs) lib;
      in
      {
        inherit pkgs;
        packages = {
          default = pkgs.nixVersions.nix_2_18;
          inherit (pkgs) nix-doc nix-eval-jobs;
        };

        packages.system-profile = import ./system-profile.nix { inherit pkgs flakey-profile; };

        nixosTests = pkgs.recurseIntoAttrs (pkgs.callPackage ./test-nixos.nix { inherit pkgs; lix-module = self.nixosModules.default; });

        checks = {
          inherit (self.packages.${system}) default nix-eval-jobs;
        } // lib.optionalAttrs (lib.elem system linux64BitSystems) {
          # wrongMajor intentionally not included here since it is expected to fail
          inherit (self.nixosTests.${system}) it-builds;
        };
      });
}
