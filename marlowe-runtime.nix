{ inputs, lib, ... }:
let
  flake_100 = inputs.marlowe-cardano_1_0_0;
  # The old flake in marlowe-cardano doesn't have Shea recent changes
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
  # When you add/remove particular network cardano-node state will be preserved.
  # Data should be removed manually if it's not needed anymore.
  marlowe.runtimes = {
    # Docs: We don't use domain-based addressing since state is keyed here meaning
    # we don't want to recreate the service on its domain change.
    preprod-tip = {
      network = "preprod";
      domain = "preprod.staging.runtime.marlowe-lang.org";
    };
    preview-tip = {
      network = "preview";
      domain = "preview.staging.runtime.marlowe-lang.org";
    };
    # mainnet-tip = {
    #   network = "mainnet";
    #   domain = "mainnet.staging.runtime.marlowe-lang.org";
    # };
    preprod-051 = {
      domain = "preprod.051.runtime.marlowe-lang.org";
      network = "preprod";
      flake = flake_051;
    };
    preview-051 = {
      domain = "preview.051.runtime.marlowe-lang.org";
      network = "preview";
      flake = flake_051;
    };
    # mainnet-051 = {
    #   domain = "mainnet.051.runtime.marlowe-lang.org";
    #   network = "mainnet";
    #   flake = flake_051;
    # };
    preprod-100 = {
      domain = "preprod.100.runtime.marlowe-lang.org";
      network = "preprod";
      flake = flake_100;
    };
    preview-100 = {
      domain = "preview.100.runtime.marlowe-lang.org";
      network = "preview";
      flake = flake_100;
    };
  };
}
