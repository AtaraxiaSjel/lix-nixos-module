{ lix, versionSuffix ? "" }:
final: prev:
let
  # This is kind of scary to not override the nix version to pretend to be
  # 2.18 since nixpkgs can introduce new breakage in its Nix unstable CLI
  # usage.
  # https://github.com/nixos/nixpkgs/blob/6afb255d976f85f3359e4929abd6f5149c323a02/nixos/modules/config/nix.nix#L121
  lixPackageFromSource = final.callPackage (lix + "/package.nix") ({
    inherit versionSuffix;
  });

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
    }
  );

  inherit (prev) lib;

  csi = builtins.fromJSON ''"\u001b"'';
  orange = "${csi}[35;1m";
  normal = "${csi}[0m";
  warning = ''
    ${orange}warning${normal}: You have the lix overlay included into a nixpkgs import twice,
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
  wrongMajorWarning = ''
    ${orange}warning${normal}: This Lix NixOS module is being built against a Lix with a
    major version (got ${lixPackageToUse.version}) other than the one the
    module was designed for (expecting ${supportedLixMajor}). Some downstream
    packages like nix-eval-jobs may be broken by this. Consider using a
    matching version of the Lix NixOS module to the version of Lix you are
    using.
  '';

  maybeWarnDuplicate = x: if final.lix-overlay-present > 1 then builtins.trace warning x else x;

  versionJson = builtins.fromJSON (builtins.readFile ./version.json);
  supportedLixMajor = lib.versions.majorMinor versionJson.version;
  lixPackageToUse = if lix != null then lixPackageFromSource else prev.lix;
  # Especially if using Lix from nixpkgs, it is plausible that the overlay
  # could be used against the wrong Lix major version and cause confusing build
  # errors. This is a simple safeguard to put in at least something that might be seen.
  maybeWarnWrongMajor = x: if !(lib.hasPrefix supportedLixMajor lixPackageToUse.version) then builtins.trace wrongMajorWarning x else x;

  overlay = override_2_18 // {
    lix-overlay-present = 1;
    # used for things that one wouldn't necessarily want to update, but we
    # nevertheless shove it in the overlay and fixed-point it in case one *does*
    # want to do that.
    lix-sources = import ./pins.nix;

    lix = maybeWarnWrongMajor (maybeWarnDuplicate lixPackageToUse);

    nixVersions = prev.nixVersions // rec {
      nix_2_18 = final.lix;
      stable = nix_2_18;
      nix_2_18_upstream = prev.nixVersions.nix_2_18;
    };

    nix-eval-jobs = (prev.nix-eval-jobs.override {
      # lix
      nix = final.nixVersions.nix_2_18;
    }).overrideAttrs (old:
      let src = final.lix-sources.nix-eval-jobs;
      in {
        version = "2.91.0-lix-${builtins.substring 0 7 src.rev}";

        # FIXME: should this be patches instead?
        inherit src;

        mesonBuildType = "debugoptimized";

        ninjaFlags = old.ninjaFlags or [ ] ++ [ "-v" ];
      }
    );

    nix-doc = prev.callPackage ./nix-doc/package.nix { withPlugin = false; };
  };
in
# Make the overlay idempotent, since flakes passing nixos modules around by
  # value and many other things make it way too easy to include the overlay
  # twice
if (prev ? lix-overlay-present) then { lix-overlay-present = 2; } else overlay
