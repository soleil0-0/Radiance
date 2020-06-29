#!/usr/bin/env bash

SCRIPT_HOME="$(cd "$(dirname "$0")"; pwd)"

VERSION="${VERSION:-1.1.5a}"

RADIANCE_IMAGE_DEV="soleil0/radiance-dev:${VERSION}"
RADIANCE_IMAGE_RELEASE="soleil0/radiance:${VERSION}"
RADIANCE_PORT="${RADIANCE_PORT:-34000}"

usage() {
    echo "./util.sh [subcmd]:"
    echo "    image_dev      - build docker image for dev            "
    echo "    image_release  - build docker image for release        "
    echo "    image_push     - push images to docker registry        "
    echo
    echo "    dev            - enter interactive terminal for compile"
    echo "    compile        - compile in docker                     "
    echo "    launch         - start radiance when in container      "
}

image_dev() {
    docker build -t "${RADIANCE_IMAGE_DEV}" . -f Dockerfile.dev
}
image_release() {
    docker build -t "${RADIANCE_IMAGE_RELEASE}" . -f Dockerfile
}
image_push() {
    docker push "${RADIANCE_IMAGE_DEV}"
    docker push "${RADIANCE_IMAGE_RELEASE}"
}

dev() {
    docker run --rm -it -v "${PWD}:${PWD}" -w "${PWD}" -p ${RADIANCE_PORT}:34000 "${RADIANCE_IMAGE_DEV}" bash
}
compile() {
    cat <<EOF | docker run --rm -i -v "${PWD}:${PWD}" -w "${PWD}" "${RADIANCE_IMAGE_DEV}" bash -i
autoreconf -i
./configure
make -j
EOF
}
launch() {
    cat <<EOF >radiance.conf
# Radiance config file
# Lines starting with a # are ignored
# A # anywhere else is treated like any other character

[tracker]
# If you want you can bind a single interface, if the bind option is not
# specified or * all the interfaces will listen for incoming connections.
# To listen on multiple interfaces separate them with a space ("0.0.0.0 ::").
# To listen on Unix socket set this value to "unix:/tmp/radiance.sock" (without quotes).
listen_host         = *
listen_port         = 34000
max_connections     = 128
max_middlemen       = 20000
max_read_buffer     = 4096
connection_timeout  = 10
# Keepalive is mostly useful if the tracker runs behind reverse proxies
keepalive_timeout   = 0
# Override the client IP with the HTTP header provided by a proxy or load balancer (nginx, etc.).
# Disabled by default
real_ip_header      = X-Forwarded-For

announce_interval   = 1800
max_request_size    = 4096
numwant_limit       = 50

mysql_host          = ${MYSQL_HOST:-i}
mysql_username      = ${MYSQL_USERNAME:-root}
mysql_password      = ${MYSQL_PASSWORD:-radiance}
mysql_db            = ${MYSQL_DB:-radiance}

# The passwords must be 32 characters and match the Gazelle config
report_password     = 00000000000000000000000000000000
site_password       = 00000000000000000000000000000000

peers_timeout       = 7200
del_reason_lifetime = 86400
reap_peers_interval = 1800
schedule_interval   = 3

readonly            = false
anonymous           = false
# If using anonymous function, create a user in users_main with a torrent_pass with the anonymous_password,
# which will be the anonymous user, for tracking
anonymous_password  = 00000000000000000000000000000000
clear_peerlists     = true
load_peerlists      = false
peers_history       = true
files_peers         = true
snatched_history    = true
daemonize           = false
# syslog_path         = radiance.log
syslog_level        = info
pid_file            = radiance.pid
daemon_user         = root

[tester]
EOF
    RADIANCE_BIN="${SCRIPT_HOME}/radiance"
    if [ ! -f "${RADIANCE_BIN}" ]; then
        RADIANCE_BIN="${SCRIPT_HOME}/src/radiance"
        if [ ! -f "${RADIANCE_BIN}" ]; then
            echo "can't find binary: radiance"
            exit 1
        fi
    fi

    "${RADIANCE_BIN}" -c radiance.conf
}
start_radiance() {
    RADIANCE_CONTAINER_NAME=mariadb
    if [ ! "$(docker ps -q -f name=${RADIANCE_CONTAINER_NAME})" ]; then
        if [ "$(docker ps -aq -f status=exited -f name=${RADIANCE_CONTAINER_NAME})" ]; then
            # cleanup
            docker rm "${RADIANCE_CONTAINER_NAME}"
        fi
        docker run --name "${RADIANCE_CONTAINER_NAME}" -d -e TZ=Asia/Shanghai -p "${RADIANCE_PORT}:34000" "${RADIANCE_IMAGE_RELEASE}"
    fi
}
start_database() {
    DB_CONTAINER_NAME=mariadb
    if [ ! "$(docker ps -q -f name=$DB_CONTAINER_NAME)" ]; then
        if [ "$(docker ps -aq -f status=exited -f name=$DB_CONTAINER_NAME)" ]; then
            # cleanup
            docker rm $DB_CONTAINER_NAME
        fi
        docker run --name mariadb -d -e TZ=Asia/Shanghai -e MYSQL_ROOT_PASSWORD=radiance -p 3306:3306 mariadb:10.5.4
    fi

    {
        echo "CREATE DATABASE IF NOT EXISTS radiance CHARACTER SET utf8 COLLATE utf8_general_ci; USE radiance; "
        cat install/radiance.sql
        echo "SELECT '===Available Tables===' AS ''; SHOW TABLES"
    } | docker exec -i mariadb mysql -u root -pradiance
}

[ -n "$1" ] || {
    usage
    exit 1
}
[ -z "${DEBUG}" ] || set -x
case "$1" in
image_dev | image_release | image_push| dev | compile | launch | database)
    "$@"
    ;;
*)
    echo "arg not support: $1"
    usage
    exit 1
    ;;
esac
