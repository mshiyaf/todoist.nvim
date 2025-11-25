local config = require("todoist.config")
local auth = require("todoist.auth")
local client = require("todoist.client")
local fzf = require("todoist.fzf")

local M = {}

local function notify(msg, level)
  local cfg = config.get()
  local handler = cfg.notify or vim.notify
  handler(msg, level or vim.log.levels.INFO)
end

local function get_token()
  local token, err = auth.load_token()
  if token then
    return token
  end
  notify(err or "Todoist token not set. Run :TodoistLogin or set TODOIST_API_TOKEN.", vim.log.levels.ERROR)
  return nil
end

local function refresh_tasks(opts)
  opts = opts or {}
  local token = get_token()
  if not token then
    return
  end

  -- Start loader for FZF
  local loader = require("todoist.loader")
  local loader_id = loader.create_loader({
    ui_type = "fzf",
    message = "Loading tasks...",
  })
  loader.start(loader_id)

  client.fetch_tasks(token, {
    project_id = opts.project_id or config.get().default_project,
    filter = opts.filter,
  }, function(err, tasks)
    -- Stop loader
    loader.stop(loader_id)

    if err then
      notify(err, vim.log.levels.ERROR)
      return
    end

    local filtered_tasks = tasks or {}

    if opts.priority_filter or opts.date_filter then
      fzf.show_tasks_filtered(filtered_tasks, {
        priority_filter = opts.priority_filter,
        date_filter = opts.date_filter,
        on_refresh = function()
          refresh_tasks(opts)
        end,
        on_complete = function(task)
          M.complete_task(task.id, function(close_err)
            if close_err then
              notify(close_err, vim.log.levels.ERROR)
              return
            end
            notify(string.format("Completed task %s", task.content))
            refresh_tasks(opts)
          end)
        end,
      })
    else
      fzf.show_tasks(filtered_tasks, {
        on_refresh = function()
          refresh_tasks(opts)
        end,
        on_complete = function(task)
          M.complete_task(task.id, function(close_err)
            if close_err then
              notify(close_err, vim.log.levels.ERROR)
              return
            end
            notify(string.format("Completed task %s", task.content))
            refresh_tasks(opts)
          end)
        end,
      })
    end
  end)
end

local function refresh_today_view()
  local token = get_token()
  if not token then
    return
  end

  local cfg = config.get()
  local use_custom_ui = cfg.today_view_ui == "custom"

  -- Start loader for both UI modes
  local loader = require("todoist.loader")
  local loader_id = loader.create_loader({
    ui_type = "fzf",  -- Use notification style for both (UI doesn't exist yet)
    message = "Loading today's tasks...",
  })
  loader.start(loader_id)

  local function open_today(tasks, projects)
    -- Stop loader before opening UI
    loader.stop(loader_id)

    if use_custom_ui then
      local custom_ui = require("todoist.custom_ui")
      custom_ui.show_today(tasks or {}, {
        projects = projects,
        on_refresh = refresh_today_view,
        on_complete = function(task)
          M.complete_task(task.id, function(close_err)
            if close_err then
              notify(close_err, vim.log.levels.ERROR)
              return
            end
            notify(string.format("Completed task %s", task.content))
            refresh_today_view()
          end)
        end,
      })
    else
      fzf.show_today(tasks or {}, {
        projects = projects,
        on_refresh = refresh_today_view,
        on_complete = function(task)
          M.complete_task(task.id, function(close_err)
            if close_err then
              notify(close_err, vim.log.levels.ERROR)
              return
            end
            notify(string.format("Completed task %s", task.content))
            refresh_today_view()
          end)
        end,
      })
    end
  end

  client.fetch_tasks(token, { filter = "today" }, function(err, tasks)
    if err then
      -- Stop loader on error
      loader.stop(loader_id)
      notify(err, vim.log.levels.ERROR)
      return
    end

    client.fetch_projects(token, function(project_err, projects)
      if project_err then
        notify(project_err, vim.log.levels.WARN)
      end
      open_today(tasks, projects or {})
    end)
  end)
end

function M.setup(opts)
  config.setup(opts)

  -- Setup keymaps if enabled
  local keymaps = require("todoist.keymaps")
  local cfg = config.get()
  keymaps.setup(cfg.keymaps)
end

function M.login()
  vim.ui.input({ prompt = "Todoist API token: ", secret = true }, function(token)
    if not token or token == "" then
      notify("Token not provided", vim.log.levels.WARN)
      return
    end
    local path, err = auth.save_token(token)
    if not path then
      notify(err or "Failed to save token", vim.log.levels.ERROR)
      return
    end
    notify("Todoist token saved to " .. path)
  end)
end

function M.logout()
  local ok, err = auth.clear_token()
  if not ok then
    notify(err or "No saved token found", vim.log.levels.WARN)
    return
  end
  notify("Todoist token removed")
end

function M.complete_task(task_id, cb)
  local token = get_token()
  if not token then
    return
  end
  client.close_task(token, task_id, function(err)
    if err then
      notify(err, vim.log.levels.ERROR)
      if cb then
        cb(err)
      end
      return
    end
    if cb then
      cb()
    end
  end)
end

function M.add_task()
  local token = get_token()
  if not token then
    return
  end
  vim.ui.input({ prompt = "Task content: " }, function(content)
    if not content or content == "" then
      notify("Task content is required", vim.log.levels.WARN)
      return
    end
    vim.ui.input({ prompt = "Due (optional - 'tomorrow', '2024-12-31'): " }, function(due)
      local payload = {
        content = content,
        project_id = config.get().default_project,
        priority = config.get().default_priority,
      }
      if due and due ~= "" then
        payload.due_string = due
      end
      client.add_task(token, payload, function(err, task)
        if err then
          notify(err, vim.log.levels.ERROR)
          return
        end
        notify(string.format("Created task %s", task and task.content or content))
      end)
    end)
  end)
end

local function setup_commands()
  vim.api.nvim_create_user_command("TodoistLogin", function()
    M.login()
  end, {})

  vim.api.nvim_create_user_command("TodoistLogout", function()
    M.logout()
  end, {})

  vim.api.nvim_create_user_command("TodoistTasks", function(opts)
    refresh_tasks({
      project_id = tonumber(opts.args) or config.get().default_project,
    })
  end, { nargs = "?" })

  vim.api.nvim_create_user_command("TodoistToday", function()
    refresh_today_view()
  end, {})

  vim.api.nvim_create_user_command("TodoistAdd", function()
    M.add_task()
  end, {})

  vim.api.nvim_create_user_command("TodoistComplete", function(opts)
    local id = opts.args
    if id == "" then
      notify("Provide a task id", vim.log.levels.WARN)
      return
    end
    M.complete_task(id)
  end, { nargs = 1 })
end

setup_commands()

return M
