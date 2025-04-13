{ pkgs, packages }:
with packages;
{
  minimal = [
    pls
    git
    atomiutils
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
