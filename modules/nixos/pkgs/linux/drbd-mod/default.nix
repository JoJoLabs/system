{ lib, stdenv, fetchurl, flex, systemd, perl, ... }:
with import <nixpkgs> {};
stdenv.mkDerivation rec {
  pname = "drbd-mod";
  version = "9.2.8";

  src = fetchurl {
    url = "http://pkg.linbit.com//downloads/drbd/9/drbd-${version}.tar.gz";
    sha256 = "511d889439468c32c3a8e8191d0a25cad18c11bc";
  };

  nativeBuildInputs = [ flex ];
  buildInputs = [ perl ];

  configureFlags = [
    "--without-distro"
    "--without-pacemaker"
    "--localstatedir=/var"
    "--sysconfdir=/etc"
  ];

  preConfigure =
    ''
      export PATH=${systemd}/sbin:$PATH
      substituteInPlace user/Makefile.in \
        --replace /sbin '$(sbindir)'
      substituteInPlace user/legacy/Makefile.in \
        --replace '$(DESTDIR)/lib/drbd' '$(DESTDIR)$(LIBDIR)'
      substituteInPlace user/drbdadm_usage_cnt.c --replace /lib/drbd $out/lib/drbd
      substituteInPlace scripts/drbd.rules --replace /usr/sbin/drbdadm $out/sbin/drbdadm
    '';

  makeFlags = [ "SHELL=${stdenv.shell}" ];

  installFlags = [
    "localstatedir=$(TMPDIR)/var"
    "sysconfdir=$(out)/etc"
    "INITDIR=$(out)/etc/init.d"
  ];

  meta = with lib; {
    homepage = "http://www.drbd.org/";
    description = "Distributed Replicated Block Device, a distributed storage system for Linux";
    license = licenses.gpl2;
    platforms = platforms.linux;
  };
}
