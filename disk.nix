{
  # TODO: Move data partitions to a single bcachefs once https://github.com/nix-community/disko/issues/511 is fixed
  disko.devices = {
    disk = {
      disk0 = {
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            mbr = {
              size = "1M";
              type = "EF02"; # grub MBR
            };

            boot = {
              size = "2G";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/boot";
              };
            };

            pv = {
              size = "100%";
              content = {
                type = "lvm_pv";
                vg = "pool";
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
            pv = {
              size = "100%";
              content = {
                type = "lvm_pv";
                vg = "pool";
              };
            };
          };
        };
      };
    };

    lvm_vg = {
      pool = {
        type = "lvm_vg";
        lvs = {
          root = {
            size = "100%FREE";
            lvm_type = "raid0";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    };
  };
}
