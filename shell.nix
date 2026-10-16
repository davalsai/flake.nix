{
  pkgs ? import <nixpkgs> { },
  lib ? pkgs.lib,
  ...
}:
let
  pdoo =
    let
      netbeans = pkgs.writeShellScriptBin "netbeans" ''
        # waypipe workin properly with --xwsl
        export _JAVA_AWT_WM_NONREPARENTING=1
        exec ${pkgs.netbeans}/bin/netbeans "$@"
      '';


      vscodium = pkgs.writeShellScriptBin "codium" ''
        declare warnings="ozone-platform-hint|enable-features|enable-wayland-ime|wayland-text-input-version"

        export NIXOS_OZONE_WL=1

        exec ${pkgs.vscodium}/bin/codium "$@" 2> >(
          >&2 grep -vE "^Warning: '($warnings)' is not in the list of known options"
        )
      '';
    in
    [
      {
        package = netbeans;
        description = "Fixed-up Netbeans for Java development";
        hl-binaries = [ "netbeans" ];
      }
      {
        package = vscodium;
        description = "Fixed-up VSCodium for Ruby development";
        hl-binaries = [ "codium" ];
        dependencies = [
          {
            package = pkgs.ruby;
            hl-binaries = [
              "ruby"
              "bundle"
              "gem"
            ];
          }
          {
            package = pkgs.ruby-lsp;
            hl-binaries = [ "ruby-lsp" ];
          }
          {
            package = pkgs.rufo;
            hl-binaries = [ "rufo" ];
          }
        ];
      }
    ];

  ed =
    let
      csh = pkgs.writeShellScriptBin "csh" ''
        unset LS_COLORS # f*cking obnoxious outdated messy piece of sh*t deal with `ma`
        exec ${pkgs.tcsh}/bin/tcsh "$@"
      '';

      custom = {
        plotdat =
          let
            plotdat = builtins.toFile "plotdat.gnuplot" ''
              if (ARGC < 1) {
                  print "Uso: gnuplot -c script.gp <archivo>"
                  exit
              }

              lineal(x) = a*x + b
              expo(x) = c*x*x + d*x + e

              fit lineal(x) ARG1 via a, b
              fit expo(x) ARG1 via c, d, e

              plot ARG1, \
                lineal(x) title "Fit lineal", \
                expo(x)   title "Fit exponencial"
              pause mouse close
            '';
          in
          pkgs.writeShellScriptBin "plotdat" ''
            gnuplot -c  ${plotdat} "$@"
          '';
      };
    in
    [
      {
        package = csh;
        description = "tcsh wrapper as csh with fix-ups";
        hl-binaries = [ "csh" ];
      }
      {
        package = custom.plotdat;
        description = "custom command to plot data and some function fits";
        hl-binaries = [ "plotdat" ];
      }
    ];

  groups = [
    {
      name = "pdoo";
      group = pdoo;
    }
    {
      name = "ed";
      group = ed;
    }
  ];

  mk-default-group = group: {
    inherit (group) package;
    description = group.description or null;
    hl-binaries = group.hl-binaries or [ ];
    dependencies = group.dependencies or [ ];
  };

  environment = {
    EC_ASM_CFLAGS = { value = "-fno-stack-protector -fno-asynchronous-unwind-tables -fno-omit-frame-pointer -no-pie -fno-if-conversion -fno-tree-ch -fno-reorder-blocks -fno-tree-ter -mmanual-endbr"; description = "Recommended flags to compile no-pie assembly with human-friendly results a C compiler."; };
  };
in
pkgs.mkShell {
  packages =
    let
      get-grp-pkgs = builtins.concatMap (
        {
          package,
          dependencies ? [ ],
          ...
        }:
        [ package ] ++ (if (builtins.length dependencies) == 0 then [ ] else get-grp-pkgs dependencies)
      );
    in
    builtins.concatMap ({ group, ... }: get-grp-pkgs group) groups;

  shellHook =
    let
      esc = "$ESC"; # can't be real
      reset = "${esc}[0m";

      format-pkggrp =
        let
          mk-ident = sep: n: lib.concatMapStrings (_: sep) (lib.range 1 n);

          format-pkg =
            {
              package,
              description,
              hl-binaries,
              dependencies ? [ ],

              ident-level,
            }:
            let
              ident = mk-ident "  " ident-level;
            in
            "${ident}${package.name}${
              if description != null then ": ${description}" else ""
            } (some binaries: ${lib.concatStringsSep " " hl-binaries})"
            + (
              if (builtins.length dependencies) == 0 then
                ""
              else
                "\n${
                  format-pkggrp {
                    ident-level = ident-level + 1;
                    group = dependencies;
                  }
                }"
            );

          format-pkggrp =
            { group, ident-level }:
            lib.concatStringsSep "\n" (
              map (
                group:
                let
                  group' = mk-default-group group;
                in
                format-pkg {
                  inherit ident-level;
                  inherit (group')
                    package
                    description
                    hl-binaries
                    dependencies
                    ;
                }
              ) group
            );
        in
        format-pkggrp;

      msg = lib.concatStringsSep "\n\n" (
        map (
          { name, group }:
          "${esc}[4m${name}${reset}:\n"
          + (format-pkggrp {
            ident-level = 1;
            inherit group;
          })
        ) groups
      );
    in
    ''
      declare ESC=$'\x1b'

      cat <<-EOF
      ${msg}
      EOF

      echo
      echo "$ESC[7mENVIRONMENT$ESC[0m: (remember to spread with "''\'''${(z)FOO}'" in zsh)"
      ${builtins.foldl' (acc: { name, value }: acc + "echo '  ${name}  ${value.description}'\n") "" (lib.attrsToList environment)}
      ${builtins.foldl' (acc: { name, value }: acc + "export ${ name }='${value.value}'\n") "" (lib.attrsToList environment)}
    '';
}
