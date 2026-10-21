#!/bin/sh
# Builds the production image for the NAS (linux/amd64) with Podman and saves it
# as dist/plattensammlung-<version>.tar.gz for `docker load` on TrueNAS.
#
#   deploy/build-image.sh            # version = date + git commit
#   deploy/build-image.sh 1.2.0      # explicit version
set -eu
cd "$(dirname "$0")/.."

VERSION="${1:-$(date +%Y%m%d)-$(git rev-parse --short HEAD)}"
IMAGE="localhost/plattensammlung:$VERSION"

if [ -n "$(git status --porcelain)" ]; then
  echo "Hinweis: Es gibt nicht committete Änderungen; sie landen trotzdem im Image." >&2
fi

# Docker format keeps the HEALTHCHECK (OCI images drop it)
podman build --platform linux/amd64 --format docker --tag "$IMAGE" .

mkdir -p dist
ARCHIVE="dist/plattensammlung-$VERSION.tar.gz"
podman save --format docker-archive "$IMAGE" | gzip > "$ARCHIVE"

cat <<INFO

Fertig: $ARCHIVE ($(du -h "$ARCHIVE" | cut -f1))
Image:  $IMAGE

Auf das NAS kopieren und laden:
  scp $ARCHIVE <nas>:/mnt/POOL/apps/plattensammlung/images/
  ssh <nas> sudo docker load -i /mnt/POOL/apps/plattensammlung/images/$(basename "$ARCHIVE")

Danach in der TrueNAS-App die Zeile "image:" auf $IMAGE setzen und speichern.
INFO
