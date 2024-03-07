{ lix }:
{ pkgs, config, ... }:
{
  nixpkgs.overlays = [ (import ./overlay.nix { inherit lix; }) ];
}
