{ nixos, lix-module }:
let
  configs = {
    it-builds = nixos ({ ... }: {
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
}
