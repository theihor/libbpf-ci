let
  nixpkgs = fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixos-24.05";
  pkgs = import nixpkgs { config = {}; overlays = []; };
in

let
  llvmVersion = "17";
in

pkgs.stdenv.mkDerivation {
  pname = "bpf-next";
  version = "d39100d01ce1";
  src = pkgs.fetchgit {
    url = "https://git.kernel.org/pub/scm/linux/kernel/git/bpf/bpf-next.git/";
    rev = "d39100d01ce1ba1bffe0447a0550f592aa6e1e9b";
    sha256 = "HGOAFhvV4XcL9P9d8i7gineQC8Agg2ie/GCd5lpgnuQ=";
    deepClone = false;
  };
  
  nativeBuildInputs = with pkgs; [
    bc
    bison
    gcc
    cmake
    curl
    docutils
    e2fsprogs
    flex
    git
    gnupg
    elfutils
    libelf
    openssl
    lsb-release
    python3Packages.sphinx
    rsync
    wget
    zlib
    zstd
    qemu_kvm
    pkgs."llvm_${llvmVersion}"
    pkgs."clang_${llvmVersion}"
  ];
}
