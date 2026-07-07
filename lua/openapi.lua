local M = {}

local API_NAMES = {
  "openapi.yaml", "openapi.yml", "openapi.json",
  "swagger.yaml", "swagger.yml", "swagger.json",
}

local function find_files()
  if vim.fn.executable("git") == 1 and vim.fn.isdirectory(".git") == 1 then
    local patterns = {}
    for _, name in ipairs(API_NAMES) do
      table.insert(patterns, ":(glob)**/" .. name)
    end
    local result = vim.fn.systemlist({ "git", "ls-files", "--", unpack(patterns) })
    local files = {}
    for _, f in ipairs(result) do
      if f ~= "" and vim.fn.filereadable(f) == 1 then
        table.insert(files, vim.fn.getcwd() .. "/" .. f)
      end
    end
    table.sort(files)
    return files
  end
  local found = vim.fs.find(API_NAMES, { type = "file", limit = 10 })
  table.sort(found)
  return found
end

local PYTHON_SCRIPT = [[
import json, sys
try:
    import yaml
except ImportError:
    import subprocess
    subprocess.run([sys.executable, "-m", "pip", "install", "pyyaml", "-q"],
        capture_output=True)
    import yaml

def to_http(data):
    lines = []
    servers = data.get("servers") or [{"url": "http://localhost"}]
    base_url = servers[0].get("url", "http://localhost")
    info = data.get("info", {})
    lines.append(f"# {info.get('title', 'API')}")
    lines.append(f"# Base URL: {base_url}")
    lines.append("")
    for path, methods in data.get("paths", {}).items():
        for method in ("get","post","put","patch","delete","options","head"):
            spec = methods.get(method) or next((v for k,v in methods.items() if k.upper()==method.upper()), None)
            if not spec: continue
            name = spec.get("summary") or spec.get("operationId") or f"{method.upper()} {path}"
            lines.append(f"### {name}")
            lines.append(f"{method.upper()} {base_url}{path}")
            for param in spec.get("parameters", []):
                if param.get("in") == "header":
                    lines.append(f"{param['name']}: {{{{{param['name']}}}}}")
            body = spec.get("requestBody", {})
            content = body.get("content", {})
            for ct, ct_spec in content.items():
                lines.append(f"Content-Type: {ct}")
                schema = ct_spec.get("schema", {})
                example = schema.get("example") or (schema.get("properties") and {k: v.get("example", "") for k, v in schema["properties"].items()}) or None
                if example is None and "$ref" in schema:
                    ref = schema["$ref"].split("/")
                    root = data
                    for part in ref[1:]: root = root.get(part, {})
                    example = root.get("example")
                if example is not None:
                    lines.append("")
                    try: lines.append(json.dumps(example, indent=2, default=str))
                    except: pass
                break
            lines.append("")
    return lines

with open(sys.argv[1]) as f:
    raw = f.read()
try: data = json.loads(raw)
except: data = yaml.safe_load(raw)
sys.stdout.write("\n".join(to_http(data)))
]]

--- Parse endpoint entries from .http lines.
--- Returns list of { name, method, path, line }
local function parse_endpoints(lines)
  local endpoints = {}
  local current_name, current_method, current_path, current_line

  for i, line in ipairs(lines) do
    local name_match = line:match("^###%s*(.+)$")
    if name_match then
      if current_name then
        table.insert(endpoints, { name = current_name, method = current_method, path = current_path, line = current_line })
      end
      current_name = name_match
    end

    local method_match = line:match("^(%u+)%s+(%S+)")
    if method_match and current_name then
      current_method = method_match
      current_path = line:match("^%u+%s+(.+)")
      current_line = i
    end
  end
  if current_name then
    table.insert(endpoints, { name = current_name, method = current_method, path = current_path, line = current_line })
  end
  return endpoints
end

local hidden_buf = nil

--- Show a picker with all endpoints and run the selected one.
local function show_endpoint_picker(lines, input)
  local endpoints = parse_endpoints(lines)
  if #endpoints == 0 then
    vim.notify("openapi: No endpoints found in spec", vim.log.levels.WARN)
    return
  end

  hidden_buf = vim.api.nvim_create_buf(false, true)
  pcall(vim.api.nvim_buf_set_name, hidden_buf,
    "openapi://" .. vim.fn.fnamemodify(input, ":t:r") .. ".http")
  vim.api.nvim_buf_set_lines(hidden_buf, 0, -1, false, lines)
  vim.bo[hidden_buf].filetype = "http"
  vim.bo[hidden_buf].buflisted = true

  vim.schedule(function()
    vim.ui.select(endpoints, {
      prompt = "Select endpoint (" .. #endpoints .. " available)",
      format_item = function(e)
        local method = e.method or "?"
        return string.format("%-6s %s", method, e.name)
      end,
    }, function(choice)
      if not choice then return end

      -- Store the current buffer so we can restore later
      local prev_buf = vim.api.nvim_get_current_buf()
      local prev_win = vim.api.nvim_get_current_win()

      -- Switch to hidden .http buffer and position cursor
      vim.api.nvim_set_current_buf(hidden_buf)
      if choice.line then
        pcall(vim.api.nvim_win_set_cursor, 0, { choice.line, 0 })
      end

      -- Execute the request via kulala
      local ok, err = pcall(require("kulala").run)
      if not ok then
        vim.notify("openapi: " .. tostring(err), vim.log.levels.ERROR)
        -- Restore buffer if kulala failed
        pcall(vim.api.nvim_set_current_buf, prev_buf)
      end
    end)
  end)
end

function M.import_from(input)
  input = vim.fn.expand(input)
  if vim.fn.filereadable(input) ~= 1 then
    vim.notify("openapi: File not found: " .. input, vim.log.levels.ERROR)
    return
  end

  vim.notify("openapi: Converting " .. vim.fn.fnamemodify(input, ":t") .. "...", vim.log.levels.INFO)

  local done = false

  local function try_python()
    if done then return end
    vim.system({ "python3", "-c", PYTHON_SCRIPT, input }, { text = true }, function(r)
      if done then return end
      if r.code ~= 0 then
        vim.schedule(function()
          vim.notify("openapi: Failed: " .. (r.stderr or "unknown"), vim.log.levels.ERROR)
        end)
        return
      end
      vim.schedule(function()
        show_endpoint_picker(vim.split(r.stdout, "\n"), input)
      end)
    end)
  end

  local function handle_kulala_result(r)
    if done then return end
    if r.code ~= 0 then
      vim.schedule(function()
        vim.notify("openapi: kulala-fmt failed, trying Python fallback", vim.log.levels.WARN)
        try_python()
      end)
      return
    end
    vim.schedule(function()
      if done then return end
      local generated
      for _, ext in ipairs({ ".http", ".rest" }) do
        local candidate = input:gsub("%.[^.]*$", "") .. ext
        if vim.fn.filereadable(candidate) == 1 then generated = candidate; break end
      end
      if not generated then try_python() return end
      done = true
      local lines = vim.fn.readfile(generated)
      vim.fn.delete(generated)
      show_endpoint_picker(lines, input)
    end)
  end

  if vim.fn.executable("kulala-fmt") == 1 then
    vim.system({ "kulala-fmt", "convert", "--from", "openapi", input }, { text = true }, handle_kulala_result)
  elseif vim.fn.executable("python3") == 1 then
    try_python()
  else
    vim.notify("openapi: Neither kulala-fmt nor python3 available", vim.log.levels.ERROR)
  end
end

function M.import()
  local files = find_files()
  if #files == 0 then
    vim.notify("openapi: No OpenAPI spec files found", vim.log.levels.WARN)
    return
  end
  if #files == 1 then
    M.import_from(files[1])
    return
  end
  vim.ui.select(files, {
    prompt = "Select OpenAPI spec to import",
    format_item = function(f) return vim.fn.fnamemodify(f, ":~:.") end,
  }, function(choice)
    if choice then M.import_from(choice) end
  end)
end

vim.api.nvim_create_augroup("openapi_import", { clear = true })
vim.api.nvim_create_autocmd("BufRead", {
  group = "openapi_import",
  pattern = API_NAMES,
  callback = function()
    vim.defer_fn(function()
      vim.notify("OpenAPI spec detected. Use <leader>Rf or :OpenApiImport",
        vim.log.levels.INFO)
    end, 500)
  end,
})

return M
