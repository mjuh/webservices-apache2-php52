with import <nixpkgs> {
  overlays = [
    (import (builtins.fetchGit { url = "git@gitlab.intr:_ci/nixpkgs.git"; ref = "master"; }))
  ];
};

let

inherit (builtins) concatMap getEnv toJSON;
inherit (dockerTools) buildLayeredImage;
inherit (lib) concatMapStringsSep firstNChars flattenSet dockerRunCmd buildPhpPackage mkRootfs;
inherit (lib.attrsets) collect isDerivation;
inherit (stdenv) mkDerivation;

  locale = glibcLocales.override {
      allLocales = false;
      locales = ["en_US.UTF-8/UTF-8"];
  };

sh = dash.overrideAttrs (_: rec {
  postInstall = ''
    ln -s dash "$out/bin/sh"
  '';
});

  zendoptimizer = stdenv.mkDerivation rec {
      name = "zend-optimizer-3.3.9";
      src =  fetchurl {
          url = "http://downloads.zend.com/optimizer/3.3.9/ZendOptimizer-3.3.9-linux-glibc23-x86_64.tar.gz";
          sha256 = "1f7c7p9x9p2bjamci04vr732rja0l1279fvxix7pbxhw8zn2vi1d";
      };
      installPhase = ''
                  mkdir -p  $out/
                  tar zxvf  ${src} -C $out/ ZendOptimizer-3.3.9-linux-glibc23-x86_64/data/5_2_x_comp/ZendOptimizer.so
      '';
  };

  pcre831 = stdenv.mkDerivation rec {
      name = "pcre-8.31";
      src = fetchurl {
          url = "https://ftp.pcre.org/pub/pcre/${name}.tar.bz2";
          sha256 = "0g4c0z4h30v8g8qg02zcbv7n67j5kz0ri9cfhgkpwg276ljs0y2p";
      };
      outputs = [ "out" ];
      configureFlags = ''
          --enable-jit
      '';
  };

  libjpeg130 = stdenv.mkDerivation rec {
     name = "libjpeg-turbo-1.3.0";
     src = fetchurl {
         url = "mirror://sourceforge/libjpeg-turbo/${name}.tar.gz";
         sha256 = "0d0jwdmj3h89bxdxlwrys2mw18mqcj4rzgb5l2ndpah8zj600mr6";
     };
     buildInputs = [ nasm ];
     doCheck = true;
     checkTarget = "test";
 };

  libpng12 = stdenv.mkDerivation rec {
     name = "libpng-1.2.59";
     src = fetchurl {
        url = "mirror://sourceforge/libpng/${name}.tar.xz";
        sha256 = "b4635f15b8adccc8ad0934eea485ef59cc4cae24d0f0300a9a941e51974ffcc7";
     };
     buildInputs = [ zlib ];
     doCheck = true;
     checkTarget = "test";
  };

  connectorc = stdenv.mkDerivation rec {
     name = "mariadb-connector-c-${version}";
     version = "6.1.0";

     src = fetchurl {
         url = "https://downloads.mysql.com/archives/get/file/mysql-connector-c-6.1.0-src.tar.gz";
         sha256 = "0cifddg0i8zm8p7cp13vsydlpcyv37mz070v6l2mnvy0k8cng2na";
         name   = "mariadb-connector-c-${version}-src.tar.gz";
     };

  # outputs = [ "dev" "out" ]; FIXME: cmake variables don't allow that < 3.0
     cmakeFlags = [
            "-DWITH_EXTERNAL_ZLIB=ON"
            "-DMYSQL_UNIX_ADDR=/run/mysqld/mysqld.sock"
     ];

  # The cmake setup-hook uses $out/lib by default, this is not the case here.
     preConfigure = stdenv.lib.optionalString stdenv.isDarwin ''
             cmakeFlagsArray+=("-DCMAKE_INSTALL_NAME_DIR=$out/lib/mariadb")
     '';

     nativeBuildInputs = [ cmake ];
     propagatedBuildInputs = [ openssl zlib ];
     buildInputs = [ libiconv ];
     enableParallelBuilding = true;
  };

 imagemagick68 = stdenv.mkDerivation rec {
  version = "6.8.8-7";
    name = "ImageMagick-${version}";

  src = fetchurl {
    url = "https://mirror.sobukus.de/files/src/imagemagick/${name}.tar.xz";
    sha256 = "1x5jkbrlc10rx7vm344j7xrs74c80xk3n1akqx8w5c194fj56mza";
  };

  enableParallelBuilding = true;

  configureFlags = ''
    --with-gslib
    --with-frozenpaths
    ${if librsvg != null then "--with-rsvg" else ""}
  '';

  buildInputs =
    [ pkgconfig bzip2 fontconfig freetype libjpeg libpng libtiff libxml2 zlib librsvg
      libtool jasper
    ];

  postInstall = ''(cd "$out/include" && ln -s ImageMagick* ImageMagick)'';
 };

  php52 = stdenv.mkDerivation rec {
      name = "php-5.2.17";
      sha256 = "e81beb13ec242ab700e56f366e9da52fd6cf18961d155b23304ca870e53f116c";
      enableParallelBuilding = true;
      nativeBuildInputs = [ pkgconfig autoconf213 ];
      srcs = [
             ( fetchurl {
                 url = "https://museum.php.net/php5/php-5.2.17.tar.bz2";
                 inherit sha256;
             })
             ./src/ext/standard
      ];
      sourceRoot = "php-5.2.17";
      patches = [
                 ./patch/php5/mj/backport_crypt_from_php53.patch
                 ./patch/php5/mj/configure.patch
                 ./patch/php5/mj/zts.patch
                 ./patch/php5/mj/fix-pcre-php52.patch
                 ./patch/php5/mj/debian_patches_disable_SSLv2_for_openssl_1_0_0.patch.patch
                 ./patch/php5/mj/fix-exif-buffer-overflow.patch
                 ./patch/php5/mj/libxml2-2-9_adapt_documenttype.patch
                 ./patch/php5/mj/libxml2-2-9_adapt_node.patch
                 ./patch/php5/mj/libxml2-2-9_adapt_simplexml.patch
                 ./patch/php5/mj/mj_engineers_apache2_4_abi_fix.patch
                 ./patch/php5/mj/php52-fix-mysqli-buffer-overflow.patch
      ];
      stripDebugList = "bin sbin lib modules";
      outputs = [ "out" ];
      doCheck = false;
      checkTarget = "test";
      buildInputs = [
         autoconf213
         automake
         pkgconfig
         curl
         apacheHttpd.dev
         bison
         bzip2
         flex
         freetype
         gettext
         icu
         libzip
         libjpeg130
         libmcrypt
         libmhash
         libpng12
         libxml2
         libsodium
         icu.dev
         xorg.libXpm.dev
         libxslt
         connectorc
         pam
         pcre831
         postgresql
         readline
         sqlite
         uwimap
         zlib
         libiconv
         t1lib
         libtidy
         kerberos
         openssl
         glibc.dev
         glibcLocales
      ];
      CXXFLAGS = "-std=c++11";
      configureFlags = ''
       --disable-maintainer-zts
       --disable-pthreads
       --disable-fpm
       --disable-cgi
       --disable-phpdbg
       --disable-debug
       --disable-memcached-sasl
       --enable-pdo
       --enable-dom
       --enable-libxml
       --enable-inline-optimization
       --enable-dba
       --enable-bcmath
       --enable-soap
       --enable-sockets
       --enable-zip
       --enable-exif
       --enable-ftp
       --enable-mbstring
       --enable-calendar
       --enable-timezonedb
       --enable-gd-native-ttf 
       --enable-sysvsem
       --enable-sysvshm
       --enable-opcache
       --enable-magic-quotes
       --with-config-file-scan-dir=/etc/php.d
       --with-pcre-regex=${pcre831} 
       --with-imap=${uwimap}
       --with-imap-ssl
       --with-mhash=${libmhash}
       --with-libzip
       --with-curl=${curl.dev}
       --with-curlwrappers
       --with-zlib=${zlib.dev}
       --with-libxml-dir=${libxml2.dev}
       --with-xmlrpc
       --with-readline=${readline.dev}
       --with-pdo-sqlite=${sqlite.dev}
       --with-pgsql=${postgresql}
       --with-pdo-pgsql=${postgresql}
       --with-gd
       --with-freetype-dir=${freetype.dev}
       --with-png-dir=${libpng12}
       --with-jpeg-dir=${libjpeg130} 
       --with-openssl
       --with-gettext=${glibc.dev}
       --with-xsl=${libxslt.dev}
       --with-mcrypt=${libmcrypt}
       --with-bz2=${bzip2.dev}
       --with-sodium=${libsodium.dev}
       --with-tidy=${html-tidy}
       --with-password-argon2=${libargon2}
       --with-apxs2=${apacheHttpd.dev}/bin/apxs
       --with-pdo-mysql=${connectorc}
       --with-mysql=${connectorc}
       --with-mysqli=${connectorc}/bin/mysql_config
       '';
      hardeningDisable = [ "bindnow" ];
      preConfigure = ''
        cp -pr ../standard/* ext/standard
        # Don't record the configure flags since this causes unnecessary
        # runtime dependencies
        for i in main/build-defs.h.in scripts/php-config.in; do
          substituteInPlace $i \
            --replace '@CONFIGURE_COMMAND@' '(omitted)' \
            --replace '@CONFIGURE_OPTIONS@' "" \
            --replace '@PHP_LDFLAGS@' ""
        done
        substituteInPlace ext/tidy/tidy.c \
            --replace buffio.h tidybuffio.h
        [[ -z "$libxml2" ]] || addToSearchPath PATH $libxml2/bin
        export EXTENSION_DIR=$out/lib/php/extensions
        configureFlags+=(--with-config-file-path=$out/etc \
          --includedir=$dev/include)
        ./buildconf --force
      '';
      postInstall = ''
          sed -i $out/include/php/main/build-defs.h -e '/PHP_INSTALL_IT/d'
      '';     
  };



buildPhp52Package = args: buildPhpPackage ({ php = php52; } // args);


php52Packages = {
  timezonedb = buildPhp52Package {
    name = "timezonedb";
    version = "2019.1";
    sha256 = "0rrxfs5izdmimww1w9khzs9vcmgi1l90wni9ypqdyk773cxsn725";
  };

  dbase = buildPhp52Package {
      name = "dbase";
      version = "5.1.0";
      sha256 = "15vs527kkdfp119gbhgahzdcww9ds093bi9ya1ps1r7gn87s9mi0";
  };

  intl = buildPhp52Package {
      name = "intl";
      version = "3.0.0";
      sha256 = "11sz4mx56pc1k7llgbbpz2i6ls73zcxxdwa1d0jl20ybixqxmgc8";
      inputs = [ icu58 ];
  };

  zendopcache = buildPhp52Package {
      name = "zendopcache";
      version = "7.0.5";
      sha256 = "1h79x7n5pylbc08cxl44fvbi1a1592n0w0mm847jirkqrhxs5r68";
  };

  imagick = buildPhp52Package {
      name = "imagick";
      version = "3.1.2";
      sha256 = "528769ac304a0bbe9a248811325042188c9d16e06de16f111fee317c85a36c93";
      inputs = [ pkgconfig imagemagick68 pcre ];
      configureFlags = [ "--with-imagick=${imagemagick68}" ];
  };
};

#   ## fixxed nix-generate-from-cpan Text::Truncate  ## TO DO in overlay perl modules
#   perlTextTruncate = perlPackages.buildPerlPackage rec {
#    name = "Text-Truncate-1.06";
#    src = fetchurl {
#      url = "mirror://cpan/authors/id/I/IL/ILV/${name}.tar.gz";
#      sha256 = "1933361ec297253d1dd518068b863dcda131aba1da5ac887040c3d85a2d2a5d2";
#    };
#    buildInputs = [ perlPackages.ModuleBuild ];
#  };

  rootfs = mkRootfs {
      name = "apache2-php52-rootfs";
      perl5Packages = [
         perlPackages.TimeLocal
         perlPackages.PerlMagick
         perlPackages.commonsense
         perlPackages.Mojolicious
         perlPackages.base
         perlPackages.libxml_perl
         perlPackages.libnet
         perlPackages.libintl_perl
         perlPackages.LWP
         perlPackages.ListMoreUtilsXS
         perlPackages.LWPProtocolHttps
         perlPackages.DBI
         perlPackages.DBDmysql
         perlPackages.CGI
         perlPackages.FilePath
         perlPackages.DigestPerlMD5
         perlPackages.DigestSHA1
         perlPackages.FileBOM
         perlPackages.GD
         perlPackages.LocaleGettext
         perlPackages.HashDiff
         perlPackages.JSONXS
         perlPackages.POSIXstrftimeCompiler
         perlPackages.perl
      ];
      src = ./rootfs;
#      nativeBuildInputs = [ perl  ] ++ perl5Packages ;
#      perl5lib = perlPackages.makePerlPath perl5Packages;
      inherit curl coreutils findutils apacheHttpdmpmITK apacheHttpd mjHttpErrorPages php52 postfix s6 execline zendoptimizer connectorc  ;
      ioncube = ioncube.v52;
      s6PortableUtils = s6-portable-utils;
      s6LinuxUtils = s6-linux-utils;
      mimeTypes = mime-types;
      libstdcxx = gcc-unwrapped.lib;
  };

dockerArgHints = {
    init = false;
    read_only = true;
    network = "host";
    environment = { HTTPD_PORT = "$SOCKET_HTTP_PORT"; PHP_INI_SCAN_DIR = ":${rootfs}/etc/phpsec/$SECURITY_LEVEL"; };
    tmpfs = [
      "/tmp:mode=1777"
      "/run/bin:exec,suid"
    ];
    ulimits = [
      { name = "stack"; hard = -1; soft = -1; }
    ];
    security_opt = [ "apparmor:unconfined" ];
    cap_add = [ "SYS_ADMIN" ];
    volumes = [
      ({ type = "bind"; source =  "$SITES_CONF_PATH" ; target = "/read/sites-enabled"; read_only = true; })
      ({ type = "bind"; source =  "/etc/passwd" ; target = "/etc/passwd"; read_only = true; })
      ({ type = "bind"; source =  "/etc/group" ; target = "/etc/group"; read_only = true; })
      ({ type = "bind"; source = "/opcache"; target = "/opcache"; })
      ({ type = "bind"; source = "/home"; target = "/home"; })
      ({ type = "bind"; source = "/opt/postfix/spool/maildrop"; target = "/var/spool/postfix/maildrop"; })
      ({ type = "bind"; source = "/opt/postfix/spool/public"; target = "/var/spool/postfix/public"; })
      ({ type = "bind"; source = "/opt/postfix/lib"; target = "/var/lib/postfix"; })
      ({ type = "tmpfs"; target = "/run"; })
    ];
  };

gitAbbrev = firstNChars 8 (getEnv "GIT_COMMIT");

in 

pkgs.dockerTools.buildLayeredImage rec {
  maxLayers = 124;
  name = "docker-registry.intr/webservices/apache2-php52";
  tag = if gitAbbrev != "" then gitAbbrev else "latest";
  contents = [
    rootfs
    tzdata
    locale
    postfix
    sh
    coreutils
    perl
    perl528Packages.Mojolicious
    perl528Packages.base
    perl528Packages.libxml_perl
    perl528Packages.libnet
    perl528Packages.libintl_perl
    perl528Packages.LWP
    perl528Packages.ListMoreUtilsXS
    perl528Packages.LWPProtocolHttps
  ] ++ collect isDerivation php52Packages;
  config = {
    Entrypoint = [ "${rootfs}/init" ];
    Env = [
      "TZ=Europe/Moscow"
      "TZDIR=${tzdata}/share/zoneinfo"
      "LOCALE_ARCHIVE_2_27=${locale}/lib/locale/locale-archive"
      "LC_ALL=en_US.UTF-8"
    ];
    Labels = flattenSet rec {
      ru.majordomo.docker.arg-hints-json = builtins.toJSON dockerArgHints;
      ru.majordomo.docker.cmd = dockerRunCmd dockerArgHints "${name}:${tag}";
      ru.majordomo.docker.exec.reload-cmd = "${apacheHttpd}/bin/httpd -d ${rootfs}/etc/httpd -k graceful";
    };
  };
}
