{ formatter, pre-commit-lib, packages }:
pre-commit-lib.run {
  src = ./.;

  # hooks
  hooks = {
    # formatter
    treefmt = {
      enable = true;
      excludes = [
        ".*Changelog.+(MD|md)"
      ];
    };

    # linters From https://github.com/cachix/pre-commit-hooks.nix
    shellcheck = {
      enable = false;
    };

    a-action-docs = {
      enable = true;
      name = "Action Docs";
      description = "Generate action documentation";
      entry = "${packages.action_docs}/bin/action-docs --no-banner -u";
      language = "system";
      pass_filenames = false;
      files = "^.*action\\.(yaml|yml)$";
    };

    a-config-sync = {
      enable = true;
      name = "Sync configurations to helm charts";
      entry = "${packages.bash}/bin/bash scripts/local/config-sync.sh";
      files = "config/app/.*\\.yaml";
      language = "system";
      pass_filenames = false;
    };

    a-infisical = {
      enable = true;
      name = "Secrets Scanning";
      description = "Scan for possible secrets";
      entry = "${packages.infisical}/bin/infisical scan . --verbose";
      language = "system";
      pass_filenames = false;
    };

    a-infisical-staged = {
      enable = true;
      name = "Secrets Scanning (Staged files)";
      description = "Scan for possible secrets in staged files";
      entry = "${packages.infisical}/bin/infisical scan git-changes --staged -v";
      language = "system";
      pass_filenames = false;
    };

    a-gitlint = {
      enable = true;
      name = "Gitlint";
      description = "Lints git commit message";
      entry = "${packages.gitlint}/bin/gitlint --staged --msg-filename .git/COMMIT_EDITMSG";
      language = "system";
      pass_filenames = false;
      stages = [ "commit-msg" ];
    };


    a-enforce-gitlint = {
      enable = true;
      name = "Enforce gitlint";
      description = "Enforce atomi_releaser conforms to gitlint";
      entry = "${packages.sg}/bin/sg gitlint";
      files = "(atomi_release\\.yaml|\\.gitlint)";
      language = "system";
      pass_filenames = false;
    };

    a-shellcheck = {
      enable = true;
      name = "Shell Check";
      entry = "${packages.shellcheck}/bin/shellcheck";
      files = ".*sh$";
      language = "system";
      pass_filenames = true;
    };

    a-enforce-exec = {
      enable = true;
      name = "Enforce Shell Script executable";
      entry = "${packages.coreutils}/bin/chmod +x";
      files = ".*sh$";
      language = "system";
      pass_filenames = true;
    };

  };

  settings = {
    treefmt = {
      package = formatter;
    };
  };
}
