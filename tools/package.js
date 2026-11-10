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
// Copy only what the addon needs: top-level Lua/TOC files, the Media folder, changelog and licence.
// (The staging dir lives inside the repo, so a recursive copy of the root is not allowed.)
const target = path.join(stage, "ProfBalance");
for (const f of fs.readdirSync(addon)) {
  if (/\.(lua|toc|xml)$/i.test(f)) fs.copyFileSync(path.join(addon, f), path.join(target, f));
}
fs.cpSync(path.join(addon, "Media"), path.join(target, "Media"), { recursive: true });
fs.copyFileSync(path.join(root, "CHANGELOG.md"), path.join(target, "CHANGELOG.md"));
fs.copyFileSync(path.join(root, "LICENSE"), path.join(target, "LICENSE.txt"));

execFileSync("powershell.exe", [
  "-NoProfile", "-Command",
  `Compress-Archive -Path '${path.join(stage, "ProfBalance")}' -DestinationPath '${out}' -Force`,
], { stdio: "inherit" });
fs.rmSync(stage, { recursive: true, force: true });
console.log("Built " + out);
