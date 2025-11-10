{ config, ... }: {
  age.secrets.konduit-adaptor-env-file.file = ./konduit-adaptor-env-file.age;
  konduit-adaptors."konduit.channel" = {
    domain = "ada.konduit.channel";
    env-file = config.age.secrets.konduit-adaptor-env-file.path;
  };
}
