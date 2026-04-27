{
  writeShellApplication,
  fence,
  jq,
  git,
}:
writeShellApplication {
  name = "fence";
  runtimeInputs = [
    jq
    git
    fence
  ];
  text = builtins.readFile ./fence.bash;
}
