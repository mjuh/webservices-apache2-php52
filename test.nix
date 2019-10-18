with import <nixpkgs> {
  overlays = [
    (import (builtins.fetchGit { url = "git@gitlab.intr:_ci/nixpkgs.git"; ref = "master"; }))
  ];
};

maketestPhp {
  php = phpDeprecated.php52;
  image = callPackage ./default.nix {};
  rootfs = ./rootfs;
}
