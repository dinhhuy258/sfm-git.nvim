local Job = require "plenary.job"
local debounce = require "sfm.utils.debounce"
local path = require "sfm.utils.path"

local is_windows = vim.fn.has "win32" == 1 or vim.fn.has "win32unix" == 1
local path_separator = package.config:sub(1, 1)

local M = {
  git_roots = {},
  git_roots_cache = {},
}

local function reduce(list, memo, func)
  for _, i in ipairs(list) do
    memo = func(memo, i)
  end
  return memo
end

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

local function get_simple_git_status_code(status)
  -- prioritze M then A over all others
  if status:match "U" or status == "AA" or status == "DD" then
    return "U"
  elseif status:match "M" then
    return "M"
  elseif status:match "[ACR]" then
    return "A"
  elseif status:match "!$" then
    return "!"
  elseif status:match "?$" then
    return "?"
  else
    local len = #status
    while len > 0 do
      local char = status:sub(len, len)
      if char ~= " " then
        return char
      end
      len = len - 1
    end

    return status
  end
end

local function get_priority_git_status_code(status, other_status)
  if not status then
    return other_status
  elseif not other_status then
    return status
  elseif status == "U" or other_status == "U" then
    return "U"
  elseif status == "?" or other_status == "?" then
    return "?"
  elseif status == "M" or other_status == "M" then
    return "M"
  elseif status == "A" or other_status == "A" then
    return "A"
  else
    return status
  end
end

local function parse_git_status_line(context, line)
  context.lines_parsed = context.lines_parsed + 1
  if type(line) ~= "string" then
    return
  end
  if #line < 4 then
    return
  end
  local git_root = context.git_root
  local git_status = context.git_status
  local exclude_directories = context.exclude_directories

  local line_parts = vim.split(line, "	")
  if #line_parts < 2 then
    return
  end
  local status = line_parts[1]
  local relative_path = line_parts[2]

  -- rename output is `R000 from/filename to/filename`
  if status:match "^R" then
    relative_path = line_parts[3]
  end

  -- remove any " due to whitespace in the path
  relative_path = relative_path:gsub('^"', ""):gsub('$"', "")

  if is_windows then
    relative_path = relative_path:gsub("/", "\\")
  end

  local absolute_path = path.join { git_root, relative_path }
  -- merge status result if there are results from multiple passes
  local existing_status = git_status[absolute_path]
  if existing_status then
    local merged = ""
    local i = 0
    while i < 2 do
      i = i + 1
      local existing_char = #existing_status >= i and existing_status:sub(i, i) or ""
      local new_char = #status >= i and status:sub(i, i) or ""
      local merged_char = get_priority_git_status_code(existing_char, new_char)
      merged = merged .. merged_char
    end
    status = merged
  end
  git_status[absolute_path] = status

  if not exclude_directories then
    -- now bubble this status up to the parent directories
    local parts = path.split(absolute_path)
    table.remove(parts) -- pop the last part so we don't override the file's status
    reduce(parts, "", function(acc, part)
      local fpath = acc .. path_separator .. part
      if is_windows then
        fpath = fpath:gsub("^" .. path_separator, "")
      end
      local path_status = git_status[fpath]
      local file_status = get_simple_git_status_code(status)
      git_status[fpath] = get_priority_git_status_code(path_status, file_status)
      return fpath
    end)
  end
end

local function parse_lines_batch(context, job_complete_callback)
  local i, batch_size = 0, context.batch_size

  if context.lines_total == nil then
    -- first time through, get the total number of lines
    context.lines_total = math.min(context.max_lines, #context.lines)
    context.lines_parsed = 0
    if context.lines_total == 0 then
      if type(job_complete_callback) == "function" then
        job_complete_callback()
      end
      return
    end
  end
  batch_size = math.min(context.batch_size, context.lines_total - context.lines_parsed)

  while i < batch_size do
    i = i + 1
    parse_git_status_line(context, context.lines[context.lines_parsed + 1])
  end

  if context.lines_parsed >= context.lines_total then
    if type(job_complete_callback) == "function" then
      job_complete_callback()
    end
  else
    -- add small delay so other work can happen
    vim.defer_fn(function()
      parse_lines_batch(context, job_complete_callback)
    end, context.batch_delay)
  end
end

function M.get_status_async(fpath, callback)
  get_git_root_async(fpath, function(git_root)
    if git_root == nil then
      print("[sfm-git] Failed to get git root for the given path: " .. fpath)

      return
    end

    local git_base = "HEAD"

    local context = {
      git_root = git_root,
      git_status = {},
      exclude_directories = false,
      lines = {},
      lines_parsed = 0,
      batch_size = 1000,
      batch_delay = 10,
      max_lines = 100000,
    }

    local parse_lines = vim.schedule_wrap(function()
      parse_lines_batch(context, function()
        callback(context.git_status)
      end) -- job_complete_callback
    end)

    local should_process = function(err, _, job, err_msg)
      if vim.v.dying > 0 or vim.v.exiting ~= vim.NIL then
        job:shutdown()
        return false
      end
      if err and err > 0 then
        print(err_msg)

        return false
      end
      return true
    end

    debounce.debounce("sfm-git-" .. git_root, 1000, function()
      local staged_job = Job:new {
        command = "git",
        args = { "-C", git_root, "diff", "--staged", "--name-status", git_base, "--" },
        enable_recording = false,
        maximium_results = context.max_lines,
        on_stdout = vim.schedule_wrap(function(err, line, job)
          if should_process(err, line, job, "status_async staged error:") then
            table.insert(context.lines, line)
          end
        end),
        on_stderr = function() -- err, line
          print "[sfm-git] Failed to retrieve git staged"
        end,
      }

      local unstaged_job = Job:new {
        command = "git",
        args = { "-C", git_root, "diff", "--name-status" },
        enable_recording = false,
        maximium_results = context.max_lines,
        on_stdout = vim.schedule_wrap(function(err, line, job)
          if should_process(err, line, job, "status_async unstaged error:") then
            if line then
              line = " " .. line
            end

            table.insert(context.lines, line)
          end
        end),
        on_stderr = function(_, _) -- err, line
          print "[sfm-git] Failed to retrieve git unstaged"
        end,
      }

      local untracked_job = Job:new {
        command = "git",
        args = { "-C", git_root, "ls-files", "--exclude-standard", "--others" },
        enable_recording = false,
        maximium_results = context.max_lines,
        on_stdout = vim.schedule_wrap(function(err, line, job)
          if should_process(err, line, job, "status_async untracked error:") then
            if line then
              line = "?	" .. line
            end

            table.insert(context.lines, line)
          end
        end),
        on_stderr = function(_, _) -- err, line
          print "[sfm-git] Failed to retrieve git untracked"
        end,
      }

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
          if result[1] == "no" then
            unstaged_job:after(parse_lines)
            Job.chain(staged_job, unstaged_job)
          else
            untracked_job:after(parse_lines)
            Job.chain(staged_job, unstaged_job, untracked_job)
          end
        end,
      }):start()
    end)
  end)
end

return M
