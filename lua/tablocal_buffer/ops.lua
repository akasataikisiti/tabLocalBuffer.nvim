local M = {}

function M.is_buffer_visible(bufnr)
  for _, winid in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(winid) == bufnr then
      return true
    end
  end
  return false
end

function M.set_win_buf(winid, bufnr)
  if not vim.api.nvim_win_is_valid(winid) or not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end
  return pcall(vim.api.nvim_win_set_buf, winid, bufnr)
end

function M.close_win(winid, force)
  if not vim.api.nvim_win_is_valid(winid) then
    return false
  end
  return pcall(vim.api.nvim_win_close, winid, force or false)
end

function M.delete_buffer(bufnr, opts)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end
  return pcall(vim.api.nvim_buf_delete, bufnr, opts or { force = false })
end

function M.delete_unmodified_unnamed_buffer(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end
  if vim.api.nvim_buf_get_name(bufnr) ~= "" then
    return false
  end
  if vim.bo[bufnr].buftype ~= "" or vim.bo[bufnr].modified or M.is_buffer_visible(bufnr) then
    return false
  end
  return M.delete_buffer(bufnr, { force = false })
end

function M.delete_unmodified_named_buffer(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end
  if vim.api.nvim_buf_get_name(bufnr) == "" then
    return false
  end
  if vim.bo[bufnr].modified or M.is_buffer_visible(bufnr) then
    return false
  end
  return M.delete_buffer(bufnr, { force = false })
end

return M
