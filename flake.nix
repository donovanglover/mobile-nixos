{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { ... }: {
    nixosModules = {
      pine64-pinephone = import ./devices/pine64-pinephone;
      module-list = import ./modules/module-list.nix;
    };
  };
}
