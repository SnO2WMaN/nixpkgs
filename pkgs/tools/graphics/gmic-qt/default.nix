{ lib
, stdenv
, fetchzip
, cimg
, cmake
, coreutils
, curl
, fftw
, gimp
, gimpPlugins
, gmic
, gnugrep
, gnused
, graphicsmagick
, libjpeg
, libpng
, libtiff
, ninja
, nix-update
, opencv3
, openexr
, pkg-config
, qtbase
, qttools
, wrapQtAppsHook
, writeShellScript
, zlib
, variant ? "standalone"
}:

let
  variants = {
    gimp = {
      extraDeps = [
        gimp
        gimp.gtk
      ];
      description = "GIMP plugin for the G'MIC image processing framework";
    };

    standalone = {
      description = "Versatile front-end to the image processing framework G'MIC";
    };
  };

in

assert lib.assertMsg
  (builtins.hasAttr variant variants)
  "gmic-qt variant \"${variant}\" is not supported. Please use one of ${lib.concatStringsSep ", " (builtins.attrNames variants)}.";

assert lib.assertMsg
  (builtins.all (d: d != null) variants.${variant}.extraDeps or [])
  "gmic-qt variant \"${variant}\" is missing one of its dependencies.";

stdenv.mkDerivation (finalAttrs: {
  pname = "gmic-qt${lib.optionalString (variant != "standalone") "-${variant}"}";
  version = "3.2.4";

  src = fetchzip {
    url = "https://gmic.eu/files/source/gmic_${finalAttrs.version}.tar.gz";
    hash = "sha256-FJ2zlsah/3Jf5ie4UhQsPvMoxDMc6iHl3AkhKsZSuqE=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
    ninja
    wrapQtAppsHook
  ];

  buildInputs = [
    gmic
    qtbase
    qttools
    fftw
    zlib
    libjpeg
    libtiff
    libpng
    opencv3
    openexr
    graphicsmagick
    curl
  ] ++ variants.${variant}.extraDeps or [];

  preConfigure = ''
    cd gmic-qt
  '';

  postPatch = ''
    patchShebangs \
      translations/filters/csv2ts.sh \
      translations/lrelease.sh
  '';

  cmakeFlags = [
    "-DGMIC_QT_HOST=${if variant == "standalone" then "none" else variant}"
    "-DENABLE_SYSTEM_GMIC=ON"
    "-DENABLE_DYNAMIC_LINKING=ON"
  ];

  postFixup = lib.optionalString (variant == "gimp") ''
    echo "wrapping $out/${gimp.targetPluginDir}/gmic_gimp_qt/gmic_gimp_qt"
    wrapQtApp "$out/${gimp.targetPluginDir}/gmic_gimp_qt/gmic_gimp_qt"
  '';

  passthru = {
    tests = {
      gimp-plugin = gimpPlugins.gmic;
      # Needs to update them all in lockstep.
      inherit cimg gmic;
    };

    updateScript = writeShellScript "gmic-qt-update-script" ''
      set -euo pipefail

      export PATH="${lib.makeBinPath [ coreutils curl gnugrep gnused nix-update ]}:$PATH"

      latestVersion=$(curl 'https://gmic.eu/files/source/' \
                       | grep -E 'gmic_[^"]+\.tar\.gz' \
                       | sed -E 's/.+<a href="gmic_([^"]+)\.tar\.gz".+/\1/g' \
                       | sort --numeric-sort --reverse | head -n1)

      if [[ '${finalAttrs.version}' = "$latestVersion" ]]; then
          echo "The new version same as the old version."
          exit 0
      fi

      nix-update --version "$latestVersion"
    '';
  };

  meta = {
    homepage = "http://gmic.eu/";
    inherit (variants.${variant}) description;
    license = lib.licenses.gpl3Plus;
    maintainers = [ lib.maintainers.lilyinstarlight ];
    platforms = lib.platforms.unix;
    mainProgram = "gmic_qt";
  };
})
