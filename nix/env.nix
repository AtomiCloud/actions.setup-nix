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
    action_docs
  ];

  releaser = [
    sg
  ];

}
