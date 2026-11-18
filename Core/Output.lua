local _, addon = ...

addon.outputLines = {}

function addon:AppendOutput(message)
    self.outputLines[#self.outputLines + 1] = string.format("[%s] %s", date("%H:%M:%S"), tostring(message))
    if #self.outputLines > 100 then
        table.remove(self.outputLines, 1)
    end
end

function addon:Log(message)
    if self.UI and type(self.UI.Log) == "function" then
        self.UI:Log(self.name, tostring(message))
    else
        self:AppendOutput(message)
    end
end
