local M = {}

local function quoted(label)
  return ("%q"):format(label)
end

local function validate_group(group, seen, reverse)
  if type(group) ~= "table" then
    return nil, "each group must be a table"
  end

  local resolved = {}
  for _, label in ipairs(group) do
    if type(label) ~= "string" then
      return nil, "group entries must be strings"
    end
    if seen[label] then
      return nil, ("duplicate label: %s"):format(label)
    end
    if not reverse[label] then
      return nil, ("unknown label: %s"):format(label)
    end
    seen[label] = true
    table.insert(resolved, reverse[label])
  end
  return resolved
end

function M.parse(lines, reverse)
  local chunk = table.concat(lines, "\n")
  local fn, err = loadstring(chunk)
  if not fn then
    return nil, err
  end

  local ok, payload = pcall(fn)
  if not ok then
    return nil, payload
  end

  if type(payload) ~= "table" then
    return nil, "top-level value must be a table"
  end

  local groups = payload.groups or payload
  if type(groups) ~= "table" then
    return nil, "groups must be a table"
  end

  local seen = {}
  local resolved_groups = {}
  for _, group in ipairs(groups) do
    local resolved, group_err = validate_group(group, seen, reverse)
    if not resolved then
      return nil, group_err
    end
    table.insert(resolved_groups, resolved)
  end

  local resolved_unassigned = {}
  local unassigned = payload.unassigned or {}
  if type(unassigned) ~= "table" then
    return nil, "unassigned must be a table"
  end
  for _, label in ipairs(unassigned) do
    if type(label) ~= "string" then
      return nil, "unassigned entries must be strings"
    end
    if seen[label] then
      return nil, ("duplicate label: %s"):format(label)
    end
    if not reverse[label] then
      return nil, ("unknown label: %s"):format(label)
    end
    seen[label] = true
    table.insert(resolved_unassigned, reverse[label])
  end

  return {
    groups = resolved_groups,
    unassigned = resolved_unassigned,
  }
end

function M.render(payload)
  local lines = {
    "-- Edit tab-local buffers and write/quit to apply. Press q to close without saving. Duplicate basenames keep the shown :<bufnr> suffix.",
    "return {",
    "  groups = {",
  }

  for _, group in ipairs(payload.groups or {}) do
    table.insert(lines, "    {")
    for _, label in ipairs(group) do
      table.insert(lines, ("      %s,"):format(quoted(label)))
    end
    table.insert(lines, "    },")
  end

  table.insert(lines, "  },")
  table.insert(lines, "")
  table.insert(lines, "  -- Unassigned buffers (not in any tab). Move labels above or leave here to keep unassigned.")
  table.insert(lines, "  unassigned = {")

  if payload.unassigned and #payload.unassigned > 0 then
    for _, label in ipairs(payload.unassigned) do
      table.insert(lines, ("    %s,"):format(quoted(label)))
    end
  else
    table.insert(lines, "    -- (none)")
  end

  table.insert(lines, "  },")
  table.insert(lines, "}")
  return lines
end

return M
