{ lib, config, pkgs, ... }:
let
  inherit (lib) types mkOption optionals;
  userType = types.submodule {
    options = {
      admin = mkOption {
        type = types.bool;
        default = false;
        description = "Whether the user is an admin";
      };
      keys = mkOption {
        type = types.listOf types.str;
        description = "The user's SSH public key";
      };
      name = mkOption {
        type = types.str;
        description = "The user's name";
      };
    };
  };

  admin-keys = lib.concatMap (name:
    let user = config.marlowe.users.${name};
    in optionals user.admin user.keys)
    (builtins.attrNames config.marlowe.users);
in {
  options = {
    marlowe.users = lib.mkOption {
      type = lib.types.attrsOf userType;
      internal = true;
      description = "The users with access to the machine";
    };
  };
  config = {
    marlowe.users = lib.importTOML ./users.toml;

    users.users = {
      #FIXME should not be needed with --use-remote-sudo, but that's not working...
      root.openssh.authorizedKeys.keys = admin-keys;
    } // lib.mapAttrs (_: user:
      {
        isNormalUser = true;
        openssh.authorizedKeys.keys = user.keys;
        description = user.name;
      } // lib.optionalAttrs user.admin { extraGroups = [ "wheel" ]; })
      config.marlowe.users;

    # Enable SSH + mosh
    environment.systemPackages = with pkgs; [ mosh ];
    services.openssh.enable = true;
    services.openssh.hostKeys = [{
      path = "/etc/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }];
    networking.firewall.allowedTCPPorts = [ 22 ];
    networking.firewall.allowedUDPPortRanges = lib.singleton {
      from = 60001;
      to = 60999;
    };
    security.pam.enableSSHAgentAuth = true;
    security.pam.services.sudo.sshAgentAuth = true;
  };
}
