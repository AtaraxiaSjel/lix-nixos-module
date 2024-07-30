{ pkgs, nixos, lix-module }:
let
  pkgs' = import pkgs.path {
    inherit (pkgs) system;
  };
  configs = {
    it-builds = nixos ({ ... }: {
      imports = [ lix-module ];
      documentation.enable = false;
      fileSystems."/".device = "ignore-root-device";
      boot.loader.grub.enable = false;
      system.stateVersion = "24.05";
    });

    # Intentionally provoke the wrong major version.
    # Does assume that the module is one major ahead of the release; the main
    # purpose here is a manual testing fixture.
    wrongMajor = pkgs'.nixos ({ ... }: {
      imports = [ (import ./module.nix { lix = null; }) ];
      documentation.enable = false;
      fileSystems."/".device = "ignore-root-device";
      boot.loader.grub.enable = false;
      system.stateVersion = "24.05";
    });
  };
in
{
  inherit configs;

  it-builds = configs.it-builds.config.system.build.toplevel;
  wrongMajor = configs.wrongMajor.config.system.build.toplevel;
}
