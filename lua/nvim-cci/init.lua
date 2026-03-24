local M = {}

M.config = {}

--- Set up the plugin with user options merged over the defaults.
--- Also checks authentication state and notifies the user if not logged in.
--- @param opts table|nil
function M.setup(opts)
  local config = require('nvim-cci.config')
  M.config = config.merge(opts)

  local auth = require('nvim-cci.auth')
  if not auth.is_authenticated() then
    vim.notify(
      '[nvim-cci] Not logged in to CircleCI. Run :CCILogin to authenticate.',
      vim.log.levels.INFO
    )
  end
end

return M
