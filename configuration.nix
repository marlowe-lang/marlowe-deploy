{
  imports = [
    ./access.nix
    ./bootloader.nix
    ./disk.nix
    ./dev.nix
    ./http-services.nix
    ./konduit-adaptor.nix
    ./konduit-app.nix
    ./konduit-landing.nix

    # ./marlowe-docs-website.nix
    # ./marlowe-playground
    # ./marlowe-runtime.nix
    # ./marlowe-runner.nix
    # ./marlowe-token-plans.nix
    # ./marlowe-website.nix
    # ./node.nix
  ];

  nixpkgs.localSystem.system = "x86_64-linux";

  system.stateVersion = "23.11";
}
