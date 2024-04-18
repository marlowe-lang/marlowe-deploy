{
  inputs = {
    # When updating past 23.11, use runtimeEnv in writeShellApplication
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    nixpkgsHetznerHead = {
      url = "github:shlevy/nixpkgs/hetznerHEAD";
      flake = false;
    };
    devenv.url = "github:cachix/devenv";
    agenix.url = "github:ryantm/agenix";
    disko.url = "github:nix-community/disko";
    nixos-anywhere.url = "github:nix-community/nixos-anywhere";
    nixos-anywhere.inputs.nixpkgs.follows = "nixpkgs";
    nixos-images.url = "github:nix-community/nixos-images";
    marlowe-playground.url = "github:shlevy/marlowe-playground/marlowe-deploy";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } ({ lib, ... }:
      let
        inherit (inputs)
          self nixpkgs devenv agenix disko nixos-anywhere nixos-images
          marlowe-playground nixpkgsHetznerHead;
        base-modules = [
          ./configuration.nix
          agenix.nixosModules.default
          disko.nixosModules.disko
          marlowe-playground.nixosModules.default
        ];
      in {
        imports = [ devenv.flakeModule ];
        systems = [ "x86_64-linux" ];
        flake.nixosConfigurations.marlowe-vm =
          nixpkgs.lib.nixosSystem { modules = base-modules ++ [ ./vm.nix ]; };
        flake.nixosConfigurations.marlowe-hetzner =
          nixpkgs.lib.nixosSystem { modules = base-modules ++ [ ./hetzner ]; };

        perSystem = { pkgs, config, system, ... }:
          let
            inherit (pkgs)
              agenix python3 writeShellApplication fetchurl runCommand cdrkit
              qemu_full;
            prjroot = dirOf config.devenv.shells.default.env.MARLOWE_VM_STATE;
            initialize-common = writeShellApplication {
              name = "initialize-common";
              text = ''
                tmpdir="$1"
                ssh_port="$2"
                ssh_host="$3"
                variant="$4"

                # Make the SSH server key available to the VM
                mkdir -p "$tmpdir/extra/etc/ssh"
                (umask a=,u=rw; cd "${prjroot}"; agenix -d id_ed25519.age > "$tmpdir/extra/etc/ssh/ssh_host_ed25519_key")
                # Initialize NixOS install
                nixos-anywhere --extra-files "$tmpdir/extra" --flake "${prjroot}#marlowe-$variant" "$ssh_host" -p "$ssh_port" --post-kexec-ssh-port "$ssh_port" --kexec ${nixos-images.packages.x86_64-linux.kexec-installer-nixos-2311-noninteractive}/nixos-kexec-installer-noninteractive-x86_64-linux.tar.gz
                rm -fR "$tmpdir/extra"
              '';
              runtimeInputs =
                [ agenix nixos-anywhere.packages.${system}.default ];
            };
            hetznerAddr = (lib.importTOML ./hetzner/config.toml).network.ipv4;
            utilities = {
              redeploy-hetzner = writeShellApplication {
                name = "redeploy-hetzner";
                text = ''
                  nixos-rebuild "''${1:-switch}" --flake "${prjroot}#marlowe-hetzner" --target-host root@${hetznerAddr} --use-substitutes
                '';
              };
              initialize-hetzner = let
                pythonWithHetzner = python3.withPackages (p: [ p.hetznerHEAD ]);
              in writeShellApplication {
                name = "initialize-hetzner";
                text = ''
                  # Set up temp space
                  tmpdir="$(mktemp -d)"
                  trap 'rm -fR "$tmpdir"' EXIT

                  (umask a=,u=rw; cd "${prjroot}"; agenix -d hetzner/auth-config.age > "$tmpdir/auth-config")
                  python ${prjroot}/hetzner/prepare-rescue.py \
                    --auth-config "$tmpdir/auth-config" \
                    --users ${prjroot}/users.toml \
                    --server-addr ${hetznerAddr}
                  rm "$tmpdir/auth-config"

                  initialize-common "$tmpdir" 22 root@${hetznerAddr} hetzner

                  # wait for connection
                  until
                    ssh root@${hetznerAddr} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 true
                  do
                    sleep 3
                  done
                '';
                runtimeInputs = [ pythonWithHetzner agenix initialize-common ];
              };
              initialize-vm = let
                alpine-image = fetchurl {
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
                    self.nixosConfigurations.marlowe-vm.config.marlowe.users);

                meta-data = builtins.toFile "meta-data" (builtins.toJSON {
                  public-keys =
                    map (openssh-key: { inherit openssh-key; }) bootstrap-keys;
                });

                cloud-init-config = runCommand "cloud-init.iso" {
                  nativeBuildInputs = [ cdrkit ];
                } ''
                  cp ${meta-data} meta-data
                  genisoimage -output $out -volid cidata -joliet -rock meta-data
                '';

              in writeShellApplication {
                name = "initialize-vm";
                text = ''
                  # Set up temp space
                  tmpdir="$(mktemp -d)"
                  trap 'rm -fR "$tmpdir"' EXIT

                  rm -fR ${state-dir}

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

                  initialize-common "$tmpdir" 2221 alpine@localhost vm

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
                runtimeInputs = [ qemu_full initialize-common ];
              };
            };
          in {
            _module.args.pkgs = import nixpkgs {
              inherit system;
              overlays = [
                inputs.agenix.overlays.default
                (_self: super: {
                  pythonPackagesExtensions = super.pythonPackagesExtensions ++ [
                    (pself: _psuper: {
                      hetznerHEAD = pself.callPackage (nixpkgsHetznerHead
                        + "/pkgs/development/python-modules/hetzner") {
                          head = true;
                        };
                    })
                  ];
                })
              ];
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
