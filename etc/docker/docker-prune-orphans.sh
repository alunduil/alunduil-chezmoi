#!/usr/bin/env bash
# Remove devcontainers whose host folder is gone. The devcontainer CLI labels
# each container with the folder it mounts. Once that folder is deleted nothing
# reattaches, and docker system prune never removes a running container.
set -euo pipefail

docker ps -a --filter label=devcontainer.local_folder \
  --format '{{.ID}}\t{{.Label "devcontainer.local_folder"}}' |
  while IFS=$'\t' read -r id folder; do
    [[ -z "$folder" || -e "$folder" ]] && continue
    printf 'removing %s: %s is gone\n' "$id" "$folder"
    docker rm -f "$id" >/dev/null
  done
