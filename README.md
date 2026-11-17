# Spectro Cloud Palette packs

Custom add-on packs for Spectro Cloud Palette. Each pack set comes with scripts to build and validate it.

## Packs

| Directory | Packs | What they deploy |
|---|---|---|
| [`packs/vdura`](packs/vdura/README.md) | `vdura-panfs-csi` 1.2.5, `kernel-module-management` 2.7.0 | The VDURA PanFS CSI driver, plus the Kernel Module Management operator that loads the PanFS kernel module on client nodes |

## Layout

Each directory under `packs/` stands on its own:

| Path | Contents |
|---|---|
| `packs/<name>-<version>/` | The Palette pack: `pack.json`, `values.yaml`, `README.md`, `logo.png`, and `charts/*.tgz` |
| `charts-src/` | Source for helper or wrapper charts that the packs include |
| `scripts/build.sh` | Rebuilds the chart archives from pinned upstream tags and writes uploadable pack archives to `dist/`, which git ignores |
| `scripts/validate.sh` | Offline checks: pack structure, `helm lint` and `helm template` with the pack values, and image lists. It never contacts a cluster |

## Tools

The scripts need `git`, `helm`, `yq` (mikefarah v4), `jq`, and `tar`. `crane` is optional and used by `validate.sh --images` to confirm the images exist. Publishing to an OCI pack registry needs `oras`.

## Using a pack

1. Run `scripts/build.sh`, then `scripts/validate.sh`, in the pack set's directory.
2. Push the archives in `dist/` to an OCI pack registry that Palette uses.
3. Add the packs to a cluster profile and fill in the required values.

Each pack set's README has the exact commands, the profile layer order, and the values to set. Each pack's own README lists its prerequisites and parameters.
