local config = require("tablocal_buffer.config")
local model = require("tablocal_buffer.model")

local M = {}

local function sanitize_bufferline_state()
  local ok_state, state = pcall(require, "bufferline.state")
  if not ok_state or type(state) ~= "table" or type(state.set) ~= "function" then
    return
  end

  local function keep_valid(components)
    if type(components) ~= "table" then
      return {}
    end

    local filtered = {}
    for _, item in ipairs(components) do
      if type(item) == "table" and item.id and vim.api.nvim_buf_is_valid(item.id) then
        table.insert(filtered, item)
      end
    end
    return filtered
  end

  state.set({
    components = keep_valid(state.components),
    visible_components = keep_valid(state.visible_components),
  })
end

function M.get_global_buffer_order()
  local order = {}
  local index = 1
  for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
    for _, bufnr in ipairs(model.get_tab_buffers(tabpage)) do
      if order[bufnr] == nil then
        order[bufnr] = index
        index = index + 1
      end
    end
  end
  return order
end

function M.sort_bufferline()
  if not config.get().bufferline.enabled then
    return false
  end

  local ok, bufferline = pcall(require, "bufferline")
  if not ok or type(bufferline.sort_by) ~= "function" then
    return false
  end

  sanitize_bufferline_state()

  local sorted_ok = pcall(bufferline.sort_by, function(buffer_a, buffer_b)
    local order = M.get_global_buffer_order()
    local a = order[buffer_a.id] or math.huge
    local b = order[buffer_b.id] or math.huge
    if a == b then
      return buffer_a.id < buffer_b.id
    end
    return a < b
  end)
  return sorted_ok
end

return M
