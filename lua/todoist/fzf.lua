local M = {}

local function format_task_entry(task)
  local parts = {}

  if task.id then
    table.insert(parts, string.format("[ID:%s]", task.id))
  end

  if task.priority then
    table.insert(parts, string.format("[P%d]", task.priority))
  end

  if task.due and type(task.due) == "table" and task.due.date then
    table.insert(parts, string.format("[%s]", task.due.date))
  end

  table.insert(parts, task.content or "(no content)")

  return table.concat(parts, " ")
end

local function parse_task_from_entry(entry)
  local id = entry:match("%[ID:(%d+)%]")
  if not id then return nil end
  return { id = id }
end

local preview_file = vim.fn.tempname()

local function create_preview_command(task_map)
  return function(items)
    local entry = items[1]
    local parsed = parse_task_from_entry(entry)

    if not parsed then
      vim.fn.writefile({"Invalid task"}, preview_file)
      return "cat " .. preview_file
    end

    local task = task_map[tostring(parsed.id)]
    if not task then
      vim.fn.writefile({"Task not found"}, preview_file)
      return "cat " .. preview_file
    end

    local due_str = "None"
    if task.due and type(task.due) == "table" then
      due_str = task.due.string or task.due.date or "None"
    end

    local lines = {
      "╔══════════════════════════════════════╗",
      "║          TASK DETAILS                ║",
      "╚══════════════════════════════════════╝",
      "",
      "ID:       " .. (task.id or "N/A"),
      "Content:  " .. (task.content or "N/A"),
      "Priority: " .. (task.priority and ("P" .. task.priority) or "None"),
      "Due:      " .. due_str,
      "Project:  " .. (task.project_id or "Inbox"),
      "Created:  " .. (task.created_at or "Unknown"),
      "",
      "Description:",
      "──────────────────────────────────────",
      task.description or "(no description)",
    }

    vim.fn.writefile(lines, preview_file)
    return "cat " .. preview_file
  end
end

local function handle_complete(entry, task_map, opts)
  local parsed = parse_task_from_entry(entry)
  if not parsed then return end

  local task = task_map[tostring(parsed.id)]
  if task and opts.on_complete then
    opts.on_complete(task)
  end
end

local function handle_view_details(entry, task_map)
  local parsed = parse_task_from_entry(entry)
  if not parsed then return end

  local task = task_map[tostring(parsed.id)]
  if not task then return end

  local due_info = "None"
  if task.due and type(task.due) == "table" then
    due_info = task.due.string or task.due.date or "None"
  end

  local lines = {
    "Task: " .. (task.content or ""),
    "",
    "Details:",
    "  ID: " .. (task.id or ""),
    "  Priority: " .. (task.priority or "None"),
    "  Due: " .. due_info,
    "  Project: " .. (task.project_id or "Inbox"),
    "",
    "Description:",
    task.description or "(none)",
  }

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)

  local width = 60
  local height = #lines + 2
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
  })

  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf })
end

local function update_task_field(task_id, updates, opts)
  local auth = require("todoist.auth")
  local client = require("todoist.client")

  local token = auth.load_token()
  if not token then
    vim.notify("No token found", vim.log.levels.ERROR)
    return
  end

  client.update_task(token, task_id, updates, function(err, updated)
    if err then
      vim.notify("Update failed: " .. err, vim.log.levels.ERROR)
      return
    end
    vim.notify("Task updated", vim.log.levels.INFO)
    if opts.on_refresh then
      opts.on_refresh()
    end
  end)
end

local function edit_content(task, opts)
  vim.ui.input(
    { prompt = "New content: ", default = task.content },
    function(content)
      if not content or content == "" then return end
      update_task_field(task.id, { content = content }, opts)
    end
  )
end

local function edit_due_date(task, opts)
  local default = ""
  if task.due and type(task.due) == "table" then
    default = task.due.string or task.due.date or ""
  end
  vim.ui.input(
    { prompt = "Due (e.g. 'tomorrow', '2024-12-31'): ", default = default },
    function(due)
      if not due then return end
      update_task_field(task.id, { due_string = due }, opts)
    end
  )
end

local function edit_priority(task, opts)
  vim.ui.select(
    { "1 (Normal)", "2 (Medium)", "3 (High)", "4 (Urgent)" },
    { prompt = "Priority:" },
    function(choice)
      if not choice then return end
      local priority = tonumber(choice:match("^(%d)"))
      if priority then
        update_task_field(task.id, { priority = priority }, opts)
      end
    end
  )
end

local function handle_edit(entry, task_map, opts)
  local parsed = parse_task_from_entry(entry)
  if not parsed then return end

  local task = task_map[tostring(parsed.id)]
  if not task then return end

  vim.ui.select(
    { "Content", "Due date", "Priority", "Cancel" },
    { prompt = "Edit what?" },
    function(choice)
      if choice == "Content" then
        edit_content(task, opts)
      elseif choice == "Due date" then
        edit_due_date(task, opts)
      elseif choice == "Priority" then
        edit_priority(task, opts)
      end
    end
  )
end

local function handle_delete(entry, task_map, opts)
  local parsed = parse_task_from_entry(entry)
  if not parsed then return end

  local task = task_map[tostring(parsed.id)]
  if not task then return end

  vim.ui.select(
    { "Yes, delete", "Cancel" },
    { prompt = string.format("Delete '%s'?", task.content or "this task") },
    function(choice)
      if choice ~= "Yes, delete" then return end

      local auth = require("todoist.auth")
      local client = require("todoist.client")

      local token = auth.load_token()
      if not token then
        vim.notify("No token found", vim.log.levels.ERROR)
        return
      end

      client.delete_task(token, task.id, function(err)
        if err then
          vim.notify("Delete failed: " .. err, vim.log.levels.ERROR)
          return
        end
        vim.notify("Task deleted", vim.log.levels.INFO)
        if opts.on_refresh then
          opts.on_refresh()
        end
      end)
    end
  )
end

local function create_actions(task_map, opts)
  local cfg = require("todoist.config").get()

  return {
    [cfg.fzf.keybinds.complete] = function(selected)
      handle_complete(selected[1], task_map, opts)
    end,
    [cfg.fzf.keybinds.view_details] = function(selected)
      handle_view_details(selected[1], task_map)
    end,
    [cfg.fzf.keybinds.edit] = function(selected)
      handle_edit(selected[1], task_map, opts)
    end,
    [cfg.fzf.keybinds.delete] = function(selected)
      handle_delete(selected[1], task_map, opts)
    end,
    [cfg.fzf.keybinds.refresh] = function(selected)
      if opts.on_refresh then opts.on_refresh() end
    end,
  }
end

local function is_today(date_str)
  if not date_str then return false end
  local today = os.date("%Y-%m-%d")
  return date_str == today
end

local function is_overdue(date_str, now)
  if not date_str then return false end
  local year, month, day = date_str:match("(%d+)-(%d+)-(%d+)")
  if not year then return false end
  local task_time = os.time({ year = year, month = month, day = day })
  return task_time < now
end

local function is_within_week(date_str, now)
  if not date_str then return false end
  local year, month, day = date_str:match("(%d+)-(%d+)-(%d+)")
  if not year then return false end
  local task_time = os.time({ year = year, month = month, day = day })
  local week_from_now = now + (7 * 24 * 60 * 60)
  return task_time >= now and task_time <= week_from_now
end

local function filter_by_priority(tasks, priority)
  if not priority then return tasks end
  local filtered = {}
  for _, task in ipairs(tasks) do
    if task.priority == priority then
      table.insert(filtered, task)
    end
  end
  return filtered
end

local function filter_by_date(tasks, filter_type)
  if not filter_type then return tasks end

  local now = os.time()
  local filtered = {}

  for _, task in ipairs(tasks) do
    local include = false

    if filter_type == "today" then
      include = task.due and type(task.due) == "table" and is_today(task.due.date)
    elseif filter_type == "overdue" then
      include = task.due and type(task.due) == "table" and is_overdue(task.due.date, now)
    elseif filter_type == "week" then
      include = task.due and type(task.due) == "table" and is_within_week(task.due.date, now)
    elseif filter_type == "none" then
      include = not task.due or type(task.due) ~= "table"
    end

    if include then
      table.insert(filtered, task)
    end
  end

  return filtered
end

function M.show_tasks_filtered(tasks, opts)
  opts = opts or {}
  local filtered = tasks

  if opts.priority_filter then
    filtered = filter_by_priority(filtered, opts.priority_filter)
  end

  if opts.date_filter then
    filtered = filter_by_date(filtered, opts.date_filter)
  end

  M.show_tasks(filtered, opts)
end

function M.show_tasks(tasks, opts)
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    error("fzf-lua is required. Install it with your plugin manager.")
  end

  opts = opts or {}
  local cfg = require("todoist.config").get()

  local entries = {}
  local task_map = {}

  for _, task in ipairs(tasks) do
    local entry = format_task_entry(task)
    table.insert(entries, entry)
    task_map[tostring(task.id)] = task
  end

  if #entries == 0 then
    vim.notify("No tasks found", vim.log.levels.INFO)
    return
  end

  fzf.fzf_exec(entries, {
    prompt = "Todoist> ",
    winopts = cfg.fzf.winopts,
    preview = create_preview_command(task_map),
    actions = create_actions(task_map, opts),
    fzf_opts = {
      ["--no-multi"] = "",
      ["--layout"] = "reverse",
    },
  })
end

return M
