{ lix, versionSuffix ? "" }:
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

  lixPkg = (final.callPackage (lix + "/package.nix") {
    build-release-notes = false;
    versionSuffix = "-lix${versionSuffix}";
    boehmgc-nix = boehmgc-patched;
  }).overrideAttrs {
    # Note: load-bearing version override. Nixpkgs does version detection to determine
    # what commands and whatnot we support, so tell Nixpkgs that we're 2.18 (ish).
    version = "2.18.3-lix${versionSuffix}";
  };
in
{
  # used for things that one wouldn't necessarily want to update, but we
  # nevertheless shove it in the overlay and fixed-point it in case one *does*
  # want to do that.
  lix-sources = import ./npins;

  nixVersions = prev.nixVersions // rec {
    # FIXME: do something less scuffed
    nix_2_18 = lixPkg;
    stable = nix_2_18;
    nix_2_18_upstream = prev.nixVersions.nix_2_18;
  };

  nix-eval-jobs = (prev.nix-eval-jobs.override {
    # lix
    nix = final.nixVersions.nix_2_18;
  }).overrideAttrs (old: {
    # FIXME: should this be patches instead?
    src = final.lix-sources.nix-eval-jobs;

    mesonBuildType = "debugoptimized";

    ninjaFlags = old.ninjaFlags or [ ] ++ [ "-v" ];
  });

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

  nix-init = prev.nix-init.override {
    nix = final.nixVersions.nix_2_18_upstream;
  };

  nurl = prev.nurl.override {
    nix = final.nixVersions.nix_2_18_upstream;
  };
}
