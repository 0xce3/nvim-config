local M = {}

local API_PATTERNS = {
  "**/openapi.yaml", "**/openapi.yml", "**/openapi.json",
  "**/swagger.yaml", "**/swagger.yml", "**/swagger.json",
}

local function find_files()
  local files = {}
  for _, pattern in ipairs(API_PATTERNS) do
    local matches = vim.fn.glob(pattern, false, true)
    for _, f in ipairs(matches) do
      if vim.fn.filereadable(f) == 1 then
        files[f] = true
      end
    end
  end
  local sorted = vim.tbl_keys(files)
  table.sort(sorted)
  return sorted
end

local function convert_with_kulala_fmt(input)
  local cmd = string.format("kulala-fmt convert --from openapi %s", vim.fn.shellescape(input))
  local result = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    return nil, result
  end
  local base = input:gsub("%.[^.]*$", "")
  local generated = base .. ".http"
  if vim.fn.filereadable(generated) ~= 1 then
    generated = vim.fn.fnamemodify(input, ":t:r") .. ".http"
    if vim.fn.filereadable(generated) ~= 1 then
      return nil, "Could not find generated .http file"
    end
  end
  local lines = vim.fn.readfile(generated)
  vim.fn.delete(generated)
  return lines, nil
end

local function convert_with_python(input)
  local script = [[
import json, sys
try:
    import yaml
except ImportError:
    import subprocess, os
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
    paths = data.get("paths", {})
    for path, methods in paths.items():
        for method in ("get","post","put","patch","delete","options","head"):
            spec = methods.get(method)
            if not spec:
                continue
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
                example = None
                if "example" in schema:
                    example = schema["example"]
                elif "$ref" in schema:
                    ref = schema["$ref"].split("/")
                    root = data
                    for part in ref[1:]:
                        root = root.get(part, {})
                    example = root.get("example")
                if example is not None:
                    try:
                        lines.append("")
                        lines.append(json.dumps(example, indent=2, default=str))
                    except:
                        pass
                break
            lines.append("")
    return lines

with open(sys.argv[1]) as f:
    raw = f.read()
try:
    data = json.loads(raw)
except:
    data = yaml.safe_load(raw)
if data:
    sys.stdout.write("\n".join(to_http(data)))
]]
  local result = vim.fn.system({ "python3", "-c", script, input })
  if vim.v.shell_error ~= 0 then
    return nil, result
  end
  return vim.fn.split(result, "\n"), nil
end

function M.import_from(input)
  input = vim.fn.expand(input)
  if vim.fn.filereadable(input) ~= 1 then
    vim.notify("openapi: File not found: " .. input, vim.log.levels.ERROR)
    return
  end

  local lines, err

  if vim.fn.executable("kulala-fmt") == 1 then
    lines, err = convert_with_kulala_fmt(input)
  end

  if not lines then
    if vim.fn.executable("python3") == 1 then
      lines, err = convert_with_python(input)
    else
      err = "Neither kulala-fmt nor python3 available in container"
    end
  end

  if not lines then
    vim.notify("openapi: Conversion failed: " .. (err or "unknown error"), vim.log.levels.ERROR)
    return
  end

  local buf = vim.api.nvim_create_buf(false, true)
  local ok, _ = pcall(vim.api.nvim_buf_set_name, buf,
    "openapi://" .. vim.fn.fnamemodify(input, ":t:r") .. ".http")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = "http"
  vim.api.nvim_set_current_buf(buf)
  vim.notify("openapi: Imported " .. vim.fn.fnamemodify(input, ":t"), vim.log.levels.INFO)
end

function M.import()
  local files = find_files()
  if #files == 0 then
    vim.notify("openapi: No OpenAPI spec files found in project", vim.log.levels.WARN)
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

local group = vim.api.nvim_create_augroup("openapi_import", { clear = true })
vim.api.nvim_create_autocmd("BufRead", {
  group = group,
  pattern = API_PATTERNS,
  callback = function()
    vim.defer_fn(function()
      vim.notify(
        "OpenAPI spec detected. Use <leader>Ri or :OpenApiImport",
        vim.log.levels.INFO
      )
    end, 500)
  end,
})

return M
