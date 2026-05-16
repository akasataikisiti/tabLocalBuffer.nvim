local h = dofile("tests/helpers.lua")
local eq, ok, reset, new_named_buffer = h.eq, h.ok, h.reset, h.new_named_buffer

local function test_navigation_and_registration()
  reset()
  package.loaded["tablocal_buffer"] = nil
  local plugin = require("tablocal_buffer")
  plugin.setting({})

  local first = new_named_buffer("one.lua")
  local second = new_named_buffer("two.lua")
  eq(vim.api.nvim_tabpage_get_var(0, "tablocal_buffers"), { first, second }, "buffers should register in current tab")

  vim.api.nvim_set_current_buf(first)
  plugin.bnext_tablocal()
  eq(vim.api.nvim_get_current_buf(), second, "bnext should move within tab order")
  plugin.bprevious_tablocal()
  eq(vim.api.nvim_get_current_buf(), first, "bprevious should wrap back")
end

local function test_navigation_includes_unnamed_buffers_by_default()
  reset()
  package.loaded["tablocal_buffer"] = nil
  local plugin = require("tablocal_buffer")
  plugin.setting({})

  local named = new_named_buffer("one.lua")
  vim.cmd.enew()
  local unnamed = vim.api.nvim_get_current_buf()

  eq(vim.api.nvim_tabpage_get_var(0, "tablocal_buffers"), { named, unnamed }, "unnamed buffer should register in current tab")

  vim.api.nvim_set_current_buf(named)
  plugin.bnext_tablocal()
  eq(vim.api.nvim_get_current_buf(), unnamed, "bnext should include unnamed buffers")
end

local function test_excluded_buffer_enter_does_not_sync_window_back()
  reset()
  package.loaded["tablocal_buffer"] = nil
  local plugin = require("tablocal_buffer")
  plugin.setting({})

  local managed = new_named_buffer("managed.lua")
  local excluded = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_name(excluded, "fugitive:///tmp/repo/.git//0/staged.lua")

  vim.api.nvim_set_current_buf(excluded)

  eq(vim.api.nvim_get_current_buf(), excluded, "excluded buffer should remain visible after BufWinEnter")
  eq(plugin.get_buf_tabnr(managed), 1, "managed buffer should stay assigned to the tab")
  eq(plugin.get_buf_tabnr(excluded), nil, "excluded buffer should not become a cycle buffer")
end

local function test_move_to_new_tab()
  reset()
  package.loaded["tablocal_buffer"] = nil
  local plugin = require("tablocal_buffer")
  plugin.setting({})

  local first = new_named_buffer("move-a.lua")
  local second = new_named_buffer("move-b.lua")
  vim.api.nvim_set_current_buf(first)

  plugin.move_current_window_to_new_tab()

  eq(#vim.api.nvim_list_tabpages(), 2, "move should create a new tab")
  eq(plugin.get_buf_tabnr(first), 2, "moved buffer should belong to new tab")
  eq(plugin.get_buf_tabnr(second), 1, "remaining buffer should stay in source tab")
end

local function test_move_to_new_tab_replaces_last_source_window()
  reset()
  package.loaded["tablocal_buffer"] = nil
  local plugin = require("tablocal_buffer")
  plugin.setting({})

  local only = new_named_buffer("move-last.lua")

  plugin.move_current_window_to_new_tab()

  vim.api.nvim_set_current_tabpage(vim.api.nvim_list_tabpages()[1])
  eq(plugin.get_buf_tabnr(only), 2, "moved buffer should only belong to destination tab")
  ok(vim.api.nvim_get_current_buf() ~= only, "source tab should no longer show the moved buffer")
  ok(plugin.is_cycle_candidate(vim.api.nvim_get_current_buf()), "source tab fallback unnamed buffer should remain manageable")
end

local function test_detach_current_buffer_keeps_tab_open_and_unassigns_buffer()
  reset()
  package.loaded["tablocal_buffer"] = nil
  local plugin = require("tablocal_buffer")
  plugin.setting({})

  local first = new_named_buffer("a.txt")
  local second = new_named_buffer("b.txt")
  vim.api.nvim_set_current_buf(first)

  local detached = plugin.detach_current_buffer_from_tab()

  ok(detached, "detach should report success")
  eq(#vim.api.nvim_list_tabpages(), 1, "detaching should not close the tab")
  eq(plugin.get_buf_tabnr(first), nil, "detached buffer should become unassigned")
  eq(plugin.get_buf_tabnr(second), 1, "remaining buffer should stay assigned to the tab")
  eq(vim.api.nvim_get_current_buf(), second, "current window should switch to another buffer in the tab")
end

local function test_delete_current_buffer_from_tab_removes_buffer_without_closing_tab()
  reset()
  package.loaded["tablocal_buffer"] = nil
  local plugin = require("tablocal_buffer")
  plugin.setting({})

  local first = new_named_buffer("a.txt")
  local second = new_named_buffer("b.txt")
  vim.api.nvim_set_current_buf(first)

  local deleted = plugin.delete_current_buffer_from_tab()

  ok(deleted, "delete should report success")
  eq(#vim.api.nvim_list_tabpages(), 1, "deleting current tab-local buffer should not close the tab")
  ok(not vim.api.nvim_buf_is_valid(first), "deleted buffer should be wiped")
  eq(plugin.get_buf_tabnr(second), 1, "remaining buffer should stay assigned to the tab")
  eq(vim.api.nvim_get_current_buf(), second, "window should remain on a valid fallback buffer")
end

local function test_bufwipeout_syncs_after_autocmd()
  reset()
  package.loaded["tablocal_buffer"] = nil
  local plugin = require("tablocal_buffer")
  plugin.setting({})

  local first = new_named_buffer("COMMIT_EDITMSG")
  local second = new_named_buffer("after-commit.lua")
  vim.api.nvim_set_current_buf(first)

  local deleted, err = pcall(vim.api.nvim_buf_delete, first, { force = true })
  ok(deleted, "wiping the current buffer should not fail: " .. tostring(err))
  vim.wait(1000, function()
    return vim.api.nvim_get_current_buf() == second
  end)

  ok(not vim.api.nvim_buf_is_valid(first), "wiped buffer should be invalid")
  eq(vim.api.nvim_tabpage_get_var(0, "tablocal_buffers"), { second }, "wiped buffer should be removed from tab state")
  eq(vim.api.nvim_get_current_buf(), second, "window should settle on the remaining tab buffer")
end

return {
  test_navigation_and_registration,
  test_navigation_includes_unnamed_buffers_by_default,
  test_excluded_buffer_enter_does_not_sync_window_back,
  test_move_to_new_tab,
  test_move_to_new_tab_replaces_last_source_window,
  test_detach_current_buffer_keeps_tab_open_and_unassigns_buffer,
  test_delete_current_buffer_from_tab_removes_buffer_without_closing_tab,
  test_bufwipeout_syncs_after_autocmd,
}
