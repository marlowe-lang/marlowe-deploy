{ modulesPath, ... }: {
  disko.devices.disk = {
    disk0.device = "/dev/vda";
    disk1.device = "/dev/vdb";
  };

  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
}
