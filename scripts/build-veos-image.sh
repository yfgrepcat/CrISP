#!/usr/bin/env bash
# This script automates building a Docker image for Arista vEOS using vrnetlab.
# It clones the srl-labs/vrnetlab repository and packages the local 'hda.qcow2'
# and 'cdrom.iso' files into a custom docker image tagged vrnetlab/arista_veos:4.31.0F.
#
# Requirements:
#   - hda.qcow2 and cdrom.iso in the root directory.
#   - docker installed and running.
#
# Environment variables:
#   VRNETLAB_DIR : Path where srl-labs/vrnetlab is cloned (default: /tmp/vrnetlab).
#   BUILD_DIR    : Temporary directory used for the build context (default: /tmp/veos-build-4310F).
#   VEOS_IMAGE   : The final docker image tag (default: vrnetlab/arista_veos:4.31.0F).
#
# Usage:
#   ./scripts/build-veos-image.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VRNETLAB_DIR="${VRNETLAB_DIR:-/tmp/vrnetlab}"
BUILD_DIR="${BUILD_DIR:-/tmp/veos-build-4310F}"
IMAGE_TAG="${VEOS_IMAGE:-vrnetlab/arista_veos:4.31.0F}"

if [[ ! -f "$ROOT_DIR/hda.qcow2" || ! -f "$ROOT_DIR/cdrom.iso" ]]; then
  echo "Missing hda.qcow2 or cdrom.iso in $ROOT_DIR" >&2
  exit 1
fi

if [[ ! -d "$VRNETLAB_DIR/.git" ]]; then
  git clone --depth 1 https://github.com/srl-labs/vrnetlab.git "$VRNETLAB_DIR"
fi

mkdir -p "$BUILD_DIR"
cp "$VRNETLAB_DIR/arista/veos/docker/Dockerfile" "$BUILD_DIR/Dockerfile"
cp "$VRNETLAB_DIR/arista/veos/docker/launch.py" "$BUILD_DIR/launch.py"
cp "$VRNETLAB_DIR/common/healthcheck.py" "$BUILD_DIR/healthcheck.py"
cp "$VRNETLAB_DIR/common/vrnetlab.py" "$BUILD_DIR/vrnetlab.py"
cp --reflink=auto "$ROOT_DIR/hda.qcow2" "$BUILD_DIR/hda.qcow2"
cp --reflink=auto "$ROOT_DIR/cdrom.iso" "$BUILD_DIR/cdrom.iso"

sed -i 's#COPY $IMAGE\* /#COPY hda.qcow2 /\nCOPY cdrom.iso /cdrom.iso#' "$BUILD_DIR/Dockerfile"

sed -i '/re.search(".vmdk$", e)/c\            if re.search(r"\\.(vmdk|qcow2)$", e):' "$BUILD_DIR/launch.py"
perl -0pi -e 's#(disk_image = "/" \+ e\n)#\1                break\n#' "$BUILD_DIR/launch.py"
perl -0pi -e 's#(        self\.hostname = hostname\n)#        if os.path.exists("/cdrom.iso"):\n            self.qemu_args.extend(["-cdrom", "/cdrom.iso", "-boot", "d"])\n\1#' "$BUILD_DIR/launch.py"

docker run --rm \
  -e LIBGUESTFS_DEBUG=0 \
  -v "$BUILD_DIR:/work" \
  cmattoon/guestfish \
  -a hda.qcow2 \
  -m /dev/sda2 \
  write /zerotouch-config DISABLE=True

docker build \
  --build-arg IMAGE=hda.qcow2 \
  --build-arg VERSION=4.31.0F \
  -t "$IMAGE_TAG" \
  "$BUILD_DIR"
