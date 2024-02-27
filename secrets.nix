let
  users = builtins.fromTOML (builtins.readFile ./users.toml);

  admin-keys = builtins.concatMap (user: if user.admin then user.keys else [ ])
    (builtins.attrValues users);

  # system-key = builtins.readFile ./id_ed25519.pub;

  # all-keys = [ system-key ] ++ admin-keys;
in { "id_ed25519.age".publicKeys = admin-keys; }
