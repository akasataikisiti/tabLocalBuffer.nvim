local h = dofile("tests/helpers.lua")
local eq, ok, reset, new_named_buffer = h.eq, h.ok, h.reset, h.new_named_buffer

local function test_bufferline_sort_sanitizes_invalid_state()
  reset()
  package.loaded["tablocal_buffer"] = nil
  package.loaded["tablocal_buffer.bufferline"] = nil
  package.loaded["bufferline.state"] = nil
  package.loaded["bufferline"] = nil
  require("tablocal_buffer").setting({
    bufferline = {
      enabled = true,
      auto_sort_on_apply = true,
    },
  })

  local kept = new_named_buffer("kept.txt")
  local invalid = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_delete(invalid, { force = true })

  local captured_ids = nil
  package.loaded["bufferline.state"] = {
    components = {
      { id = kept },
      { id = invalid },
    },
    visible_components = {
      { id = kept },
      { id = invalid },
    },
    set = function(next_state)
      package.loaded["bufferline.state"].components = next_state.components
      package.loaded["bufferline.state"].visible_components = next_state.visible_components
    end,
  }
  package.loaded["bufferline"] = {
    sort_by = function(_)
      captured_ids = {}
      for _, item in ipairs(package.loaded["bufferline.state"].components) do
        table.insert(captured_ids, item.id)
      end
    end,
  }

  local tlb_bufferline = require("tablocal_buffer.bufferline")
  ok(tlb_bufferline.sort_bufferline(), "bufferline sort should succeed with sanitized state")
  eq(captured_ids, { kept }, "invalid buffer ids should be removed before sorting")

  package.loaded["bufferline"] = nil
  package.loaded["bufferline.state"] = nil
end

return {
  test_bufferline_sort_sanitizes_invalid_state,
}
