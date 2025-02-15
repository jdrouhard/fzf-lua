local core = require "fzf-lua.core"
local path = require "fzf-lua.path"
local utils = require "fzf-lua.utils"
local config = require "fzf-lua.config"
local actions = require "fzf-lua.actions"
local libuv = require "fzf-lua.libuv"
local shell = require "fzf-lua.shell"

local M = {}

M.files = function(opts)
  opts = config.normalize_opts(opts, config.globals.git.files)
  if not opts then return end
  opts.cwd = path.git_root(opts.cwd)
  if not opts.cwd then return end
  local contents = core.mt_cmd_wrapper(opts)
  opts = core.set_header(opts, 2)
  return core.fzf_files(opts, contents)
end

M.status = function(opts)
  opts = config.normalize_opts(opts, config.globals.git.status)
  if not opts then return end
  opts.cwd = path.git_root(opts.cwd)
  if not opts.cwd then return end
  if opts.preview then
    opts.preview = vim.fn.shellescape(path.git_cwd(opts.preview, opts.cwd))
  end
  local contents = libuv.spawn_nvim_fzf_cmd(opts,
    function(x)
      -- greedy match anything after last space
      local f = x:match("[^ ]*$")
      if f:sub(#f) == '"' then
        -- `git status -s` wraps
        -- spaced files with quotes
        f = x:sub(1, #x-1)
        f = f:match('[^"]*$')
      end
      return core.make_entry_file(opts, f)
    end,
    function(o)
      return core.make_entry_preprocess(o)
    end)
  opts = core.set_header(opts, 2)
  return core.fzf_files(opts, contents)
end

local function git_cmd(opts)
  opts.cwd = path.git_root(opts.cwd)
  if not opts.cwd then return end
  coroutine.wrap(function ()
    opts = core.set_header(opts, 2)
    local selected = core.fzf(opts, opts.cmd)
    if not selected then return end
    actions.act(opts.actions, selected, opts)
  end)()
end

M.commits = function(opts)
  opts = config.normalize_opts(opts, config.globals.git.commits)
  if not opts then return end
  opts.preview = vim.fn.shellescape(path.git_cwd(opts.preview, opts.cwd))
  return git_cmd(opts)
end

M.bcommits = function(opts)
  opts = config.normalize_opts(opts, config.globals.git.bcommits)
  if not opts then return end
  local git_root = path.git_root(opts.cwd)
  if not git_root then return end
  local file = path.relative(vim.fn.expand("%:p"), git_root)
  opts.cmd = opts.cmd .. " " .. file
  local git_ver = utils.git_version()
  -- rotate-to first appeared with git version 2.31
  if git_ver and git_ver >= 2.31 then
    opts.preview = opts.preview .. " --rotate-to=" .. vim.fn.shellescape(file)
  end
  opts.preview = vim.fn.shellescape(path.git_cwd(opts.preview, opts.cwd))
  return git_cmd(opts)
end

M.branches = function(opts)
  opts = config.normalize_opts(opts, config.globals.git.branches)
  if not opts then return end
  opts.fzf_opts["--no-multi"] = ''
  opts._preview = path.git_cwd(opts.preview, opts.cwd)
  opts.preview = shell.preview_action_cmd(function(items)
    local branch = items[1]:gsub("%*", "")  -- remove the * from current branch
    if branch:find("%)") ~= nil then
      -- (HEAD detached at origin/master)
      branch = branch:match(".* ([^%)]+)") or ""
    else
      -- remove anything past space
      branch = branch:match("[^ ]+")
    end
    return opts._preview:gsub("{.*}", branch)
    -- return "echo " .. branch
  end)
  return git_cmd(opts)
end

return M
