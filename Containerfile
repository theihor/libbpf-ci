FROM localhost/runner

ENV http_proxy="http://fwdproxy:8080"
ENV https_proxy="http://fwdproxy:8080"
ENV no_proxy=".fbcdn.net,.facebook.com,.thefacebook.com,.tfbnw.net,.fb.com,.fburl.com,.facebook.net,.sb.fbsbx.com,localhost,diem-fullnode-premainnet.fbinfra.net,diem-fullnode-mainnet.fbinfra.net,yum"

RUN apt-get update -y && apt-get install -y --no-install-recommends \
    cmake flex bison build-essential libssl-dev ncurses-dev xz-utils bc rsync libguestfs-tools qemu-kvm qemu-utils \
    clang git sudo curl wget \
    zstd libzstd-dev binutils-dev elfutils libcap-dev libelf-dev libdw-dev python3-docutils texinfo libpcap-dev pkg-config


COPY helpers.sh /ci/actions/helpers.sh
COPY setup-build-env /ci/actions/setup-build-env

ENV GCC_VERSION=14
ENV LLVM_VERSION=20
RUN /ci/actions/setup-build-env/install_packages.sh
RUN /ci/actions/setup-build-env/install_clang.sh

# ENV TARGET_ARCH=s390x
# RUN /ci/actions/setup-build-env/install_cross_compilation_toolchain.sh s390x

WORKDIR /ci/lib
ENV PAHOLE_BRANCH=master
RUN /ci/actions/setup-build-env/build_pahole.sh

ENV GITHUB_WORKSPACE=/ci/workspace
WORKDIR $GITHUB_WORKSPACE

RUN mkdir -p /etc/sudoers.d && \
    echo ubuntu "ALL=(ALL) NOPASSWD:ALL" \
    > /etc/sudoers.d/ubuntu

USER ubuntu

ENV LD_LIBRARY_PATH=/usr/local/lib
ENTRYPOINT ["sh", "-c", "sudo chmod 666 /dev/kvm; trap exit TERM; while :; do sleep 1; done"]
