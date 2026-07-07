local M = {}

local API_NAMES = {
  "openapi.yaml", "openapi.yml", "openapi.json",
  "swagger.yaml", "swagger.yml", "swagger.json",
}

local function find_files()
  -- Fast: git ls-files uses index, no filesystem walk
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

  -- Fallback: vim.fs.find mit Limit (trotzdem blockierend bei großen Trees)
  local found = vim.fs.find(API_NAMES, { type = "file", limit = 10 })
  table.sort(found)
  return found
end

local function open_http_buffer(input, lines)
  if not lines or #lines == 0 then
    vim.notify("openapi: Conversion produced no output", vim.log.levels.ERROR)
    return
  end
  local buf = vim.api.nvim_create_buf(false, true)
  pcall(vim.api.nvim_buf_set_name, buf,
    "openapi://" .. vim.fn.fnamemodify(input, ":t:r") .. ".http")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = "http"
  vim.api.nvim_set_current_buf(buf)
  vim.notify("openapi: Imported " .. vim.fn.fnamemodify(input, ":t"), vim.log.levels.INFO)
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

function M.import_from(input)
  input = vim.fn.expand(input)
  if vim.fn.filereadable(input) ~= 1 then
    vim.notify("openapi: File not found: " .. input, vim.log.levels.ERROR)
    return
  end

  vim.notify("openapi: Converting " .. vim.fn.fnamemodify(input, ":t") .. "...", vim.log.levels.INFO)

  local function try_python()
    vim.system({ "python3", "-c", PYTHON_SCRIPT, input }, { text = true }, function(r)
      if r.code == 0 and r.stdout and #r.stdout > 0 then
        open_http_buffer(input, vim.fn.split(r.stdout, "\n"))
      else
        vim.notify("openapi: Failed: " .. (r.stderr or "unknown"), vim.log.levels.ERROR)
      end
    end)
  end

  if vim.fn.executable("kulala-fmt") == 1 then
    vim.system({ "kulala-fmt", "convert", "--from", "openapi", input }, { text = true }, function(r)
      if r.code ~= 0 then
        vim.notify("openapi: kulala-fmt failed, trying Python fallback", vim.log.levels.WARN)
        try_python()
        return
      end
      local generated
      for _, ext in ipairs({ ".http", ".rest" }) do
        local candidate = input:gsub("%.[^.]*$", "") .. ext
        if vim.fn.filereadable(candidate) == 1 then generated = candidate; break end
      end
      if not generated then
        try_python()
        return
      end
      local lines = vim.fn.readfile(generated)
      vim.fn.delete(generated)
      open_http_buffer(input, lines)
    end)
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
  vim.schedule(function()
    vim.ui.select(files, {
      prompt = "Select OpenAPI spec to import",
      format_item = function(f) return vim.fn.fnamemodify(f, ":~:.") end,
    }, function(choice)
      if choice then M.import_from(choice) end
    end)
  end)
end

vim.api.nvim_create_augroup("openapi_import", { clear = true })
vim.api.nvim_create_autocmd("BufRead", {
  group = "openapi_import",
  pattern = API_PATTERNS,
  callback = function()
    vim.defer_fn(function()
      vim.notify("OpenAPI spec detected. Use <leader>Rf or :OpenApiImport",
        vim.log.levels.INFO)
    end, 500)
  end,
})

return M
