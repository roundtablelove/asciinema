{
  description = "Terminal session recorder";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    nix-seed = {
      url = "github:roundtablelove/nix-seed";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      rust-overlay,
      flake-utils,
      nix-seed,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ (import rust-overlay) ];
        };

        packageToml = (fromTOML (builtins.readFile ./Cargo.toml)).package;
        msrv = packageToml.rust-version;
      in
      {
        packages.default = pkgs.callPackage ./default.nix {
          version = packageToml.version;
          rust = pkgs.rust-bin.stable.latest.minimal;
        };

        # The Nix Seed: a squashfs (Linux) or disk image (macOS) of this
        # flake's build closure -- both devShells (default and msrv) --
        # which CI mounts as /nix/store and builds against offline.
        # flake-utils.lib.eachDefaultSystem only iterates linux and
        # darwin systems, which is what mkSeed supports, so no platform
        # guard is needed here.
        packages.seed = nix-seed.lib.mkSeed {
          inherit pkgs self;
          # seed-ci.yaml only ever `nix develop`s default/msrv -- never
          # `nix build`s packages.default -- so that's deliberately not
          # baked here.
          seedOutputs = [
            "devShells.default"
            "devShells.msrv"
          ];
          # explicit override: the default name would resolve from
          # devShells.default, whose own `.name` is generic ("nix-shell").
          name = "asciinema.seed";
        };

        devShells = pkgs.callPackages ./shell.nix {
          package = self.packages.${system}.default;

          rust = {
            default = pkgs.rust-bin.stable.latest.minimal;
            msrv = pkgs.rust-bin.stable.${msrv}.minimal;
          };
        };

        formatter = pkgs.nixfmt-tree;
      }
    );
}
