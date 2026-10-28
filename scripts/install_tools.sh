#!/usr/bin/env bash
# Verified upstream Linux/amd64 release archives. No curl-to-shell execution.
set -euo pipefail
if [[ "$(uname -s)-$(uname -m)" != "Linux-x86_64" ]]; then
  echo 'This installer is for Linux x86_64 CI; install matching tools manually elsewhere.' >&2
  exit 1
fi
target="${1:?supply a tool directory}"
mkdir -p "$target"
target="$(cd "$target" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
  https://github.com/terraform-linters/tflint/releases/download/v0.65.0/tflint_linux_amd64.zip -o tflint.zip
printf '%s  %s\n' d4c545ed2e29d6338604b586f34f544f380f70f243aa72f7b484713835eaec61 tflint.zip | sha256sum -c -
unzip -q tflint.zip -d "$target"
curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
  https://github.com/rhysd/actionlint/releases/download/v1.7.12/actionlint_1.7.12_linux_amd64.tar.gz -o actionlint.tar.gz
printf '%s  %s\n' 8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8 actionlint.tar.gz | sha256sum -c -
tar -xzf actionlint.tar.gz -C "$target" actionlint
curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
  https://kind.sigs.k8s.io/dl/v0.33.0/kind-linux-amd64 -o kind
printf '%s  %s\n' aee6151561422756b764a4ae28e7f44cda5af5a9eead3cc9985112b1de8d8e0d kind | sha256sum -c -
install -m 0755 kind "$target/kind"
curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
  https://dl.k8s.io/release/v1.37.0/bin/linux/amd64/kubectl -o kubectl
printf '%s  %s\n' 6129359f4e1f3848a5572ccb0b26cf28b8ca08cef38c95a765b2f64a2c961a2f kubectl | sha256sum -c -
install -m 0755 kubectl "$target/kubectl"
