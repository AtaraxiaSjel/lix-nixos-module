{ lix }:
final: prev:
let
  boehmgc-patched = ((final.boehmgc.override {
    enableLargeConfig = true;
  }).overrideAttrs (o: {
    patches = (o.patches or [ ]) ++ [
      # for clown reasons this version is newer than the one in lix, we should
      # fix this and update our nixpkgs pin
      (prev.path + "/pkgs/tools/package-management/nix/patches/boehmgc-coroutine-sp-fallback.patch")

      # https://github.com/ivmai/bdwgc/pull/586
      (lix + "/boehmgc-traceable_allocator-public.diff")
    ];
  })
  );
in
{
  nixVersions = prev.nixVersions // rec {
    # FIXME: do something less scuffed
    nix_2_18 = (prev.nixVersions.nix_2_18.override { boehmgc = boehmgc-patched; }).overrideAttrs (old: {
      src = lix;
      version = "2.18.3-lix";
      VERSION_SUFFIX = "-lix";

      patches = [ ];
    });
    stable = nix_2_18;
  };

  nix-doc = prev.nix-doc.overrideAttrs (old: {
    # for the purposes of nix C++ API for nix-doc, lix is Nix 2.20
    NIX_CFLAGS_COMPILE = [ "-DNIX_2_20_0" ];
  });
}
