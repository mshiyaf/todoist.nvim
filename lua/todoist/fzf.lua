local M = {}

local priority_colors = {
  [4] = 196, -- urgent
  [3] = 208, -- high
  [2] = 39,  -- medium
  [1] = 245, -- normal
}

local project_color_map = {
  berry_red = 161,
  red = 196,
  orange = 208,
  yellow = 226,
  olive_green = 100,
  lime_green = 118,
  green = 34,
  mint_green = 121,
  teal = 30,
  sky_blue = 81,
  light_blue = 39,
  blue = 27,
  grape = 171,
  violet = 135,
  lavender = 183,
  magenta = 201,
  salmon = 209,
  charcoal = 240,
  grey = 247,
  taupe = 244,
}

local function colorize(text, color_code)
  if not color_code then return text end
  return string.format("\27[38;5;%sm%s\27[0m", color_code, text)
end

local function project_color_to_ansi(color)
  if not color then return nil end
  if type(color) == "number" then
    return color
  end
  return project_color_map[color]
end

local function build_project_lookup(projects)
  local lookup = {}

  if projects then
    for _, project in ipairs(projects) do
      if project.id then
        lookup[tostring(project.id)] = {
          name = project.name or ("Project " .. project.id),
          color = project_color_to_ansi(project.color),
        }
      end
    end
  end

  lookup.inbox = lookup.inbox or { name = "Inbox", color = project_color_to_ansi("charcoal") }
  return lookup
end

local function resolve_project(task, lookup)
  local fallback = {
    name = task.project_id and ("Project " .. task.project_id) or "Inbox",
    color = project_color_to_ansi("charcoal"),
  }

  if not lookup then
    return fallback
  end

  local project = lookup[tostring(task.project_id)]
  if project then
    return {
      name = project.name or fallback.name,
      color = project.color or fallback.color,
    }
  end

  if not task.project_id and lookup.inbox then
    return {
      name = lookup.inbox.name or fallback.name,
      color = lookup.inbox.color or fallback.color,
    }
  end

  return fallback
end

local function format_task_entry(task)
  local cfg = require("todoist.config").get()
  local fmt_cfg = cfg.task_format or {}
  local parts = {}

  if fmt_cfg.show_id ~= false and task.id then
    table.insert(parts, string.format("[ID:%s]", task.id))
  end

  if fmt_cfg.show_priority ~= false and task.priority then
    table.insert(parts, string.format("[P%d]", task.priority))
  end

  if fmt_cfg.show_due_date ~= false and task.due and type(task.due) == "table" and task.due.date then
    table.insert(parts, string.format("[%s]", task.due.date))
  end

  table.insert(parts, task.content or "(no content)")

  return table.concat(parts, " ")
end

local function format_today_entry(task, opts)
  local project_lookup = opts and opts.project_lookup or {}
  local project = resolve_project(task, project_lookup)
  local priority = task.priority or 1

  local id_part = string.format("[ID:%s]", task.id or "?")
  local priority_part = colorize(string.format("[P%d]", priority), priority_colors[priority] or priority_colors[1])
  local project_part = colorize("#" .. (project.name or "Project"), project.color)

  local due_suffix = ""
  if task.due and type(task.due) == "table" then
    local time = nil
    if task.due.datetime then
      time = task.due.datetime:match("T(%d%d:%d%d)")
    end
    local label = time or task.due.string or task.due.date
    if label and label ~= "" then
      due_suffix = " @" .. label
    end
  end

  local content = task.content or "(no content)"

  return table.concat({
    id_part,
    priority_part,
    project_part,
    content .. due_suffix,
  }, "  ")
end

local function parse_task_from_entry(entry)
  local id = entry:match("%[ID:(%d+)%]")
  if not id then return nil end
  return { id = id }
end


local function handle_complete(entry, task_map, opts)
  local parsed = parse_task_from_entry(entry)
  if not parsed then return end

  local task = task_map[tostring(parsed.id)]
  if task and opts.on_complete then
    opts.on_complete(task)
  end
end

local function project_label(task, opts)
  if not opts or not opts.project_lookup then
    return task.project_id or "Inbox"
  end

  local project = resolve_project(task, opts.project_lookup)
  return project.name or task.project_id or "Inbox"
end

local function handle_view_details(entry, task_map, opts, fzf_resume_fn)
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
    "  Project: " .. project_label(task, opts),
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
    if fzf_resume_fn then
      vim.schedule(fzf_resume_fn)
    end
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
  local fzf = require("fzf-lua")

  return {
    [cfg.fzf.keybinds.complete] = function(selected)
      handle_complete(selected[1], task_map, opts)
    end,
    [cfg.fzf.keybinds.view_details] = function(selected, fzf_opts)
      handle_view_details(selected[1], task_map, opts, function()
        fzf.resume()
      end)
      return false  -- Keep picker open
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
  for _, task in ipairs(tasks or {}) do
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

  for _, task in ipairs(tasks or {}) do
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

local function merge_tables(base, extra)
  local result = {}

  if base then
    for k, v in pairs(base) do
      result[k] = v
    end
  end

  if extra then
    for k, v in pairs(extra) do
      result[k] = v
    end
  end

  return result
end

local function build_entries(tasks, formatter, opts)
  local entries = {}
  local task_map = {}

  for _, task in ipairs(tasks or {}) do
    local entry = formatter(task, opts)
    table.insert(entries, entry)
    if task.id then
      task_map[tostring(task.id)] = task
    end
  end

  return entries, task_map
end

local function prepare_tasks(tasks, sorter)
  local list = vim.deepcopy(tasks or {})
  if sorter then
    pcall(table.sort, list, sorter)
  end
  return list
end

local function open_picker(tasks, opts)
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    error("fzf-lua is required. Install it with your plugin manager.")
  end

  opts = opts or {}
  local cfg = require("todoist.config").get()
  local formatter = opts.format_entry or format_task_entry
  local sorted_tasks = prepare_tasks(tasks, opts.sorter)
  local entries, task_map = build_entries(sorted_tasks, formatter, opts)

  if #entries == 0 then
    vim.notify("No tasks found", vim.log.levels.INFO)
    return
  end

  local fzf_opts = merge_tables({
    ["--no-multi"] = "",
    ["--layout"] = "reverse",
  }, opts.fzf_opts)

  fzf.fzf_exec(entries, {
    prompt = opts.prompt or "Todoist> ",
    winopts = opts.winopts or cfg.fzf.winopts,
    actions = create_actions(task_map, opts),
    fzf_opts = fzf_opts,
  })
end

function M.show_tasks_filtered(tasks, opts)
  opts = opts or {}
  local filtered = tasks or {}

  if opts.priority_filter then
    filtered = filter_by_priority(filtered, opts.priority_filter)
  end

  if opts.date_filter then
    filtered = filter_by_date(filtered, opts.date_filter)
  end

  M.show_tasks(filtered, opts)
end

function M.show_tasks(tasks, opts)
  open_picker(tasks or {}, opts)
end

local function today_sorter(project_lookup)
  project_lookup = project_lookup or {}
  return function(a, b)
    local pa = a.priority or 1
    local pb = b.priority or 1
    if pa ~= pb then
      return pa > pb
    end

    local proj_a = resolve_project(a, project_lookup)
    local proj_b = resolve_project(b, project_lookup)
    local name_a = (proj_a.name or ""):lower()
    local name_b = (proj_b.name or ""):lower()
    if name_a ~= name_b then
      return name_a < name_b
    end

    local due_a = ""
    local due_b = ""
    if a.due and type(a.due) == "table" then
      due_a = a.due.datetime or a.due.date or ""
    end
    if b.due and type(b.due) == "table" then
      due_b = b.due.datetime or b.due.date or ""
    end
    if due_a ~= due_b then
      return due_a < due_b
    end

    return (a.id or 0) < (b.id or 0)
  end
end

function M.show_today(tasks, opts)
  opts = opts or {}
  opts.project_lookup = opts.project_lookup or build_project_lookup(opts.projects)
  opts.prompt = opts.prompt or "Todoist Today> "
  opts.sorter = opts.sorter or today_sorter(opts.project_lookup)
  opts.format_entry = function(task)
    return format_today_entry(task, opts)
  end
  opts.fzf_opts = merge_tables({ ["--ansi"] = "" }, opts.fzf_opts)

  open_picker(tasks or {}, opts)
end

return M
