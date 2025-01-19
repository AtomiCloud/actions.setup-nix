# Setup AtomiCloud's Nix Action

Setup AtomiCloud CI Nix (Compatible with Namespace)

# Get Started

Instruction

```yaml
name: Example Workflow
on: push
jobs:
  Test:
    runs-on: ubuntu-latest
    steps:
      # change this
      - uses: AtomiCloud/actions.setup-nix@v1.0.0
```

<!-- prettier-ignore-start -->
<!-- action-docs-inputs -->
## Inputs

| parameter | description | required | default |
| --- | --- | --- | --- |
| namespacelabs | Using Namespace Lab's runners | `false` | true |
| checkout | Whether to checkout the repository | `false` | true |
| short-length | length for short values | `false` | 7 |
<!-- action-docs-inputs -->

<!-- action-docs-outputs -->

<!-- action-docs-outputs -->

<!-- action-docs-runs -->
## Runs

This action is a `composite` action.
<!-- action-docs-runs -->

<!-- prettier-ignore-end -->
