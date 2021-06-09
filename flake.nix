{
  description = "Use Base16 themes and templates in home-manager";

  inputs = {
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";
    flake-compat.url = "github:edolstra/flake-compat";
    flake-compat.flake = false;
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { flake-utils, nixpkgs, ...}@inputs:
  flake-utils.lib.eachDefaultSystem (system:
  let pkgs = nixpkgs.legacyPackages.${system}; in
  rec {
    devShell = pkgs.mkShell {
      buildInputs = with pkgs; [
        bash
        curl
        nix-prefetch-git
        yq
        jq
      ];
    };
  }) //
  {
    hmModule = import ./module.nix inputs;
  };
}
