{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [ gitAndTools.gitFull neovim ];

  nix.settings = {
    max-jobs = 6;
    cores = 0;
    sandbox = true;
    substituters = [ "https://cache.iog.io" ];
    trusted-public-keys =
      [ "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ=" ];
    builders-use-substitutes = true;
    experimental-features = [ "nix-command" "flakes" ];
  };
}
