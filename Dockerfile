FROM ghcr.io/kernel-patches/runner:main-noble-x86_64

# RUN git clone --depth=1 https://github.com/kernel-patches/bpf.git /ci/linux

# RUN git clone https://github.com/libbpf/ci.git /ci/actions
# ENV GITHUB_ACTION_PATH=/ci/actions
COPY helpers.sh /ci/actions/helpers.sh
COPY setup-build-env /ci/actions/setup-build-env

WORKDIR /ci/lib

ARG LLVM_VERSION
ENV LLVM_VERSION=${LLVM_VERSION}
RUN /ci/actions/setup-build-env/install_clang.sh

ENV PAHOLE_BRANCH=master
# ENV PAHOLE_BRANCH=tmp.master
RUN /ci/actions/setup-build-env/build_pahole.sh

RUN rm -rf /ci/actions

ENV GITHUB_WORKSPACE=/ci/workspace
WORKDIR $GITHUB_WORKSPACE

# RUN git fetch --depth=100 origin pull/7933/head:ci-build-id-debug \
#  && git checkout ci-build-id-debug

# ENTRYPOINT ["sh", "-c", "trap exit TERM; while :; do sleep 1; done"]

# install Nix
# RUN apt-get -y install nix

# USER ubuntu
# RUN curl -L https://nixos.org/nix/install | sh -s -- --no-daemon

ENV LD_LIBRARY_PATH=/usr/local/lib
ENTRYPOINT ["sh", "-c", "sudo chmod 666 /dev/kvm; trap exit TERM; while :; do sleep 1; done"]


