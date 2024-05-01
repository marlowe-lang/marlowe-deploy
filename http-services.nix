{ lib, options, config, ... }:
let
  inherit (lib)
    mkOption types mapAttrs mkIf listToAttrs imap0 attrNames mkMerge mapAttrs';

  static-sites-options.options = {
    domain = mkOption {
      type = types.str;
      description = "The domain to host the site on";
    };

    root = mkOption {
      type = types.path;
      description = "The static file root directory to serve";
    };

    index-fallback = mkOption {
      type = types.bool;
      description =
        "Whether to serve index.html if a non-existent file is requested (useful for react client-side routing)";
      default = false;
    };
  };

  proxied-services-options.options = {
    domain = mkOption {
      type = types.str;
      description = "The domain to host the site on";
    };

    prefix = mkOption {
      type = types.str;
      description =
        "The path prefix (of the domain) to serve from this service";
      default = "/";
    };

    systemdConfig = mkOption {
      type = types.functionTo types.attrs;
      description =
        "A function taking a port number and returning a systemd config (`systemd.services.*`) serving the backend at that port";
    };
  };

  cfg = config.http-services;

  static-virtual-hosts = mapAttrs' (_: static-cfg: {
    # TODO: If we have two static-sites at the same domain, this will silently clobber one (should error instead)
    name = static-cfg.domain;
    value = {
      forceSSL = true;
      enableACME = true;
      inherit (static-cfg) root;
      locations =
        mkIf static-cfg.index-fallback { "/".tryFiles = "$uri /index.html"; };
    };
  }) cfg.static-sites;

  port-base = 8000;

  proxy-defs = listToAttrs (imap0 (idx: name:
    let
      proxy-cfg = cfg.proxied-services.${name};
      port = port-base + idx;
    in {
      inherit name;
      value = {
        inherit (proxy-cfg) domain;
        vhost = {
          forceSSL = true;
          enableACME = true;
          locations.${proxy-cfg.prefix} = {
            proxyPass = "http://localhost:${toString port}";
          };
        };
        service = proxy-cfg.systemdConfig port;
      };
    }) (attrNames cfg.proxied-services));

  proxied-virtual-hosts = mapAttrs' (_: def: {
    # TODO: If we have two proxied-services at the same domain, this will silently clobber one (should error unless at different prefixes, should merge if different prefixes)
    name = def.domain;
    value = def.vhost;
  }) proxy-defs;
in {
  options = {
    http-services = {
      static-sites = mkOption {
        type = types.attrsOf (types.submodule static-sites-options);
        description = "Static sites to serve";
        default = { };
      };

      proxied-services = mkOption {
        type = types.attrsOf (types.submodule proxied-services-options);
        description = "Proxied http services to serve";
        default = { };
      };
    };
  };
  config =
    let any-hosts = static-virtual-hosts != { } || proxied-virtual-hosts != { };
    in {
      services.nginx = {
        enable = any-hosts;
        virtualHosts = mkMerge [
          static-virtual-hosts
          proxied-virtual-hosts
          {
            default = {
              locations."/".return = "404";
              default = true;
              rejectSSL = true;
            };
          }
        ];
        recommendedOptimisation = true;
        recommendedProxySettings = true;
      };
      systemd.services = mapAttrs
        (_: def: mkMerge [ def.service { wantedBy = [ "nginx.service" ]; } ])
        proxy-defs;
      networking.firewall.allowedTCPPorts = mkIf any-hosts [ 80 443 ];

      security.acme = mkIf any-hosts {
        acceptTerms = true;
        # TODO change to proper admin
        defaults.email = "shea.levy+acme@iohk.io";
      };
    };
}
