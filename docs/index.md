---
title: Codebase Structure
---

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

## Nix Codebase Structure

### Profiles and Modules

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

    | Type    | Provider       | Where to search built-in options?                                                  | Usage                       |
    | ------- | -------------- | ---------------------------------------------------------------------------------- | --------------------------- |
    | `flake` | [flake-parts]  | [flake-parts built in - flake-parts](https://flake.parts/options/flake-parts.html) | manage flake Configurations |
    | `nixos` | [nixpkgs]      | [NixOS Search - Options](https://search.nixos.org/options)                         | manage NixOS configurations |
    | `home`  | [home-manager] | [Home Manager - Option Search](https://home-manager-options.extranix.com/)         | manage user environments    |

    We may add more module types in the future.

2.  You can use file hierarchy to manage modules and profiles.
    `lib/` provides several helper functions to map a directory of Nix files into an attribute list.

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

    Here's the rules for profile and module discovery.
    1.  Files and directories starting with `_` are ignored.
    2.  Files not ending with `.nix` are ignored.
    3.  `default.nix` in a directory stops further directory traversal.

3.  Profiles can be parameterized, which enables different configurations for multiple deployments.
    For example, the nixos profile `system.disko` is parameterized by `device` and `swapSize`,
    since these options are machine-specific.
    There parameters should be declared under the `profiles.<profile-full-path>` option to avoid conflicts.

[Module System]: https://nixos.org/manual/nixpkgs/stable/#module-system
[flake-parts]: https://github.com/hercules-ci/flake-parts
[nixpkgs]: https://github.com/NixOS/nixpkgs
[home-manager]: https://github.com/nix-community/home-manager
