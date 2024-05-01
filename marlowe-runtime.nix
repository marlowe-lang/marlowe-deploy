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
    # Docs: We don't use domain-based addressing since state is keyed here.
    preprod-tip = {
      network = "preprod";
      domain = "runtime.tip.preprod.marlowe.shealevy.com";
    };
    preview-tip = {
      network = "preview";
      domain = "runtime.tip.preview.marlowe.shealevy.com";
    };
    mainnet-tip = {
      network = "mainnet";
      domain = "runtime.tip.mainnet.marlowe.shealevy.com";
    };

    preprod-051 = {
      domain = "runtime.051.preprod.marlowe.shealevy.com";
      network = "preprod";
      flake = flake_051;
    };
    preview-051 = {
      domain = "runtime.051.preview.marlowe.shealevy.com";
      network = "preview";
      flake = flake_051;
    };
    mainnet-051 = {
      domain = "runtime.051.mainnet.marlowe.shealevy.com";
      network = "mainnet";
      flake = flake_051;
    };
  };
}
