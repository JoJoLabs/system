{ lib, stdenv, fetchurl, flex, systemd, perl, kernel, pkgs, ... }:
stdenv.mkDerivation rec {
  pname = "drbd-mod";
  version = "9.2.8";

  src = fetchurl {
    url = "http://pkg.linbit.com//downloads/drbd/9/drbd-${version}.tar.gz";
    sha256 = "2ea2b594fb9c69bef02af701e1528676f048abe2bd5edb8eda6d033f95ed2b73";
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
      export PATH=${systemd}/sbin:${pkgs.coccinelle}/bin:$PATH
      substituteInPlace drbd/Makefile \
        --replace /sbin '$(sbindir)'
    '';

  preBuild = ''
    export PATH=${systemd}/sbin:${pkgs.coccinelle}/bin:$PATH
  '';
  
  makeFlags = [ "SHELL=${stdenv.shell}" "KDIR='${kernel.dev}/lib/modules/${kernel.modDirVersion}/build'" ];

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
