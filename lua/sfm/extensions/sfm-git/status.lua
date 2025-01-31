local Job = require "plenary.job"

local api = require "sfm.api"

local watcher = require "sfm.extensions.sfm-git.watcher"
local config = require "sfm.extensions.sfm-git.config"

local is_windows = vim.fn.has "win32" == 1 or vim.fn.has "win32unix" == 1
local GIT_STATUS_IGNORE = "!!"
local MAX_LINES = 100000
local BATCH_SIZE = 1000
local BATCH_DELAY = 10
local WATCHED_FILES = {
  "FETCH_HEAD", -- remote ref
  "HEAD", -- local ref
  "HEAD.lock", -- HEAD will not always be updated e.g. revert
  "config", -- user config
  "index", -- staging area
}

local M = {
  _callback = function(_, _) end,
  _git_roots_cache = {},
  _watchers = {},
}

local function reduce(list, memo, func)
  for _, i in ipairs(list) do
    memo = func(memo, i)
  end
  return memo
end

local function get_git_root_async(fpath, callback)
  if M._git_roots_cache[fpath] ~= nil then
    callback(M._git_roots_cache[fpath])

    return
  end

  local args = { "-C", fpath, "rev-parse", "--show-toplevel" }

  Job:new({
    command = "git",
    args = args,
    enabled_recording = true,
    on_exit = function(self, code, _)
      if code ~= 0 then
        callback(nil)

        return
      end

      local git_root = self:result()[1]

      if is_windows then
        git_root = git_root:gsub("/", "\\")
      end

      M._git_roots_cache[fpath] = git_root
      M._git_roots_cache[git_root] = git_root

      callback(git_root)
    end,
  }):start()
end

local function parse_git_status_line(git_root, line)
  if type(line) ~= "string" or #line < 4 then
    return nil
  end

  local status = line:sub(1, 2)
  local relative_path = line:sub(4)

  if status:match "^R" then
    -- rename output is `from/filename -> to/filename`
    relative_path = string.match(relative_path, "->%s+(.+)")
  end

  -- remove any " due to whitespace in the path
  relative_path = relative_path:gsub('^"', ""):gsub('$"', "")

  if is_windows then
    relative_path = relative_path:gsub("/", "\\")
  end

  local absolute_path = api.path.join { git_root, relative_path }

  return {
    path = absolute_path,
    status = status,
  }
end

local function parse_git_statuses_batch(ctx, job_complete_callback)
  local i, batch_size = 0, BATCH_SIZE

  if ctx.lines_total == nil then
    -- first time through, get the total number of lines
    ctx.lines_total = math.min(MAX_LINES, #ctx.lines)
    ctx.lines_parsed = 0
    if ctx.lines_total == 0 then
      if type(job_complete_callback) == "function" then
        job_complete_callback()
      end

      return
    end
  end

  batch_size = math.min(BATCH_SIZE, ctx.lines_total - ctx.lines_parsed)

  while i < batch_size do
    i = i + 1
    local state = parse_git_status_line(ctx.git_root, ctx.lines[ctx.lines_parsed + 1])
    ctx.lines_parsed = ctx.lines_parsed + 1

    if state ~= nil then
      ctx.git_statuses.direct[state.path] = ctx.git_statuses.direct[state.path] or {}
      ctx.git_statuses.direct[state.path][state.status] = true

      if state.status ~= GIT_STATUS_IGNORE then
        -- parse indirect
        local parts = api.path.split(state.path)
        table.remove(parts) -- pop the last part so we don't override the file's status
        reduce(parts, "", function(acc, part)
          local fpath = acc .. api.path.path_separator .. part
          if is_windows then
            fpath = fpath:gsub("^" .. api.path.path_separator, "")
          end

          ctx.git_statuses.indirect[fpath] = ctx.git_statuses.indirect[fpath] or {}
          ctx.git_statuses.indirect[fpath][state.status] = true

          return fpath
        end)
      end
    end
  end

  if ctx.lines_parsed >= ctx.lines_total then
    if type(job_complete_callback) == "function" then
      job_complete_callback()
    end
  else
    -- add small delay so other work can happen
    vim.defer_fn(function()
      parse_git_statuses_batch(ctx, job_complete_callback)
    end, BATCH_DELAY)
  end
end

function M.reload_git_status_async()
  for git_root, _ in pairs(M._watchers) do
    M.update_git_status_async(git_root)
  end
end

function M.update_git_status_async(fpath, force)
  get_git_root_async(fpath, function(git_root)
    if git_root == nil then
      return
    end

    force = force == nil and true or force

    if M._watchers[git_root] == nil then
      M._watchers[git_root] = watcher.Watcher:new(api.path.join { git_root, ".git" }, WATCHED_FILES, function(w)
        if w:is_destroyed() then
          return
        end

        api.debounce("sfm-git-watcher" .. git_root, config.opts.debounce_interval_ms, function()
          M.update_git_status_async(w.git_root)
        end)
      end, {
        git_root = git_root,
      })
      -- start watcher
      M._watchers[git_root]:start()
    elseif not force then
      return
    end

    local ctx = {
      git_root = git_root,
      git_statuses = {
        direct = {},
        indirect = {},
      },
      lines = {},
      lines_parsed = 0,
    }

    local parse_git_statuses = vim.schedule_wrap(function()
      parse_git_statuses_batch(ctx, function()
        M._callback(ctx.git_root, ctx.git_statuses)
      end) -- job_complete_callback
    end)

    api.debounce("sfm-git-" .. git_root, config.opts.debounce_interval_ms, function()
      Job:new({
        command = "git",
        args = {
          "-C",
          git_root,
          "config",
          "--get",
          "status.showUntrackedFiles",
        },
        enabled_recording = true,
        on_exit = function(self, _, _)
          local result = self:result()
          local list_untracked = result[1] ~= "no"
          local untracked = list_untracked and "-u" or nil
          local ignored = list_untracked and "--ignored=matching" or "--ignored=no"

          local status_job = Job:new {
            command = "git",
            args = {
              "-C",
              git_root,
              "--no-optional-locks",
              "status",
              "--porcelain=v1",
              ignored,
              untracked,
            },
            enable_recording = true,
            maximium_results = MAX_LINES,
            on_exit = function(job, job_code, _)
              if job_code ~= 0 then
                return
              end

              ctx.lines = job:result()
            end,
            -- Temporary disable error handling
            -- on_stderr = function() -- err, line
            --   api.log.error "[sfm-git] Failed to retrieve git status"
            -- end,
          }

          status_job:after(parse_git_statuses)
          Job.chain(status_job)
        end,
      }):start()
    end)
  end)
end

function M.stop_watchers()
  for _, w in pairs(M._watchers) do
    w:destroy()
  end

  M._watchers = {}
end

function M.setup(callback)
  M._callback = callback
end

return M
