local model = require("tablocal_buffer.model")

local M = {}

local function cycle(step)
  local tabpage = vim.api.nvim_get_current_tabpage()
  local buffers = model.get_tab_buffers(tabpage)
  if #buffers == 0 then
    return
  end

  local current = vim.api.nvim_get_current_buf()
  local current_index = nil
  for index, bufnr in ipairs(buffers) do
    if bufnr == current then
      current_index = index
      break
    end
  end

  local next_index
  if current_index then
    next_index = ((current_index - 1 + step) % #buffers) + 1
  else
    next_index = 1
  end

  local target = buffers[next_index]
  if target and vim.api.nvim_buf_is_valid(target) then
    vim.api.nvim_set_current_buf(target)
  end
end

function M.bnext_tablocal()
  cycle(1)
end

function M.bprevious_tablocal()
  cycle(-1)
end

return M
