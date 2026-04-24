local M = {}

local sessions = {}

local config = {
	width = 0.9,
	height = 0.9,
	position = "float",
	close = "<C-q>",
}

local function open_window(buf, name)
	local win
	if config.position == "float" then
		local w = math.floor(vim.o.columns * config.width)
		local h = math.floor(vim.o.lines * config.height)
		win = vim.api.nvim_open_win(buf, true, {
			relative = "editor",
			width = w,
			height = h,
			col = math.floor((vim.o.columns - w) / 2),
			row = math.floor((vim.o.lines - h) / 2),
			style = "minimal",
			border = "rounded",
			title = name,
			title_pos = "center",
		})
	elseif config.position == "vsplit" then
		vim.cmd("botright vsplit")
		win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(win, buf)
		vim.api.nvim_win_set_width(win, math.floor(vim.o.columns * config.width))
	elseif config.position == "hsplit" then
		vim.cmd("botright split")
		win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(win, buf)
		vim.api.nvim_win_set_height(win, math.floor(vim.o.lines * config.height))
	end
	return win
end

local function make_close(name)
	return function()
		local s = sessions[name]
		if s and s.win and vim.api.nvim_win_is_valid(s.win) then
			vim.api.nvim_win_close(s.win, false)
			s.win = nil
		end
	end
end

local function destroy_session(name)
	local s = sessions[name]
	if not s then
		return
	end
	if s.win and vim.api.nvim_win_is_valid(s.win) then
		vim.api.nvim_win_close(s.win, false)
	end
	if s.job_id then
		vim.fn.jobstop(s.job_id)
	end
	if s.buf and vim.api.nvim_buf_is_valid(s.buf) then
		vim.api.nvim_buf_delete(s.buf, { force = true })
	end
	sessions[name] = nil
end

local function create_session(cmd, name)
	local buf = vim.api.nvim_create_buf(false, true)
	local win = open_window(buf, name)
	local job_id = vim.fn.termopen(cmd, {
		on_exit = function()
			local s = sessions[name]
			if s then
				s.job_id = nil
			end
		end,
	})
	if config.close then
		local close = make_close(name)
		vim.keymap.set("t", config.close, close, { buffer = buf })
		vim.keymap.set("n", config.close, close, { buffer = buf })
	end
	sessions[name] = { cmd = cmd, name = name, buf = buf, win = win, job_id = job_id }
	vim.cmd("startinsert")
end

local function session_alive(s)
	return s and s.buf and vim.api.nvim_buf_is_valid(s.buf) and s.job_id and vim.fn.jobwait({ s.job_id }, 0)[1] == -1
end

local function show_existing(s, name)
	if not (s.win and vim.api.nvim_win_is_valid(s.win)) then
		s.win = open_window(s.buf, name)
	end
	vim.api.nvim_set_current_win(s.win)
	local line_count = vim.api.nvim_buf_line_count(s.buf)
	vim.api.nvim_win_set_cursor(s.win, { line_count, 0 })
	vim.cmd("startinsert")
end

local function ensure_session(cmd, name)
	local s = sessions[name]
	if session_alive(s) then
		if s.cmd ~= cmd then
			destroy_session(name)
			create_session(cmd, name)
		end
		return
	end
	if s then
		destroy_session(name)
	end
	create_session(cmd, name)
end

function M.toggle(opts)
	local cmd, name = opts.cmd, opts.name
	assert(cmd, "terms.nvim: cmd is required")
	assert(name, "terms.nvim: name is required")

	local s = sessions[name]
	if session_alive(s) then
		if s.cmd ~= cmd then
			destroy_session(name)
			create_session(cmd, name)
			return
		end
		if s.win and vim.api.nvim_win_is_valid(s.win) then
			vim.api.nvim_win_close(s.win, false)
			s.win = nil
			return
		end
		show_existing(s, name)
		return
	end

	if s then
		destroy_session(name)
	end
	create_session(cmd, name)
end

function M.new(opts)
	local cmd, name = opts.cmd, opts.name
	assert(cmd, "terms.nvim: cmd is required")
	assert(name, "terms.nvim: name is required")
	destroy_session(name)
	create_session(cmd, name)
end

function M.delete(opts)
	local name = opts.name
	assert(name, "terms.nvim: name is required")
	destroy_session(name)
end

function M.send(opts)
	local text, cmd, name = opts.text, opts.cmd, opts.name
	assert(text, "terms.nvim: text is required")
	assert(cmd, "terms.nvim: cmd is required")
	assert(name, "terms.nvim: name is required")
	ensure_session(cmd, name)
	local s = sessions[name]
	if not (s and s.job_id) then
		return
	end
	vim.fn.chansend(s.job_id, text)
	if not (s.win and vim.api.nvim_win_is_valid(s.win)) then
		s.win = open_window(s.buf, name)
	end
	vim.api.nvim_set_current_win(s.win)
	local line_count = vim.api.nvim_buf_line_count(s.buf)
	vim.api.nvim_win_set_cursor(s.win, { line_count, 0 })
	vim.cmd("startinsert")
end

function M.send_selection(opts)
	local cmd, name = opts.cmd, opts.name
	local include_context = opts.include_context
	if include_context == nil then
		include_context = true
	end
	assert(cmd, "terms.nvim: cmd is required")
	assert(name, "terms.nvim: name is required")

	local mode = vim.fn.mode()
	local start_pos, end_pos
	if mode:match("[vV\22]") then
		start_pos = vim.fn.getpos("v")
		end_pos = vim.fn.getpos(".")
		if start_pos[2] > end_pos[2] or (start_pos[2] == end_pos[2] and start_pos[3] > end_pos[3]) then
			start_pos, end_pos = end_pos, start_pos
		end
		vim.cmd("normal! \27")
	else
		mode = vim.fn.visualmode()
		start_pos = vim.fn.getpos("'<")
		end_pos = vim.fn.getpos("'>")
	end

	local lines = vim.api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)
	if #lines == 0 then
		return
	end
	if mode == "v" then
		if #lines == 1 then
			lines[1] = lines[1]:sub(start_pos[3], math.min(end_pos[3], #lines[1]))
		else
			lines[1] = lines[1]:sub(start_pos[3])
			lines[#lines] = lines[#lines]:sub(1, math.min(end_pos[3], #lines[#lines]))
		end
	end

	local body = table.concat(lines, "\n")
	local text
	if include_context then
		local ft = vim.bo.filetype
		local fpath = vim.fn.expand("%:p")
		local header = string.format("File: %s, lines %d-%d\n```%s\n", fpath, start_pos[2], end_pos[2], ft)
		text = header .. body .. "\n```\n"
	else
		text = body .. "\n"
	end

	M.send({ text = text, cmd = cmd, name = name })
end

function M.setup(opts)
	config = vim.tbl_deep_extend("force", config, opts or {})
end

return M
