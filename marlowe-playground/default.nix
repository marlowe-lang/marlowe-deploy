{ config, ... }: {
  age.secrets.marlowe-playground-jwt.file = ./jwt.age;
  age.secrets.marlowe-playground-gh.file = ./gh.age;
  marlowe.playgrounds."play.marlowe.shealevy.com" = {
    jwt-signature-file = config.age.secrets.marlowe-playground-jwt.path;
    github-client-id = "34224008df1522ba5929";
    github-client-secret-file = config.age.secrets.marlowe-playground-gh.path;
  };
}
