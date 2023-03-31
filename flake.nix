{
  # inputs = {
  # };

  outputs = {
    self,
    nixpkgs,
    ...
  } @ inputs: let
    systems = ["x86_64-linux" "i686-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin"];
    nixlib = pkgs:
      with builtins; rec {
        forAllSystems = f:
          listToAttrs (map (name: {
              inherit name;
              value = f name;
            })
            systems);
        maxStringLength = names:
          with builtins;
            foldl' (mx: p:
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
            if hasAttr "meta" p
            then p.meta.description
            else "${p}")
          ps;
        menu = packages: with pkgs.lib.strings; with pkgs.lib.lists; let
          mx = maxStringLength names;
          names = packageNames packages;
          descs = descriptions packages;
          rpads = map (name: let
            padSize = n - (stringLength name);
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
            ) (zipLists (zipLists names rpads) descs))
          );
      };
  in {
    lib = nixlib;
    devShells = let
      system = "x86_64-linux";
      pkgs = import nixpkgs {inherit system;};
    in {
      ${system}.default = pkgs.mkShell {
        buildInputs = [pkgs.alejandra];
      };
    };
  };
}
