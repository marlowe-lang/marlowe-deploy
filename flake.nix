{
  inputs = {
    # When updating past 23.11, use runtimeEnv in writeShellApplication
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    devenv.url = "github:cachix/devenv";
    agenix.url = "github:ryantm/agenix";
    disko.url = "github:nix-community/disko";
    nixos-anywhere.url = "github:shlevy/nixos-anywhere/alpine";
    nixos-anywhere.inputs.nixpkgs.follows = "nixpkgs";
    nixos-images.url = "github:shlevy/nixos-images/doas";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } ({ lib, ... }:
      let
        inherit (inputs)
          self nixpkgs devenv agenix disko nixos-anywhere nixos-images;
        nixos = self.nixosConfigurations.marlowe-vm.config;
      in {
        imports = [ devenv.flakeModule ];
        systems = [ "x86_64-linux" ];
        flake.nixosConfigurations.marlowe-vm = nixpkgs.lib.nixosSystem {
          modules = [ ./configuration.nix disko.nixosModules.disko ./vm.nix ];
        };

        perSystem = { pkgs, config, system, ... }:
          let
            utilities = {
              initialize-vm = let
                alpine-image = pkgs.fetchurl {
                  url =
                    "https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/cloud/nocloud_alpine-3.19.1-x86_64-bios-tiny-r0.qcow2";
                  hash = "sha256-YsnUOJtcnHpb9khOwaqyDPnpxihAbRDOoDpXtXtBbBI=";
                };

                qemu-args = [
                  # Host kernel virtualization facilities
                  "-enable-kvm"
                  # Enough RAM for nixos-anywhere
                  "-m"
                  "2G"
                  # Boot the Alpine cloud image
                  ## We put it on SCSI so that it doesn't get allocated to /dev/vda, ensuring the persistent disks get the same name when initializing and in normal use.
                  "-device"
                  "virtio-scsi-pci,id=scsi"
                  "-drive"
                  ''file="$tmpdir/alpine.qcow2",format=qcow2,if=none,id=alpine''
                  "-device"
                  "scsi-hd,drive=alpine"
                  # Attach the persistent disks
                  "-drive"
                  "file=${state-dir}/disk1.qcow2,format=qcow2,if=virtio"
                  "-drive"
                  "file=${state-dir}/disk2.qcow2,format=qcow2,if=virtio"
                  # Pass in configuration to allow all users ssh access
                  "-cdrom"
                  cloud-init-config
                  # Enable port-forwarding
                  "-net"
                  "nic,netdev=user.0,model=virtio"
                  "-netdev"
                  "user,id=user.0,hostfwd=tcp::2221-:22"
                  # Disable output
                  "-display"
                  "none"
                ];

                state-dir = config.devenv.shells.default.env.MARLOWE_VM_STATE;

                bootstrap-keys = lib.concatLists
                  (lib.mapAttrsToList (_: lib.getAttr "keys")
                    nixos.marlowe.users);

                meta-data = builtins.toFile "meta-data" (builtins.toJSON {
                  public-keys =
                    map (openssh-key: { inherit openssh-key; }) bootstrap-keys;
                });

                cloud-init-config = pkgs.runCommand "cloud-init.iso" {
                  nativeBuildInputs = [ pkgs.cdrkit ];
                } ''
                  cp ${meta-data} meta-data
                  genisoimage -output $out -volid cidata -joliet -rock meta-data
                '';

              in pkgs.writeShellApplication {
                name = "initialize-vm";
                text = ''
                  if [ -d ${state-dir} ]
                  then
                    echo "${state-dir} already exists, I won't automatically clear it." >&2
                    echo "If you're sure you need to (re-)initialize, delete ${state-dir} and try again." >&2
                    exit 1
                  fi
                  prjroot="$(dirname ${state-dir})"

                  # Set up temp space
                  tmpdir="$(mktemp -d)"
                  trap 'rm -fR "$tmpdir"' EXIT

                  # Create the VM disks
                  mkdir -p ${state-dir}
                  qemu-img create -f qcow2 ${state-dir}/disk1.qcow2 -o nocow=on 512G
                  qemu-img create -f qcow2 ${state-dir}/disk2.qcow2 -o nocow=on 512G

                  # Start qemu running Alpine
                  qemu-img create "$tmpdir/alpine.qcow2" -b ${alpine-image} -F qcow2 -f qcow2 1G
                  qemu-system-x86_64 ${lib.concatStringsSep " " qemu-args} &

                  # wait for connection
                  until
                    ssh alpine@localhost -p 2221 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 true
                  do
                    sleep 3
                  done

                  # reboot with kexec enabled
                  ssh alpine@localhost -p 2221 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "doas sed -i 's|APPEND\(.*\)|APPEND\1 kexec_load_disabled=0|' /boot/extlinux.conf && doas reboot"

                  # Make the SSH server key available to the VM
                  mkdir -p "$tmpdir/extra/etc/ssh"
                  (umask a=,u=rw; cd "$prjroot"; agenix -d id_ed25519.age > "$tmpdir/extra/etc/ssh/ssh_host_ed25519_key")

                  # Initialize NixOS install
                  nixos-anywhere --extra-files "$tmpdir/extra" --flake "$prjroot"#marlowe-vm alpine@localhost -p 2221 --post-kexec-ssh-port 2221 --kexec ${nixos-images.packages.x86_64-linux.kexec-installer-nixos-2311-noninteractive}/nixos-kexec-installer-noninteractive-x86_64-linux.tar.gz

                  # wait for connection
                  until
                    ssh alpine@localhost -p 2221 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 true
                  do
                    sleep 3
                  done

                  # Terminate the VM
                  ssh alpine@localhost -p 2221 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "nohup sh -c 'sleep 2; doas poweroff'&"

                  # Wait for qemu to finish
                  wait
                '';
                runtimeInputs = [
                  pkgs.qemu_full
                  pkgs.agenix
                  nixos-anywhere.packages.${system}.default
                ];
              };
            };
          in {
            _module.args.pkgs = import nixpkgs {
              inherit system;
              overlays = [ agenix.overlays.default ];
            };
            apps =
              lib.mapAttrs (name: prog: { program = "${prog}/bin/${name}"; })
              utilities;
            devenv.shells.default = { config, ... }: {
              env.MARLOWE_VM_STATE = "${config.devenv.root}/state";

              pre-commit.hooks = {
                nixfmt.enable = true;
                deadnix.enable = true;
                statix.enable = true;
              };

              packages = [ pkgs.nixos-rebuild pkgs.agenix pkgs.qemu_full ]
                ++ lib.mapAttrsToList (_: prog: prog) utilities;
            };
          };
      });
}
