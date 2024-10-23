{ pkgs ? import <nixpkgs> {} }:

pkgs.stdenv.mkDerivation {
  version = "c2f89da";
  pname = "pahole";
  src = pkgs.fetchgit {
    url = "https://git.kernel.org/pub/scm/devel/pahole/pahole.git";
    rev = "c2f89dab3f2b0ebb53bab3ed8be32f41cb743c37";
    sha256 = "b5LcgfFMl7JXIiT2JWZEZOKZO5Oex620AhH7LNu8X+g=";
  };

  nativeBuildInputs = with pkgs; [ cmake pkg-config elfutils zlib libdwarf libelf ];

  cmakeFlags = [
    "-D__LIB=lib/pahole"
  ];

  installPhase = ''
    make install
  '';
}
