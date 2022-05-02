{ lib, gccStdenv, fetchzip
, boost
, cmake
, coreutils
, fetchpatch
, ncurses
, python3
, z3Support ? true
, z3 ? null
, cvc4Support ? gccStdenv.isLinux
, cvc4 ? null
, cln ? null
, gmp ? null
}:

# compiling source/libsmtutil/CVC4Interface.cpp breaks on clang on Darwin,
# general commandline tests fail at abiencoderv2_no_warning/ on clang on NixOS

assert z3Support -> z3 != null && lib.versionAtLeast z3.version "4.6.0";
assert cvc4Support -> cvc4 != null && cln != null && gmp != null;

let
  jsoncppVersion = "1.9.3";
  jsoncppUrl = "https://github.com/open-source-parsers/jsoncpp/archive/${jsoncppVersion}.tar.gz";
  jsoncpp = fetchzip {
    url = jsoncppUrl;
    sha256 = "1vbhi503rgwarf275ajfdb8vpdcbn1f7917wjkf8jghqwb1c24lq";
  };

  range3Version = "0.11.0";
  range3Url = "https://github.com/ericniebler/range-v3/archive/${range3Version}.tar.gz";
  range3 = fetchzip {
    url = range3Url;
    sha256 = "18230bg4rq9pmm5f8f65j444jpq56rld4fhmpham8q3vr1c1bdjh";
  };

  fmtlibVersion = "8.0.1";
  fmtlibUrl = "https://github.com/fmtlib/fmt/archive/${fmtlibVersion}.tar.gz";
  fmtlib = fetchzip {
    url = fmtlibUrl;
    sha256 = "1mnvxqsan034d2jiqnw2yvkljl7lwvhakmj5bscwp1fpkn655bbw";
  };

  solc = gccStdenv.mkDerivation rec {
    pname = "solc";
    version = "0.8.13";

    # upstream suggests avoid using archive generated by github
    src = fetchzip {
      url = "https://github.com/ethereum/solidity/releases/download/v${version}/solidity_${version}.tar.gz";
      hash = "sha256-cFC9M65kSYgYq9rhBXZKEdfvIMbMaDiDwdPmU8v9s7k=";
    };

    postPatch = ''
      substituteInPlace cmake/jsoncpp.cmake \
        --replace "${jsoncppUrl}" ${jsoncpp}
      substituteInPlace cmake/range-v3.cmake \
        --replace "${range3Url}" ${range3}
      substituteInPlace cmake/fmtlib.cmake \
        --replace "${fmtlibUrl}" ${fmtlib}
    '';

    cmakeFlags = [
      "-DBoost_USE_STATIC_LIBS=OFF"

    ] ++ (if z3Support then [
      "-DSTRICT_Z3_VERSION=OFF"
    ] else [
      "-DUSE_Z3=OFF"
    ]) ++ lib.optionals (!cvc4Support) [
      "-DUSE_CVC4=OFF"
    ];

    nativeBuildInputs = [ cmake ];
    buildInputs = [ boost ]
      ++ lib.optionals z3Support [ z3 ]
      ++ lib.optionals cvc4Support [ cvc4 cln gmp ];
    checkInputs = [ ncurses python3 ];

    # tests take 60+ minutes to complete, only run as part of passthru tests
    doCheck = false;

    checkPhase = ''
      while IFS= read -r -d ''' dir
      do
        LD_LIBRARY_PATH=$LD_LIBRARY_PATH''${LD_LIBRARY_PATH:+:}$(pwd)/$dir
        export LD_LIBRARY_PATH
      done <   <(find . -type d -print0)

      pushd ..
      # IPC tests need aleth avaliable, so we disable it
      sed -i "s/IPC_ENABLED=true/IPC_ENABLED=false\nIPC_FLAGS=\"--no-ipc\"/" ./scripts/tests.sh
      for i in ./scripts/*.sh ./scripts/*.py ./test/*.sh ./test/*.py; do
        patchShebangs "$i"
      done
      TERM=xterm ./scripts/tests.sh ${if z3Support then "--no-smt" else ""}
      popd
    '';

    doInstallCheck = true;
    installCheckPhase = ''
      $out/bin/solc --version > /dev/null
    '';

    passthru.tests = {
      solcWithTests = solc.overrideAttrs (attrs: { doCheck = true; });
    };

    meta = with lib; {
      description = "Compiler for Ethereum smart contract language Solidity";
      homepage = "https://github.com/ethereum/solidity";
      license = licenses.gpl3;
      maintainers = with maintainers; [ dbrock akru lionello sifmelcara ];
    };
  };
in
  solc
