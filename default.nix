{ nixpkgs ? (import ./common.nix).nixpkgs }:

with nixpkgs;

let
  inherit (builtins) concatMap getEnv toJSON;
  inherit (dockerTools) buildLayeredImage;
  inherit (lib) concatMapStringsSep firstNChars flattenSet dockerRunCmd mkRootfs;
  inherit (lib.attrsets) collect isDerivation;
  inherit (stdenv) mkDerivation;

  php52DockerArgHints = lib.phpDockerArgHints { php = php52;
    extraVolumes = [({ # workaround that needed till problem that cause php realpath() return false on valid path with new majordomo input is not found
      type = "bind";
      source = "/var/log/home";
      target = "/var/log/home";
    })];
 };

  rootfs = mkRootfs {
    name = "apache2-rootfs-php52";
    src = ./rootfs;
    inherit zlib curl coreutils findutils apacheHttpdmpmITK apacheHttpd
      mjHttpErrorPages s6 execline php52 logger;
    postfix = sendmail;
    mjperl5Packages = mjperl5lib;
    ioncube = ioncube.v52;
    zendoptimizer = zendoptimizer.v52;
    zendopcache = php52Packages.zendopcache;
    s6PortableUtils = s6-portable-utils;
    s6LinuxUtils = s6-linux-utils;
    mimeTypes = mime-types;
    libstdcxx = gcc-unwrapped.lib;
  };

in

pkgs.dockerTools.buildLayeredImage rec {
  name = "docker-registry.intr/webservices/apache2-php52";
  tag = "latest";
  contents = [
    rootfs
    tzdata apacheHttpd
    locale
    sendmail
    sh
    coreutils
    libjpeg_turbo
    jpegoptim
    (optipng.override{ inherit libpng ;})
    imagemagick
    gifsicle nss-certs.unbundled zip
    gcc-unwrapped.lib
    glibc
    zlib
    mariadbConnectorC
    logger
    perl520
  ]
  ++ collect isDerivation php52Packages
  ++ collect isDerivation mjperl5Packages;
  config = {
    Entrypoint = [ "${rootfs}/init" ];
    Env = [
      "TZ=Europe/Moscow"
      "TZDIR=${tzdata}/share/zoneinfo"
      "LOCALE_ARCHIVE_2_27=${locale}/lib/locale/locale-archive"
      "LOCALE_ARCHIVE=${locale}/lib/locale/locale-archive"
      "LC_ALL=en_US.UTF-8"
      "LD_PRELOAD=${jemalloc}/lib/libjemalloc.so"
      "PERL5LIB=${mjPerlPackages.PERL5LIB}"
    ];
    Labels = flattenSet rec {
      ru.majordomo.docker.arg-hints-json = builtins.toJSON php52DockerArgHints;
      ru.majordomo.docker.cmd = dockerRunCmd php52DockerArgHints "${name}:${tag}";
      ru.majordomo.docker.exec.reload-cmd = "${apacheHttpd}/bin/httpd -d ${rootfs}/etc/httpd -k graceful";
    };
  };
    extraCommands = ''
      set -xe
      ls
      mkdir -p etc
      mkdir -p bin
      chmod u+w usr
      mkdir -p usr/local
      mkdir -p opt
      ln -s ${php52} opt/php52
      ln -s /bin usr/sbin
      ln -s /bin usr/local/bin
      mkdir tmp
      chmod 1777 tmp
    '';
}
