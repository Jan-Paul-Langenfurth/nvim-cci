if vim.g.loaded_nvim_cci then
  return
end
vim.g.loaded_nvim_cci = true

local CCI_TOKEN_URL = 'https://app.circleci.com/settings/user/tokens'

vim.api.nvim_create_user_command('CCIOpen', function()
  require('nvim-cci.ui.panel').open()
end, { desc = 'Open CCI panel' })

vim.api.nvim_create_user_command('CCIClose', function()
  require('nvim-cci.ui.panel').close()
end, { desc = 'Close CCI panel' })

vim.api.nvim_create_user_command('CCIToggle', function()
  require('nvim-cci.ui.panel').toggle()
end, { desc = 'Toggle CCI panel' })

vim.api.nvim_create_user_command('CCILogin', function()
  local auth = require('nvim-cci.auth')

  -- Open the CircleCI personal token settings page in the browser
  local open_cmd = vim.fn.has('mac') == 1 and 'open' or 'xdg-open'
  vim.fn.jobstart({ open_cmd, CCI_TOKEN_URL })

  vim.notify(
    '[nvim-cci] Opening CircleCI token page in browser.\n'
    .. 'Create a Personal API Token there, then paste it below.',
    vim.log.levels.INFO
  )

  local token = vim.fn.input('CircleCI Personal API Token: ')
  if token == '' then
    vim.notify('[nvim-cci] Login cancelled.', vim.log.levels.WARN)
    return
  end

  if auth.store(token) then
    vim.notify('[nvim-cci] Logged in successfully.', vim.log.levels.INFO)
  else
    vim.notify('[nvim-cci] Failed to store token.', vim.log.levels.ERROR)
  end
end, { desc = 'Log in to CircleCI (paste Personal API Token)' })

vim.api.nvim_create_user_command('CCILogout', function()
  local auth = require('nvim-cci.auth')

  if not auth.is_authenticated() then
    vim.notify('[nvim-cci] Not logged in.', vim.log.levels.INFO)
    return
  end

  auth.delete()
  vim.notify('[nvim-cci] Logged out of CircleCI.', vim.log.levels.INFO)
end, { desc = 'Log out of CircleCI and remove stored token' })
