local M = {}

local function basename(name)
  if name == "" then
    return ""
  end
  return vim.fn.fnamemodify(name, ":t")
end

function M.build_label_map(bufnrs)
  local counts = {}
  for _, bufnr in ipairs(bufnrs) do
    local name = vim.api.nvim_buf_get_name(bufnr)
    local key = basename(name)
    counts[key] = (counts[key] or 0) + 1
  end

  local labels = {}
  local reverse = {}
  for _, bufnr in ipairs(bufnrs) do
    local name = vim.api.nvim_buf_get_name(bufnr)
    local base = basename(name)
    local label
    if base == "" then
      label = ("[No Name:%d]"):format(bufnr)
    elseif counts[base] > 1 then
      label = ("%s:%d"):format(base, bufnr)
    else
      label = base
    end
    labels[bufnr] = label
    reverse[label] = bufnr
  end

  return labels, reverse
end

return M
