local M = {}

M.defaults = {
  keymap = {
    toggle = '<leader>ci',
    refresh = 'r',
    approve = 'a',
    abort = 'x',
    rerun = 'R',
    close = 'q',
  },
}

--- Merge user-provided config over the defaults.
--- @param user_config table|nil
--- @return table
function M.merge(user_config)
  if user_config == nil then
    user_config = {}
  end
  local result = vim.deepcopy(M.defaults)
  for k, v in pairs(user_config) do
    if type(v) == 'table' and type(result[k]) == 'table' then
      for ik, iv in pairs(v) do
        result[k][ik] = iv
      end
    else
      result[k] = v
    end
  end
  return result
end

return M
