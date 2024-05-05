# this is a custom pinning tool, written because npins doesn't have narHash
# compatible output for git inputs, and also doesn't support the Nix immutable
# tarball protocol
let
  pins = builtins.fromJSON (builtins.readFile ./pins.json);
  fetchPin = args@{ kind, ... }:
    if kind == "git" then
      builtins.fetchGit
        {
          url = args.url;
          ref = args.ref;
          rev = args.rev;
          narHash = args.nar_hash;
        }
    else if kind == "tarball" then
      builtins.fetchTarball
        {
          url = args.locked_url;
          sha256 = args.nar_hash;
        } else builtins.throw "unsupported input type ${kind}";
in
builtins.mapAttrs (_: fetchPin) pins
