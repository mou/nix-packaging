{
  description = "Nix packages for yamldiff and diffnest, built from source at pinned release tags";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1.*.tar.gz";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    utils,
  }: let
    # Package builders, independent of the target system. Exposed as an overlay
    # so downstream flakes can consume them with either
    #   overlays = [ inputs.nix-packaging.overlays.default ];  # then pkgs.yamldiff
    # or
    #   inputs.nix-packaging.packages.${system}.yamldiff
    #
    # The pinned version/srcHash/vendorHash live in each package file and stay
    # `.override`-able at the call site.
    overlay = final: _prev: {
      yamldiff = final.callPackage ./pkgs/yamldiff/package.nix {};
      diffnest = final.callPackage ./pkgs/diffnest/package.nix {};
    };
  in
    {
      overlays.default = overlay;
    }
    // utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [overlay];
      };
    in {
      # No `default` on purpose: these are two unrelated tools, so there is no
      # honest default. Use `.#yamldiff` / `.#diffnest` explicitly.
      packages = {inherit (pkgs) yamldiff diffnest;};

      apps = {
        yamldiff = {
          type = "app";
          program = "${pkgs.yamldiff}/bin/yamldiff";
          meta.description = pkgs.yamldiff.meta.description;
        };
        diffnest = {
          type = "app";
          program = "${pkgs.diffnest}/bin/diffnest";
          meta.description = pkgs.diffnest.meta.description;
        };
      };

      # Makes `nix flake check` actually build both packages and run their
      # upstream test suites, rather than just evaluating the flake.
      checks = {inherit (pkgs) yamldiff diffnest;};

      formatter = pkgs.alejandra;

      # Tooling for bumping the pinned tags and formatting this repo; none of
      # it needs to be installed system-wide.
      devShells.default = pkgs.mkShell {
        packages = with pkgs; [
          alejandra
          nurl
          nix-update
          nix-prefetch-git
        ];
      };
    });
}
