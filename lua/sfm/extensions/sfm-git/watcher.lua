-- this file are copied from nvim-tree

local api = require "sfm.api"

local M = {}

local Event = {
  _events = {},
}
Event.__index = Event

local Watcher = {}
Watcher.__index = Watcher

local FS_EVENT_FLAGS = {
  -- inotify or equivalent will be used; fallback to stat has not yet been implemented
  stat = false,
  -- recursive is not functional in neovim's libuv implementation
  recursive = false,
}

function Event:new(path)
  local e = setmetatable({
    _path = path,
    _fs_event = nil,
    _listeners = {},
  }, Event)

  if e:start() then
    Event._events[path] = e
    return e
  else
    return nil
  end
end

function Event:start()
  local rc, _, name

  self._fs_event, _, name = vim.loop.new_fs_event()
  if not self._fs_event then
    self._fs_event = nil
    api.log.error(string.format("Could not initialize an fs_event watcher for path %s : %s", self._path, name))

    return false
  end

  local event_cb = vim.schedule_wrap(function(err, filename)
    if err then
      self:destroy(string.format("File system watcher failed (%s) for path %s, halting watcher.", err, self._path))
    else
      for _, listener in ipairs(self._listeners) do
        listener(filename)
      end
    end
  end)

  rc, _, name = self._fs_event:start(self._path, FS_EVENT_FLAGS, event_cb)
  if rc ~= 0 then
    api.log.error(string.format("Could not start the fs_event watcher for path %s : %s", self._path, name))

    return false
  end

  return true
end

function Event:add(listener)
  table.insert(self._listeners, listener)
end

function Event:remove(listener)
  for pos, l in ipairs(self._listeners) do
    if l == listener then
      table.remove(self._listeners, pos)

      break
    end
  end

  if vim.tbl_isempty(self._listeners) then
    self:destroy()
  end
end

function Event:destroy(message)
  if self._fs_event then
    if message then
      api.log.error(message)
    end

    local rc, _, name = self._fs_event:stop()
    if rc ~= 0 then
      api.log.error(string.format("Could not stop the fs_event watcher for path %s : %s", self._path, name))
    end
    self._fs_event = nil
  end

  Event._events[self._path] = nil

  self.destroyed = true
end

function Watcher:new(path, files, callback, data)
  local w = setmetatable(data, Watcher)

  w._event = Event._events[path] or Event:new(path)
  w._listener = nil
  w._path = path
  w._files = files
  w._callback = callback

  if not w._event then
    return nil
  end

  return w
end

function Watcher:start()
  self._listener = function(filename)
    if not self._files or vim.tbl_contains(self._files, filename) then
      self._callback(self)
    end
  end

  self._event:add(self._listener)
end

function Watcher:destroy()
  self._event:remove(self._listener)
  self.destroyed = true
end

M.Watcher = Watcher

return M
