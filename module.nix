{ self, ... }@inputs:
{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.themes.base16;
  templates = importJSON ./templates.json;
  schemes = importJSON ./schemes.json;

  # mustache engine
  mustache = template-attrs: name: src:
    pkgs.stdenv.mkDerivation ({
      name = "${name}-${template-attrs.scheme-slug}";
      inherit src;
      data = pkgs.writeText "${name}-data" (builtins.toJSON template-attrs);
      phases = [ "buildPhase" ];
      buildPhase = "${pkgs.mustache-go}/bin/mustache $data $src > $out";
      allowSubstitutes = false; # will never be in cache
    });

  # nasty python script for dealing with yaml + different output types
  python = pkgs.python.withPackages (ps: with ps; [ pyyaml ]);
  loadyaml = { src, name ? "yaml" }:
    importJSON (pkgs.stdenv.mkDerivation {
      inherit name src;
      builder = pkgs.writeText "builder.sh" ''
        slug_all=$(${pkgs.coreutils}/bin/basename $src)
        slug=''${slug_all%.*}
        ${python}/bin/python ${./base16writer.py} $slug < ${src} > $out
      '';
      allowSubstitutes = false; # will never be in cache
    });

  theme = loadyaml { src = "${lib.base16.scheme}/${cfg.variant}.yaml"; };
in {
  options = {
    themes.base16 = {
      enable = mkEnableOption "Base16 color schemes";
      scheme = mkOption {
        type = types.anything;
        example = literalExample "gruvbox";
      };
      extraParams = mkOption {
        type = types.attrsOf types.string;
        default = { };
      };
      variant = mkOption {
        type = types.str;
        example = literalExample "gruvbox-light-medium";
      };
    };
  };

  config = mkIf cfg.enable
    (let base16scheme = scheme: pkgs.fetchgit (schemes."${scheme}");
    in rec {
      lib.base16.theme = theme // cfg.extraParams;
      lib.base16.scheme =
        if lib.isString cfg.scheme then base16scheme cfg.scheme else cfg.scheme;
      lib.base16.base16template = repo:
        mustache (theme // cfg.extraParams) repo
        "${pkgs.fetchgit (templates."${repo}")}/templates/default.mustache";
      lib.base16.template = attrs@{ name ? "unknown-template", src, ... }:
        mustache (theme // cfg.extraParams // attrs) name src;

      lib.base16.flatcolor-gtk-theme = pkgs.stdenv.mkDerivation {
        pname = "flatcolor-gtk-theme";
        version = "0a56c50e8c5e2ad35f6174c19a00e01b30874074";

        src = fetchFromGitHub {
          owner = "jasperro";
          repo = "FlatColor";
          rev = version;
          sha256 = "0pv3fmvs8bfkn5fwyg9z8fszknmca4sjs3210k15lrrx75hngi1z";
        };

        patches = [
          ./gtk2.patch
          ./gtk3.patch
          ./gtk32.patch
        ];

        postPatch = ''
          for file in $(ls gtk-3.20/gtk.css gtk-3.0/gtk.css gtk-2.0/gtkrc); do
            ${pkgs.mustache-go}/bin/mustache ${builtins.toJSON lib.base16.theme} $file > $file
          done
        '';

        buildInputs = with pkgs; [ gdk-pixbuf librsvg ];

        propagatedUserEnvPkgs = with pkgs; [ gtk-engine-murrine ];

        installPhase = ''
          runHook preInstall
          mkdir -p $out/share/themes/FlatColor
          cp -a * $out/share/themes/FlatColor/
          runHook postInstall
        '';
      };
    });
}
