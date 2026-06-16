#!/usr/bin/env node

const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");

const input = fs.readFileSync(0, "utf8");

function outputPath() {
  return path.join(
    os.homedir(),
    "Library",
    "Application Support",
    "Mac Work Timer",
    "agent-usage",
    "claude.json"
  );
}

function writeClaudeUsage(rawInput) {
  let payload;
  try {
    payload = JSON.parse(rawInput);
  } catch {
    return false;
  }

  const fiveHour = payload?.rate_limits?.five_hour;
  if (!fiveHour || typeof fiveHour.used_percentage !== "number") {
    return false;
  }

  const weekly = payload?.rate_limits?.weekly;
  const rateLimits = {
    five_hour: {
      used_percentage: fiveHour.used_percentage,
      resets_at: fiveHour.resets_at ?? null,
    },
  };

  if (weekly && typeof weekly.used_percentage === "number") {
    rateLimits.weekly = {
      used_percentage: weekly.used_percentage,
      resets_at: weekly.resets_at ?? null,
    };
  }

  const file = outputPath();
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(
    file,
    JSON.stringify(
      {
        rate_limits: rateLimits,
      },
      null,
      2
    )
  );
  return true;
}

function forwardIfRequested(rawInput) {
  const index = process.argv.indexOf("--forward");
  if (index === -1) {
    return false;
  }

  const command = process.argv.slice(index + 1).join(" ");
  if (!command) {
    return false;
  }

  const result = spawnSync(command, {
    input: rawInput,
    shell: true,
    encoding: "utf8",
  });

  if (result.stdout) {
    process.stdout.write(result.stdout);
  }
  if (result.stderr) {
    process.stderr.write(result.stderr);
  }

  process.exit(result.status ?? 0);
}

const didWrite = writeClaudeUsage(input);
if (!forwardIfRequested(input) && didWrite) {
  process.stdout.write("");
}
