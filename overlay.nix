{ lix, versionSuffix ? "" }:
final: prev:
let
  boehmgc-patched = ((final.boehmgc.override {
    enableLargeConfig = true;
  }).overrideAttrs (o: {
    # cherrypick: boehmgc: disable tests on aarch64-linux
    # https://github.com/NixOS/nixpkgs/pull/309418
    doCheck = !((final.stdenv.isDarwin && final.stdenv.isx86_64) || (final.stdenv.isLinux && final.stdenv.isAarch64));

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

  lixFunctionArgs = builtins.functionArgs (import (lix + "/package.nix"));
  # fix up build-release-notes being required in older versions of Lix.
  lixPackageBuildReleaseNotes =
      if lixFunctionArgs.build-release-notes or true
      then { }
      else { build-release-notes = null; };

  # This is kind of scary to not override the nix version to pretend to be
  # 2.18 since nixpkgs can introduce new breakage in its Nix unstable CLI
  # usage.
  # https://github.com/nixos/nixpkgs/blob/6afb255d976f85f3359e4929abd6f5149c323a02/nixos/modules/config/nix.nix#L121
  lixPkg = final.callPackage (lix + "/package.nix") ({
    versionSuffix = "-lix${versionSuffix}";
    boehmgc-nix = boehmgc-patched;
  } // lixPackageBuildReleaseNotes);

  # These packages depend on Nix features that Lix does not support
  overridelist_2_18 = [
    "attic-client"
    "devenv"
    "nix-du"
    "nix-init"
    "nix-prefetch-git"
    "nixos-option"
    "nurl"
    "prefetch-yarn-deps" # force these onto upstream so we are not regularly rebuilding electron
  ];
  override_2_18 = prev.lib.genAttrs overridelist_2_18 (
    name: prev.${name}.override {
      nix = final.nixVersions.nix_2_18_upstream;
    });

  inherit (prev) lib;

  prefetch-npm-deps-args = lib.functionArgs prev.prefetch-npm-deps.override;

  warning = ''
    warning: You have the lix overlay included into a nixpkgs import twice,
    perhaps due to the NixOS module being included twice, or because of using
    pkgs.nixos and also including it in imports, or perhaps some unknown
    machinations of a complicated flake library.
    This is completely harmless since we have no-op'd the second one if you are
    seeing this message, but it would be a small style improvement to fix
    it :)
    P.S. If you had some hack to fix nixos-option build failures in your
    configuration, that was caused by including an older version of the lix
    overlay twice, which is now mitigated if you see this message, so you can
    delete that.
    P.P.S. This Lix has super catgirl powers.
  '';

  maybeWarnDuplicate = x: if final.lix-overlay-present > 1 then builtins.trace warning x else x;

  overlay = override_2_18 // {
    lix-overlay-present = 1;
    # used for things that one wouldn't necessarily want to update, but we
    # nevertheless shove it in the overlay and fixed-point it in case one *does*
    # want to do that.
    lix-sources = import ./pins.nix;

    nixVersions = prev.nixVersions // rec {
      # FIXME: do something less scuffed
      nix_2_18 = maybeWarnDuplicate lixPkg;
      stable = nix_2_18;
      nix_2_18_upstream = prev.nixVersions.nix_2_18;
    };

    nix-eval-jobs = (prev.nix-eval-jobs.override {
      # lix
      nix = final.nixVersions.nix_2_18;
    }).overrideAttrs (old:
      let src = final.lix-sources.nix-eval-jobs;
      in {
        version = "2.90.0-lix-${builtins.substring 0 7 src.rev}";

        # FIXME: should this be patches instead?
        inherit src;

        mesonBuildType = "debugoptimized";

        ninjaFlags = old.ninjaFlags or [ ] ++ [ "-v" ];
      }
    );

    # support both having and missing https://github.com/NixOS/nixpkgs/pull/304913
    prefetch-npm-deps =
      if (prefetch-npm-deps-args ? nix) || (prefetch-npm-deps-args == {})
      then prev.prefetch-npm-deps.override {
        nix = final.nixVersions.nix_2_18_upstream;
      }
      else prev.prefetch-npm-deps;

    nix-doc = prev.callPackage ./nix-doc/package.nix { withPlugin = false; };
  };
in
  # Make the overlay idempotent, since flakes passing nixos modules around by
  # value and many other things make it way too easy to include the overlay
  # twice
  if (prev ? lix-overlay-present) then { lix-overlay-present = 2; } else overlay
