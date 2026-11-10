// Builds dist/ProfBalance-<version>.zip with a top-level ProfBalance/ folder, ready for CurseForge.
// Version is read from the TOC. Uses PowerShell's Compress-Archive (Windows).
const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const root = path.resolve(__dirname, "..");
const addon = root; // TOC and Lua files live in the repository root
const toc = fs.readFileSync(path.join(addon, "ProfBalance.toc"), "utf8");
const version = (toc.match(/^## Version:\s*(\S+)/m) || [])[1];
if (!version) { console.error("No ## Version in TOC"); process.exit(1); }

const dist = path.join(root, "dist");
fs.mkdirSync(dist, { recursive: true });
const out = path.join(dist, `ProfBalance-${version}.zip`);
fs.rmSync(out, { force: true });

// Stage a clean copy so nothing but the addon files end up in the zip.
const stage = path.join(dist, "stage");
fs.rmSync(stage, { recursive: true, force: true });
fs.mkdirSync(path.join(stage, "ProfBalance"), { recursive: true });
const skip = new Set(["node_modules", ".git", ".github", "tests", "tools", "docs", "dist", "README.md"]);
fs.cpSync(addon, path.join(stage, "ProfBalance"), {
  recursive: true,
  filter: (src) => !skip.has(path.basename(src)) && (fs.statSync(src).isDirectory() || /\.(lua|toc|xml|tga|blp)$/i.test(src) || /CHANGELOG\.md$/.test(src)),
});
fs.copyFileSync(path.join(root, "LICENSE"), path.join(stage, "ProfBalance", "LICENSE.txt"));

execFileSync("powershell.exe", [
  "-NoProfile", "-Command",
  `Compress-Archive -Path '${path.join(stage, "ProfBalance")}' -DestinationPath '${out}' -Force`,
], { stdio: "inherit" });
fs.rmSync(stage, { recursive: true, force: true });
console.log("Built " + out);
