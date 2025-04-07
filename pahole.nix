{ pkgs ? import <nixpkgs> {} }:

pkgs.stdenv.mkDerivation {
  version = "v1.28";
  pname = "pahole";
  enableParallelBuilding = true;
  src = pkgs.fetchgit {
    url = "https://git.kernel.org/pub/scm/devel/pahole/pahole.git";
    rev = "v1.28";
    sha256 = "dk1Lde36AZM+notYA6+pEWXl1PxO7Wii3mmFx5W/jU4=";
  };

  nativeBuildInputs = with pkgs; [ cmake pkg-config elfutils zlib libdwarf libelf ];

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
  ];

  installPhase = ''
    make install
  '';
}
