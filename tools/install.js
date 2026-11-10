// Installs the addon into the WoW: Forever client.
// Default: create a directory junction so edits in this repo show up in game after /reload.
// --copy  : copy files instead of linking (for a frozen install)
// --remove: remove the installed addon (junction or copy)
const fs = require("fs");
const path = require("path");

// The repository root is the addon folder (TOC at root), so the junction points at the repo itself.
// WoW only loads files listed in the TOC, so tests/, tools/ and node_modules/ are ignored by the client.
const src = path.resolve(__dirname, "..");
const addons = process.env.WOW_FOREVER_ADDONS || "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns";
const dst = path.join(addons, "ProfBalance");
const args = new Set(process.argv.slice(2));

function isJunction(p) {
  try { return fs.lstatSync(p).isSymbolicLink(); } catch { return false; }
}

if (!fs.existsSync(addons)) {
  console.error("AddOns folder not found: " + addons + "\nSet WOW_FOREVER_ADDONS to override.");
  process.exit(1);
}

if (args.has("--remove")) {
  if (isJunction(dst)) { fs.unlinkSync(dst); console.log("Removed junction " + dst); }
  else if (fs.existsSync(dst)) { fs.rmSync(dst, { recursive: true }); console.log("Removed folder " + dst); }
  else console.log("Nothing installed at " + dst);
  process.exit(0);
}

if (args.has("--copy")) {
  if (isJunction(dst)) fs.unlinkSync(dst);
  fs.rmSync(dst, { recursive: true, force: true });
  const skip = new Set(["node_modules", ".git", ".github", "tests", "tools", "docs", "dist"]);
  fs.cpSync(src, dst, {
    recursive: true,
    filter: (p) => !skip.has(path.basename(p)) && (fs.statSync(p).isDirectory() || /\.(lua|toc|xml|tga|blp|md|txt)$/i.test(p)),
  });
  console.log("Copied addon to " + dst);
} else {
  if (isJunction(dst)) fs.unlinkSync(dst);
  else if (fs.existsSync(dst)) {
    console.error(dst + " already exists as a real folder. Use --copy to overwrite it, or --remove first.");
    process.exit(1);
  }
  fs.symlinkSync(src, dst, "junction");
  console.log("Linked " + dst + " -> " + src);
}
console.log("Now /reload in game (or restart the client if the addon is new).");
