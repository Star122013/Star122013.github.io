{
  description = "flake for nix devShells";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    git-hooks-nix = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, treefmt-nix, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        treefmt-nix.flakeModule
        inputs.git-hooks-nix.flakeModule
      ];

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      perSystem =
        { pkgs, config, ... }:
        {
          pre-commit.settings.hooks = {
            treefmt = {
              enable = true;
              # 避免 --fail-on-change 因文件修改时间变化而误报
              settings.fail-on-change = false;
              settings.formatters = with pkgs; [
                biome
                typstyle
              ];
            };
            deadnix.enable = true;
            statix.enable = true;
            end-of-file-fixer.enable = true;
            check-merge-conflicts.enable = true;
          };

          devShells.default = pkgs.mkShell {
            name = "Astro devShell";
            buildInputs = with pkgs; [
              astro-language-server
              nodejs-slim
              nodejs-slim.npm
              pnpm
              typescript
              typst
              tinymist
            ];
            inputsFrom = [ config.pre-commit.devShell ];
          };
        };
    };
}
