{}:

with import <nixpkgs> {
  overlays = [
    (import (builtins.fetchGit { url = "git@gitlab.intr:_ci/nixpkgs.git"; ref = "master"; }))
  ];
};

let
  inherit (builtins) concatMap getEnv toJSON;
  inherit (dockerTools) buildLayeredImage;
  inherit (lib) concatMapStringsSep firstNChars flattenSet dockerRunCmd mkRootfs;
  inherit (lib.attrsets) collect isDerivation;
  inherit (stdenv) mkDerivation;

  php52DockerArgHints = lib.phpDockerArgHints php.php52;

  rootfs = mkRootfs {
    name = "apache2-rootfs";
    src = ./rootfs;
    inherit curl coreutils findutils apacheHttpdmpmITK apacheHttpd
      mjHttpErrorPages postfix s6 execline connectorc;
    php52 = php.php52;
    mjperl5Packages = mjperl5lib;
    ioncube = ioncube.v52;
    zendoptimizer = zendoptimizer.v52;
    zendopcache = phpPackages.php52Packages.zendopcache;
    s6PortableUtils = s6-portable-utils;
    s6LinuxUtils = s6-linux-utils;
    mimeTypes = mime-types;
    libstdcxx = gcc-unwrapped.lib;
  };

  rootfsImage = pkgs.dockerTools.buildLayeredImage rec {
    maxLayers = 3;
    name = "rootfs-layered-image";
    tag = "latest";
    contents = [
      rootfs
    ];
  };

in

pkgs.dockerTools.buildImage rec {
  fromImage = rootfsImage;
  name = "docker-registry.intr/webservices/apache2-php52";
  tag = "latest";
  contents = [
    tzdata
    locale
    postfix
    sh
    coreutils
    perl
  ] ++ collect isDerivation phpPackages.php52Packages;
  config = {
    Entrypoint = [ "${rootfs}/init" ];
    Env = [
      "TZ=Europe/Moscow"
      "TZDIR=${tzdata}/share/zoneinfo"
      "LOCALE_ARCHIVE_2_27=${locale}/lib/locale/locale-archive"
      "LOCALE_ARCHIVE=${locale}/lib/locale/locale-archive"
      "LC_ALL=en_US.UTF-8"
    ];
    Labels = flattenSet rec {
      ru.majordomo.docker.arg-hints-json = builtins.toJSON php52DockerArgHints;
      ru.majordomo.docker.cmd = dockerRunCmd php52DockerArgHints "${name}:${tag}";
      ru.majordomo.docker.exec.reload-cmd = "${apacheHttpd}/bin/httpd -d ${rootfs}/etc/httpd -k graceful";
    };
  };
}
