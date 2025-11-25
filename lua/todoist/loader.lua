-- Loader module for animated loading indicators

local M = {}

-- Spinner frames (Braille pattern animation)
local SPINNER_FRAMES = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local FRAME_DELAY = 80 -- milliseconds between frames

-- Track active loaders
local loaders = {}
local next_id = 1

-- Create a new loader instance
function M.create_loader(opts)
  opts = opts or {}

  local loader = {
    id = next_id,
    ui_type = opts.ui_type or "custom", -- "custom" or "fzf"
    buffer = opts.buffer,
    message = opts.message or "Loading...",
    timer = nil,
    frame_idx = 0,
  }

  loaders[next_id] = loader
  next_id = next_id + 1

  return loader.id
end

-- Render spinner in custom UI buffer
local function render_custom_ui(loader)
  if not loader.buffer or not vim.api.nvim_buf_is_valid(loader.buffer) then
    M.stop(loader.id)
    return
  end

  local frame = SPINNER_FRAMES[(loader.frame_idx % #SPINNER_FRAMES) + 1]
  local loading_line = string.format("  %s %s", frame, loader.message)

  vim.schedule(function()
    local ok = pcall(function()
      if vim.api.nvim_buf_is_valid(loader.buffer) then
        vim.api.nvim_buf_set_option(loader.buffer, 'modifiable', true)
        vim.api.nvim_buf_set_lines(loader.buffer, 0, 1, false, { loading_line })
        vim.api.nvim_buf_set_option(loader.buffer, 'modifiable', false)
      end
    end)

    if not ok then
      M.stop(loader.id)
    end
  end)
end

-- Show static loader for FZF (using vim.notify)
-- Don't animate to avoid notification spam
local function show_fzf_loader(loader)
  vim.schedule(function()
    vim.notify(loader.message, vim.log.levels.INFO, {
      title = "Todoist",
      timeout = 3000, -- Auto-dismiss after 3 seconds
    })
  end)
end

-- Start the loader animation
function M.start(loader_id)
  local loader = loaders[loader_id]
  if not loader then
    return
  end

  if loader.ui_type == "custom" then
    -- Animate in-buffer loaders
    loader.timer = vim.loop.new_timer()

    -- Initial render
    render_custom_ui(loader)

    -- Start repeating timer for animation
    loader.timer:start(FRAME_DELAY, FRAME_DELAY, vim.schedule_wrap(function()
      if not loaders[loader_id] then
        return
      end

      loader.frame_idx = loader.frame_idx + 1
      render_custom_ui(loader)
    end))
  else
    -- For FZF, just show a static notification (no animation to avoid spam)
    show_fzf_loader(loader)
  end
end

-- Stop the loader and cleanup
function M.stop(loader_id)
  local loader = loaders[loader_id]
  if not loader then
    return
  end

  -- Stop and close timer
  if loader.timer then
    loader.timer:stop()
    loader.timer:close()
    loader.timer = nil
  end

  -- No need to clear display here - refresh_ui will repopulate with actual content
  -- Removing the clear operation prevents race conditions where the scheduled clear
  -- runs after refresh_ui has already rendered new content
  -- FZF notifications auto-dismiss after timeout, no need to clear

  -- Remove from tracking
  loaders[loader_id] = nil
end

-- Stop all active loaders (utility function for cleanup)
function M.stop_all()
  for id, _ in pairs(loaders) do
    M.stop(id)
  end
end

return M
