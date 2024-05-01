{
  imports = [
    ./access.nix
    ./bootloader.nix
    ./disk.nix

    ./http-services.nix
    ./marlowe-playground
    ./marlowe-runtime.nix
    ./marlowe-runner.nix
  ];

  nixpkgs.localSystem.system = "x86_64-linux";

  system.stateVersion = "23.11";
}
