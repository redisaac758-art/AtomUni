-- Central owner for runtime resources that must not outlive the UI/backend.
local Cleanup = {
    Connections = {},
    Tasks = {},
    Drawings = {},
    Instances = {},
    Restorers = {},
    Running = false,
    Ran = false,
}

function Cleanup:TrackConnection(connection)
    if not connection then return connection end
    if self.Running or self.Ran then
        pcall(function() connection:Disconnect() end)
    else
        table.insert(self.Connections, connection)
    end
    return connection
end

function Cleanup:TrackTask(thread)
    if not thread then return thread end
    if self.Running or self.Ran then
        pcall(task.cancel, thread)
    else
        table.insert(self.Tasks, thread)
    end
    return thread
end

function Cleanup:TrackDrawing(drawing)
    if not drawing then return drawing end
    if self.Running or self.Ran then
        pcall(function() drawing.Visible = false; drawing:Remove() end)
    else
        table.insert(self.Drawings, drawing)
    end
    return drawing
end

function Cleanup:TrackInstance(instance)
    if not instance then return instance end
    if self.Running or self.Ran then
        pcall(function() instance:Destroy() end)
    else
        table.insert(self.Instances, instance)
    end
    return instance
end

function Cleanup:TrackRestore(callback)
    if type(callback) ~= "function" then return end
    if self.Running or self.Ran then
        pcall(callback)
    else
        table.insert(self.Restorers, callback)
    end
end

local function disconnectAll(list)
    for _, connection in ipairs(list or {}) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(list or {})
end

local function cancelAll(list)
    for _, thread in ipairs(list or {}) do pcall(task.cancel, thread) end
    table.clear(list or {})
end

local function runCallbacks(list)
    for index = #(list or {}), 1, -1 do pcall(list[index]) end
    table.clear(list or {})
end

function Cleanup:Run(config)
    if self.Running or self.Ran then return end
    self.Running = true

    -- Stop every producer before restoring or removing its output.
    disconnectAll(self.Connections)
    cancelAll(self.Tasks)
    if config then
        disconnectAll(config.Connections)
        cancelAll(config.Tasks)
    end

    if config then runCallbacks(config.Cleanup) end
    runCallbacks(self.Restorers)

    for _, instance in ipairs(self.Instances) do
        pcall(function() instance:Destroy() end)
    end
    table.clear(self.Instances)

    for _, drawing in ipairs(self.Drawings) do
        pcall(function()
            drawing.Visible = false
            drawing:Remove()
        end)
    end
    table.clear(self.Drawings)

    if config then
        config.Connections = {}
        config.Tasks = {}
        config.Cleanup = {}
    end
    self.Running = false
    self.Ran = true
end

_G.AtomwareCleanup = Cleanup
