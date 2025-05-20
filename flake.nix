{
  description = "nixpkgs-re";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs?rev=b134951a4c9f3c995fd7be05f3243f8ecd65d798"; # nixos-24.05
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    let
      lib = nixpkgs.lib;

      readFile = path: builtins.filter (n: n != "") (lib.splitString "\n" (builtins.readFile path));

      filteredPackageNames_2 = readFile ./assets/2.txt;
      filteredPackageNames_5 = readFile ./assets/5.txt;
      filteredPackageNames_8 = readFile ./assets/8.txt;
      filteredPackageNames_10 = readFile ./assets/10.txt;
      finalPackageNames = readFile ./assets/final.txt;

      forSystems =
        f:
        nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (
          system:
          (f (
            import nixpkgs {
              inherit system;
              config = {
                allowInsecurePredicate = _: true;
              };
            }
          ))
        );

      makeDebugPackage =
        pkg: level:
        if !pkg ? overrideAttrs then
          throw "package ${pkg} does not have `overrideAttrs`"
        else
          pkg.overrideAttrs (
            final: prev: {
              dontStrip = true;
              doCheck = false;
              env = (prev.env or { }) // {
                NIX_CFLAGS_COMPILE =
                  toString (prev.env.NIX_CFLAGS_COMPILE or "") + " -ggdb -O${level} -Wa,--compress-debug-sections";
                NIX_RUSTFLAGS = toString (prev.env.NIX_RUSTFLAGS or "") + " -g -C strip=none";
              };
            }
          );

      makePackageVariants =
        pkgs: packageNames:
        (lib.genAttrs packageNames (
          name:
          let
            pkg = lib.getAttrFromPath (lib.splitString "." name) pkgs;
          in
          {
            src = pkgs.srcOnly pkg;
            default = pkg;
            O0 = makeDebugPackage pkg "0";
            O2 = makeDebugPackage pkg "2";
            recurseForDerivations = true;
          }
        ))
        // {
          recurseForDerivations = true;
        };

    in
    rec {
      stage2Pkgs = forSystems (
        pkgs:
        (lib.genAttrs filteredPackageNames_2 (name: lib.getAttrFromPath (lib.splitString "." name) pkgs))
        // {
          recurseForDerivations = true;
        }
      );
      stage2Corpora = forSystems (pkgs: makePackageVariants pkgs filteredPackageNames_2);
      stage5Src =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        in
        lib.genAttrs filteredPackageNames_5 (
          name: pkgs.srcOnly (lib.getAttrFromPath (lib.splitString "." name) pkgs)
        );
      stage8Corpora = forSystems (pkgs: makePackageVariants pkgs filteredPackageNames_8);
      stage10Corpora = forSystems (pkgs: makePackageVariants pkgs filteredPackageNames_10);

      finalCorpora = forSystems (pkgs: makePackageVariants pkgs finalPackageNames);
      legacyPackages = finalCorpora;
    };
}
