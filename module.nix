{ lix, versionSuffix ? "" }:
{ pkgs, config, ... }:
{
  nixpkgs.overlays = [ (import ./overlay.nix { inherit lix versionSuffix; }) ];
}
