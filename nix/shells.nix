{ pkgs, packages, env, shellHook }:
with env;
{
  default = pkgs.mkShell {
    buildInputs = minimal ++ lint;
    inherit shellHook;
  };
  ci = pkgs.mkShell {
    buildInputs = minimal ++ lint;
    inherit shellHook;
  };
  releaser = pkgs.mkShell {
    buildInputs = releaser;
    inherit shellHook;
  };
}
