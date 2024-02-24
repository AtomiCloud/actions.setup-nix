{ pkgs, packages }:
with packages;
{
  minimal = [
    pls
    git
    coreutils
  ];

  lint = [
    # core
    treefmt
    gitlint
    shellcheck
    sg
  ];

  releaser = [
    sg
  ];

}
