local config = require("nvim_todoist.config")

local uv = vim.loop

local M = {}

local function ensure_dir(path)
  local stat = uv.fs_stat(path)
  if stat and stat.type == "directory" then
    return true
  end
  if stat then
    return nil, string.format("%s exists and is not a directory", path)
  end
  local ok, err = uv.fs_mkdir(path, 448) -- 0700
  if not ok then
    return nil, err
  end
  return true
end

local function token_path()
  local cfg = config.get()
  return cfg.data_dir .. "/token"
end

function M.load_token()
  local cfg = config.get()
  if cfg.token and cfg.token ~= "" then
    return cfg.token
  end

  local env = vim.env.TODOIST_API_TOKEN
  if env and env ~= "" then
    return env
  end

  local path = token_path()
  local fd = uv.fs_open(path, "r", 384)
  if not fd then
    return nil, "No saved token"
  end
  local data = uv.fs_read(fd, 1024, 0)
  uv.fs_close(fd)
  if not data or data == "" then
    return nil, "Saved token file is empty"
  end
  return vim.trim(data)
end

function M.save_token(token)
  if not token or token == "" then
    return nil, "Token cannot be empty"
  end
  local cfg = config.get()
  local ok, err = ensure_dir(cfg.data_dir)
  if not ok then
    return nil, err
  end

  local path = token_path()
  local fd, open_err = uv.fs_open(path, "w", 384) -- 0600
  if not fd then
    return nil, open_err
  end
  uv.fs_write(fd, token, -1)
  uv.fs_close(fd)
  uv.fs_chmod(path, 384)
  return path
end

function M.clear_token()
  local path = token_path()
  local ok = uv.fs_unlink(path)
  if not ok then
    return nil, "No token file to remove"
  end
  return true
end

return M
