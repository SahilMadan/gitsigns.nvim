local a = require('plenary.async.async')
local wrap = a.wrap
local void = a.void
local scheduler = require('plenary.async.util').scheduler

local cache = require('gitsigns.cache').cache
local config = require('gitsigns.config').config

local api = vim.api

local current_buf = api.nvim_get_current_buf

local namespace = api.nvim_create_namespace('gitsigns_blame')

local timer = vim.loop.new_timer()

local M = {}





local wait_timer = wrap(vim.loop.timer_start, 4)

M.reset = function(bufnr)
   bufnr = bufnr or current_buf()
   api.nvim_buf_del_extmark(bufnr, namespace, 1)
   pcall(api.nvim_buf_del_var, bufnr, 'gitsigns_blame_line_dict')
end

M.update = void(function()
   M.reset()


   wait_timer(timer, config.current_line_blame_opts.delay, 0)
   scheduler()

   local bufnr = current_buf()
   local bcache = cache[bufnr]
   if not bcache or not bcache.git_obj.object_name then
      return
   end

   local buftext = api.nvim_buf_get_lines(bufnr, 0, -1, false)
   local lnum = api.nvim_win_get_cursor(0)[1]
   local result = bcache.git_obj:run_blame(buftext, lnum)

   scheduler()

   M.reset(bufnr)

   api.nvim_buf_set_var(bufnr, 'gitsigns_blame_line_dict', result)
   if config.current_line_blame_opts.virt_text then
      api.nvim_buf_set_extmark(bufnr, namespace, lnum - 1, 0, {
         id = 1,
         virt_text = config.current_line_blame_formatter(
         bcache.git_obj.username,
         result,
         config.current_line_blame_formatter_opts),

         virt_text_pos = config.current_line_blame_opts.virt_text_pos,
      })
   end
end)

M.setup = function()
   vim.cmd('augroup gitsigns_blame | autocmd! | augroup END')
   for k, _ in pairs(cache) do
      M.reset(k)
   end

   if config.current_line_blame then
      vim.cmd([[autocmd gitsigns_blame FocusGained,BufEnter,CursorMoved,CursorMovedI * lua require("gitsigns.current_line_blame").update()]])
      vim.cmd([[autocmd gitsigns_blame FocusLost,BufLeave                            * lua require("gitsigns.current_line_blame").reset()]])
      M.update()
   end
end

return M
