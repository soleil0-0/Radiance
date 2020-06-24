#!/usr/bin/env bash

VERSION="${VERSION:-1.1.5a}"
IMAGE_DEV="soleil0/radiance-dev:${VERSION}"
IMAGE_RELEASE="soleil0/radiance:${VERSION}"

usage() {
    echo "./util.sh usage:"
    echo "    devimage    - build docker image for dev"
    echo "    dev         - enter interactive terminal for compile"
    echo "    compile     - compile in docker"
    echo "    release     - build docker image for release"
    echo "    push        - push images to docker registry"
}
devimage() {
    docker build -t "${IMAGE_DEV}" . -f Dockerfile.dev
}
dev() {
    docker run --rm -it -v "${PWD}:${PWD}" -w "${PWD}" "${IMAGE_DEV}" bash
}
compile() {
    cat <<EOF | docker run --rm -i -v "${PWD}:${PWD}" -w "${PWD}" "${IMAGE_DEV}" bash -i
autoreconf -i
./configure
make -j
EOF
}
release() {
    docker build -t "${IMAGE_RELEASE}" . -f Dockerfile
}
push() {
    docker push "${IMAGE_DEV}"
    docker push "${IMAGE_RELEASE}"
}

[ -n "$1" ] || { usage; exit 1; }
[ -z "${DEBUG}" ] || set -x
case "$1" in
    devimage|dev|compile|release|push)
        "$@"
        ;;
    *)
        echo "arg not support: $1"
        usage
        exit 1
        ;;
esac