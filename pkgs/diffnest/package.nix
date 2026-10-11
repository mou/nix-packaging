# diffnest — diff for structured data files (JSON and YAML, cross-format).
#
# Built from source at a pinned release tag. Override any of the three values
# below to build a different tag (see `.override` note in the README).
#
#   version    the git tag, without the leading "v"
#   srcHash    hash of the GitHub source tarball for that tag
#   vendorHash hash of the vendored Go module dependencies
#
# To bump the tag:
#   1. srcHash:
#        nix-prefetch-url --unpack \
#          https://github.com/sters/diffnest/archive/refs/tags/v<version>.tar.gz
#        nix hash convert --hash-algo sha256 --to sri <base32-output>
#   2. vendorHash: set it to lib.fakeHash, run `nix build .#diffnest`, and copy
#      the "got:" hash from the error into place.
{
  lib,
  buildGoModule,
  fetchFromGitHub,
  version ? "1.7.0",
  srcHash ? "sha256-P+d5C/PiTbfwjW+BBqrSPBBH1mlgDDLeNyRynDd8vFY=",
  vendorHash ? "sha256-s5WcWtONOTgvgqPsF9ZsSfT/W4LacfAhkHJYphaYMqQ=",
}:
buildGoModule {
  pname = "diffnest";
  inherit version vendorHash;

  src = fetchFromGitHub {
    owner = "sters";
    repo = "diffnest";
    rev = "v${version}";
    hash = srcHash;
  };

  env.CGO_ENABLED = 0;

  # Mirror upstream .goreleaser.yml. As with yamldiff, the injected version
  # carries no leading "v".
  ldflags = [
    "-s"
    "-w"
    "-X github.com/sters/diffnest/diffnest.Version=${version}"
  ];

  # Upstream go.mod carries a `tool golangci-lint` directive, which drags ~190
  # modules the binary never needs into the vendor fetch. Nothing breaks; the
  # goModules derivation is just large and slow to build the first time.

  doCheck = true;

  # No completions to install: diffnest uses the stdlib `flag` package and has
  # no completion subcommand.

  meta = with lib; {
    description = "Diff tool for structured data files like YAML and JSON";
    homepage = "https://github.com/sters/diffnest";
    license = licenses.mit;
    mainProgram = "diffnest";
    platforms = platforms.unix;
  };
}
