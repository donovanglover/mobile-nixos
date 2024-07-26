{ lib
, runCommand
, fetchgit
}:

# The minimum set of firmware files required for the device.
runCommand "pine64-pinephone-firmware" {
  src = fetchgit {
    url = "https://megous.com/git/linux-firmware";
    rev = "93a06aaf905d3204b12a48de2fc8cbf384ce7c2b";
    hash = "sha256-RrAeq1kx8PiJecW5eS9x8dkzSQayUCUBiBgMYEPk0Qs=";
  };
  meta.license = lib.licenses.unfreeRedistributableFirmware;
} ''
  mkdir -p "$out/lib/firmware"
  cp -vrf "$src/rtl_bt" $out/lib/firmware/
  cp -vf "$src/anx7688-fw.bin" $out/lib/firmware/
  cp -vf "$src/ov5640_af.bin" $out/lib/firmware/
''
