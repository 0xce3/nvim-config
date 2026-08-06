--- @sync entry

return {
  entry = function()
    local hovered = cx.active.current.hovered
    if hovered and not hovered.cha.is_dir then ya.emit("open", { hovered = true }) end
  end,
}
