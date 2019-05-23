with import <nixpkgs> {};

with lib;

let

  locale = glibcLocales.override {
      allLocales = false;
      locales = ["en_US.UTF-8/UTF-8"];
  };

  postfix = stdenv.mkDerivation rec {
      name = "postfix-${version}";
      version = "3.4.5";
      srcs = [
         ( fetchurl {
            url = "ftp://ftp.cs.uu.nl/mirror/postfix/postfix-release/official/${name}.tar.gz";
            sha256 = "17riwr21i9p1h17wpagfiwkpx9bbx7dy4gpdl219a11akm7saawb";
          })
       ./patch/postfix/mj/lib
      ];
      nativeBuildInputs = [ makeWrapper m4 ];
      buildInputs = [ db openssl cyrus_sasl icu libnsl pcre ];
      sourceRoot = "postfix-3.4.5";
      hardeningDisable = [ "format" ];
      hardeningEnable = [ "pie" ];
      patches = [
       ./patch/postfix/nix/postfix-script-shell.patch
       ./patch/postfix/nix/postfix-3.0-no-warnings.patch
       ./patch/postfix/nix/post-install-script.patch
       ./patch/postfix/nix/relative-symlinks.patch
       ./patch/postfix/mj/sendmail.patch
       ./patch/postfix/mj/postdrop.patch
       ./patch/postfix/mj/globalmake.patch
      ];
       ccargs = lib.concatStringsSep " " ([
          "-DUSE_TLS"
          "-DHAS_DB_BYPASS_MAKEDEFS_CHECK"
          "-DNO_IPV6"
          "-DNO_KQUEUE" "-DNO_NIS" "-DNO_DEVPOLL" "-DNO_EAI" "-DNO_PCRE"
       ]);

       auxlibs = lib.concatStringsSep " " ([
           "-lresolv" "-lcrypto" "-lssl" "-ldb"
       ]);
      preBuild = ''
          cp -pr ../lib/* src/global
          sed -e '/^PATH=/d' -i postfix-install
          sed -e "s|@PACKAGE@|$out|" -i conf/post-install

          # post-install need skip permissions check/set on all symlinks following to /nix/store
          sed -e "s|@NIX_STORE@|$NIX_STORE|" -i conf/post-install

          export command_directory=$out/sbin
          export config_directory=/etc/postfix
          export meta_directory=$out/etc/postfix
          export daemon_directory=$out/libexec/postfix
          export data_directory=/var/lib/postfix
          export html_directory=$out/share/postfix/doc/html
          export mailq_path=$out/bin/mailq
          export manpage_directory=$out/share/man
          export newaliases_path=$out/bin/newaliases
          export queue_directory=/var/spool/postfix
          export readme_directory=$out/share/postfix/doc
          export sendmail_path=$out/bin/sendmail
          make makefiles CCARGS='${ccargs}' AUXLIBS='${auxlibs}'
      '';

      installTargets = [ "non-interactive-package" ];
      installFlags = [ "install_root=installdir" ];

      postInstall = ''
          mkdir -p $out
          cat << EOF > installdir/etc/postfix/main.cf
          mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
          mailbox_size_limit = 0
          recipient_delimiter = +
          message_size_limit = 20480000
          maillog_file = /dev/stdout
          relayhost = mail-checker2.intr
          EOF
          echo "smtp            25/tcp          mail" >> installdir/etc/services
          echo "postlog   unix-dgram n  -       n       -       1       postlogd" >> installdir/etc/postfix/master.cf
          echo "*: /dev/null" >> installdir/etc/aliases
          mv -v installdir/$out/* $out/
          cp -rv installdir/etc $out
          sed -e '/^PATH=/d' -i $out/libexec/postfix/post-install
          wrapProgram $out/libexec/postfix/post-install \
            --prefix PATH ":" ${lib.makeBinPath [ coreutils findutils gnugrep ]}
          wrapProgram $out/libexec/postfix/postfix-script \
            --prefix PATH ":" ${lib.makeBinPath [ coreutils findutils gnugrep gawk gnused ]}
          rm -f $out/libexec/postfix/post-install \
                $out/libexec/postfix/postfix-wrapper \
                $out/libexec/postfix/postfix-script \
                $out/libexec/postfix/.post-install-wrapped \
                $out/libexec/postfix/postfix-tls-script \
                $out/libexec/postfix/postmulti-script \
                $out/libexec/postfix/.postfix-script-wrapped
      '';
  };

  apacheHttpd = stdenv.mkDerivation rec {
      version = "2.4.39";
      name = "apache-httpd-${version}";
      src = fetchurl {
          url = "mirror://apache/httpd/httpd-${version}.tar.bz2";
          sha256 = "18ngvsjq65qxk3biggnkhkq8jlll9dsg9n3csra9p99sfw2rvjml";
      };
      outputs = [ "out" "dev" ];
      setOutputFlags = false; # it would move $out/modules, etc.
      buildInputs = [ perl zlib nss_ldap nss_pam_ldapd openldap];
      prePatch = ''
          sed -i config.layout -e "s|installbuilddir:.*|installbuilddir: $dev/share/build|"
      '';

      preConfigure = ''
          configureFlags="$configureFlags --includedir=$dev/include"
      '';

      configureFlags = [
          "--with-apr=${apr.dev}"
          "--with-apr-util=${aprutil.dev}"
          "--with-z=${zlib.dev}"
          "--with-pcre=${pcre.dev}"
          "--disable-maintainer-mode"
          "--disable-debugger-mode"
          "--enable-mods-shared=all"
          "--enable-mpms-shared=all"
          "--enable-cern-meta"
          "--enable-imagemap"
          "--enable-cgi"
          "--disable-ldap"
          "--with-mpm=prefork"
      ];

      enableParallelBuilding = true;
      stripDebugList = "lib modules bin";
      postInstall = ''
          #mkdir -p $doc/share/doc/httpd
          #mv $out/manual $doc/share/doc/httpd
          mkdir -p $dev/bin

          mv $out/bin/apxs $dev/bin/apxs
      '';

      passthru = {
          inherit apr aprutil ;
      };
  };

  phpioncubepack = stdenv.mkDerivation rec {
      name = "phpioncubepack";
      src =  fetchurl {
          url = "https://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.tar.gz";
          sha256 = "08bq06yr29zns53m603yv5h11ija8vzkq174qhcj4hz7ya05zb4a";
      };
      installPhase = ''
                  mkdir -p  $out/
                  tar zxvf  ${src} -C $out/ ioncube/ioncube_loader_lin_5.2.so
      '';
  };

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

  php52 = stdenv.mkDerivation rec {
      name = "php-5.2.17";
      sha256 = "e81beb13ec242ab700e56f366e9da52fd6cf18961d155b23304ca870e53f116c";
      enableParallelBuilding = true;
      nativeBuildInputs = [ pkgconfig autoconf213 ];

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
      postInstall = ''
          sed -i $out/include/php/main/build-defs.h -e '/PHP_INSTALL_IT/d'
      '';     
  };

  php52Packages.timezonedb = stdenv.mkDerivation rec {
      name = "timezonedb-2019.1";
      src = fetchurl {
          url = "http://pecl.php.net/get/${name}.tgz";
          sha256 = "0rrxfs5izdmimww1w9khzs9vcmgi1l90wni9ypqdyk773cxsn725";
      };
      nativeBuildInputs = [ autoreconfHook ] ;
      buildInputs = [ php52 ];
      makeFlags = [ "EXTENSION_DIR=$(out)/lib/php/extensions" ];
      autoreconfPhase = "phpize";
      postInstall = ''
          mkdir -p  $out/etc/php.d
          echo "extension = $out/lib/php/extensions/timezonedb.so" >> $out/etc/php.d/timezonedb.ini
      '';
  };

  php52Packages.dbase = stdenv.mkDerivation rec {
      name = "dbase-5.1.0";
      src = fetchurl {
          url = "http://pecl.php.net/get/${name}.tgz";
          sha256 = "15vs527kkdfp119gbhgahzdcww9ds093bi9ya1ps1r7gn87s9mi0";
      };
      nativeBuildInputs = [ autoreconfHook ] ;
      buildInputs = [ php52 ];
      makeFlags = [ "EXTENSION_DIR=$(out)/lib/php/extensions" ];
      autoreconfPhase = "phpize";
      postInstall = ''
          mkdir -p  $out/etc/php.d
          echo "extension = $out/lib/php/extensions/dbase.so" >> $out/etc/php.d/dbase.ini
      '';
  };

  php52Packages.intl = stdenv.mkDerivation rec {
      name = "intl-3.0.0";
      src = fetchurl {
          url = "http://pecl.php.net/get/${name}.tgz";
          sha256 = "11sz4mx56pc1k7llgbbpz2i6ls73zcxxdwa1d0jl20ybixqxmgc8";
      };
      nativeBuildInputs = [ autoreconfHook ] ;
      buildInputs = [ php52 icu ];
      makeFlags = [ "EXTENSION_DIR=$(out)/lib/php/extensions" ];
      autoreconfPhase = "phpize";
      postInstall = ''
          mkdir -p  $out/etc/php.d
          ls  $out/lib/php/extensions/
          echo "extension = $out/lib/php/extensions/intl.so" >> $out/etc/php.d/intl.ini
      '';
  };

  php52Packages.zendopcache = stdenv.mkDerivation rec {
      name = "zendopcache-7.0.5";
      src = fetchurl {
          url = "http://pecl.php.net/get/${name}.tgz";
          sha256 = "1h79x7n5pylbc08cxl44fvbi1a1592n0w0mm847jirkqrhxs5r68";
      };
      nativeBuildInputs = [ autoreconfHook ] ;
      buildInputs = [ php52 ];
      makeFlags = [ "EXTENSION_DIR=$(out)/lib/php/extensions" ];
      autoreconfPhase = "phpize";
      postInstall = ''
          mkdir -p  $out/etc/php.d
          cat << EOF > $out/etc/php.d/opcache.ini
          zend_extension = $out/lib/php/extensions/opcache.so
          opcache.enable = On
          opcache.file_cache_only = On
          opcache.file_cache = "/opcache"
          opcache.log_verbosity_level = 4
          EOF
      '';
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

  php52Packages.imagick = stdenv.mkDerivation rec {
      name = "imagick-3.1.2";
      src = fetchurl {
          url = "http://pecl.php.net/get/${name}.tgz";
          sha256 = "528769ac304a0bbe9a248811325042188c9d16e06de16f111fee317c85a36c93";
      };
      nativeBuildInputs = [ autoreconfHook pkgconfig ] ;
      buildInputs = [ php52 imagemagick68 pcre ];
      makeFlags = [ "EXTENSION_DIR=$(out)/lib/php/extensions" ];
      configureFlags = [ "--with-imagick=${imagemagick68}" ];
      autoreconfPhase = "phpize";
      postInstall = ''
          mkdir -p  $out/etc/php.d
          echo "extension = $out/lib/php/extensions/imagick.so" >> $out/etc/php.d/imagick.ini
      '';
  };

#http://mpm-itk.sesse.net/
  apacheHttpdmpmITK = stdenv.mkDerivation rec {
      name = "apacheHttpdmpmITK";
      buildInputs =[ apacheHttpd.dev ];
      src = fetchurl {
          url = "http://mpm-itk.sesse.net/mpm-itk-2.4.7-04.tar.gz";
          sha256 = "609f83e8995416c5491348e07139f26046a579db20cf8488ebf75d314668efcf";
      };
      configureFlags = [ "--with-apxs2=${apacheHttpd.dev}/bin/apxs" ];
      patches = [ ./patch/httpd/itk.patch ];
      postInstall = ''
          mkdir -p $out/modules
          cp -pr /tmp/out/mpm_itk.so $out/modules
      '';
      outputs = [ "out" ];
      enableParallelBuilding = true;
      stripDebugList = "lib modules bin";
  };

  mjerrors = stdenv.mkDerivation rec {
      name = "mjerrors";
      buildInputs = [ gettext ];
      src = fetchGit {
              url = "git@gitlab.intr:shared/http_errors.git";
              ref = "master";
              rev = "f83136c7e6027cb28804172ff3582f635a8d2af7";
            };
      outputs = [ "out" ];
      postInstall = ''
             mkdir -p $out/tmp $out/mjstuff/mj_http_errors
             cp -pr /tmp/mj_http_errors/* $out/mjstuff/mj_http_errors/
      '';
  };

  rootfs = stdenv.mkDerivation rec {
      nativeBuildInputs = [ 
         mjerrors
         phpioncubepack
         php52
         php52Packages.timezonedb
         php52Packages.imagick
         php52Packages.zendopcache
         php52Packages.intl
         php52Packages.dbase
         bash
         apacheHttpd
         apacheHttpdmpmITK
         execline
         coreutils
         findutils
         postfix
         perl
         gnugrep
         zendoptimizer
      ];
      name = "rootfs";
      src = ./rootfs;
      buildPhase = ''
         echo $nativeBuildInputs
         export coreutils="${coreutils}"
         export bash="${bash}"
         export apacheHttpdmpmITK="${apacheHttpdmpmITK}"
         export apacheHttpd="${apacheHttpd}"
         export s6portableutils="${s6-portable-utils}"
         export phpioncubepack="${phpioncubepack}"
         export php52="${php52}"
         export zendoptimizer="${zendoptimizer}"
         export mjerrors="${mjerrors}"
         export postfix="${postfix}"
         echo ${apacheHttpd}
         for file in $(find $src/ -type f)
         do
           echo $file
           substituteAllInPlace $file
         done
      '';
      installPhase = ''
         cp -pr ${src} $out/
      '';
  };

in 

pkgs.dockerTools.buildLayeredImage rec {
    name = "docker-registry.intr/webservices/php52";
    tag = "master";
    contents = [ php52 
                 perl
                 php52Packages.timezonedb
                 php52Packages.imagick
                 php52Packages.zendopcache
                 php52Packages.intl
                 php52Packages.dbase
                 phpioncubepack
                 zendoptimizer
                 bash
                 coreutils
                 findutils
                 apacheHttpd.out
                 apacheHttpdmpmITK
                 rootfs
                 execline
                 tzdata
                 mime-types
                 postfix
                 locale
                 perl528Packages.Mojolicious
                 perl528Packages.base
                 perl528Packages.libxml_perl
                 perl528Packages.libnet
                 perl528Packages.libintl_perl
                 perl528Packages.LWP 
                 perl528Packages.ListMoreUtilsXS
                 perl528Packages.LWPProtocolHttps
                 mjerrors
    ];
      extraCommands = ''
          chmod 555 ${postfix}/bin/postdrop
      '';
   config = {
       Entrypoint = [ "${apacheHttpd}/bin/httpd" "-D" "FOREGROUND" "-d" "${rootfs}/etc/httpd" ];
       Env = [ "TZ=Europe/Moscow" "TZDIR=/share/zoneinfo" "LOCALE_ARCHIVE_2_27=${locale}/lib/locale/locale-archive" "LC_ALL=en_US.UTF-8" "HTTPD_PORT=8074" "HTTPD_SERVERNAME=web15" ];
    };
}

