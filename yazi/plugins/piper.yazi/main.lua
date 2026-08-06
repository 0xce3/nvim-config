local M = {}

local function fail(job, message)
  ya.preview_widget(job, ui.Text.parse(message):area(job.area):wrap(ui.Wrap.YES))
end

function M:peek(job)
  local child, err = Command("sh")
    :arg({ "-c", job.args[1], "sh", tostring(job.file.path) })
    :env("w", job.area.w)
    :env("h", job.area.h)
    :stdout(Command.PIPED)
    :stderr(Command.PIPED)
    :spawn()
  if not child then return fail(job, "sh: " .. err) end

  local limit, index, output, errors = job.area.h, 0, {}, {}
  repeat
    local line, event = child:read_line()
    if event == 1 then
      errors[#errors + 1] = line
    elseif event ~= 0 then
      break
    end
    index = index + 1
    if index > job.skip then output[#output + 1] = line end
  until index >= job.skip + limit

  child:start_kill()
  if #errors > 0 then
    fail(job, table.concat(errors, ""))
  elseif job.skip > 0 and index < job.skip + limit then
    ya.emit("peek", { math.max(0, index - limit), only_if = job.file.url, upper_bound = true })
  else
    local text = table.concat(output, ""):gsub("\t", string.rep(" ", rt.preview.tab_size))
    ya.preview_widget(job, ui.Text.parse(text):area(job.area))
  end
end

function M:seek(job)
  require("code"):seek(job)
end

return M
