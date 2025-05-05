-- sync_minipage_width.lua -- Ipelet
-- Synchronize widths of minipages: includes a second menu item that
-- displays a detailed help window.

label = "Sync minipage widths"

about = [[
Copy the width of the primary‑selected minipage to all other selected
minipages.
]]

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

local function abort(model, msg)
  model:warning(msg)
end

----------------------------------------------------------------------
-- Main action -------------------------------------------------------
----------------------------------------------------------------------

local function sync_widths(model)
  local page = model:page()
  local prim = page:primarySelection()
  if not prim then return abort(model, "No primary selection – select the reference minipage last.") end

  local ref = page[prim]
  if ref:type() ~= "text" or not ref:get("minipage") then
    return abort(model, "Primary selection must be a minipage.")
  end

  local ref_width = ({ref:dimensions()})[1]  -- width, height, depth

  local final = page:clone()
  local changed = false

  for i, obj, sel in final:objects() do
    if sel and i ~= prim and obj:type() == "text" and obj:get("minipage") then
      if math.abs((obj:get("width") or 0) - ref_width) > 1e-7 then
        obj:set("width", ref_width)
        changed = true
      end
    end
  end

  if not changed then
    return abort(model, "Selected minipages already have that width.")
  end

  model:register{
    label    = "sync minipage widths",
    pno      = model.pno,
    vno      = model.vno,
    original = page:clone(),
    final    = final,
    undo     = _G.revertOriginal,
    redo     = _G.revertFinal,
  }
end

----------------------------------------------------------------------
-- Detailed help -----------------------------------------------------
----------------------------------------------------------------------

local detailed_help = [[
Sync minipage widths — detailed help

1. Select every minipage you want to resize.
2. Select the reference minipage *last* so it becomes the primary selection.
3. Run “Sync widths”.

All secondary minipages adopt the width of the primary in one undoable step.
]]

local function show_help(model)
  model:warning(detailed_help)
end

----------------------------------------------------------------------
-- Provide multiple menu entries
----------------------------------------------------------------------

methods = {
  { label = "Sync widths",     run = sync_widths },
  { label = "Help / Examples", run = show_help },
}
