#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl git gnugrep gnused yq-go nurl go

# shellcheck shell=bash
# copy from https://github.com/NixOS/nixpkgs/blob/master/pkgs/applications/networking/cluster/rke2/update-script.sh

set -x -eu -o pipefail

MINOR_VERSION="${1:?Must provide a minor version number, like '26', as the only argument}"

WORKDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)

RELEASE_CHANNEL_DATA=$(curl -sS --fail https://update.rke2.io/v1-release/channels | yq ".data[]")
LATEST_TAG_NAME=$(yq -p=json "select(.id == \"v1.$MINOR_VERSION\") | .latest" <<<"$RELEASE_CHANNEL_DATA")

RKE2_VERSION=${LATEST_TAG_NAME/v/}
RKE2_COMMIT=$(curl -sS --fail "https://api.github.com/repos/rancher/rke2/git/refs/tags/${LATEST_TAG_NAME}" | yq '.object.sha')

PREFETCH_META=$(nix-prefetch-url --unpack --print-path "https://github.com/rancher/rke2/archive/refs/tags/${LATEST_TAG_NAME}.tar.gz")
STORE_HASH="$(nix --extra-experimental-features nix-command hash to-sri --type sha256 "${PREFETCH_META%%$'\n'*}")"
STORE_PATH="${PREFETCH_META##*$'\n'}"

cd "${STORE_PATH}"
# Used in scripts/version.sh
# shellcheck disable=SC2034
GITHUB_ACTION_TAG=${LATEST_TAG_NAME}
# shellcheck disable=SC2034
DRONE_COMMIT=${RKE2_COMMIT}

set +u
# shellcheck disable=SC1091
source scripts/version.sh
set -u

ETCD_BUILD=$(grep "images.DefaultEtcdImage" scripts/build-binary | sed 's/.*-\(build[0-9]*\)$/\1/')
ETCD_VERSION="${ETCD_VERSION}-${ETCD_BUILD}"
cd "${WORKDIR}"

FAKE_HASH="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

# Get sha256sums for amd64 and arm64
SHA256_AMD64=$(curl -L "https://github.com/rancher/rke2/releases/download/v${RKE2_VERSION}/sha256sum-amd64.txt")
SHA256_ARM64=$(curl -L "https://github.com/rancher/rke2/releases/download/v${RKE2_VERSION}/sha256sum-arm64.txt")
# Merge both sha256sums in a single variable, one entry per line
SHA256_SUMS="$SHA256_AMD64\n$SHA256_ARM64"
# Get a list of images archives that are assets of this release, one entry (name and download_url) per line
IMAGES_ARCHIVES=$(curl "https://api.github.com/repos/rancher/rke2/releases/tags/v${RKE2_VERSION}" |
  # Filter the assets by name, discard .txt files and legacy image archives (e.g. rke2-images.linux-arm64.tar.gz)
  jq -r '.assets[] | select(.name | test("^rke2-images-.*\\.tar\\.")) | "\(.name) \(.browser_download_url)"')
# Iterate over all lines of IMAGES_ARCHIVES, pick the appropriate sha256, and create a JSON file
# that can be imported by builder.nix
while read -r name url; do
  sha256=$(grep "$name" <<<"$SHA256_SUMS" | cut -d ' ' -f 1)
  # Remove the rke2 prefix and replace all dots in $name with hyphens
  clean_name=$(sed -e "s/^rke2-//" -e "s/\./-/g" <<<"$name")
  jq --null-input --arg name "$clean_name" \
    --arg url "$url" \
    --arg sha256 "$sha256" \
    '{$name: {"url": $url, "sha256": $sha256}}'
done <<<"${IMAGES_ARCHIVES}" | jq --slurp 'reduce .[] as $item ({}; . * $item)' >"${WORKDIR}/images-versions.json"

cat <<EOF >"${WORKDIR}/versions.nix"
{
  rke2Version = "${RKE2_VERSION}";
  rke2Commit = "${RKE2_COMMIT}";
  rke2TarballHash = "${STORE_HASH}";
  rke2VendorHash = "${FAKE_HASH}";
  k8sImageTag = "${KUBERNETES_IMAGE_TAG}";
  etcdVersion = "${ETCD_VERSION}";
  pauseVersion = "${PAUSE_VERSION}";
  ccmVersion = "${CCM_VERSION}";
  dockerizedVersion = "${DOCKERIZED_VERSION}";
  helmJobVersion = "${KLIPPERHELM_VERSION}";
  imagesVersions = with builtins; fromJSON (readFile ./images-versions.json);
}
EOF

PKGS_ROOT="$(git rev-parse --show-toplevel)/pkgs"
RKE2_VENDOR_HASH=$(nurl -e "(import $PKGS_ROOT {}).rke2.goModules")
if [ -n "${RKE2_VENDOR_HASH:-}" ]; then
  sed -i "s#${FAKE_HASH}#${RKE2_VENDOR_HASH}#g" "${WORKDIR}/versions.nix"
else
  echo "Update failed. 'RKE2_VENDOR_HASH' is empty."
  exit 1
fi
