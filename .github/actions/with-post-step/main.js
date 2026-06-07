const { basename } = require("node:path");
const { spawn } = require("node:child_process");

function run(cmd) {
  const subprocess = spawn(cmd, { stdio: "inherit", shell: "/bin/bash" });
  subprocess.on("exit", (exitCode) => {
    process.exitCode = exitCode;
  });
}

switch (basename(process.argv[1])) {
  case "main.js":
    run(process.env.INPUT_MAIN);
    break;
  case "post.js":
    run(process.env.INPUT_POST);
    break;
}
