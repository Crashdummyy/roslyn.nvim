local M = {}

---@class RoslynExtension
---@field enabled boolean
---@field config (RoslynExtensionConfig | fun(): RoslynExtensionConfig)

---@class RoslynExtensionConfig
---@field path string?
---@field args? string[]

---@class RoslynNvimDaemonConfig
---@field enabled boolean
---@field keep_alive? integer

---@class InternalRoslynNvimConfig
---@field filewatching "auto" | "off" | "roslyn"
---@field choose_target? fun(targets: string[]): string?
---@field ignore_target? fun(target: string): boolean
---@field broad_search boolean
---@field lock_target boolean
---@field debug boolean
---@field daemon RoslynNvimDaemonConfig

---@class RoslynNvimConfig
---@field filewatching? boolean | "auto" | "off" | "roslyn"
---@field choose_target? fun(targets: string[]): string?
---@field ignore_target? fun(target: string): boolean
---@field broad_search? boolean
---@field lock_target? boolean
---@field debug? boolean
---@field daemon? RoslynNvimDaemonConfig

---@type InternalRoslynNvimConfig
local roslyn_config = {
    filewatching = "auto",
    choose_target = nil,
    ignore_target = nil,
    broad_search = false,
    lock_target = false,
    debug = false,
    daemon = {
        enabled = false,
    },
}

local function configure_daemon(daemon)
    local thin_client = require("roslyn.utils").get_roslyn_thin_client_path()
    if not thin_client then
        vim.notify(
            "roslyn.nvim: `daemon.enabled` is set, but the `roslyn-language-server` thin client was not found. "
            .. "If on mason please update to >= 5.12.0-1.26453.19",
            vim.log.levels.WARN,
            { title = "roslyn.nvim" }
        )
        return
    end

    local cmd = { thin_client, "--stdio", "--daemon-mode", "--clientProcessId", tostring(vim.uv.os_getpid()) }
    if daemon.keep_alive then
        vim.list_extend(cmd, { "--daemonKeepAlive", tostring(daemon.keep_alive) })
    end

    vim.lsp.config("roslyn", { cmd = cmd })
end

function M.get()
    return roslyn_config
end

---@param user_config? RoslynNvimConfig
---@return InternalRoslynNvimConfig
function M.setup(user_config)
    roslyn_config = vim.tbl_deep_extend("force", roslyn_config, user_config or {})

    -- HACK: Enable or disable filewatching based on config options
    -- `off` enables filewatching but just ignores all files to watch at a later stage
    -- `roslyn` disables filewatching to force the server to take care of this
    if roslyn_config.filewatching == "off" or roslyn_config.filewatching == "roslyn" then
        vim.lsp.config("roslyn", {
            -- HACK: Set filewatching capabilities here based on filewatching option to the plugin
            capabilities = {
                workspace = {
                    didChangeWatchedFiles = {
                        dynamicRegistration = roslyn_config.filewatching == "off",
                    },
                },
            },
        })
    end

    if roslyn_config.daemon.enabled then
        configure_daemon(roslyn_config.daemon)
    end

    return roslyn_config
end

return M
