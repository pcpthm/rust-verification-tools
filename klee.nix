{ pkgs ? import <nixpkgs> { } }:

pkgs.callPackage ({ lib, stdenv, src, version, patches, # meta
  cmake, bison, flex, # buildBuild
  boost, sqlite, llvm, clang, zlib, gperftools, cryptominisat, # buildHost
  enableSolverStp ? true, stp, # stp solver
  enableSolverZ3 ? true, z3, # z3 solver
  #   enableSolverMetaSMT ? false, # metaSMT solver is not currently supported (not in nixpkgs)
  }:
  assert enableSolverStp || enableSolverZ3;
  stdenv.mkDerivation {
    pname = "klee";
    inherit src version patches;

    nativeBuildInputs = [ cmake bison flex ];
    buildInputs = [ boost sqlite llvm clang zlib gperftools cryptominisat ]
      ++ lib.optional enableSolverStp stp ++ lib.optional enableSolverZ3 z3;

    cmakeFlags = [ "-DENABLE_SYSTEM_TESTS=OFF" ]
      ++ lib.optional enableSolverStp "-DENABLE_SOLVER_STP=ON"
      ++ lib.optional enableSolverZ3 "-DENABLE_SOLVER_Z3=ON";

    passthru = { inherit llvm; };
  }) (let rev = "7bd9582967636f9f4f9acecadd26ab8faef74323";
  in {
    src = pkgs.fetchFromGitHub {
      owner = "klee";
      repo = "klee";
      inherit rev;
      sha256 = "sha256-CT5LoHftDAit29HrWEqYv7u0j/GWP8cfbHRt65/i1DQ=";
    };
    version = "dev-2020-09-05";
    patches = [
      (pkgs.fetchurl {
        name = "00-handle-global-variables.patch";
        url =
          "https://github.com/klee/klee/compare/${rev}...MartinNowack:f46f59c.patch";
        sha256 = "sha256-gffPeckLI1zt0LAEv9xJ4EbJzefqd5hvvtSTtCqmsBc=";
      })
    ];
    inherit (pkgs.llvmPackages_10) llvm clang;
  })
