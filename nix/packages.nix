{ pkgs, atomi, pkgs-2305, pkgs-feb-23-24 }:
let
  all = {
    atomipkgs = (
      with atomi;
      {
        inherit
          infisical
          action_docs
          pls
          sg;
      }
    );
    nix-2305 = (
      with pkgs-2305;
      { }
    );
    feb-23-24 = (
      with pkgs-feb-23-24;
      {
        inherit
          coreutils
          git
          bash

          # lint
          treefmt
          gitlint
          shellcheck;
      }
    );
  };
in
with all;
nix-2305 //
feb-23-24 //
atomipkgs
