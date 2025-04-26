{
  projectRootFile = "treefmt.nix";

  # You can add formatters for your languages.
  # See https://github.com/numtide/treefmt-nix#supported-programs

  programs.nixfmt.enable = true;

  programs.actionlint.enable = true;

  programs.ocamlformat.enable = true;
}
