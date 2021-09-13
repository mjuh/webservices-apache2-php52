{
  description = "Docker container with Apache and PHP builded by Nix";

  inputs.majordomo.url = "git+https://gitlab.intr/_ci/nixpkgs";

  outputs = { self, nixpkgs, majordomo }:
    let
      system = "x86_64-linux";
    in {

      checks.${system}.container =
        import ./test.nix { nixpkgs = majordomo.outputs.nixpkgs; };

      defaultPackage.${system} = self.packages.${system}.container;

      packages.${system} = {
        deploy = majordomo.outputs.deploy { tag = "webservices/apache2-php52"; };
        container = import ./default.nix { nixpkgs = majordomo.outputs.nixpkgs; };
      };

      devShell.${system} = with nixpkgs.legacyPackages.${system};
        mkShell {
          buildInputs = [ nixUnstable ];
          shellHook = ''
            # Fix ssh completion
            # bash: warning: setlocale: LC_CTYPE: cannot change locale (en_US.UTF-8)
            export LANG=C
            . ${nixUnstable}/share/bash-completion/completions/nix
         '';
        };

    };
}
