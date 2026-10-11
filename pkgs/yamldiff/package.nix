# yamldiff — structural diff for YAML documents.
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
#          https://github.com/semihbkgr/yamldiff/archive/refs/tags/v<version>.tar.gz
#        nix hash convert --hash-algo sha256 --to sri <base32-output>
#   2. vendorHash: set it to lib.fakeHash, run `nix build .#yamldiff`, and copy
#      the "got:" hash from the error into place.
{
  lib,
  stdenv,
  buildGoModule,
  fetchFromGitHub,
  installShellFiles,
  version ? "0.3.1",
  srcHash ? "sha256-bruyw4CSdAwHRRh5E3yG9Xf0EcUwQ6JQJat89nRAgv0=",
  vendorHash ? "sha256-JRJxloT5qvEm44jTJefhtDtBmoRgiRRqwyZhTXxAMDU=",
}:
buildGoModule {
  pname = "yamldiff";
  inherit version vendorHash;

  src = fetchFromGitHub {
    owner = "semihbkgr";
    repo = "yamldiff";
    rev = "v${version}";
    hash = srcHash;
  };

  nativeBuildInputs = [installShellFiles];

  env.CGO_ENABLED = 0;

  # Mirror upstream .goreleaser.yaml. Unlike many projects, the injected
  # version carries no leading "v" (goreleaser's {{.Version}} is bare).
  ldflags = [
    "-s"
    "-w"
    "-X github.com/semihbkgr/yamldiff/cmd.buildVersion=${version}"
  ];

  # cmd/wasm is a second `package main` behind a `js && wasm` build tag; it is
  # irrelevant to the CLI and must stay out of both the build and the tests.
  excludedPackages = ["cmd/wasm"];

  # Generate shell completions from the CLI itself (cobra ships a `completion`
  # subcommand). Guarded so it is skipped when cross-compiling, since a
  # foreign-arch binary cannot be executed here.
  postInstall = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    installShellCompletion --cmd yamldiff \
      --bash <($out/bin/yamldiff completion bash) \
      --zsh  <($out/bin/yamldiff completion zsh) \
      --fish <($out/bin/yamldiff completion fish)
  '';

  doCheck = true;

  meta = with lib; {
    description = "Compare YAML documents to clearly identify structural differences";
    homepage = "https://github.com/semihbkgr/yamldiff";
    license = licenses.mit;
    mainProgram = "yamldiff";
    platforms = platforms.unix;
  };
}
