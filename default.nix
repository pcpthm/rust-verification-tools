{ }:
let
  pkgs = import (builtins.fetchTarball
    "https://github.com/NixOS/nixpkgs/archive/20.09-alpha.tar.gz") { };

  klee = import ./klee.nix { inherit pkgs; };

in pkgs.callPackage
({ stdenv, klee, python3, makeWrapper, rustc-nightly, cargo }:
  let
    pythonEnv = python3.withPackages (ps: [ ps.toml ps.termcolor ]);
    defaultTarget = "x86_64-unknown-linux-gnu"; # hardcoded for now
  in stdenv.mkDerivation {
    name = "cargo-verify";
    version = "dev";

    src = ./scripts;

    buildInputs = [ klee makeWrapper ];

    buildPhase = ''
      mkdir -p "$out/bin"

      substitute "$src/cargo-verify" "$out/bin/cargo-verify" \
        --replace '#!/usr/bin/env python3' '#!${pythonEnv}/bin/python' \
        --replace "'/usr/bin/env', 'llvm-nm'" "'${klee.llvm}/bin/llvm-nm'" \
        --replace "Popen(['klee'" "Popen(['${klee}/bin/klee'" \
        --replace 'target = get_default_host()' 'target = "${defaultTarget}"'

      chmod +x "$out/bin/cargo-verify"
      wrapProgram "$out/bin/cargo-verify" \
        --prefix RUSTFLAGS ' ' '-L native=${klee}/lib' \
        --prefix PATH ':' '${rustc-nightly}/bin' \
        --prefix PATH ':' '${cargo}/bin'
    '';

    dontInstall = true;
    doCheck = true;

    checkPhase = ''
      "$out/bin/cargo-verify" -h
    '';
  }) {
    # LLVM version has to match
    klee = klee.override { inherit (pkgs.rustc) llvm; };
    # Predend a Nightly compiler
    rustc-nightly =
      pkgs.runCommand "rustc-nightly" { buildInputs = [ pkgs.makeWrapper ]; } ''
        mkdir -p "$out/bin"
        makeWrapper '${pkgs.rustc}/bin/rustc' "$out/bin/rustc" --set RUSTC_BOOTSTRAP 1
      '';
  }
