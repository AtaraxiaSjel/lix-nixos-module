# Lix NixOS module

See the [official installation guide][install-guide] for details on usage of
release versions.

[install-guide]: https://lix.systems/install/

See the [beta guide][beta-guide] for a setup guide on how to use HEAD:

[beta-guide]: https://wiki.lix.systems/link/1

## What does this do?

This is an overlay wrapped in a NixOS module that will replace CppNix with Lix
in nixpkgs. This is useful so that `nixos-rebuild`, `nix-direnv` and similar
will use Lix.

Optionally, it can build Lix from source.

## Versioning with Lix

The version of this overlay should match the major Lix version, *and* if
running HEAD, it should be the latest available version of the overlay.
Changes breaking the overlay are shamelessly done on HEAD, and we expect people
doing such changes to have prepared corresponding fix commits to make to the
overlay immediately after submitting their changes. If your build randomly
broke when updating HEAD, try updating your overlay.

The version of Lix pinned in this flake's `flake.lock` is a version of Lix
that is expected to work, however if running HEAD, it can be assumed to work
with HEAD as well if both `lix-nixos-module` and `lix` are the latest version.

## Common pitfalls

Various flake frameworks such as flake-parts and snowfall (and possibly Colmena
in the future if they do a similar optimization) manage overlays separately
from NixOS, since they provide `pkgs` pre-imported to NixOS. This saves a
couple of seconds of evaluation time and resources, but it means that the NixOS
option `nixpkgs.overlays` **is completely ignored** on these frameworks.

If you are using such a framework, add `overlays.default` to the overlays list
for said framework.

## Flake structure and usage

The flake here has two inputs of note:
- `nixpkgs`, *which is unused for most people*. It is purely used for `checks`
  in developing `lix-nixos-module` itself.

  The installation instructions make it `follows` to make `flake.lock` less
  confusing, but it is nonetheless unused.
- `lix`, which determines the version of Lix to do source builds for, if doing
  source builds.

These are the most relevant outputs for most people:

- `nixosModules.lixFromNixpkgs` - uses Lix from nixpkgs and installs the
  overlay to use Lix on a NixOS system. This is only useful for a stable
  version of Lix, and cannot be used for running HEAD.
- `nixosModules.default` - uses Lix from source and installs the overlay to use
  Lix on a NixOS system.
- `overlays.lixFromNixpkgs` - overlay to use Lix from nixpkgs in place of Nix.
- `overlays.default` - overlay to use Lix from source in place of Nix.

## Non-flake usage

Import `module.nix` or `overlay.nix` as desired, with the arguments `lix`
(derivation-like attribute set with the Lix sources, or `null` to use Lix from
nixpkgs) and `versionSuffix` (optional string).

It's desirable to also include a `versionSuffix` like the following while
building HEAD from source, to have `nix --version` include date and commit
information. To get such metadata, it depends on which pinning system is in
use, but `builtins.fetchGit` will provide the necessary metadata for the
following to work:

```
versionSuffix = "pre${builtins.substring 0 8 lix.lastModifiedDate}-${lix.shortRev or lix.dirtyShortRev}";
```
