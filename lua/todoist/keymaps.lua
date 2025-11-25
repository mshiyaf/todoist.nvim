local M = {}

local defaults = {
  enable = true,
  mappings = {
    open_tasks = "<leader>tt",
    add_task = "<leader>ta",
    login = "<leader>tl",
    logout = "<leader>tL",
  }
}

function M.setup(opts)
  opts = opts or {}
  local config = vim.tbl_deep_extend("force", defaults, opts)

  if not config.enable then
    return
  end

  local mappings = config.mappings

  -- Open tasks window
  if mappings.open_tasks then
    vim.keymap.set("n", mappings.open_tasks, "<cmd>TodoistTasks<cr>", {
      desc = "Open Todoist tasks",
      silent = true,
    })
  end

  -- Add new task
  if mappings.add_task then
    vim.keymap.set("n", mappings.add_task, "<cmd>TodoistAdd<cr>", {
      desc = "Add Todoist task",
      silent = true,
    })
  end

  -- Login (optional)
  if mappings.login then
    vim.keymap.set("n", mappings.login, "<cmd>TodoistLogin<cr>", {
      desc = "Todoist login",
      silent = true,
    })
  end

  -- Logout (optional)
  if mappings.logout then
    vim.keymap.set("n", mappings.logout, "<cmd>TodoistLogout<cr>", {
      desc = "Todoist logout",
      silent = true,
    })
  end
end

return M
