---
title: Codebase Structure
---

## Overview

```py title="Codebase Structure"
📁 homelab/
├── 📁 docs/
├── 📁 flake/             # flake profiles
│   ├── 📄 checks.nix
│   ├── 📄 devshell.nix
│   ├── 📄 hosts.nix
│   ├── 📄 pre-commit.nix
│   └── 📄 treefmt.nix
├── 📁 flake-modules/     # flake modules
├── 📁 lib/
├── 📁 nixos/             # NixOS profiles
├── 📁 nixos-modules/     # NixOS modules
├── 📁 pkgs/              # Nix packages
│   ├── 📁 dev-packages/
│   ├── 📁 rke2/
│   └── 📄 dnsfmt.nix
├── 📁 secrets/           # GitOps secrets
│   ├── 📁 hosts/
│   │   └── 📄 <host>.yaml
│   └── 📁 sources/
│       └── 📄 <source>.yaml
├── 📁 k8s/               # Kubernetes manifests
│   ├── 📁 <component>/
│   └── 📁 applications/
├── 📁 terraform/         # Terraform modules
│   └── 📁 <module>/
└── 📄 flake.nix
```

This repository is a monorepo for my homelab.
It follows the infrastructure as code (IaC) and GitOps paradigms.
It contains 3 kinds of configurations:

| Kind       | What does it manage?                         |
| ---------- | -------------------------------------------- |
| Nix        | NixOS, devshell, packages, ...               |
| Kubernetes | Monitoring, storage and various services ... |
| Terraform  | DNS, Clouds, ...                             |

This documentation will explain the guidelines for code organization.

## Nix Profiles and Modules

Nixpkgs provides a declarative, type-safe, reusable and composable [Module System].
It can be used to configure flakes, NixOSs and home-manager configurations.

We further divide NixOS modules into two categories: **profiles** and **modules** to clarify their usage.

| Category     | Usage                         | Side Effects       | Auto Imported      |
| ------------ | ----------------------------- | ------------------ | ------------------ |
| **profiles** | apply a set of configurations | :heavy_check_mark: | :x:                |
| **modules**  | provide more options          | :x:                | :heavy_check_mark: |

Here're some rules

1.  You should place folders for profiles and modules in the root directory of this repo.
    They should be named in the form of `<type>/` and `<type>-module/`,
    where `<type>` is the module types in kebab-case.

    | Type    | Provider       | Where to search built-in options?                                                  | Usage                 | Module Flake Outputs |
    | ------- | -------------- | ---------------------------------------------------------------------------------- | --------------------- | -------------------- |
    | `flake` | [flake-parts]  | [flake-parts built in - flake-parts](https://flake.parts/options/flake-parts.html) | devshell, checks, ... | `flakeModules`       |
    | `nixos` | [nixpkgs]      | [NixOS Search - Options](https://search.nixos.org/options)                         | NixOSs                | `nixosModules`       |
    | `home`  | [home-manager] | [Home Manager - Option Search](https://home-manager-options.extranix.com/)         | home environment      | `homeModules`        |

    We may add more module types in the future.

2.  You can use file hierarchy to manage modules and profiles.

    <div class="grid cards" markdown>

    ```text title="From"
    ├─ foo/
    │  ├─ bar
    │  │  ├─ default.nix
    │  │  └─ util.nix
    │  ├─ baz.nix
    │  └─ baz-data.json
    ├─ _internal/
    │  └─ foo.nix
    └─ bar.nix
    ```

    ```nix title="To"
    {
      foo = {
        bar = <...>;
        baz = <...>;
      };
      bar = <...>;
    }
    ```

    </div>

    In short, any file or directory that starts with `_` or does not end with `.nix` is ignored. `default.nix` in a directory stops further directory traversal.

3.  Modules are exported as flake outputs.
    Most of them are exported in `flake/modules.nix`,
    except for flake modules, which are exported in `flake.nix` to avoid circular dependencies.

4.  Profiles can be extended using the `extend` method.
    This allows composing multiple profiles into a single profile.
    You can check `flake/hosts.nix` for an example.

5.  Profiles can be parameterized, which enables different configurations in different deployments.
    For example, the nixos profile `system.disko` is parameterized by machine-specific options like `device` and `swapSize`.
    There parameters should be declared under the `profiles.<profile-full-path>` option to avoid conflicts.

## Nix Packages

This repository also provides some Nix packages in `pkgs/`.
They are not managed in the form of profiles and modules.

One notable package is `devPackages.scripts`.
It contains some Python scripts, which are installed in devshell in editable mode.

## Kubernetes Manifests

Kubernetes manifests are managed in the `k8s/` directory.

# Terraform Modules

Terraform modules are managed in the `terraform/` directory.

[Module System]: https://nixos.org/manual/nixpkgs/stable/#module-system
[flake-parts]: https://github.com/hercules-ci/flake-parts
[nixpkgs]: https://github.com/NixOS/nixpkgs
[home-manager]: https://github.com/nix-community/home-manager
