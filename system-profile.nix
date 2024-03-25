{ pkgs, flakey-profile }:
flakey-profile.lib.mkProfile {
  inherit pkgs;
  paths = with pkgs; [
    cacert
    nix
  ];
  name = "system-profile";
  extraSwitchArgs = [ "--profile" "/nix/var/nix/profiles/default" ];
}
