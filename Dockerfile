FROM debian:stretch-slim AS builder
RUN set -ex; \
    apt-get update; \
    apt-get install -y \
        build-essential \
        automake \
        git \
        cmake \
        default-libmysqlclient-dev \
        libboost-all-dev \
        libev-dev \
        libjemalloc-dev \
        libmysql++-dev \
        pkg-config;\
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
COPY . /build
RUN set -ex; \
    cd /build; \
    autoreconf -i; \
    ./configure; \
    make -j

FROM debian:stretch-slim
RUN set -ex; \
    apt-get update; \
    apt-get install -y \
        libboost-all-dev \
        libev-dev \
        libmysql++-dev \
        pkg-config;\
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
WORKDIR /app
COPY --from=builder /build/src/radiance /app/radiance
COPY ./util.sh /app/util.sh
EXPOSE 34000
CMD ["/app/util.sh"]