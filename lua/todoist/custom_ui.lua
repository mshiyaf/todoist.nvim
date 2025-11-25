local M = {}

-- Import dependencies from fzf.lua for code reuse
local fzf_module = require("todoist.fzf")

-- Priority color codes (from fzf.lua)
local priority_colors = {
  [4] = 196, -- urgent
  [3] = 208, -- high
  [2] = 39,  -- medium
  [1] = 245, -- normal
}

-- Project color map (from fzf.lua)
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

-- Module-local state
local state = nil

-- Helper: Convert project color name to ANSI code
local function project_color_to_ansi(color)
  if not color then return nil end
  if type(color) == "number" then
    return color
  end
  return project_color_map[color]
end

-- Helper: Build project lookup table (reused from fzf.lua)
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

-- Helper: Resolve project info for a task (reused from fzf.lua)
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

-- Helper: Convert ANSI color to hex for highlight groups
local function ansi_to_hex(ansi_code)
  -- Common 256-color conversions (simplified)
  local ansi_to_hex_map = {
    [196] = "#ff0000", -- red
    [208] = "#ff8700", -- orange
    [39]  = "#00afff", -- cyan/blue
    [245] = "#8a8a8a", -- grey
    [161] = "#d7005f", -- berry_red
    [226] = "#ffff00", -- yellow
    [100] = "#878700", -- olive_green
    [118] = "#87ff00", -- lime_green
    [34]  = "#00af00", -- green
    [121] = "#87ffaf", -- mint_green
    [30]  = "#008787", -- teal
    [81]  = "#5fd7ff", -- sky_blue
    [27]  = "#005fff", -- blue
    [171] = "#d75fff", -- grape
    [135] = "#af5fff", -- violet
    [183] = "#d7afff", -- lavender
    [201] = "#ff00ff", -- magenta
    [209] = "#ff875f", -- salmon
    [240] = "#585858", -- charcoal
    [247] = "#9e9e9e", -- grey
    [244] = "#808080", -- taupe
  }
  return ansi_to_hex_map[ansi_code] or "#ffffff"
end

-- Setup highlight groups
local function setup_highlights()
  local cfg = require("todoist.config").get()
  local custom_cfg = cfg.custom_ui or {}
  local hl_cfg = custom_cfg.highlights or {}

  -- Priority highlights
  vim.api.nvim_set_hl(0, "TodoistP4", hl_cfg.priority_4 or { fg = "#ff5555", bold = true })
  vim.api.nvim_set_hl(0, "TodoistP3", hl_cfg.priority_3 or { fg = "#ffb86c", bold = true })
  vim.api.nvim_set_hl(0, "TodoistP2", hl_cfg.priority_2 or { fg = "#8be9fd" })
  vim.api.nvim_set_hl(0, "TodoistP1", hl_cfg.priority_1 or { fg = "#6272a4" })

  -- UI element highlights
  vim.api.nvim_set_hl(0, "TodoistHeader", hl_cfg.header or { fg = "#f8f8f2", bold = true })
  vim.api.nvim_set_hl(0, "TodoistProject", hl_cfg.project or { fg = "#50fa7b", italic = true })
  vim.api.nvim_set_hl(0, "TodoistDueTime", hl_cfg.due_time or { fg = "#ff79c6" })
  vim.api.nvim_set_hl(0, "TodoistTaskId", { fg = "#6272a4" })
  vim.api.nvim_set_hl(0, "TodoistSeparator", { fg = "#44475a" })
end

-- Format task entry for display (adapted from fzf.lua)
local function format_task_entry(task, project_lookup)
  local project = resolve_project(task, project_lookup)
  local priority = task.priority or 1

  local id_part = string.format("[ID:%s]", task.id or "?")
  local priority_part = string.format("[P%d]", priority)
  local project_part = "#" .. (project.name or "Project")

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

  return string.format("%s  %s  %s  %s%s", id_part, priority_part, project_part, content, due_suffix)
end

-- Create split layout with buffers and windows
local function create_split_layout()
  local cfg = require("todoist.config").get()
  local custom_cfg = cfg.custom_ui or {}
  local split_ratio = custom_cfg.split_ratio or 0.6

  -- Save the original window
  local original_win = vim.api.nvim_get_current_win()

  -- Create scratch buffers
  local list_buf = vim.api.nvim_create_buf(false, true)
  local preview_buf = vim.api.nvim_create_buf(false, true)

  -- Validate buffers were created
  if not vim.api.nvim_buf_is_valid(list_buf) or not vim.api.nvim_buf_is_valid(preview_buf) then
    vim.notify("Failed to create buffers for custom UI", vim.log.levels.ERROR)
    return nil
  end

  -- Configure buffer options
  pcall(function()
    vim.api.nvim_buf_set_option(list_buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(list_buf, 'swapfile', false)
    vim.api.nvim_buf_set_option(list_buf, 'bufhidden', 'wipe')
    vim.api.nvim_buf_set_option(list_buf, 'filetype', 'todoist')

    vim.api.nvim_buf_set_option(preview_buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(preview_buf, 'swapfile', false)
    vim.api.nvim_buf_set_option(preview_buf, 'bufhidden', 'wipe')
  end)

  -- Create vertical split
  vim.cmd('vsplit')
  local list_win = vim.api.nvim_get_current_win()

  -- Check if we're in a different window now (split successful)
  if list_win == original_win then
    -- Try alternative split method
    vim.cmd('new')
    list_win = vim.api.nvim_get_current_win()
  end

  -- Set list buffer
  pcall(vim.api.nvim_win_set_buf, list_win, list_buf)

  -- Set list window width
  local total_width = vim.o.columns
  local list_width = math.floor(total_width * split_ratio)
  pcall(vim.api.nvim_win_set_width, list_win, list_width)

  -- Move to the window on the right
  vim.cmd('wincmd l')
  local preview_win = vim.api.nvim_get_current_win()

  -- If we're still in the same window, create a new one
  if preview_win == list_win then
    vim.cmd('vnew')
    preview_win = vim.api.nvim_get_current_win()
  end

  -- Set preview buffer
  pcall(vim.api.nvim_win_set_buf, preview_win, preview_buf)

  -- Focus back on list window
  pcall(vim.api.nvim_set_current_win, list_win)

  -- Set window options
  pcall(function()
    vim.api.nvim_win_set_option(list_win, 'number', false)
    vim.api.nvim_win_set_option(list_win, 'relativenumber', false)
    vim.api.nvim_win_set_option(list_win, 'cursorline', true)
    vim.api.nvim_win_set_option(list_win, 'wrap', false)

    vim.api.nvim_win_set_option(preview_win, 'number', false)
    vim.api.nvim_win_set_option(preview_win, 'relativenumber', false)
    vim.api.nvim_win_set_option(preview_win, 'wrap', true)
  end)

  return {
    list_buf = list_buf,
    preview_buf = preview_buf,
    list_win = list_win,
    preview_win = preview_win,
  }
end

-- Group tasks by priority
local function group_tasks_by_priority(tasks)
  local grouped = {
    [4] = {},
    [3] = {},
    [2] = {},
    [1] = {},
  }

  for _, task in ipairs(tasks or {}) do
    local priority = task.priority or 1
    table.insert(grouped[priority], task)
  end

  return grouped
end

-- Format priority header
local function format_priority_header(priority, count)
  local labels = {
    [4] = "URGENT",
    [3] = "HIGH",
    [2] = "MEDIUM",
    [1] = "NORMAL",
  }

  local label = labels[priority] or "UNKNOWN"
  return string.format("━━━ %s PRIORITY (%d tasks) ━━━", label, count)
end

-- Render grouped task list with priority headers
local function render_grouped_tasks(buf, tasks, project_lookup)
  -- Validate buffer
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return {}, {}, {}
  end

  local lines = {}
  local task_map = {}
  local line_map = {}
  local line_num = 1

  -- Group tasks by priority
  local grouped = group_tasks_by_priority(tasks)

  local has_tasks = false
  for _, priority in ipairs({ 4, 3, 2, 1 }) do
    if #grouped[priority] > 0 then
      has_tasks = true

      -- Add priority header
      local header = format_priority_header(priority, #grouped[priority])
      table.insert(lines, header)
      line_map[line_num] = { type = "header", priority = priority }
      line_num = line_num + 1

      -- Add tasks in this priority group
      for _, task in ipairs(grouped[priority]) do
        local line = format_task_entry(task, project_lookup)
        table.insert(lines, line)
        line_map[line_num] = { type = "task", task_id = task.id, task = task }
        if task.id then
          task_map[tostring(task.id)] = task
        end
        line_num = line_num + 1
      end

      -- Add separator between groups (except after last group)
      if priority > 1 then
        table.insert(lines, "")
        line_map[line_num] = { type = "separator" }
        line_num = line_num + 1
      end
    end
  end

  if not has_tasks or #tasks == 0 then
    lines = { "", "  No tasks found", "" }
    line_map = {
      [1] = { type = "empty" },
      [2] = { type = "empty" },
      [3] = { type = "empty" },
    }
  end

  -- Set buffer content
  local ok, err = pcall(function()
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  end)

  if not ok then
    vim.notify("Error rendering tasks: " .. tostring(err), vim.log.levels.ERROR)
    return {}, {}, {}
  end

  return line_map, task_map, lines
end

-- Apply highlights to buffer
local function apply_highlights(buf, lines, line_map)
  -- Validate buffer
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local ns = vim.api.nvim_create_namespace("todoist_custom_ui")

  -- Clear existing highlights safely
  pcall(vim.api.nvim_buf_clear_namespace, buf, ns, 0, -1)

  for line_num, line_info in pairs(line_map) do
    local line_idx = line_num - 1 -- 0-indexed
    if line_idx >= 0 and line_idx < #lines then
      if line_info.type == "header" then
        -- Highlight entire header line
        local hl_group = "TodoistP" .. (line_info.priority or 1)
        pcall(vim.api.nvim_buf_add_highlight, buf, ns, hl_group, line_idx, 0, -1)
      elseif line_info.type == "task" then
        local task = line_info.task
        local line = lines[line_num]

        if not line then goto continue end

        -- Highlight task ID [ID:xxx]
        local id_start, id_end = line:find("%[ID:[^%]]+%]")
        if id_start then
          pcall(vim.api.nvim_buf_add_highlight, buf, ns, "TodoistTaskId", line_idx, id_start - 1, id_end)
        end

        -- Highlight priority badge [Px]
        local priority = task.priority or 1
        local p_start, p_end = line:find("%[P%d%]")
        if p_start then
          pcall(vim.api.nvim_buf_add_highlight, buf, ns, "TodoistP" .. priority, line_idx, p_start - 1, p_end)
        end

        -- Highlight project tag #ProjectName
        local proj_start, proj_end = line:find("#[^%s]+")
        if proj_start then
          pcall(vim.api.nvim_buf_add_highlight, buf, ns, "TodoistProject", line_idx, proj_start - 1, proj_end)
        end

        -- Highlight due time @time
        local time_start, time_end = line:find("@[^%s]+")
        if time_start then
          pcall(vim.api.nvim_buf_add_highlight, buf, ns, "TodoistDueTime", line_idx, time_start - 1, time_end)
        end
      end
      ::continue::
    end
  end
end

-- Format detailed task preview
local function format_task_preview_detailed(task, project_lookup)
  if not task then
    return { "No task selected" }
  end

  local lines = {}
  local project = resolve_project(task, project_lookup)
  local priority = task.priority or 1

  -- Title
  table.insert(lines, task.content or "(no content)")
  table.insert(lines, string.rep("─", 50))
  table.insert(lines, "")

  -- Metadata section
  table.insert(lines, "DETAILS")
  table.insert(lines, "  Task ID:   " .. (task.id or "?"))

  local priority_labels = {
    [4] = "P4 - Urgent",
    [3] = "P3 - High",
    [2] = "P2 - Medium",
    [1] = "P1 - Normal",
  }
  table.insert(lines, "  Priority:  " .. (priority_labels[priority] or "Unknown"))
  table.insert(lines, "  Project:   " .. (project.name or "Unknown"))

  -- Due date info
  if task.due and type(task.due) == "table" then
    local due_text = task.due.string or task.due.date or ""
    local is_recurring = task.due.is_recurring or false
    table.insert(lines, "  Due:       " .. due_text .. (is_recurring and " (recurring)" or ""))
  else
    table.insert(lines, "  Due:       No due date")
  end

  -- Created date
  if task.created_at then
    local created = task.created_at:match("(%d%d%d%d%-%d%d%-%d%d)") or task.created_at
    table.insert(lines, "  Created:   " .. created)
  end

  -- Labels
  if task.labels and #task.labels > 0 then
    table.insert(lines, "  Labels:    " .. table.concat(task.labels, ", "))
  end

  -- Description
  if task.description and task.description ~= "" then
    table.insert(lines, "")
    table.insert(lines, "DESCRIPTION")
    for desc_line in (task.description .. "\n"):gmatch("([^\n]*)\n") do
      table.insert(lines, "  " .. desc_line)
    end
  end

  -- Quick actions hint
  table.insert(lines, "")
  table.insert(lines, string.rep("─", 50))
  table.insert(lines, "ACTIONS")
  table.insert(lines, "  Enter      Complete task")
  table.insert(lines, "  ctrl-e     Edit task")
  table.insert(lines, "  ctrl-x     Delete task")
  table.insert(lines, "  ctrl-r     Refresh list")
  table.insert(lines, "  /          Search tasks")
  table.insert(lines, "  <leader>ta Add new task")
  table.insert(lines, "  p          Toggle details pane")
  table.insert(lines, "  q          Close window")

  return lines
end

-- Update preview pane with current task
local function update_preview(state_obj)
  if not state_obj or not vim.api.nvim_win_is_valid(state_obj.list_win) then
    return
  end

  if not vim.api.nvim_win_is_valid(state_obj.preview_win) then
    return
  end

  -- Don't update if preview is hidden
  if state_obj.preview_hidden then
    return
  end

  -- Validate preview buffer
  if not vim.api.nvim_buf_is_valid(state_obj.preview_buf) then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(state_obj.list_win)
  local line_num = cursor[1]
  local line_info = state_obj.line_map[line_num]

  local preview_lines = { "", "  No task selected", "", "  Use j/k to navigate through tasks" }
  if line_info and line_info.type == "task" and line_info.task then
    preview_lines = format_task_preview_detailed(line_info.task, state_obj.project_lookup)
  elseif line_info and line_info.type == "empty" then
    if state_obj.search_mode and state_obj.search_query ~= "" then
      preview_lines = { "", "  No tasks match your search", "", string.format("  Query: '%s'", state_obj.search_query),
        "", "  Press ESC to clear search" }
    else
      preview_lines = { "", "  No tasks in your today list", "", "  Add tasks with :TodoistAdd" }
    end
  end

  pcall(function()
    vim.api.nvim_buf_set_option(state_obj.preview_buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(state_obj.preview_buf, 0, -1, false, preview_lines)
    vim.api.nvim_buf_set_option(state_obj.preview_buf, 'modifiable', false)
  end)
end

-- Toggle preview pane visibility
local function toggle_preview_pane(state_obj)
  if not state_obj then
    return
  end

  state_obj.preview_hidden = not state_obj.preview_hidden

  if state_obj.preview_hidden then
    -- Hide the preview window by closing it
    if vim.api.nvim_win_is_valid(state_obj.preview_win) then
      pcall(vim.api.nvim_win_close, state_obj.preview_win, true)
    end
    vim.notify("Details pane hidden (press 'p' to show)", vim.log.levels.INFO)
  else
    -- Show the preview window again
    if not vim.api.nvim_win_is_valid(state_obj.list_win) then
      return
    end

    -- Recreate preview buffer if it was wiped
    if not vim.api.nvim_buf_is_valid(state_obj.preview_buf) then
      state_obj.preview_buf = vim.api.nvim_create_buf(false, true)
      pcall(function()
        vim.api.nvim_buf_set_option(state_obj.preview_buf, 'buftype', 'nofile')
        vim.api.nvim_buf_set_option(state_obj.preview_buf, 'swapfile', false)
        vim.api.nvim_buf_set_option(state_obj.preview_buf, 'bufhidden', 'wipe')
      end)
    end

    -- Make sure we're in the list window
    pcall(vim.api.nvim_set_current_win, state_obj.list_win)

    -- Create a new vertical split for the preview
    vim.cmd('vsplit')

    -- Move to the new window (right split)
    vim.cmd('wincmd l')
    local new_preview_win = vim.api.nvim_get_current_win()

    -- Set the preview buffer in the new window
    if vim.api.nvim_buf_is_valid(state_obj.preview_buf) then
      pcall(vim.api.nvim_win_set_buf, new_preview_win, state_obj.preview_buf)
    end

    -- Update the preview window reference
    state_obj.preview_win = new_preview_win

    -- Restore split ratio
    local cfg = require("todoist.config").get()
    local custom_cfg = cfg.custom_ui or {}
    local split_ratio = custom_cfg.split_ratio or 0.6
    local total_width = vim.o.columns
    local list_width = math.floor(total_width * split_ratio)
    local preview_width = total_width - list_width

    -- Set both window widths explicitly
    pcall(vim.api.nvim_win_set_width, state_obj.list_win, list_width)
    pcall(vim.api.nvim_win_set_width, new_preview_win, preview_width)

    -- Set window options for new preview window
    if vim.api.nvim_win_is_valid(new_preview_win) then
      pcall(function()
        vim.api.nvim_win_set_option(new_preview_win, 'number', false)
        vim.api.nvim_win_set_option(new_preview_win, 'relativenumber', false)
        vim.api.nvim_win_set_option(new_preview_win, 'wrap', true)
      end)
    end

    -- Focus back on list window
    pcall(vim.api.nvim_set_current_win, state_obj.list_win)

    -- Update the preview content
    update_preview(state_obj)

    vim.notify("Details pane visible", vim.log.levels.INFO)
  end
end

-- Move cursor with smart navigation (skip headers/separators)
local function move_cursor(state_obj, delta)
  if not state_obj or not vim.api.nvim_win_is_valid(state_obj.list_win) then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(state_obj.list_win)
  local current = cursor[1]
  local target = current + delta
  local line_count = vim.api.nvim_buf_line_count(state_obj.list_buf)

  -- Clamp to valid range
  target = math.max(1, math.min(target, line_count))

  -- Check if there are any tasks at all
  local has_tasks = false
  for _, info in pairs(state_obj.line_map) do
    if info.type == "task" then
      has_tasks = true
      break
    end
  end

  if not has_tasks then
    -- No tasks available, just position on first line
    vim.api.nvim_win_set_cursor(state_obj.list_win, { math.max(1, math.min(2, line_count)), 0 })
    return
  end

  -- Skip headers, separators, and search prompts
  local max_iterations = line_count + 1
  local iterations = 0
  while target >= 1 and target <= line_count and iterations < max_iterations do
    local line_info = state_obj.line_map[target]
    if line_info and line_info.type == "task" then
      break
    end
    target = target + (delta > 0 and 1 or -1)
    iterations = iterations + 1
  end

  -- If we found a valid task line, move cursor
  if target >= 1 and target <= line_count then
    local line_info = state_obj.line_map[target]
    if line_info and line_info.type == "task" then
      vim.api.nvim_win_set_cursor(state_obj.list_win, { target, 0 })
    end
  end
end

-- Setup navigation keymaps
local function setup_navigation(state_obj)
  local buf = state_obj.list_buf

  -- Basic movement
  vim.keymap.set('n', 'j', function() move_cursor(state_obj, 1) end,
    { buffer = buf, noremap = true, silent = true })
  vim.keymap.set('n', 'k', function() move_cursor(state_obj, -1) end,
    { buffer = buf, noremap = true, silent = true })
  vim.keymap.set('n', '<Down>', function() move_cursor(state_obj, 1) end,
    { buffer = buf, noremap = true, silent = true })
  vim.keymap.set('n', '<Up>', function() move_cursor(state_obj, -1) end,
    { buffer = buf, noremap = true, silent = true })

  -- Jump to first/last task
  vim.keymap.set('n', 'gg', function() move_cursor(state_obj, -math.huge) end,
    { buffer = buf, noremap = true, silent = true })
  vim.keymap.set('n', 'G', function() move_cursor(state_obj, math.huge) end,
    { buffer = buf, noremap = true, silent = true })

  -- Page movement
  vim.keymap.set('n', '<C-d>', function() move_cursor(state_obj, 10) end,
    { buffer = buf, noremap = true, silent = true })
  vim.keymap.set('n', '<C-u>', function() move_cursor(state_obj, -10) end,
    { buffer = buf, noremap = true, silent = true })
end

-- Fuzzy match implementation
local function fuzzy_match(query, text)
  if not query or query == "" then
    return true, 1000
  end

  query = query:lower()
  text = text:lower()

  -- Simple substring match with position-based scoring
  local pos = text:find(query, 1, true)
  if pos then
    -- Score: earlier position = higher score
    local score = 1000 - pos
    return true, score
  end

  return false, 0
end

-- Search and filter tasks
local function search_tasks(tasks, query, project_lookup)
  if not query or query == "" then
    return tasks
  end

  local results = {}

  for _, task in ipairs(tasks) do
    -- Build searchable text
    local project = resolve_project(task, project_lookup)
    local searchable = table.concat({
      task.content or "",
      task.description or "",
      project.name or "",
      "P" .. (task.priority or 1),
      (task.due and type(task.due) == "table" and task.due.string) or "",
    }, " ")

    local matches, score = fuzzy_match(query, searchable)
    if matches then
      table.insert(results, { task = task, score = score })
    end
  end

  -- Sort by score descending
  table.sort(results, function(a, b) return a.score > b.score end)

  -- Extract just the tasks
  local filtered = {}
  for _, item in ipairs(results) do
    table.insert(filtered, item.task)
  end

  return filtered
end

-- Refresh UI with current state
local function refresh_ui(state_obj)
  if not state_obj or not vim.api.nvim_buf_is_valid(state_obj.list_buf) then
    return
  end

  -- Get tasks to display
  local tasks_to_display = state_obj.search_mode and state_obj.filtered_tasks or state_obj.tasks

  -- Re-render grouped tasks
  local line_map, task_map, lines = render_grouped_tasks(state_obj.list_buf, tasks_to_display, state_obj.project_lookup)

  -- Update state
  state_obj.line_map = line_map
  state_obj.task_map = task_map

  -- Apply highlights
  apply_highlights(state_obj.list_buf, lines, line_map)

  -- If in search mode, show search prompt
  if state_obj.search_mode then
    local search_line = string.format("Search: %s_", state_obj.search_query)
    vim.api.nvim_buf_set_option(state_obj.list_buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(state_obj.list_buf, 0, 1, false, { search_line })
    vim.api.nvim_buf_set_option(state_obj.list_buf, 'modifiable', false)

    -- Update line_map to account for search line
    local new_line_map = { [1] = { type = "search_prompt" } }
    for line_num, info in pairs(line_map) do
      new_line_map[line_num + 1] = info
    end
    state_obj.line_map = new_line_map
  end

  -- Position cursor on first task
  vim.schedule(function()
    if state_obj.search_mode then
      -- Start from line 2 (after search prompt)
      move_cursor(state_obj, 1)
    else
      move_cursor(state_obj, 0)
    end
    update_preview(state_obj)
  end)
end

-- Refresh data with loader
local function refresh_with_loader(state_obj)
  -- Guard against concurrent refreshes
  if state_obj.is_loading then
    vim.notify("Refresh already in progress...", vim.log.levels.INFO)
    return
  end

  state_obj.is_loading = true

  -- Start loader
  local loader = require("todoist.loader")
  state_obj.loader_id = loader.create_loader({
    ui_type = "custom",
    buffer = state_obj.list_buf,
    message = "Refreshing tasks...",
  })
  loader.start(state_obj.loader_id)

  -- Get token
  local auth = require("todoist.auth")
  local token = auth.load_token()

  if not token then
    loader.stop(state_obj.loader_id)
    state_obj.is_loading = false
    vim.notify("No token found", vim.log.levels.ERROR)
    return
  end

  -- Fetch tasks and projects
  local client = require("todoist.client")

  client.fetch_tasks(token, { filter = "today" }, function(err, tasks)
    if err then
      loader.stop(state_obj.loader_id)
      state_obj.is_loading = false
      vim.notify("Failed to fetch tasks: " .. err, vim.log.levels.ERROR)
      return
    end

    client.fetch_projects(token, function(project_err, projects)
      -- Stop loader
      loader.stop(state_obj.loader_id)
      state_obj.is_loading = false

      if project_err then
        vim.notify("Warning: Failed to fetch projects: " .. project_err, vim.log.levels.WARN)
      end

      -- Build project lookup
      local project_lookup = {}
      if projects then
        for _, project in ipairs(projects) do
          project_lookup[project.id] = project
        end
      end

      -- Update state with fresh data
      state_obj.tasks = tasks or {}
      state_obj.filtered_tasks = tasks or {}
      state_obj.project_lookup = project_lookup

      -- Re-render UI in-place using existing function
      refresh_ui(state_obj)

      vim.notify("Tasks refreshed", vim.log.levels.INFO)
    end)
  end)
end

-- Enter search mode
local function enter_search_mode(state_obj)
  state_obj.search_mode = true
  state_obj.search_query = ""
  state_obj.filtered_tasks = state_obj.tasks

  -- Show search prompt
  refresh_ui(state_obj)

  -- Setup search input handling
  local buf = state_obj.list_buf

  -- Character input for search
  for i = 32, 126 do -- Printable ASCII characters
    local char = string.char(i)
    vim.keymap.set('n', char, function()
      state_obj.search_query = state_obj.search_query .. char
      state_obj.filtered_tasks = search_tasks(state_obj.tasks, state_obj.search_query, state_obj.project_lookup)
      refresh_ui(state_obj)
    end, { buffer = buf, noremap = true, silent = true })
  end

  -- Backspace
  vim.keymap.set('n', '<BS>', function()
    if #state_obj.search_query > 0 then
      state_obj.search_query = state_obj.search_query:sub(1, -2)
      state_obj.filtered_tasks = search_tasks(state_obj.tasks, state_obj.search_query, state_obj.project_lookup)
      refresh_ui(state_obj)
    end
  end, { buffer = buf, noremap = true, silent = true })

  -- Escape to exit search
  vim.keymap.set('n', '<Esc>', function()
    exit_search_mode(state_obj)
  end, { buffer = buf, noremap = true, silent = true })

  -- Enter to accept search
  vim.keymap.set('n', '<CR>', function()
    -- Just close search prompt, keep filtered results
    state_obj.search_mode = false
    refresh_ui(state_obj)
    setup_navigation(state_obj) -- Restore navigation
    setup_actions(state_obj)    -- Restore actions
  end, { buffer = buf, noremap = true, silent = true })
end

-- Exit search mode
function exit_search_mode(state_obj)
  state_obj.search_mode = false
  state_obj.search_query = ""
  state_obj.filtered_tasks = state_obj.tasks

  -- Restore UI
  refresh_ui(state_obj)

  -- Restore normal keymaps
  setup_navigation(state_obj)
  setup_actions(state_obj)
end

-- Setup autocmds for preview sync
local function setup_autocmds(state_obj)
  local augroup = vim.api.nvim_create_augroup("TodoistCustomUI", { clear = true })
  state_obj.augroup = augroup

  -- Sync preview on cursor movement
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = augroup,
    buffer = state_obj.list_buf,
    callback = function()
      update_preview(state_obj)
    end,
  })

  -- Maintain split ratio on resize
  vim.api.nvim_create_autocmd("VimResized", {
    group = augroup,
    callback = function()
      if vim.api.nvim_win_is_valid(state_obj.list_win) then
        local cfg = require("todoist.config").get()
        local custom_cfg = cfg.custom_ui or {}
        local split_ratio = custom_cfg.split_ratio or 0.6
        local total_width = vim.o.columns
        local list_width = math.floor(total_width * split_ratio)
        vim.api.nvim_win_set_width(state_obj.list_win, list_width)
      end
    end,
  })

  -- Cleanup on buffer unload
  vim.api.nvim_create_autocmd("BufUnload", {
    group = augroup,
    buffer = state_obj.list_buf,
    callback = function()
      -- Stop loader if running
      if state_obj.loader_id then
        local loader = require("todoist.loader")
        loader.stop(state_obj.loader_id)
      end
      -- Close preview window
      if state_obj.preview_win and vim.api.nvim_win_is_valid(state_obj.preview_win) then
        vim.api.nvim_win_close(state_obj.preview_win, true)
      end
    end,
  })
end

-- Handle action on current task
local function handle_action(state_obj, action_type)
  if not state_obj or not vim.api.nvim_win_is_valid(state_obj.list_win) then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(state_obj.list_win)
  local line_num = cursor[1]
  local line_info = state_obj.line_map[line_num]

  if not line_info or line_info.type ~= "task" then
    vim.notify("No task selected", vim.log.levels.WARN)
    return
  end

  local task = line_info.task

  if action_type == "complete" then
    if state_obj.on_complete then
      state_obj.on_complete(task)
    end
  elseif action_type == "edit" then
    -- Use edit handler from fzf module
    vim.ui.select(
      { "Content", "Due date", "Priority", "Cancel" },
      { prompt = "Edit what?" },
      function(choice)
        if choice == "Content" then
          vim.ui.input(
            { prompt = "New content: ", default = task.content },
            function(content)
              if not content or content == "" then return end
              update_task_field(task.id, { content = content }, state_obj)
            end
          )
        elseif choice == "Due date" then
          local default = ""
          if task.due and type(task.due) == "table" then
            default = task.due.string or task.due.date or ""
          end
          vim.ui.input(
            { prompt = "Due (e.g. 'tomorrow', '2024-12-31'): ", default = default },
            function(due)
              if not due then return end
              update_task_field(task.id, { due_string = due }, state_obj)
            end
          )
        elseif choice == "Priority" then
          vim.ui.select(
            { "1 (Normal)", "2 (Medium)", "3 (High)", "4 (Urgent)" },
            { prompt = "Priority:" },
            function(choice_str)
              if not choice_str then return end
              local priority = tonumber(choice_str:match("^(%d)"))
              if priority then
                update_task_field(task.id, { priority = priority }, state_obj)
              end
            end
          )
        end
      end
    )
  elseif action_type == "delete" then
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
          -- Refresh in-place instead of closing windows
          refresh_with_loader(state_obj)
        end)
      end
    )
  end
end

-- Update task field helper
function update_task_field(task_id, updates, state_obj)
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
    -- Refresh in-place instead of closing windows
    refresh_with_loader(state_obj)
  end)
end

-- Setup action keybindings
function setup_actions(state_obj)
  local buf = state_obj.list_buf

  -- Complete task (Enter)
  vim.keymap.set('n', '<CR>', function()
    handle_action(state_obj, "complete")
  end, { buffer = buf, noremap = true, silent = true })

  -- Edit task (Ctrl-e)
  vim.keymap.set('n', '<C-e>', function()
    handle_action(state_obj, "edit")
  end, { buffer = buf, noremap = true, silent = true })

  -- Delete task (Ctrl-x)
  vim.keymap.set('n', '<C-x>', function()
    handle_action(state_obj, "delete")
  end, { buffer = buf, noremap = true, silent = true })

  -- Refresh (Ctrl-r)
  vim.keymap.set('n', '<C-r>', function()
    refresh_with_loader(state_obj)
  end, { buffer = buf, noremap = true, silent = true })

  -- Search mode (/)
  vim.keymap.set('n', '/', function()
    enter_search_mode(state_obj)
  end, { buffer = buf, noremap = true, silent = true })

  -- Toggle preview pane (p)
  vim.keymap.set('n', 'p', function()
    toggle_preview_pane(state_obj)
  end, { buffer = buf, noremap = true, silent = true })
end

-- Main entry point
function M.show_today(tasks, opts)
  opts = opts or {}

  -- Setup highlights
  setup_highlights()

  -- Build project lookup
  local project_lookup = build_project_lookup(opts.projects)

  -- Create UI layout
  local layout = create_split_layout()
  if not layout then
    vim.notify("Failed to create custom UI layout", vim.log.levels.ERROR)
    return
  end

  -- Render grouped task list
  local line_map, task_map, lines = render_grouped_tasks(layout.list_buf, tasks, project_lookup)

  -- Check if rendering succeeded
  if not line_map or not task_map or not lines then
    vim.notify("Failed to render task list", vim.log.levels.ERROR)
    return
  end

  -- Apply highlights
  apply_highlights(layout.list_buf, lines, line_map)

  -- Store state
  state = {
    list_buf = layout.list_buf,
    preview_buf = layout.preview_buf,
    list_win = layout.list_win,
    preview_win = layout.preview_win,
    tasks = tasks or {},
    filtered_tasks = tasks or {},
    line_map = line_map,
    task_map = task_map,
    project_lookup = project_lookup,
    search_mode = false,
    search_query = "",
    preview_hidden = false,
    is_loading = false,
    loader_id = nil,
    on_refresh = opts.on_refresh,
    on_complete = opts.on_complete,
  }

  -- Set buffer name (with unique timestamp to avoid conflicts)
  local timestamp = vim.fn.localtime()
  pcall(vim.api.nvim_buf_set_name, layout.list_buf, string.format("todoist://today-%d", timestamp))

  -- Setup navigation
  setup_navigation(state)

  -- Setup actions
  setup_actions(state)

  -- Setup autocmds for preview sync and cleanup
  setup_autocmds(state)

  -- Setup close keymap
  vim.keymap.set('n', 'q', function()
    -- Cleanup autocmds
    if state.augroup then
      pcall(vim.api.nvim_del_augroup_by_id, state.augroup)
    end

    -- Close preview window first (if it exists and is valid)
    if vim.api.nvim_win_is_valid(state.preview_win) then
      pcall(vim.api.nvim_win_close, state.preview_win, true)
    end

    -- Close list window or quit if it's the last window
    if vim.api.nvim_win_is_valid(state.list_win) then
      -- Check if this is the last window
      local win_count = #vim.api.nvim_list_wins()
      if win_count <= 1 then
        -- Last window, use quit instead of close
        vim.cmd('quit')
      else
        pcall(vim.api.nvim_win_close, state.list_win, true)
      end
    end
  end, { buffer = layout.list_buf, noremap = true, silent = true })

  -- Position cursor on first task and show preview
  vim.schedule(function()
    move_cursor(state, 0) -- Find first task
    update_preview(state)
  end)
end

return M
