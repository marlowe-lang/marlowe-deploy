{ inputs, ... }: {
  imports = [ inputs.cardano-node.nixosModules.cardano-node ];
  services.cardano-node = {
    enable = true;
    environment = "mainnet";
    hostAddr = "0.0.0.0";
  };
}
