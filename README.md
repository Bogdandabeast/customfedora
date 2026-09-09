# customfedora &nbsp; [![bluebuild build badge](https://github.com/bogdandabeast/customfedora/actions/workflows/build.yml/badge.svg)](https://github.com/bogdandabeast/customfedora/actions/workflows/build.yml) [![docs badge](https://github.com/bogdandabeast/customfedora/actions/workflows/docs.yml/badge.svg)](https://bogdandabeast.github.io/customfedora/)

**Docs:** [bogdandabeast.github.io/customfedora](https://bogdandabeast.github.io/customfedora/) — BlueBuild recipes, modules, and live image pipeline (Hugo + Hextra, `site/`). Local: `just docs-serve` → http://localhost:1313 · `hugo --minify --source site` (no Node).

See the [BlueBuild docs](https://blue-build.org/how-to/setup/) for quick setup instructions for setting up your own repository based on this template.

After setup, it is recommended you update this README to describe your custom image.

## Installation

> [!WARNING]  
> [This is an experimental feature](https://www.fedoraproject.org/wiki/Changes/OstreeNativeContainerStable), try at your own discretion.

To rebase an existing atomic Fedora installation to the latest build:

- First rebase to the unsigned image, to get the proper signing keys and policies installed:
```
rpm-ostree rebase ostree-unverified-registry:ghcr.io/bogdandabeast/niri:latest
```
- Reboot to complete the rebase:
  ```
  systemctl reboot
  ```
- Then rebase to the signed image, like so:
```
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/bogdandabeast/niri:latest
```
- Reboot again to complete the installation
  ```
  systemctl reboot
  ```

The `latest` tag will automatically point to the latest build. That build will still always use the Fedora version specified in `recipe.yml`, so you won't get accidentally updated to the next major version.

## ISO

Weekly ISO builds are produced by the [bluebuild-iso workflow](https://github.com/bogdandabeast/customfedora/actions/workflows/iso.yml) (Sundays 07:00 UTC) and published to the [isos release](https://github.com/bogdandabeast/customfedora/releases/tag/isos).

To generate an ISO locally from this recipe:

```bash
sudo bluebuild generate-iso --iso-name niri.iso recipe recipes/recipe.niri.yml
```

Flash the resulting `niri.iso` with [Fedora Media Writer](https://fedoraproject.org/metallivedemo/) and boot it to install. Full instructions: [BlueBuild — Fresh install from an ISO](https://blue-build.org/learn/universal-blue/#fresh-install-from-an-iso).

## Verification

These images are signed with [Sigstore](https://www.sigstore.dev/)'s [cosign](https://github.com/sigstore/cosign). You can verify the signature by downloading the `cosign.pub` file from this repo and running the following command:

```bash
cosign verify --key cosign.pub ghcr.io/bogdandabeast/niri
```
