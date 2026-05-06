local h = dofile("tests/helpers.lua")
local eq, ok, reset, new_named_buffer = h.eq, h.ok, h.reset, h.new_named_buffer

local function test_cycle_candidate()
  reset()
  package.loaded["tablocal_buffer"] = nil
  local plugin = require("tablocal_buffer")
  plugin.setting({})

  local listed = new_named_buffer("alpha.lua")
  vim.bo[listed].filetype = "lua"
  ok(plugin.is_cycle_candidate(listed), "listed buffer should be included")

  local help_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[help_buf].buflisted = true
  vim.bo[help_buf].buftype = "help"
  vim.api.nvim_buf_set_name(help_buf, "help.txt")
  ok(not plugin.is_cycle_candidate(help_buf), "help buffer should be excluded")

  vim.cmd.enew()
  local unnamed = vim.api.nvim_get_current_buf()
  ok(plugin.is_cycle_candidate(unnamed), "unnamed normal buffer should be included by default")

  plugin.setting({
    cycle = {
      exclude = {
        filetypes = { "lua" },
      },
    },
  })
  ok(not plugin.is_cycle_candidate(listed), "custom exclusion should apply")

  plugin.setting({
    cycle = {
      exclude = {
        unnamed = true,
      },
    },
  })
  ok(not plugin.is_cycle_candidate(unnamed), "unnamed exclusion option should disable unnamed buffers")
end

local function test_labels()
  reset()
  local labels = require("tablocal_buffer.labels")

  local first = new_named_buffer("/tmp/app/init.lua")
  local second = new_named_buffer("/tmp/other/init.lua")
  local third = vim.api.nvim_create_buf(false, true)
  vim.bo[third].buflisted = true

  local map = { first, second, third }
  local label_map = labels.build_label_map(map)
  eq(label_map[first], ("init.lua:%d"):format(first), "duplicate basename should include bufnr")
  eq(label_map[second], ("init.lua:%d"):format(second), "duplicate basename should include bufnr")
  eq(label_map[third], ("[No Name:%d]"):format(third), "unnamed buffer should use no-name label")
end

return {
  test_cycle_candidate,
  test_labels,
}
