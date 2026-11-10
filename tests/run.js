// Headless test runner: loads the addon under fengari (Lua in JS) with a WoW API mock.
// Usage: node tests/run.js [-v]
const fs = require("fs");
const path = require("path");
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require("fengari");

const root = path.resolve(__dirname, "..");
const addonDir = root; // the TOC and Lua files live in the repository root
const verbose = process.argv.includes("-v");

const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);

function lerr() {
  const msg = lua.lua_tojsstring(L, -1);
  lua.lua_pop(L, 1);
  return msg;
}

function runFile(file, withAddonArgs) {
  const src = fs.readFileSync(file, "utf8");
  const buf = to_luastring(src);
  if (lauxlib.luaL_loadbuffer(L, buf, buf.length, to_luastring("@" + path.relative(root, file))) !== lua.LUA_OK) {
    throw new Error("load error: " + lerr());
  }
  let nargs = 0;
  if (withAddonArgs) {
    lua.lua_pushstring(L, to_luastring("ProfBalance"));
    lua.lua_getglobal(L, to_luastring("NS"));
    nargs = 2;
  }
  if (lua.lua_pcall(L, nargs, 0, 0) !== lua.LUA_OK) {
    throw new Error("runtime error: " + lerr());
  }
}

// Files the TOC lists, in order.
const toc = fs.readFileSync(path.join(addonDir, "ProfBalance.toc"), "utf8");
const files = toc.split(/\r?\n/).map((l) => l.trim()).filter((l) => l && !l.startsWith("#"));

try {
  if (lauxlib.luaL_dostring(L, to_luastring("NS = {}; VERBOSE = " + (verbose ? "true" : "false"))) !== lua.LUA_OK) throw new Error(lerr());
  runFile(path.join(__dirname, "wow_mock.lua"), false);
  for (const f of files) runFile(path.join(addonDir, f), true);
  runFile(path.join(__dirname, "assert.lua"), false);
  const tests = fs.readdirSync(__dirname).filter((f) => f.endsWith("_test.lua")).sort();
  for (const t of tests) runFile(path.join(__dirname, t), false);
  if (lauxlib.luaL_dostring(L, to_luastring("return T.report()")) !== lua.LUA_OK) throw new Error(lerr());
  const failed = lua.lua_tointeger(L, -1);
  process.exitCode = failed === 0 ? 0 : 1;
} catch (e) {
  console.error(e.message);
  process.exitCode = 2;
}
