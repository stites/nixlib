{
  outputs = {
    self,
    nixpkgs,
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
        pkgs,
        packages,
      }:
        with pkgs.lib.strings;
        with pkgs.lib.lists; let
          mx = maxStringLength names;
          names = packageNames packages;
          descs = descriptions packages;
          rpads = map (name: let
            padSize = mx - (stringLength name);
          in
            pkgs.lib.strings.fixedWidthString padSize " " "");
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

      apps.cachix-push = {
        pkgs,
        cache,
      }:
        with pkgs;
        with pkgs.lib.strings; let
          script = writeScriptBin "cachix-push" (concatStringsSep "\n" [
            # Push flake inputs: as flake inputs are downloaded from the
            # internet, they can disappear
            ''
              nix flake archive --json \
                | jq -r '.path,(.inputs|to_entries[].value.path)' \
                | ${pkgs.cachix}/bin/cachix push ${cache}
            ''
            # Pushing runtime closure of all packages in a flake:
            ''
              nix build --json \
                | jq -r '.[].outputs | to_entries[].value' \
                | ${pkgs.cachix}/bin/cachix push ${cache}
            ''
            # Pushing shell environment
            ''
              nix develop --profile dev-profile --command 'pwd'
              ${pkgs.cachix}/bin/cachix push ${cache} dev-profile
            ''
          ]);
        in {
          type = "app";
          program = "${script}/bin/cachix-push";
        };

      apps.cachix-pull = {pkgs}:
        with pkgs;
        with pkgs.lib.strings; let
          script = writeScriptBin "cachix-pull" (concatStringsSep "\n" [
            # Optional as we already set substituters above
            # "${pkgs.cachix}/bin/cachix use ${cache}"
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
      pkgs = import nixpkgs {inherit system;};
    in {
      default = pkgs.mkShell {
        buildInputs = [pkgs.alejandra];
      };
    });
  };
}
