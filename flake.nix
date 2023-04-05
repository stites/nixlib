{
  # light weight way to get nixpkgs lib in a flake
  inputs.nixlib.url = "github:nix-community/nixpkgs.lib";
  outputs = {
    self,
    nixpkgs,
    nixlib,
    ...
  } @ inputs: let
    # systems I like
    systems = ["x86_64-linux" "i686-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin"];
    lib = with builtins; rec {
      forAllSystems = f:
        listToAttrs (map (name: {
            inherit name;
            value = f name;
          })
          systems);
      maxStringLength = names:
        with builtins;
          foldl' (mx: name:
            if stringLength name > mx
            then stringLength name
            else mx)
          0
          names;
      packageNames = ps:
        map (p:
          if hasAttr "pname" p
          then p.pname
          else p.name)
        ps;
      descriptions = ps:
        map (p:
          if hasAttr "meta" p && hasAttr "description" p.meta
          then p.meta.description
          else "${p}")
        ps;
      menu = {
        packages,
      }:
        with nixlib.lib.strings;
        with nixlib.lib.lists; let
          mx = maxStringLength names;
          names = packageNames packages;
          descs = descriptions packages;
          rpads = map (name: let
            padSize = mx - (stringLength name);
          in
            fixedWidthString padSize " " "");
        in
          concatStringsSep "\n" (
            [
              ''
                echo ""
                echo "Some tools this environment is equipped with:"
                echo ""
              ''
            ]
            ++ (map (
              tpl: let
                name = tpl.fst.fst;
                rightpad = tpl.fst.snd;
                description = tpl.snd;
              in "echo \"${name}${rightpad}\t-- ${description}\""
            ) (zipLists (zipLists names (rpads names)) descs))
          );

      # apps should be run with pkgs.callPackage
      apps.cachix-push = {
        writeScriptBin,
        cache,
      }:
        with nixlib.lib.strings; let
          script = writeScriptBin "cachix-push" (concatStringsSep "\n" [
            # Push flake inputs: as flake inputs are downloaded from the
            # internet, they can disappear
            ''
              nix flake archive --json \
                | jq -r '.path,(.inputs|to_entries[].value.path)' \
                | cachix push ${cache}
            ''
            # Pushing runtime closure of all packages in a flake:
            ''
              nix build --json \
                | jq -r '.[].outputs | to_entries[].value' \
                | cachix push ${cache}
            ''
            # Pushing shell environment
            ''
              nix develop --profile dev-profile --command 'pwd'
              cachix push ${cache} dev-profile
            ''
          ]);
        in {
          type = "app";
          program = "${script}/bin/cachix-push";
        };

      # apps should be run with pkgs.callPackage
      apps.cachix-pull = { writeScriptBin }:
        with nixlib.lib.strings; let
          script = writeScriptBin "cachix-pull" (concatStringsSep "\n" [
            # Optional as we already set substituters above
            # "cachix use ${cache}"
            "nix build" # build with cachix
            "nix develop --profile dev-profile --command 'pwd'" # build dev shell with cachix
            # this last line is important for bootstrapping, especially if you use nix-direnv
          ]);
        in {
          type = "app";
          program = "${script}/bin/cachix-pull";
        };
    };
  in {
    inherit lib;
    devShells = lib.forAllSystems (system: let
      # https://discourse.nixos.org/t/using-nixpkgs-legacypackages-system-vs-import/17462
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default = pkgs.mkShell {
        buildInputs = [pkgs.alejandra];
      };
    });
  };
}
