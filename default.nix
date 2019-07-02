{ lib
, runCommand
, symlinkJoin
, stdenv
, writeText
, llvmPackages
, jq
, rsync
, darwin
, remarshal
, cargo
, rustc
}:

with
  { libb = import ./lib.nix { inherit lib writeText runCommand remarshal; }; };

# Crate building
with rec
  {
      buildPackage = src: attrs:
        with
          { defaultAttrs =
              { inherit
                  llvmPackages
                  jq
                  runCommand
                  lib
                  darwin
                  writeText
                  stdenv
                  rsync
                  remarshal
                  symlinkJoin
                  cargo
                  rustc;
              } ;
          };
        import ./build.nix src (defaultAttrs // attrs);

      buildPackageIncremental = cargolock: name: version: src: attrs:
        with rec
          { buildDependency = depName: depVersion:
              # Really this should be 'buildPackageIncremental' but that makes
              # Nix segfault
              buildPackage (libb.dummySrc depName depVersion)
                { cargoBuild = "cargo build --release -p ${depName}:${depVersion} -j $NIX_BUILD_CORES";
                  inherit (attrs) cargo;
                  cargotomlPath = libb.writeTOML (libb.cargotomlFor depName depVersion);
                  cargolockPath = libb.writeTOML (
                    libb.cargolockFor cargolock depName depVersion
                    );
                  doCheck = false;
                };
          };
        buildPackage src (attrs //
          {
            builtDependencies = map (x: buildDependency x.name x.version)
              (libb.directDependencies cargolock name version) ;
          }
          );

  };

{ inherit buildPackage buildPackageIncremental crates;
}
