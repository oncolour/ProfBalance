-- Tiny test helper. Uses the real print even though the mock captures the addon's print.
local print = __print or print
T = { passed = 0, failed = 0, failures = {} }
T.print = print

local function fmt(v)
	if type(v) == "string" then return string.format("%q", v) end
	return tostring(v)
end

function T.test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		T.passed = T.passed + 1
		if VERBOSE then print("  ok   " .. name) end
	else
		T.failed = T.failed + 1
		T.failures[#T.failures + 1] = name .. ": " .. tostring(err)
		print("  FAIL " .. name .. ": " .. tostring(err))
	end
end

function T.eq(actual, expected, msg)
	if actual ~= expected then
		error((msg and (msg .. ": ") or "") .. "expected " .. fmt(expected) .. ", got " .. fmt(actual), 2)
	end
end

function T.truthy(v, msg) if not v then error((msg or "expected truthy") .. ", got " .. fmt(v), 2) end end
function T.falsy(v, msg) if v then error((msg or "expected falsy") .. ", got " .. fmt(v), 2) end end
function T.near(actual, expected, eps, msg)
	if math.abs(actual - expected) > (eps or 1e-6) then error((msg or "") .. " expected ~" .. expected .. ", got " .. actual, 2) end
end
function T.contains(s, sub, msg)
	if type(s) ~= "string" or not s:find(sub, 1, true) then error((msg or "") .. " expected " .. fmt(s) .. " to contain " .. fmt(sub), 2) end
end

function T.report()
	print(string.format("%d passed, %d failed", T.passed, T.failed))
	return T.failed
end
