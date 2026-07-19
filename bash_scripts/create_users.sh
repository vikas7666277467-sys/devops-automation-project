#!/usr/bin/env bash
set -euo pipefail

# This script is safe to run repeatedly. Jenkins package installation may also
# create the jenkins account; useradd --system keeps the pre-install account suitable.
create_privileged_user() {
  local username="$1"
  local home_directory="$2"

  if ! id "$username" >/dev/null 2>&1; then
    useradd --user-group --create-home --home-dir "$home_directory" --shell /bin/bash "$username"
  fi

  usermod --home "$home_directory" --shell /bin/bash "$username"
  install -d -o "$username" -g "$username" -m 0750 "$home_directory"
  usermod --append --groups sudo "$username"
  install -d -m 0750 /etc/sudoers.d
  printf '%s ALL=(ALL) NOPASSWD:ALL\n' "$username" > "/etc/sudoers.d/$username"
  chmod 0440 "/etc/sudoers.d/$username"
  visudo --check --file="/etc/sudoers.d/$username"
}

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script as root or with sudo." >&2
  exit 1
fi

create_privileged_user ansible /home/ansible
# Debian's Jenkins package uses /var/lib/jenkins as the service account home.
create_privileged_user jenkins /var/lib/jenkins

echo "Users ansible and jenkins are present with validated passwordless sudo rules."
