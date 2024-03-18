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
      (builtins.path { path = lix + "/boehmgc-traceable_allocator-public.diff"; name = "boehmgc-traceable_allocator-public.patch"; })
    ];
  })
  );
in
{
  nixVersions = prev.nixVersions // rec {
    # FIXME: do something less scuffed
    nix_2_18 = (prev.nixVersions.nix_2_18.override { boehmgc = boehmgc-patched; }).overrideAttrs (old: {
      src = lix;
      # FIXME: fake version so that nixpkgs will not try to use nix config >_>
      version = "2.18.3-lix";
      VERSION_SUFFIX = "-lix";

      patches = [ ];
      # FIXME: we don't know why this was not being picked up properly when
      # included in nativeCheckInputs.
      nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ final.git ];
    });
    stable = nix_2_18;
    nix_2_18_upstream = prev.nixVersions.nix_2_18;
  };

  # force these onto upstream so we are not regularly rebuilding electron
  prefetch-yarn-deps = prev.prefetch-yarn-deps.override {
    nix = final.nixVersions.nix_2_18_upstream;
  };
  prefetch-npm-deps = prev.prefetch-npm-deps.override {
    nix = final.nixVersions.nix_2_18_upstream;
  };
  nix-prefetch-git = prev.nix-prefetch-git.override {
    nix = final.nixVersions.nix_2_18_upstream;
  };

  nixos-option = prev.nixos-option.override {
    nix = final.nixVersions.nix_2_18_upstream;
  };

  nix-doc = prev.callPackage ./nix-doc/package.nix { withPlugin = false; };
}
