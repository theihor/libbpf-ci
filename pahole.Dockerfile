ARG UBUNTU_VERSION=focal
FROM myoung34/github-runner:ubuntu-${UBUNTU_VERSION}
# Redefining UBUNTU_VERSION without a value inherits the global default
ARG UBUNTU_VERSION

ARG LLVM_VERSION

RUN apt-get update && apt-get install -y \
    bc bison build-essential cmake cpu-checker elfutils ethtool flex g++ gawk iproute2 iptables \
    iputils-ping keyutils libguestfs-tools linux-image-generic python3-docutils rsync xz-utils zstd \
    vim tree
RUN apt-get update && apt-get install -y \
    binutils-dev libcap-dev libdw-dev libelf-dev libelf-dev libssl-dev libzstd-dev ncurses-dev
RUN apt-get update && apt-get install -y \
    qemu-guest-agent qemu-kvm qemu-system-x86 qemu-utils

RUN echo "deb https://apt.llvm.org/${UBUNTU_VERSION}/ llvm-toolchain-${UBUNTU_VERSION} main" \
    > /etc/apt/sources.list.d/llvm.list
RUN wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -
RUN apt-get update && apt-get install -y clang lld llvm

COPY helpers.sh /ci/actions/helpers.sh
COPY setup-build-env /ci/actions/setup-build-env

WORKDIR /ci/lib

ENV LLVM_VERSION=${LLVM_VERSION}
RUN /ci/actions/setup-build-env/install_clang.sh

ENV PAHOLE_BRANCH=tmp.master
RUN /ci/actions/setup-build-env/build_pahole.sh

RUN rm -rf /ci/actions

ENV GITHUB_WORKSPACE=/ci/workspace
WORKDIR $GITHUB_WORKSPACE

ENV LD_LIBRARY_PATH=/usr/local/lib
ENTRYPOINT ["sh", "-c", "sudo chmod 666 /dev/kvm; trap exit TERM; while :; do sleep 1; done"]


