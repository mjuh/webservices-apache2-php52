with import <nixpkgs> {
  overlays = [
    (import (builtins.fetchGit { url = "git@gitlab.intr:_ci/nixpkgs.git"; ref = "wip-split"; }))
  ];
};

maketestPhp {
  php = php.php52;
  image = callPackage ./default.nix {};
  rootfs = ./rootfs;
}
