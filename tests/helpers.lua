local function eq(actual, expected, message)
  if not vim.deep_equal(actual, expected) then
    error((message or "assertion failed") .. "\nexpected: " .. vim.inspect(expected) .. "\nactual: " .. vim.inspect(actual))
  end
end

local function ok(value, message)
  if not value then
    error(message or "assertion failed")
  end
end

local function reset()
  for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
    vim.api.nvim_set_current_tabpage(tabpage)
    for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
      if vim.api.nvim_win_is_valid(winid) and winid ~= vim.api.nvim_get_current_win() then
        pcall(vim.api.nvim_win_close, winid, true)
      end
    end
  end

  while #vim.api.nvim_list_tabpages() > 1 do
    vim.cmd.tabclose()
  end

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buflisted and not vim.bo[bufnr].modified then
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    end
  end

  vim.cmd.enew()
end

local function new_named_buffer(name)
  vim.cmd.enew()
  local bufnr = vim.api.nvim_get_current_buf()
  vim.bo[bufnr].buflisted = true
  vim.api.nvim_buf_set_name(bufnr, name)
  return bufnr
end
return { eq = eq, ok = ok, reset = reset, new_named_buffer = new_named_buffer }
