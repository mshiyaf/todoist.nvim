local M = {}

local function format_due(due)
  if not due then
    return ""
  end
  if type(due) == "table" and due.date then
    return due.string or due.date
  end
  return tostring(due)
end

local function build_window()
  local width = math.floor(vim.o.columns * 0.7)
  local height = math.floor(vim.o.lines * 0.6)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
  })

  return buf, win
end

local function set_keymaps(buf, opts)
  local mappings = {
    q = opts.on_close,
    r = opts.on_refresh,
    c = opts.on_complete,
    ["<CR>"] = opts.on_complete,
  }

  for lhs, fn in pairs(mappings) do
    if fn then
      vim.keymap.set("n", lhs, fn, { buffer = buf, silent = true, nowait = true })
    end
  end
end

function M.show_tasks(tasks, opts)
  opts = opts or {}
  local buf, win = build_window()
  local header = {
    string.format("Todoist Tasks (%d)", #tasks),
    string.rep("─", math.floor(vim.o.columns * 0.65)),
  }

  local rows = {}
  for idx, task in ipairs(tasks) do
    local due = format_due(task.due)
    local priority = task.priority and string.rep("!", task.priority) or ""
    local label = string.format("%-4s %-50s %s %s", task.id or ("#" .. idx), task.content or "(no content)", priority, due)
    table.insert(rows, label)
  end

  if #rows == 0 then
    rows = { "No open tasks found" }
  end

  local lines = {}
  for _, line in ipairs(header) do
    table.insert(lines, line)
  end
  for _, line in ipairs(rows) do
    table.insert(lines, line)
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)

  local state = {
    win = win,
    buf = buf,
    tasks = tasks,
    header_offset = #header,
  }

  local function current_task()
    local cursor = vim.api.nvim_win_get_cursor(win)
    local idx = cursor[1] - state.header_offset
    if idx < 1 then
      return nil
    end
    return state.tasks[idx]
  end

  set_keymaps(buf, {
    on_close = function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end,
    on_refresh = function()
      if opts.on_refresh then
        opts.on_refresh()
      end
    end,
    on_complete = function()
      local task = current_task()
      if task and opts.on_complete then
        opts.on_complete(task)
      end
    end,
  })

  return buf, win
end

return M
