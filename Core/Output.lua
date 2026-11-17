local _, addon = ...

addon.outputLines = {}

function addon:AppendOutput(message)
    self.outputLines[#self.outputLines + 1] = string.format("[%s] %s", date("%H:%M:%S"), tostring(message))
    if #self.outputLines > 100 then
        table.remove(self.outputLines, 1)
    end
end

function addon:PrintOutput()
    if #self.outputLines == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cffd8b24ahudcraft|r: No diagnostic output is available.")
        return
    end
    local firstLine = math.max(1, #self.outputLines - 29)
    for index = firstLine, #self.outputLines do
        DEFAULT_CHAT_FRAME:AddMessage("|cffd8b24ahudcraft|r " .. self.outputLines[index])
    end
end

function addon:Log(message)
    if self.UI and type(self.UI.Log) == "function" then
        self.UI:Log(self.name, tostring(message))
    else
        self:AppendOutput(message)
    end
end
