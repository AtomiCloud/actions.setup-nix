{ pkgs, atomi, pkgs-2505 }:
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
    nix-2505 = (
      with pkgs-2505;
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
nix-2505 //
atomipkgs
