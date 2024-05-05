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
    ] ++ final.lib.optionals (final.lib.versionOlder o.version "8.2.6") [
      # https://github.com/ivmai/bdwgc/pull/586
      (builtins.path { path = lix + "/boehmgc-traceable_allocator-public.diff"; name = "boehmgc-traceable_allocator-public.patch"; })
    ];
  })
  );

  # This is kind of scary to not override the nix version to pretend to be
  # 2.18 since nixpkgs can introduce new breakage in its Nix unstable CLI
  # usage.
  # https://github.com/nixos/nixpkgs/blob/6afb255d976f85f3359e4929abd6f5149c323a02/nixos/modules/config/nix.nix#L121
  lixPkg = (final.callPackage (lix + "/package.nix") {
    build-release-notes = false;
    versionSuffix = "-lix${versionSuffix}";
    boehmgc-nix = boehmgc-patched;
  });

  inherit (prev) lib;
in
{
  # used for things that one wouldn't necessarily want to update, but we
  # nevertheless shove it in the overlay and fixed-point it in case one *does*
  # want to do that.
  lix-sources = import ./pins.nix;

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

  # support both having and missing https://github.com/NixOS/nixpkgs/pull/304913
  prefetch-npm-deps =
    if (lib.functionArgs prev.prefetch-npm-deps.override) ? nix
    then prev.prefetch-npm-deps.override {
      nix = final.nixVersions.nix_2_18_upstream;
    }
    else prev.prefetch-npm-deps;

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
