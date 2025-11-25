local M = {}

local defaults = {
  api_base = "https://api.todoist.com/rest/v2",
  data_dir = vim.fn.stdpath("data") .. "/todoist",
  token = nil,
  default_project = nil,
  default_priority = nil,
  curl_bin = "curl",
  notify = vim.notify,
}

local state = vim.deepcopy(defaults)

function M.setup(opts)
  if opts then
    state = vim.tbl_deep_extend("force", state, opts)
  end
end

function M.get()
  return state
end

function M.reset()
  state = vim.deepcopy(defaults)
end

return M
