{
  inputs = {
    # When updating past 23.11, use runtimeEnv in writeShellApplication
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    devenv.url = "github:cachix/devenv";
  };

  outputs = inputs@{ flake-parts, devenv, nixpkgs, self }:
    flake-parts.lib.mkFlake { inherit inputs; } ({ lib, ... }:
      let nixos = self.nixosConfigurations.marlowe.config;
      in {
        imports = [ devenv.flakeModule ];
        systems = [ "x86_64-linux" ];
        flake.nixosConfigurations.marlowe = nixpkgs.lib.nixosSystem {
          modules = lib.singleton ./configuration.nix;
        };

        perSystem = { pkgs, config, ... }:
          let
            utilities = {
              start-vm = pkgs.writeShellApplication {
                name = "start-vm";
                text = ''
                  export QEMU_NET_OPTS="hostfwd=tcp::2221-:22"
                  exec run-nixos-vm
                '';
                runtimeInputs = [ nixos.system.build.vm ];
              };

              initialize-vm = let
                alpine-image = pkgs.fetchurl {
                  url =
                    "https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/cloud/nocloud_alpine-3.19.1-x86_64-bios-tiny-r0.qcow2";
                  hash = "sha256-YsnUOJtcnHpb9khOwaqyDPnpxihAbRDOoDpXtXtBbBI=";
                };

                qemu-args = [
                  # Host kernel virtualization facilities
                  "-enable-kvm"
                  # Boot the Alpine cloud image
                  "-drive"
                  "file=${state-dir}/alpine.qcow2,format=qcow2,if=virtio"
                  # Pass in configuration to allow all users ssh access
                  "-cdrom"
                  cloud-init-config
                  # Enable port-forwarding
                  "-net"
                  "nic,netdev=user.0,model=virtio"
                  "-netdev"
                  "user,id=user.0,hostfwd=tcp::2221-:22"
                  # Disable graphical console
                  "-nographic"
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
                  mkdir -p ${state-dir}
                  install -m644 ${alpine-image} ${state-dir}/alpine.qcow2
                  qemu-system-x86_64 ${lib.concatStringsSep " " qemu-args}
                  rm ${state-dir}/alpine.qcow2
                '';
                runtimeInputs = [ pkgs.qemu_full ];
              };
            };
          in {
            apps =
              lib.mapAttrs (name: prog: { program = "${prog}/bin/${name}"; });
            devenv.shells.default = { config, ... }: {
              env.MARLOWE_VM_STATE = "${config.devenv.root}/state";

              pre-commit.hooks = {
                nixfmt.enable = true;
                deadnix.enable = true;
                statix.enable = true;
              };

              packages = with pkgs;
                [ nixos-rebuild ]
                ++ lib.mapAttrsToList (_: prog: prog) utilities;
            };
          };
      });
}
