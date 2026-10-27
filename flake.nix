{
  description = "Context-aware session management for Ghostel";

  inputs = {
    flake-parts = {
      inputs = {
        nixpkgs-lib = {
          follows = "nixpkgs";
        };
      };

      url = "git+https://github.com/hercules-ci/flake-parts.git?ref=main";
    };

    nixpkgs = {
      url = "git+https://github.com/NixOS/nixpkgs.git?ref=nixpkgs-unstable";
    };
  };

  outputs =
    inputs@{
      flake-parts,
      nixpkgs,
      self,
      ...
    }:
    let
      inherit (flake-parts.lib)
        mkFlake
        ;

      projectRoot = ./.;
    in
    mkFlake
      {
        inherit
          inputs
          ;

        specialArgs = {
          inherit
            projectRoot
            ;
        };
      }
      {
        flake = {
          overlays = {
            default =
              _: prev:
              let
                inherit (prev)
                  emacsPackagesFor
                  fetchurl
                  lib
                  runCommandLocal
                  ;

                inherit (lib)
                  concatMapStringsSep
                  escapeShellArg
                  licenses
                  maintainers
                  ;

                emacs-ghostel-dwim =
                  {
                    ghostel,
                    melpaBuild,
                    ...
                  }:
                  melpaBuild {
                    files = ''("ghostel-dwim.el")'';

                    meta = {
                      description = "Context-aware session management for Ghostel";
                      homepage = "https://github.com/brsvh/emacs-ghostel-dwim";
                      license = licenses.gpl3Plus;
                      maintainers = with maintainers; [ brsvh ];
                    };

                    packageRequires = [
                      ghostel
                    ];

                    pname = "ghostel-dwim";
                    src = projectRoot + /src;
                    version = "0.1.0";
                  };

                ghostel =
                  upstreamGhostel:
                  upstreamGhostel.overrideAttrs (
                    finalAttrs: prevAttrs: {
                      passthru = prevAttrs.passthru // {
                        module = prevAttrs.passthru.module.overrideAttrs (
                          moduleFinalAttrs: _: {
                            # Zig 0.16 uses the project-local dependency cache.
                            postConfigure = ''
                              cp -rLT ${moduleFinalAttrs.zigDeps} zig-pkg
                              chmod -R u+w zig-pkg
                            '';
                          }
                        );
                      };

                      zigDeps =
                        let
                          # Content-addressed entries cover several Ghostel versions.
                          dependencies = [
                            {
                              hash = "sha256-F+iIY/NgBnKrSRgvIXKBtvxNPHYr3jYZNeQ2qVIU0Fw=";
                              url = "https://deps.files.ghostty.org/zlib-1220fed0c74e1019b3ee29edae2051788b080cd96e90d56836eea857b0b966742efb.tar.gz";
                              zigHash = "N-V-__8AAB0eQwD-0MdOEBmz7intriBReIsIDNlukNVoNu6o";
                            }
                            {
                              hash = "sha256-FKLtu1Ccs+UamlPj9eQ12/WXFgS0uDPmPmB26MCpl7U=";
                              url = "https://deps.files.ghostty.org/glslang-12201278a1a05c0ce0b6eb6026c65cd3e9247aa041b1c260324bf29cee559dd23ba1.tar.gz";
                              zigHash = "N-V-__8AABzkUgISeKGgXAzgtutgJsZc0-kkeqBBscJgMkvy";
                            }
                            {
                              hash = "sha256-V0QDwSO92JJpn3iUv1+F+Bzjyg2a8YzpiFBBqLnR4/A=";
                              url = "https://deps.files.ghostty.org/ghostty-themes-release-20261005-151109-31756e7.tgz";
                              zigHash = "N-V-__8AADNBBQDD4MFOa3Y7R_A8PHIeWQ1IZdOiBFZS3nZ7";
                            }
                            {
                              hash = "sha256-Veg7FtCRCCUCvxSb9FfzH0IJLFmCZQ4/+657SIcb8Ro=";
                              url = "https://deps.files.ghostty.org/pixels-12207ff340169c7d40c570b4b6a97db614fe47e0d83b5801a932dcd44917424c8806.tar.gz";
                              zigHash = "N-V-__8AADYiAAB_80AWnH1AxXC0tql9thT-R-DYO1gBqTLc";
                            }
                            {
                              hash = "sha256-yRhQPVk9cNr0hE0XWhPYFq+stmfAb7oeydzVACwVGLc=";
                              url = "https://deps.files.ghostty.org/gettext-0.24.tar.gz";
                              zigHash = "N-V-__8AADcZkgn4cMhTUpIz6mShCKyqqB-NBtf_S2bHaTC-";
                            }
                            {
                              hash = "sha256-g2U+uDe661v8fVDJG31EdyeW4IwcJDE04Rxe32yNFcU=";
                              url = "https://deps.files.ghostty.org/ghostty-themes-release-20260831-151010-752a9c0.tgz";
                              zigHash = "N-V-__8AAEFmBABuDGOKxAI6VMg41b9euMZ-z7HS9EcUdaor";
                            }
                            {
                              hash = "sha256-yBbCDox18+Fa6Gc1DnmSVQLRpqhZOLsac7iSfl8x+cs=";
                              url = "https://deps.files.ghostty.org/N-V-__8AAEbOfQBnvcFcCX2W5z7tDaN8vaNZGamEQtNOe0UI.tar.gz";
                              zigHash = "N-V-__8AAEbOfQBnvcFcCX2W5z7tDaN8vaNZGamEQtNOe0UI";
                            }
                            {
                              hash = "sha256-3S3xSrX0EDgleq7cxLX7msDuAY8/D5SvkJcCjmDTMiM=";
                              url = "https://deps.files.ghostty.org/N-V-__8AAFdWDwA0ktbNUi9pFBHCRN4weXIgIfCrVjfGxqgA.tar.gz";
                              zigHash = "N-V-__8AAFdWDwA0ktbNUi9pFBHCRN4weXIgIfCrVjfGxqgA";
                            }
                            {
                              hash = "sha256-8WNRuv4hRyX+LB1bWfDZPkmQWkskeJn7kNcM/5U6K5s=";
                              url = "https://deps.files.ghostty.org/harfbuzz-11.0.0.tar.xz";
                              zigHash = "N-V-__8AAG02ugUcWec-Ndp-i7JTsJ0dgF8nnJRUInkGLG7G";
                            }
                            {
                              hash = "sha256-bCgFni4+60K1tLFkieORamNGwQladP7jvGXNxdiaYhU=";
                              url = "https://deps.files.ghostty.org/libxml2-2.11.5.tar.gz";
                              zigHash = "N-V-__8AAG3RoQEyRC2Vw7Qoro5SYBf62IHn3HjqtNVY6aWK";
                            }
                            {
                              hash = "sha256-h9T4iT704I8iSXNgj/6/lCaKgTgLp5wS6IQZaMgKohI=";
                              url = "https://deps.files.ghostty.org/highway-66486a10623fa0d72fe91260f96c892e41aceb06.tar.gz";
                              zigHash = "N-V-__8AAGmZhABbsPJLfbqrh6JTHsXhY6qCaLAQyx25e0XE";
                            }
                            {
                              hash = "sha256-ABqhIC54RI9MC/GkjHblVodrNvFtks4yB+zP1h2Z8qA=";
                              url = "https://deps.files.ghostty.org/oniguruma-1220c15e72eadd0d9085a8af134904d9a0f5dfcbed5f606ad60edc60ebeccd9706bb.tar.gz";
                              zigHash = "N-V-__8AAHjwMQDBXnLq3Q2QhaivE0kE2aD138vtX2Bq1g7c";
                            }
                            {
                              hash = "sha256-xXppHouCrQmLWWPzlZAy5AOPORCHr3cViFulkEYQXMQ=";
                              url = "https://deps.files.ghostty.org/JetBrainsMono-2.304.tar.gz";
                              zigHash = "N-V-__8AAIC5lwAVPJJzxnCAahSvZTIlG-HhtOvnM1uh-66x";
                            }
                            {
                              hash = "sha256-/syVtGzwXo4/yKQUdQ4LparQDYnp/fF16U/wQcrxoDo=";
                              url = "https://deps.files.ghostty.org/libpng-1220aa013f0c83da3fb64ea6d327f9173fa008d10e28bc9349eac3463457723b1c66.tar.gz";
                              zigHash = "N-V-__8AAJrvXQCqAT8Mg9o_tk6m0yf5Fz-gCNEOKLyTSerD";
                            }
                            {
                              hash = "sha256-QnIB9dUVFnDQXB9bRb713aHy592XHvVPD+qqf/0quQw=";
                              url = "https://deps.files.ghostty.org/freetype-1220b81f6ecfb3fd222f76cf9106fecfa6554ab07ec7fdc4124b9bb063ae2adf969d.tar.gz";
                              zigHash = "N-V-__8AAKLKpwC4H27Ps_0iL3bPkQb-z6ZVSrB-x_3EEkub";
                            }
                            {
                              hash = "sha256-XFi6IUrNjmvKNCbcCLAixGqN2Zeymhs+KLrfccIN9EE=";
                              url = "https://deps.files.ghostty.org/plasma_wayland_protocols-12207e0851c12acdeee0991e893e0132fc87bb763969a585dc16ecca33e88334c566.tar.gz";
                              zigHash = "N-V-__8AAKYZBAB-CFHBKs3u4JkeiT4BMvyHu3Y5aaWF3Bbs";
                            }
                            {
                              hash = "sha256-6kGR1o5DdnflHzqs3ieCmBAUTpMdOXoyfcYDXiw5xQ0=";
                              url = "https://deps.files.ghostty.org/wayland-9cb3d7aa9dc995ffafdbdef7ab86a949d0fb0e7d.tar.gz";
                              zigHash = "N-V-__8AAKrHGAAs2shYq8UkE6bGcR1QJtLTyOE_lcosMn6t";
                            }
                            {
                              hash = "sha256-XO3K3egbdeYPI+XoO13SuOtO+5+Peb16NH0UiusFMPg=";
                              url = "https://deps.files.ghostty.org/wayland-protocols-258d8f88f2c8c25a830c6316f87d23ce1a0f12d9.tar.gz";
                              zigHash = "N-V-__8AAKw-DAAaV8bOAAGqA0-oD7o-HNIlPFYKRXSPT03S";
                            }
                            {
                              hash = "sha256-mChCgSYKXu9bT2OlXxbEv2p4ihAgptsDfssPcfozaYg=";
                              url = "https://deps.files.ghostty.org/gtk4-layer-shell-1.1.0.tar.gz";
                              zigHash = "N-V-__8AALiNBAA-_0gprYr92CjrMj1I5bqNu0TSJOnjFNSr";
                            }
                            {
                              hash = "sha256-bMqYlD0amQdmzvYQd8Ca/1k4Bj/heh7+EijlQSttatk=";
                              url = "https://deps.files.ghostty.org/breakpad-b99f444ba5f6b98cac261cbb391d8766b34a5918.tar.gz";
                              zigHash = "N-V-__8AALw2uwF_03u4JRkZwRLc3Y9hakkYV7NKRR9-RIZJ";
                            }
                            {
                              hash = "sha256-EWTRuVbUveJI17LwmYxDzJT1ICQxoVZKeTiVsec7DQQ=";
                              url = "https://deps.files.ghostty.org/NerdFontsSymbolsOnly-3.4.0.tar.gz";
                              zigHash = "N-V-__8AAMVLTABmYkLqhZPLXnMl-KyN38R8UVYqGrxqO26s";
                            }
                            {
                              hash = "sha256-i/7FAOAJJvZ5hT7iPWfMOS08MYFzPKRwRzhlHT9wuqM=";
                              url = "https://deps.files.ghostty.org/DearBindings_v0.17_ImGui_v1.92.5-docking.tar.gz";
                              zigHash = "N-V-__8AANT61wB--nJ95Gj_ctmzAtcjloZ__hRqNw5lC1Kr";
                            }
                            {
                              hash = "sha256-tStvz8Ref6abHwahNiwVVHNETizAmZVVaxVsU7pmV+M=";
                              url = "https://deps.files.ghostty.org/spirv_cross-1220fb3b5586e8be67bc3feb34cbe749cf42a60d628d2953632c2f8141302748c8da.tar.gz";
                              zigHash = "N-V-__8AANb6pwD7O1WG6L5nvD_rNMvnSc9Cpg1ijSlTYywv";
                            }
                            {
                              hash = "sha256-T3tVSjjN94wDP2ZsiHHzdJ4UoJT2Wgf2MMke0LQ9NeM=";
                              url = "https://gitlab.freedesktop.org/api/v4/projects/890/packages/generic/fontconfig/2.18.3/fontconfig-2.18.3.tar.xz";
                              zigHash = "N-V-__8AAOgqbADacob-q2_DMQlmgaG4xKHRuW-6PJ4oJzMZ";
                            }
                            {
                              hash = "sha256-F4d9NG95iGUdbGLkWy47BchoCaZELF40YSN0sqlxmhw=";
                              url = "https://deps.files.ghostty.org/wuffs-7411f488fe2e2c205c3d3b3d28638b7356522930.tar.gz";
                              zigHash = "N-V-__8AAP5JWgCGP_AD0teWpa4krRvE9VPZzvviGdbmN4jI";
                            }
                            {
                              hash = "sha256-KsZJfMjWGo0xCT5HrduMmyxFsWsHBbszSoNbZCPDGN8=";
                              url = "https://deps.files.ghostty.org/sentry-1220446be831adcca918167647c06c7b825849fa3fba5f22da394667974537a9c77e.tar.gz";
                              zigHash = "N-V-__8AAPlZGwBEa-gxrcypGBZ2R8Bse4JYSfo_ul8i2jlG";
                            }
                            {
                              hash = "sha256-QsjKuRNbElGOavfcXkYfBVx4uGOtyo7Xd08vt/6ad4Q=";
                              url = "https://github.com/vancluever/arocc/archive/f97cdfc3779aec4b242299e2fc9a1c828c3547c6.tar.gz";
                              zigHash = "aro-0.0.0-JSD1Qk6lNgDdcDV4Vh7Sfy-34m2TluIVOdPzMmj_0BjX";
                            }
                            {
                              hash = "sha256-q+rdCKqM6uFgTYr1NbbwS4Tc2e+DAY8MZ9+r+b/WS78=";
                              url = "https://github.com/ghostty-org/ghostty/archive/0c2a290d3a3e2a599be3a43435d778a5896667ee.tar.gz";
                              zigHash = "ghostty-1.3.2-dev-5UdBC1AtcQWmWYtcqSHFSjhTO1jn8jD5dK9rJ_M7awf5";
                            }
                            {
                              hash = "sha256-gRmkd7svYpbeDS8+W6mBgnsy4VgzOOGsD4UE9hTZKcE=";
                              url = "https://github.com/ghostty-org/ghostty/archive/a2e440396403385680008e456a741a7776091412.tar.gz";
                              zigHash = "ghostty-1.3.2-dev-5UdBC_qIewUDn1YOAhdr9LRbORjQ_zcsVMd8EygTzjWq";
                            }
                            {
                              hash = "sha256-kBTbVw2wbj+/z623syqordrMaWnnAWUGg8HHRCitumw=";
                              url = "https://deps.files.ghostty.org/gobject-2026-07-28-36-1.tar.zst";
                              zigHash = "gobject-0.3.2-Skun7F6HogCMynX2JqeSHS7xr-8pK4ob-qRFIcEasVi3";
                            }
                            {
                              hash = "sha256-4rmyJM14EBFWq7j0ZHmlH2zOZsSBXGMoVuIKFEDdArc=";
                              url = "https://deps.files.ghostty.org/libxev-9ce8e8e6ff89e583258a7f8e7adeeeaeae8611bf.tar.gz";
                              zigHash = "libxev-0.0.0-86vtcwIRFADbH4hk-EjROXxlrKIRPQdA41XiTSytYO-F";
                            }
                            {
                              hash = "sha256-j7D1xqPos78ONSJdOrwSMLz28f3xYkZ/H3R+wvpe2gc=";
                              url = "https://codeberg.org/vancluever/translate-c/archive/4e879eb8aba615de112eabd1231ea6e01920cead.tar.gz";
                              zigHash = "translate_c-0.0.0-Q_BUWhVNBwDOEcIqub4VFPJPB6D9dgwzUMHTX5KWr8Xr";
                            }
                            {
                              hash = "sha256-fnb8f6seescoxSs1u7PluMY5hBq/x/4aS8sTBQWUvJ4=";
                              url = "https://deps.files.ghostty.org/uucode-2826a37a4562284fdacd8fa029d49509cc9bffcd.tar.gz";
                              zigHash = "uucode-0.2.0-ZZjBPlK5VADj7fdoq7G8LIHzD5o6FSkcBXXrRWr4jnrA";
                            }
                            {
                              hash = "sha256-aNI1Q8ssbF39vfOLODdeDG1BKlxftyzga9E596TSUTI=";
                              url = "https://github.com/jacobsandlund/uucode/archive/9d55524551411b493cca41ca06363625d90aff1e.tar.gz";
                              zigHash = "uucode-0.2.0-ZZjBPuuFVgC8YZ8eld4fOKsZANLIhTFMzULQxhkLi1C7";
                            }
                            {
                              hash = "sha256-PqBQ6QWIfEa8oaLBjkHW7fV0wapuv7xc88UoRideT6g=";
                              url = "https://deps.files.ghostty.org/vaxis-1dbbe575dff4586fe51e3217aa5c3fecdcbb6089.tar.gz";
                              zigHash = "vaxis-0.6.0-BWNV_CrbCQCscGpzsAlR402rYQ_tV3aAl081c2iRRkka";
                            }
                            {
                              hash = "sha256-z6mP7BCEeWGhofqtsEZ5LXrRD3OhQQscGp+r08MFAgU=";
                              url = "https://github.com/rockorager/libvaxis/archive/c1e1f23be38951c425cdf31af455ba23ef178940.tar.gz";
                              zigHash = "vaxis-0.6.0-BWNV_MjFCQCs9UDHiRkrgw_ayeiPkzOe4xVbaAqXkUWW";
                            }
                            {
                              hash = "sha256-dZpjLjapSODkEtLXSkOmnS805l1AKJoWr3qjclhS7yU=";
                              url = "https://deps.files.ghostty.org/wayland-0.6.0-lQa1kqz8AQADQmdNJsNhLoNHcnEGEUjrOaPV-dtEnEmX.tar.gz";
                              zigHash = "wayland-0.6.0-lQa1kqz8AQADQmdNJsNhLoNHcnEGEUjrOaPV-dtEnEmX";
                            }
                            {
                              hash = "sha256-5VydCxVu2t3+oy+xwONZfhtjBrmk7BiI4vgAjFmLztg=";
                              url = "https://deps.files.ghostty.org/z2d-7dbae85c81784dba9988320bf9543ed9a81350c8.tar.gz";
                              zigHash = "z2d-0.12.1-j5P_Hsw8EQAKyZTQICCQnAH2xYkLDW8k9uefbsYdfPZ-";
                            }
                            {
                              hash = "sha256-ykvBCf2dl87a4vW9uHnMeMNG1DwUo046Kr0u6SCMhUc=";
                              url = "https://deps.files.ghostty.org/zf-c35c421f84895193246db06c40683c1a30e616ef.tar.gz";
                              zigHash = "zf-0.11.0-OIRy8X-RAAAwaRXHMYpj2uvBnuGTZWEE_3V7acqHQNtW";
                            }
                            {
                              hash = "sha256-ov9IiiRDAfTllGmlIyqtaGmwGsxQ99ftJkfAKaV9Szs=";
                              url = "https://deps.files.ghostty.org/zig_js-3c23860e47fdcdc5af805efb7fd0bdac5fd3e9bc.tar.gz";
                              zigHash = "zig_js-0.0.0-rjCAV7-GAADvMTBL7lPMuvDk7xgS9PCMIZWiOUXLZSlj";
                            }
                            {
                              hash = "sha256-gx6uxVS7I+8gIp8ecF2PU+iinIKYQLuND17bBcdtbfA=";
                              url = "https://deps.files.ghostty.org/zig_objc-c8de82ff80281215ad92900866dab7103a8efa8b.tar.gz";
                              zigHash = "zig_objc-0.0.0-Ir_Sp9gsAQCPAJc0oF5xoWePHWP6Y6tCphDeyNUThJoi";
                            }
                            {
                              hash = "sha256-SHeUtvKKg4DReklg08U+8vRm0wdbkujr8/hOxrVoVF0=";
                              url = "https://github.com/zigimg/zigimg/archive/d695acd97c02e57bb151e8f659d1280f5cd6ca70.tar.gz";
                              zigHash = "zigimg-0.1.0-8_eo2oyaFwBZwJpmqPkCfVXWBrHcqbYwmrp1I6bTD3lI";
                            }
                          ];
                        in
                        runCommandLocal "${finalAttrs.pname}-${finalAttrs.version}-zig-deps"
                          {
                            inherit (finalAttrs)
                              src
                              ;

                            nativeBuildInputs = [
                              finalAttrs.zig
                            ];
                          }
                          ''
                            export ZIG_GLOBAL_CACHE_DIR=$(mktemp -d)
                            mkdir -p "$ZIG_GLOBAL_CACHE_DIR/tmp"
                            runHook unpackPhase
                            cd "$sourceRoot"

                            ${concatMapStringsSep "\n" (
                              dependency:
                              let
                                archive = fetchurl {
                                  inherit (dependency)
                                    hash
                                    url
                                    ;
                                };
                              in
                              ''
                                test "$(zig fetch ${archive})" = ${escapeShellArg dependency.zigHash}
                              ''
                            ) dependencies}

                            # Verify the complete graph without network access.
                            if ! zig build --fetch=all; then
                              echo "ghostel ${finalAttrs.version}: refresh dependencies in flake.nix" >&2
                              exit 1
                            fi

                            mv zig-pkg "$out"
                          '';
                    }
                  );

                scope =
                  finalAttrs: prevAttrs:
                  prevAttrs.override {
                    manualPackages = prevAttrs.manualPackages // {
                      ghostel = ghostel prevAttrs.manualPackages.ghostel;
                      ghostel-dwim = finalAttrs.callPackage emacs-ghostel-dwim { };
                    };
                  };
              in
              {
                emacsPackagesFor = emacs: (emacsPackagesFor emacs).overrideScope scope;
              };
          };
        };

        perSystem =
          {
            system,
            ...
          }:
          {
            _module = {
              args = {
                pkgs = import nixpkgs {
                  inherit
                    system
                    ;

                  overlays = [
                    self.overlays.default
                  ];
                };
              };
            };
          };

        systems = [
          "x86_64-linux"
        ];
      };
}
