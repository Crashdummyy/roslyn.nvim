local M = {}

local function get_mason_path()
    -- Fallback in case mason is lazy loaded or MASON env var is just not set
    local expanded_mason = vim.fn.expand("$MASON")
    return expanded_mason == "$MASON" and vim.fs.joinpath(vim.fn.stdpath("data"), "mason") or expanded_mason
end

---@return string
function M.get_roslyn_lsp_path()
    local sysname = vim.uv.os_uname().sysname:lower()
    local iswin = not not (sysname:find("windows") or sysname:find("mingw"))
    local language_server_bin = iswin and "roslyn-language-server.cmd" or "roslyn-language-server"

    local mason = get_mason_path()
    local candidates = {
        vim.fs.joinpath(mason, "bin", language_server_bin),
        language_server_bin,
    }

    for _, candidate in ipairs(candidates) do
        if vim.fn.executable(candidate) == 1 then
            return candidate
        end
    end

    return "Microsoft.CodeAnalysis.LanguageServer"
end

--- Temporary code. TODO - Remove in a few weeks after everyone installed at least 5.12.0-1.26453.19 because at that point we changed the mason link
--- Resolves the `roslyn-language-server` thin client that ships next to the server binary.
---@return string?
function M.get_roslyn_thin_client_path()
    local sysname = vim.uv.os_uname().sysname:lower()
    local iswin = not not (sysname:find("windows") or sysname:find("mingw"))
    local thin_client_bin = iswin and "roslyn-language-server.exe" or "roslyn-language-server"
    local server_bin = iswin and "Microsoft.CodeAnalysis.LanguageServer.exe" or "Microsoft.CodeAnalysis.LanguageServer"

    local server_path = vim.fn.exepath(M.get_roslyn_lsp_path())
    if server_path == "" then
        return nil
    end
    server_path = vim.uv.fs_realpath(server_path) or server_path

    local basename = vim.fs.basename(server_path)
    if basename == thin_client_bin then
        return server_path
    end

    if basename == server_bin then
        local sibling = vim.fs.joinpath(vim.fs.dirname(server_path), thin_client_bin)
        if vim.fn.executable(sibling) == 1 then
            return sibling
        end
    end

    return nil
end

function M.populate_virtual_buffer_content(lsp_client, uri, bufnr)
    assert(lsp_client, "Must have a `roslyn` client to load roslyn source generated file")

    ---@type lsp.TextDocumentContentParams
    local params = {
        uri = uri,
    }

    local response = lsp_client:request_sync("workspace/textDocumentContent", params, nil, bufnr)

    assert(not response.err, vim.inspect(response.err))
    local content = response.result.text or ""
    if content == vim.NIL then
        content = ""
    end
    local normalized = string.gsub(content, "\r\n", "\n")
    local source_lines = vim.split(normalized, "\n", { plain = true, trimempty = true })

    vim.bo[bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, source_lines)
    vim.bo[bufnr].modifiable = false
    vim.bo[bufnr].modified = false
end

return M
