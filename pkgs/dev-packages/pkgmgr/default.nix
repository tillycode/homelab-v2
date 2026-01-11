{
  runCommandLocal,
  python3,
}:
runCommandLocal "pkgmgr" { buildInputs = [ python3 ]; } ''
  mkdir -p $out/{bin,lib/nix}
  cp ${./pkgmgr.py} $out/bin/pkgmgr
  cp ${./eval.nix} $out/lib/nix/eval.nix
  patchShebangs $out/bin/pkgmgr
  substituteInPlace $out/bin/pkgmgr \
    --replace-fail "os.path.dirname(__file__)" "\"$out/lib/nix\""
''
