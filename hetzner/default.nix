{ lib, ... }:
let
  cfg = lib.importTOML ./config.toml;
  inherit (cfg) network disk;
in {
  boot = {
    initrd.availableKernelModules = [ "ahci" "nvme" "ext4" ];

    kernelModules = [ "kvm-amd" ];
  };

  disko.devices.disk = {
    disk0.device = "/dev/disk/by-path/${disk.disk1}";
    disk1.device = "/dev/disk/by-path/${disk.disk2}";
  };

  systemd.network.links."10-main" = {
    matchConfig.PermanentMACAddress = network.mac;
    linkConfig.Name = "main";
  };

  networking = {
    interfaces.main = {
      ipv4.addresses = [{
        address = network.ipv4;
        prefixLength = network.netmask4;
      }];

      ipv6.addresses = [{
        address = network.ipv6;
        prefixLength = network.netmask6;
      }];
    };

    # https://docs.hetzner.com/dns-console/dns/general/recursive-name-servers
    nameservers = [ "185.12.64.1" "185.12.64.2" ];

    defaultGateway = network.gateway4;

    defaultGateway6 = {
      address = "fe80::1";
      interface = "main";
    };
  };
}
