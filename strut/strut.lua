-- strut_prepender.lua -- Ipelet
-- Adds a \strut{} at the very beginning of each selected label or
-- minipage, unless one is already present.

label = "Prepend \\strut{}"

about = [[
Prepends a \strut{} to every selected text object (label or minipage)
that does not already start with one. Useful to ensure consistent
baseline alignment.
]]

-- Returns true if the text already begins with \strut{...}
local function has_strut(text)
  -- ^%s*      : ignore leading whitespace
  -- \\strut  : literal \strut
  -- %s*%b{}  : optional spaces then a balanced pair of braces
  return text:match("^%s*\\strut%s*%b{}") ~= nil
end

function run(model)
  local page  = model:page()
  local final = page:clone()   -- work on a clone for undo/redo
  local changed = false

  for idx, obj, sel in final:objects() do
    if sel and obj:type() == "text" then
      local txt = obj:text()
      if not has_strut(txt) then
        obj:setText("\\strut{}" .. txt)
        changed = true
      end
    end
  end

  if not changed then
    model:warning("No selected text needed a \\strut{} prefix.")
    return
  end

  local t = {
    label    = "prepend \\strut{}",
    pno      = model.pno,
    vno      = model.vno,
    original = page:clone(),
    final    = final,
    undo     = _G.revertOriginal,
    redo     = _G.revertFinal,
  }

  model:register(t)
end
