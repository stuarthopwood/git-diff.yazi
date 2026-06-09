--- @sync entry
-- git-diff.yazi — toggle the preview pane between normal file preview and
-- the hovered file's uncommitted `git diff`. Press the bound key to flip.
--
-- How it works:
--   * A wildcard previewer (registered in yazi.toml) runs this plugin's peek()
--     for EVERY file. When the toggle is OFF it delegates to the built-in
--     `code` previewer, so normal previews are completely unaffected.
--   * When ON, it runs `git diff --color` for the hovered file and renders the
--     ANSI output in the pane.
--   * The `entry` (keybound, sync context) flips a persisted flag and re-emits
--     `peek` to force a redraw.

local PLUGIN = "git-diff"

-- Read the toggle flag from the shared sync state.
local get_enabled = ya.sync(function(state)
	return state.enabled or false
end)

-- Flip the toggle flag and return the new value.
local toggle_enabled = ya.sync(function(state)
	state.enabled = not (state.enabled or false)
	return state.enabled
end)

local M = {}

-- Keybound action (sync). Flip the flag, then force the previewer to re-run
-- for the currently hovered file starting at the top (skip 0).
function M:entry(job)
	local on = toggle_enabled()
	local h = cx.active.current.hovered
	if h then
		-- tostring the url before emit: passing the Url transfers ownership.
		ya.emit("peek", { "0", only_if = tostring(h.url), force = true })
	end
	ya.notify {
		title = "Git Diff",
		content = on and "Diff view ON" or "Diff view OFF",
		timeout = 2,
	}
end

-- Previewer entrypoint (async). Either delegate to `code`, or render git diff.
function M:peek(job)
	if not get_enabled() then
		-- Toggle off: behave exactly like the normal file previewer.
		return require("code"):peek(job)
	end

	local file = job.file
	local path = tostring(file.url)

	-- Parent dir as cwd so git resolves the right repo for the hovered file.
	local cwd = path:match("^(.*)[/\\][^/\\]+$") or "."

	local child, err = Command("git")
		:cwd(cwd)
		:arg({ "--no-pager", "diff", "--color=always", "--", path })
		:stdout(Command.PIPED)
		:stderr(Command.PIPED)
		:output()

	if not child then
		return require("empty").msg(job, "git diff failed: " .. tostring(err))
	end

	local out = child.stdout or ""
	if out == "" then
		-- No uncommitted changes (or file not tracked) — say so plainly.
		local stderr = child.stderr or ""
		local msg = stderr ~= "" and stderr or "No uncommitted changes"
		return require("empty").msg(job, msg)
	end

	-- Honour vertical scrolling (J/K) via job.skip by dropping leading lines.
	if job.skip and job.skip > 0 then
		local lines, n = {}, 0
		for line in (out .. "\n"):gmatch("(.-)\n") do
			n = n + 1
			if n > job.skip then
				lines[#lines + 1] = line
			end
		end
		out = table.concat(lines, "\n")
	end

	ya.preview_widget(job, ui.Text.parse(out):area(job.area):wrap(ui.Wrap.NO))
end

-- Scrolling. When toggled off, defer to code's seek; when on, adjust skip.
function M:seek(job)
	if not get_enabled() then
		return require("code"):seek(job)
	end
	local h = cx.active.current.hovered
	if not h or h.url ~= job.file.url then
		return
	end
	local step = math.floor(job.units)
	if step == 0 then
		step = job.units > 0 and 1 or -1
	end
	local skip = math.max(0, (cx.active.preview.skip or 0) + step)
	ya.emit("peek", { tostring(skip), only_if = tostring(job.file.url) })
end

return M
