{
  # TODO: Move data partitions to a single bcachefs once https://github.com/nix-community/disko/issues/511 is fixed
  disko.devices.disk = {
    disk0 = {
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            size = "1M";
            type = "EF02"; # grub MBR
          };

          root = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    };
    disk1 = {
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          nix = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/nix";
            };
          };
        };
      };
    };
  };
}
