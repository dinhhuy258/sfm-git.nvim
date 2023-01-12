local Job = require "plenary.job"
local debounce = require "sfm.utils.debounce"
local path = require "sfm.utils.path"

local is_windows = vim.fn.has "win32" == 1 or vim.fn.has "win32unix" == 1

local GIT_STATUS_IGNORE = "!!"
local MAX_LINES = 100000
local BATCH_SIZE = 1000
local BATCH_DELAY = 10

local M = {
  git_roots = {},
  git_roots_cache = {},
}

local function get_git_root_async(fpath, callback)
  if M.git_roots_cache[fpath] ~= nil then
    callback(M.git_roots_cache[fpath])

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

      M.git_roots_cache[fpath] = git_root
      M.git_roots[git_root] = true
      callback(git_root)
    end,
  }):start()
end

local function parse_git_status_line(ctx, line)
  ctx.lines_parsed = ctx.lines_parsed + 1
  if type(line) ~= "string" or #line < 4 then
    return
  end

  local git_root = ctx.git_root
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

  local absolute_path = path.join { git_root, relative_path }
  ctx.git_statuses.direct[absolute_path] = ctx.git_statuses.direct[absolute_path] or {}
  table.insert(ctx.git_statuses.direct[absolute_path], status)
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
    parse_git_status_line(ctx, ctx.lines[ctx.lines_parsed + 1])
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

function M.get_status_async(fpath, callback)
  get_git_root_async(fpath, function(git_root)
    if git_root == nil then
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
        callback(ctx.git_statuses)
      end) -- job_complete_callback
    end)

    debounce.debounce("sfm-git-" .. git_root, 1000, function()
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
            on_stderr = function() -- err, line
              print "[sfm-git] Failed to retrieve git status"
            end,
          }

          status_job:after(parse_git_statuses)
          Job.chain(status_job)
        end,
      }):start()
    end)
  end)
end

return M
