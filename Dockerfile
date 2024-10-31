# hadolint ignore=DL3007
ARG UBUNTU_VERSION=focal
FROM myoung34/github-runner:ubuntu-${UBUNTU_VERSION}
# Redefining UBUNTU_VERSION without a value inherits the global default
ARG UBUNTU_VERSION

ARG C_GID
ARG C_GROUP
ARG C_UID
ARG C_USER
ARG LLVM_VERSION

RUN groupadd --gid $C_GID $C_GROUP && adduser --gid $C_GID --uid $C_UID $C_USER

# LABEL maintainer="sunyucong@gmail.com"

RUN apt-get update && apt-get install -y \
    bc bison build-essential cmake cpu-checker elfutils ethtool flex g++ gawk iproute2 iptables \
    iputils-ping keyutils libguestfs-tools linux-image-generic python3-docutils rsync xz-utils zstd
RUN apt-get update && apt-get install -y \
    binutils-dev libcap-dev libdw-dev libelf-dev libelf-dev libssl-dev libzstd-dev ncurses-dev
RUN apt-get update && apt-get install -y \
    qemu-guest-agent qemu-kvm qemu-system-arm qemu-system-s390x qemu-system-x86 qemu-utils

RUN echo "deb https://apt.llvm.org/${UBUNTU_VERSION}/ llvm-toolchain-${UBUNTU_VERSION} main" \
    > /etc/apt/sources.list.d/llvm.list
RUN wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -
RUN apt-get update && apt-get install -y clang lld llvm

# RUN git clone --depth=1 https://github.com/kernel-patches/bpf.git /opt/linux

# RUN git clone https://github.com/libbpf/ci.git /opt/actions
# ENV GITHUB_ACTION_PATH=/opt/actions
COPY helpers.sh /opt/actions/helpers.sh
COPY setup-build-env /opt/actions/setup-build-env

WORKDIR /opt/lib

ENV LLVM_VERSION=${LLVM_VERSION}
RUN /opt/actions/setup-build-env/install_clang.sh

ENV PAHOLE_BRANCH=c2f89dab3f2b0ebb53bab3ed8be32f41cb743c37
RUN /opt/actions/setup-build-env/build_pahole.sh

RUN rm -rf /opt/actions

ENV GITHUB_WORKSPACE=/opt/workspace
WORKDIR $GITHUB_WORKSPACE

# RUN git fetch --depth=100 origin pull/7933/head:ci-build-id-debug \
#  && git checkout ci-build-id-debug

# ENTRYPOINT ["sh", "-c", "trap exit TERM; while :; do sleep 1; done"]

ENV LD_LIBRARY_PATH=/usr/local/lib
ENTRYPOINT ["sh", "-c", "sudo chmod 666 /dev/kvm; trap exit TERM; while :; do sleep 1; done"]


