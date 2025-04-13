{ pkgs, atomi, pkgs-2411 }:
let
  all = {
    atomipkgs = (
      with atomi;
      {
        inherit
          atomiutils
          action_docs
          pls
          sg;
      }
    );
    nix-2411 = (
      with pkgs-2411;
      {
        inherit
          git
          infisical

          # lint
          treefmt
          gitlint
          shellcheck;
      }
    );

  };
in
with all;
nix-2411 //
atomipkgs
