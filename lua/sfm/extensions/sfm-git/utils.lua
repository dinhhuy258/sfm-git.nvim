local M = {}

M.is_windows = vim.fn.has "win32" == 1 or vim.fn.has "win32unix" == 1

-- remove item from array if it exists
function M.array_remove(array, item)
  for i, v in ipairs(array) do
    if v == item then
      table.remove(array, i)
      break
    end
  end
end

-- return a new table with values from array
function M.array_shallow_clone(array)
  local to = {}
  for _, v in ipairs(array) do
    table.insert(to, v)
  end
  return to
end

function M.reduce(list, memo, func)
  for _, i in ipairs(list) do
    memo = func(memo, i)
  end
  return memo
end

return M
