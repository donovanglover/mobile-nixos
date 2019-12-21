{ config, pkgs, lib, ... }:

let
  inherit (pkgs)
    busybox
    makeInitrd
    mkExtraUtils
    runCommandNoCC
    udev
  ;
  inherit (lib) flatten optionals;

  device_config = config.mobile.device;
  device_name = device_config.name;

  stage-1 = config.mobile.boot.stage-1;

  mobile-nixos-init = pkgs.pkgsStatic.callPackage ../boot/init {};
  init = "${mobile-nixos-init}/bin/init";

  contents =
    (optionals (stage-1 ? contents) (flatten stage-1.contents))
    ++ [
      # Populate /bin/sh to stay POSIXLY compliant.
      # FIXME: Do we care?
      #{ object = "${extraUtils}/bin/sh"; symlink = "/bin/sh"; }

      # FIXME: udev/udevRules module.
      { object = udevRules; symlink = "/etc/udev/rules.d"; }
      { object = init; symlink = "/init"; }
    ]
  ;

  udevRules = runCommandNoCC "udev-rules" {
    allowedReferences = [ extraUtils ];
    preferLocalBuild = true;
  } ''
    mkdir -p $out

    # These 00-env rules are used both by udev to set the environment, and
    # by our bespoke init.
    # This makes it a one-stop-shop for preparing the init environment.
    echo 'ENV{LD_LIBRARY_PATH}="${extraUtils}/lib"' > $out/00-env.rules
    echo 'ENV{PATH}="${extraUtils}/bin"' >> $out/00-env.rules

    cp -v ${udev}/lib/udev/rules.d/60-cdrom_id.rules $out/
    cp -v ${udev}/lib/udev/rules.d/60-persistent-storage.rules $out/
    cp -v ${udev}/lib/udev/rules.d/80-drivers.rules $out/
    cp -v ${pkgs.lvm2}/lib/udev/rules.d/*.rules $out/

    for i in $out/*.rules; do
        substituteInPlace $i \
          --replace ata_id ${extraUtils}/bin/ata_id \
          --replace scsi_id ${extraUtils}/bin/scsi_id \
          --replace cdrom_id ${extraUtils}/bin/cdrom_id \
          --replace ${pkgs.coreutils}/bin/basename ${extraUtils}/bin/basename \
          --replace ${pkgs.utillinux}/bin/blkid ${extraUtils}/bin/blkid \
          --replace ${pkgs.lvm2}/sbin ${extraUtils}/bin \
          --replace ${pkgs.mdadm}/sbin ${extraUtils}/sbin \
          --replace ${pkgs.bash}/bin/sh ${extraUtils}/bin/sh \
          --replace ${udev}/bin/udevadm ${extraUtils}/bin/udevadm
    done

    # Work around a bug in QEMU, which doesn't implement the "READ
    # DISC INFORMATION" SCSI command:
    #   https://bugzilla.redhat.com/show_bug.cgi?id=609049
    # As a result, `cdrom_id' doesn't print
    # ID_CDROM_MEDIA_TRACK_COUNT_DATA, which in turn prevents the
    # /dev/disk/by-label symlinks from being created.  We need these
    # in the NixOS installation CD, so use ID_CDROM_MEDIA in the
    # corresponding udev rules for now.  This was the behaviour in
    # udev <= 154.  See also
    #   http://www.spinics.net/lists/hotplug/msg03935.html
    substituteInPlace $out/60-persistent-storage.rules \
      --replace ID_CDROM_MEDIA_TRACK_COUNT_DATA ID_CDROM_MEDIA
  ''; # */

  extraUtils = mkExtraUtils {
    name = "${device_name}-extra-utils";
    packages = [
      busybox
    ]
      ++ optionals (stage-1 ? extraUtils) stage-1.extraUtils
      ++ [{
      package = runCommandNoCC "empty" {} "mkdir -p $out";
      extraCommand =
        let
          inherit (pkgs) udev;
        in
        ''
          # Copy udev.
          copy_bin_and_libs ${udev}/lib/systemd/systemd-udevd
          copy_bin_and_libs ${udev}/bin/udevadm
          for BIN in ${udev}/lib/udev/*_id; do
            copy_bin_and_libs $BIN
          done
        ''
      ;
    }]
    ;
  };

  initrd = makeInitrd {
    name = "initrd-${device_config.name}";
    inherit contents;
  };
in
  {
    system.build.initrd = "${initrd}/initrd";
  }
