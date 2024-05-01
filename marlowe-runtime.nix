{ inputs, lib, ... }:
let
  flake_051 = let self = inputs.marlowe-cardano_0_5_1;
  in self // {
    sqitch-plan-dirs = {
      # Ensure this path only changes when sqitch.plan file is updated, or DDL
      # files are updated.
      chain-sync = (builtins.path {
        path = self;
        name = "marlowe-chain-sync-sqitch-plan";
        filter = path: _:
          path == "${self}/marlowe-chain-sync" || path
          == "${self}/marlowe-chain-sync/sqitch.plan"
          || lib.hasPrefix "${self}/marlowe-chain-sync/deploy" path
          || lib.hasPrefix "${self}/marlowe-chain-sync/revert" path;
      }) + "/marlowe-chain-sync";

      # Ensure this path only changes when sqitch.plan file is updated, or DDL
      # files are updated.
      runtime = (builtins.path {
        path = self;
        name = "marlowe-runtime-sqitch-plan";
        filter = path: _:
          path == "${self}/marlowe-runtime" || path
          == "${self}/marlowe-runtime/marlowe-indexer" || path
          == "${self}/marlowe-runtime/marlowe-indexer/sqitch.plan"
          || lib.hasPrefix "${self}/marlowe-runtime/marlowe-indexer/deploy" path
          || lib.hasPrefix "${self}/marlowe-runtime/marlowe-indexer/revert"
          path;
      }) + "/marlowe-runtime/marlowe-indexer";
    };
  };
in {
  marlowe.runtimes = {
    "runtime.tip.preprod.marlowe-lang.org".network = "preprod";
    "runtime.tip.preview.marlowe-lang.org".network = "preview";
    "runtime.tip.mainnet.marlowe-lang.org".network = "mainnet";
    "runtime.051.preprod.marlowe-lang.org" = {
      network = "preprod";
      flake = flake_051;
    };
    "runtime.051.preview.marlowe-lang.org" = {
      network = "preview";
      flake = flake_051;
    };
    "runtime.051.mainnet.marlowe-lang.org" = {
      network = "mainnet";
      flake = flake_051;
    };
  };
}
