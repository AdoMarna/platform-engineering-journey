#!/usr/bin/env bash
# Checks that the Week 0 setup tooling is installed.
# Usage: ./scripts/check-tools.sh
set -uo pipefail

# Required tools: "name|version command"
REQUIRED=(
  "git|git --version"
  "make|make --version | head -n1"
  "docker|docker --version"
  "kind|kind version"
  "k3d|k3d version | head -n1"
  "kubectl|kubectl version --client 2>/dev/null | head -n1"
  "helm|helm version --short"
  "k9s|k9s version --short 2>/dev/null | head -n1"
  "aws|aws --version"
  "python3|python3 --version"
)

# Tools needed later (CI, IaC): missing = warning only
OPTIONAL=(
  "terraform|terraform version | head -n1"
  "tofu|tofu version | head -n1"
  "shellcheck|shellcheck --version | sed -n 2p"
  "hadolint|hadolint --version"
  "trivy|trivy --version | head -n1"
  "gh|gh --version | head -n1"
  "jq|jq --version"
)

GREEN=$'\e[32m'; RED=$'\e[31m'; YELLOW=$'\e[33m'; RESET=$'\e[0m'
missing=0

check() {
  local name=${1%%|*} version_cmd=${1#*|} level=$2
  if command -v "$name" >/dev/null 2>&1; then
    printf '%s✔%s %-11s %s\n' "$GREEN" "$RESET" "$name" "$(eval "$version_cmd" 2>&1 | tr -d '\r')"
  elif [[ $level == required ]]; then
    printf '%s✘%s %-11s missing\n' "$RED" "$RESET" "$name"
    missing=$((missing + 1))
  else
    printf '%s!%s %-11s not found (optional)\n' "$YELLOW" "$RESET" "$name"
  fi
}

echo "== Required tools =="
for t in "${REQUIRED[@]}"; do check "$t" required; done

# kustomize: standalone binary or the one built into kubectl
if command -v kustomize >/dev/null 2>&1; then
  printf '%s✔%s %-11s %s\n' "$GREEN" "$RESET" "kustomize" "$(kustomize version 2>&1)"
elif command -v kubectl >/dev/null 2>&1 && kubectl kustomize --help >/dev/null 2>&1; then
  printf '%s✔%s %-11s %s (via kubectl)\n' "$GREEN" "$RESET" "kustomize" \
    "$(kubectl version --client 2>/dev/null | awk '/Kustomize/ {print $3}')"
else
  printf '%s✘%s %-11s missing\n' "$RED" "$RESET" "kustomize"
  missing=$((missing + 1))
fi

# Under WSL2 Multipass runs on the Windows side: accept multipass, multipass.exe or the default install path
MULTIPASS_WIN="/mnt/c/Program Files/Multipass/bin/multipass.exe"
if command -v multipass >/dev/null 2>&1 || command -v multipass.exe >/dev/null 2>&1; then
  printf '%s✔%s %-11s found\n' "$GREEN" "$RESET" "multipass"
elif [[ -x $MULTIPASS_WIN ]]; then
  printf '%s✔%s %-11s found (not in PATH: %s)\n' "$GREEN" "$RESET" "multipass" "$MULTIPASS_WIN"
else
  printf '%s✘%s %-11s missing\n' "$RED" "$RESET" "multipass"
  missing=$((missing + 1))
fi

# Docker being installed is not enough: kind/k3d need the daemon
if command -v docker >/dev/null 2>&1 && ! docker info >/dev/null 2>&1; then
  printf '%s✘%s %-11s daemon unreachable (try: sudo service docker start)\n' "$RED" "$RESET" "docker"
  missing=$((missing + 1))
fi

echo
echo "== Optional tools =="
for t in "${OPTIONAL[@]}"; do check "$t" optional; done

# A tool gets updates only if a package manager owns it (apt, snap or brew).
# Binaries dropped by hand in /usr/local/bin or ~/.local stay frozen at their version.
update_source() {
  local path
  path=$(readlink -f "$(command -v "$1")")
  if dpkg -S "$path" >/dev/null 2>&1; then
    echo "apt ($(dpkg -S "$path" 2>/dev/null | head -n1 | cut -d: -f1))"
  elif [[ $path == /snap/* ]]; then
    echo "snap"
  elif [[ $path == */linuxbrew/* || $path == */Cellar/* ]]; then
    echo "brew"
  else
    echo "manual:$path"
  fi
}

echo
echo "== Update sources =="
manual=0
for t in "${REQUIRED[@]}" "${OPTIONAL[@]}"; do
  name=${t%%|*}
  command -v "$name" >/dev/null 2>&1 || continue
  src=$(update_source "$name")
  if [[ $src == manual:* ]]; then
    printf '%s!%s %-11s manual install, no auto-update (%s)\n' "$YELLOW" "$RESET" "$name" "${src#manual:}"
    manual=$((manual + 1))
  else
    printf '%s✔%s %-11s %s\n' "$GREEN" "$RESET" "$name" "$src"
  fi
done

# WSL2 without systemd: apt-daily/unattended-upgrades timers never fire
if [[ ! -d /run/systemd/system ]]; then
  printf '%s!%s %-11s no systemd: run "sudo apt update && sudo apt upgrade" yourself\n' "$YELLOW" "$RESET" "apt"
fi

echo
if ((manual > 0)); then
  echo "${YELLOW}${manual} tool(s) won't update 'automatically'.${RESET}"
fi
if ((missing > 0)); then
  echo "${RED}${missing} problem(s) found.${RESET}"
  exit 1
fi
echo "${GREEN}All good.${RESET}"
