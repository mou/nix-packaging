# nix-packaging

A self-contained Nix flake that builds two structured-data diff tools from
source at pinned release tags. Neither is in nixpkgs.

| Package | Upstream | Pinned | What it does |
| --- | --- | --- | --- |
| `yamldiff` | [semihbkgr/yamldiff](https://github.com/semihbkgr/yamldiff) | **v0.3.1** | Structural diff of two YAML documents: colored output, multi-document files, order-insensitive sequences, diffstat. |
| `diffnest` | [sters/diffnest](https://github.com/sters/diffnest) | **v1.7.0** | Diff of structured data files (JSON and YAML, including JSON↔YAML), as a unified diff or a JSON Patch. |

Both are MIT-licensed, pure Go, and built with `CGO_ENABLED=0`.

## Outputs

| Output | What it is |
| --- | --- |
| `packages.<system>.yamldiff` | the `yamldiff` derivation |
| `packages.<system>.diffnest` | the `diffnest` derivation |
| `overlays.default` | adds `pkgs.yamldiff` and `pkgs.diffnest` |
| `apps.<system>.yamldiff` / `.diffnest` | `nix run` entry points |
| `checks.<system>.*` | mirrors `packages`, so `nix flake check` builds both and runs their upstream test suites |
| `devShells.<system>.default` | `alejandra`, `nurl`, `nix-update`, `nix-prefetch-git` for maintaining this repo |
| `formatter.<system>` | `alejandra`, for `nix fmt` |

There is deliberately **no `default`** package or app: these are two unrelated
tools, so name the one you want.

## Use it

### Run without installing

```console
nix run github:mou/nix-packaging#yamldiff -- --help
nix run github:mou/nix-packaging#diffnest -- -h
```

### As a flake input

```nix
{
  inputs.nix-packaging.url = "github:mou/nix-packaging";
  # share your own nixpkgs pin (optional but recommended):
  inputs.nix-packaging.inputs.nixpkgs.follows = "nixpkgs";
}
```

Then either reference the packages directly:

```nix
environment.systemPackages = [
  inputs.nix-packaging.packages.${system}.yamldiff
  inputs.nix-packaging.packages.${system}.diffnest
];
# or, home-manager:
home.packages = [
  inputs.nix-packaging.packages.${system}.yamldiff
  inputs.nix-packaging.packages.${system}.diffnest
];
```

or add the overlay and use the bare names:

```nix
nixpkgs.overlays = [ inputs.nix-packaging.overlays.default ];
# ... then `pkgs.yamldiff` and `pkgs.diffnest` are available everywhere
```

### Ad-hoc install

```console
nix profile install github:mou/nix-packaging#yamldiff
nix profile install github:mou/nix-packaging#diffnest
```

## Shell completions

**`yamldiff` only.** It is built on cobra, so completions are generated from
the binary at build time and installed into the standard locations inside the
package:

- `share/bash-completion/completions/yamldiff.bash`
- `share/zsh/site-functions/_yamldiff`
- `share/fish/vendor_completions.d/yamldiff.fish`

They load **automatically** when `yamldiff` is installed into a profile that
your shell scans at startup — i.e. via NixOS `environment.systemPackages`,
home-manager `home.packages`, or `nix profile install` — provided your shell's
completion system is enabled (`programs.zsh.enable`,
`programs.bash.completion.enable`, `programs.fish.enable`, etc.). No extra
wiring is needed.

> **Note — dev shells:** completions do *not* auto-load when the package is
> merely pulled into a `nix develop` / direnv dev shell. A dev shell only adds
> the binary to `PATH`; it neither extends `$NIX_PROFILES` nor re-runs
> `compinit` after the shell has started. For live completions, install into a
> profile as above, or run `source <(yamldiff completion zsh)` in the shell.

`diffnest` ships **no** completions — it uses Go's standard-library `flag`
package and has no `completion` subcommand to generate them from.

## Bumping a release tag

Each package keeps its three pinned values as default arguments in
`pkgs/<name>/package.nix`, documented inline. To bump:

1. **`version`** — the git tag without the leading `v`.
2. **`srcHash`**:
   ```console
   nix-prefetch-url --unpack \
     https://github.com/semihbkgr/yamldiff/archive/refs/tags/v<version>.tar.gz
   nix hash convert --hash-algo sha256 --to sri <base32-output>
   ```
   (`https://github.com/sters/diffnest/...` for `diffnest`.)
3. **`vendorHash`** — set it to `lib.fakeHash`, run `nix build .#<name>`, and
   copy the `got:` hash from the error into place.

Or let `nix-update` from the dev shell do all three:

```console
nix develop -c nix-update --flake yamldiff
```

You can also override at the call site without editing this repo:

```nix
pkgs.yamldiff.override {
  version    = "0.4.0";
  srcHash    = "sha256-...";
  vendorHash = "sha256-...";
}
```

## Packaging notes

- Both upstreams inject their version via goreleaser `ldflags` **without** a
  leading `v` (`{{.Version}}`), so the flake does the same. `yamldiff --version`
  must print `0.3.1`, not `undefined`; `diffnest -version` must print `1.7.0`,
  not `dev`.
- `yamldiff` carries a second `package main` at `cmd/wasm` behind a
  `js && wasm` build tag. It is listed in `excludedPackages` so it stays out of
  both the build and the test phase, while `cmd` and `pkg/diff` tests still run.
- `diffnest`'s `go.mod` has a `tool golangci-lint` directive, which pulls ~190
  modules the binary never needs into the vendor fetch. Harmless, but it makes
  the first `diffnest-*-go-modules` build noticeably slow.
