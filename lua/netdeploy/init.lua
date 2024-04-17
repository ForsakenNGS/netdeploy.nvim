local M = {}
local module_name = "netdeploy"
local vl = vim.loop
local is_windows = vl.os_uname().version:match 'Windows'

local popup_remotes

function M.is_file(path)
	local stat = vl.fs_stat(path)
	return stat and stat.type or false
end

function M.is_fs_root(path)
	if is_windows then
		return path:match '^%a:$'
	else
		return path == '/'
	end
end

-- Escape the given text to do a "regular" string replace using gsub
function M.regex_escape(text)
	return text:gsub("[%(%)%.%%%+%-%*%?%[%^%$%]]", "%%%1")
end

-- Get the configuration for the currently active buffer (if there is one)
function M.get_config()
	local config_name = ".netdeploy.lua"
	local config_path = vim.fn.expand('%:p:h')
	if not config_path or (config_path == "") then
		-- Buffer does not contain a file
		return nil
	end
	-- Find the config file in the current or one of the parent folders
	local config_file = config_path.."/"..config_name
	while not M.is_file(config_file) and not M.is_fs_root(config_path) do
		config_path = vl.fs_realpath(config_path.."/..")
		config_file = config_path.."/"..config_name
	end
	if M.is_file(config_file) then
		local config = dofile(config_file)
		if config.remotes then
			for _, remote in ipairs(config.remotes) do
				remote.localpath = remote.localpath or config_path
			end
		end
		config.path = config_path
		return config
	else
		return nil
	end
end

-- Get the upload url for the given remote (see `M.select_target` comment for an example) Will return e.g. "ftp://example.com/deploy/path/to/file.txt"
function M.get_remote_url(remote, file_abs)
	file_abs = file_abs or vim.fn.expand('%:p')
	local file_rel = file_abs:gsub(M.regex_escape(remote.localpath), '')
	return remote.url:gsub('/*$', '')..file_rel
end

-- Close the popup window if there is one open
function M.select_target_close()
	if popup_remotes then
		vim.api.nvim_win_close(popup_remotes.window, true)
		popup_remotes = nil
	end
end

-- Called when selecting a target within the up-/download popup
function M.select_target_pick(index, close_window)
	if popup_remotes then
		-- Execute the callback function set when opening the popup within `M.select_target` (see below)
		local remote = popup_remotes.config.remotes[tonumber(index)]
		vim.api.nvim_buf_call(popup_remotes.buffer, function()
			popup_remotes.callback(remote)
		end)
		if close_window then
			M.select_target_close()
		end
	end
end

-- Try to select the target for up-/downloading a file, callback_result will be called with a object like {name="Live Server",url="ftp://example.com/deploy/path"}
function M.select_target(callback_result, title)
	local config = M.get_config()
	if not config or not config.remotes or (#config.remotes == 0) then
		-- No config file found or not remotes defined
		return nil
	end
	local n = #config.remotes
	if n == 1 then
		-- Only one remote defined, no popup required
		callback_result(config.remotes[1])
	else
		-- Close any potentially still open popup
		M.select_target_close()
		-- More thann one remote defined, open popup to chose the desired one
		local popup = require("plenary.popup")
		local height = 10
		local width = 30
		local borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" }
		local opts = {}
		for i, remote in ipairs(config.remotes) do
			table.insert(opts, i.." "..(remote.name or remote.url))
		end
		local cb = function(_, remote_sel)
			-- Called by the popup if an item was selected
			local _, _, index = remote_sel:find("(%d+)%s")
			M.select_target_pick(index, false)
			popup_remotes = nil
		end
		popup_remotes = {
			buffer = vim.api.nvim_win_get_buf(0),
			config = config,
			callback = callback_result,
			window = nil,
		}
		popup_remotes.window = popup.create(opts, {
			title = title or "Remotes",
			highlight = "RemotesPopup",
			line = math.floor(((vim.o.lines - height) / 2) - 1),
			col = math.floor((vim.o.columns - width) / 2),
			minwidth = width,
			minheight = height,
			borderchars = borderchars,
			callback = cb
		})
		-- Bind hotkeys for quick selection and closing the popup
		local popup_buf = vim.api.nvim_win_get_buf(popup_remotes.window)
		vim.api.nvim_buf_set_keymap(popup_buf, "n", "q", string.format("<cmd>lua require('%s').select_target_close()<CR>", module_name), { silent = false })
		for i, _ in ipairs(config.remotes) do
			if i < 10 then
				vim.api.nvim_buf_set_keymap(popup_buf, "n", tostring(i), string.format("<cmd>lua require('%s').select_target_pick(%u, true)<CR>", module_name, i), { silent = false })
			else
				break
			end
		end
	end
end

-- Upload the file currently active to one of the configured remotes
function M.upload()
	M.select_target(function(remote)
		local url = M.get_remote_url(remote)
		if not url then
			vim.api.nvim_err_writeln("No remote found/selected!")
			return
		end
		vim.cmd({ cmd = 'w', args = { url }, bang = true })
		vim.api.nvim_echo({ {"NetDeployUpload to "..url} }, true, {})
	end, "Upload to ...")
end

-- Download the file currently active from one of the configured remotes
function M.download()
	M.select_target(function(remote)
		local url = M.get_remote_url(remote)
		if not url then
			vim.api.nvim_err_writeln("No remote found/selected!")
			return
		end
		vim.cmd("1,$d")
		vim.cmd({ cmd = 'Nread', args = { url }, mods = { silent = true } })
		vim.cmd("1d")
		vim.api.nvim_echo({ {"NetDeployDownload from "..url} }, true, {})
	end, "Download from ...")
end

-- Edit remote file
function M.edit_remote()
    M.select_target(function(remote)
		local url = M.get_remote_url(remote)
		if not url then
			vim.api.nvim_err_writeln("No remote found/selected!")
			return
		end
		vim.cmd({ cmd = 'e', args = { url } })
		vim.api.nvim_echo({ {"NetDeployEditRemote to "..url} }, true, {})
    end, "Edit on remote ...");
end

function M.setup(opts)
	vim.api.nvim_create_user_command("NetDeployUpload", M.upload, {});
	vim.api.nvim_create_user_command("NetDeployDownload", M.download, {});
	vim.api.nvim_create_user_command("NetDeployEditRemote", M.edit_remote, {});
	if opts and opts.defaultKeybinds then
		vim.keymap.set('n', '<leader>du', M.upload, {})
		vim.keymap.set('n', '<leader>dd', M.download, {})
        vim.keymap.set('n', '<leader>de', M.edit_remote, {})
	end
end

return M

