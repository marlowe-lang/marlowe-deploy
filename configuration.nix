{
  imports = [ ./access.nix ./bootloader.nix ./disk.nix ];

  nixpkgs.localSystem.system = "x86_64-linux";

  system.stateVersion = "23.11";
}
