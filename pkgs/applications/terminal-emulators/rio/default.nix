{ lib
, stdenv
, darwin
, fetchFromGitHub
, rustPlatform
, nixosTests
, nix-update-script

, autoPatchelfHook
, cmake
, ncurses
, pkg-config

, gcc-unwrapped
, fontconfig
, libGL
, vulkan-loader
, libxkbcommon

, withX11 ? !stdenv.isDarwin
, libX11
, libXcursor
, libXi
, libXrandr
, libxcb

, withWayland ? !stdenv.isDarwin
, wayland
}:
let
  rlinkLibs = if stdenv.isDarwin then [
    darwin.libobjc
    darwin.apple_sdk.frameworks.AppKit
  ] else [
    (lib.getLib gcc-unwrapped)
    fontconfig
    libGL
    libxkbcommon
    vulkan-loader
  ] ++ lib.optionals withX11 [
    libX11
    libXcursor
    libXi
    libXrandr
    libxcb
  ] ++ lib.optionals withWayland [
    wayland
  ];
in
rustPlatform.buildRustPackage rec {
  pname = "rio";
  version = "0.0.27";

  src = fetchFromGitHub {
    owner = "raphamorim";
    repo = "rio";
    rev = "v${version}";
    hash = "sha256-q3Wq7jIYE4g1uPAlpzNWvwUvMy9eN6NQNmPNC4cFmYg=";
  };

  cargoHash = "sha256-SP85se+H4jL/cXyvfbFS2lxpNSjuptAIPs3/htcrMcw=";

  nativeBuildInputs = [
    ncurses
    cmake
  ] ++ lib.optionals stdenv.isLinux [
    pkg-config
    autoPatchelfHook
  ];

  runtimeDependencies = rlinkLibs;

  buildInputs = rlinkLibs;

  outputs = [ "out" "terminfo" ];

  buildNoDefaultFeatures = true;
  buildFeatures = [ ]
    ++ lib.optional withX11 "x11"
    ++ lib.optional withWayland "wayland";

  checkFlags = [
    # Fail to run in sandbox environment.
    "--skip=screen::context::test"
  ];

  postInstall = ''
    install -D -m 644 misc/rio.desktop -t $out/share/applications
    install -D -m 644 misc/logo.svg \
                      $out/share/icons/hicolor/scalable/apps/rio.svg

    install -dm 755 "$terminfo/share/terminfo/r/"
    tic -xe rio,rio-direct -o "$terminfo/share/terminfo" misc/rio.terminfo
    mkdir -p $out/nix-support
    echo "$terminfo" >> $out/nix-support/propagated-user-env-packages
  '' + lib.optionalString stdenv.isDarwin ''
    mkdir $out/Applications/
    mv misc/osx/Rio.app/ $out/Applications/
    mkdir $out/Applications/Rio.app/Contents/MacOS/
    ln -s $out/bin/rio $out/Applications/Rio.app/Contents/MacOS/
  '';

  passthru = {
    updateScript = nix-update-script {
      extraArgs = [ "--version-regex" "v([0-9.]+)" ];
    };

    tests.test = nixosTests.terminal-emulators.rio;
  };

  meta = {
    description = "A hardware-accelerated GPU terminal emulator powered by WebGPU";
    homepage = "https://raphamorim.io/rio";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ otavio oluceps ];
    platforms = lib.platforms.unix;
    changelog = "https://github.com/raphamorim/rio/blob/v${version}/CHANGELOG.md";
    mainProgram = "rio";
  };
}
