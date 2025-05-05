----------------------------------------------------------------------
--  Sync Minipage Width Ipelet  –  copy‑tools style, axis‑aligned
----------------------------------------------------------------------
--  • “Sync widths”         – copy primary width to other selected
--  • “Interactive tool…”   – blue helper line (current width), no rotation
--  • “Help / Examples”     – quick in‑Ipe reference
----------------------------------------------------------------------

label = "Sync minipage widths"

about = [[
Synchronise the width of the *primary‑selected* minipage with all other
selected minipages (batch Alt+W).  An interactive tool lets you drag a
blue helper line (like copy‑tools) that starts at the current width.  *Esc*
cancels; one undo step records everything.
]]

---------------------------------------------------------------------
--  Helpers & copy‑tools shortcuts
---------------------------------------------------------------------

type = _G.type
V    = ipe.Vector

local MARK_TYPE = { vertex = 1, splineCP = 2, center = 3,
                    radius = 4, minor = 5, current = 6, scissor = 7 }

local function warn(m, s) m:warning(s) end
local function is_minipage(o) return o:type() == "text" and o:get("minipage") end
local function get_width(o)   return ({ o:dimensions() })[1] end
local function ui(m)          return m.ui or m end

---------------------------------------------------------------------
--  1. One‑shot “Sync widths”
---------------------------------------------------------------------

local function sync_widths(model)
  local page, pidx = model:page(), model:page():primarySelection()
  if not pidx then return warn(model, "Select the reference last.") end
  if not is_minipage(page[pidx]) then return warn(model, "Primary object must be a minipage.") end

  local w, changed, newpage = get_width(page[pidx]), false, page:clone()
  for i, obj, sel in newpage:objects() do
    if sel and i ~= pidx and is_minipage(obj) and math.abs((obj:get("width") or 0) - w) > 1e-7 then
      obj:set("width", w); changed = true
    end
  end
  if not changed then return warn(model, "All selected minipages already have that width.") end

  model:register{
    label = "sync minipage widths",
    pno   = model.pno,
    vno   = model.vno,
    original = page:clone(),
    final    = newpage,
    undo     = _G.revertOriginal,
    redo     = _G.revertFinal,
  }
end

---------------------------------------------------------------------
--  2. Interactive tool (axis‑aligned)
---------------------------------------------------------------------

local WidthTool = {}; WidthTool.__index = WidthTool

local function line_shape(a, b)
  return { { type = "curve", closed = false, { type = "segment", a, b } } }
end

function WidthTool:new(model, pidx, indices)
  local page = model:page()
  local ref  = page[pidx]
  local w    = get_width(ref)

  -- anchor at left edge, vertical centre of reference bbox
  local bb = page:bbox(pidx)
  local anchor = V(bb:left(), 0.5 * (bb:bottom() + bb:top()))
  local handle = anchor + V(w, 0)           -- current width

  local t = { model = model, page = page, indices = indices,
              anchor = anchor, handle = handle, dragging = false }
  _G.setmetatable(t, WidthTool)

  ui(model):shapeTool(t)
  t.setColor(0.0, 0.5, 1.0) -- blue, copy‑tools default
  t:update_visuals()
  return t
end

function WidthTool:update_visuals()
  self.setShape(line_shape(self.anchor, self.handle), 1)
  self.setMarks({ self.anchor, MARK_TYPE.center, self.handle, MARK_TYPE.current })
end

function WidthTool:update_handle_from_mouse()
  local pos = ui(self.model):pos()
  if pos.x < self.anchor.x then pos = V(self.anchor.x, pos.y) end
  self.handle = V(pos.x, self.anchor.y)
  return pos.x - self.anchor.x
end

function WidthTool:mouseButton(button, mods, press)
  if button ~= 1 then return false end

  if press then -- start drag
    self.dragging = true
    self:update_handle_from_mouse()
    self:update_visuals()
    return true
  else -- release
    if not self.dragging then return false end
    self.dragging = false
    local neww = self:update_handle_from_mouse()
    self:update_visuals()
    if neww > 1e-7 then
      local newpage = self.page:clone()
      for _, idx in ipairs(self.indices) do newpage[idx]:set("width", neww) end
      self.model:register{
        label = "interactive sync minipage widths",
        pno   = self.model.pno,
        vno   = self.model.vno,
        original = self.page:clone(),
        final    = newpage,
        undo     = _G.revertOriginal,
        redo     = _G.revertFinal,
      }
    end
    ui(self.model):finishTool()
    return true
  end
end

function WidthTool:mouseMove()
  if self.dragging then
    self:update_handle_from_mouse()
    self:update_visuals()
    ui(self.model):update(false)
  end
  return false
end

function WidthTool:key(txt, _)
  if txt == "\027" then ui(self.model):finishTool(); return true end
  return false
end

local function interactive(model)
  local page, pidx = model:page(), model:page():primarySelection()
  if not pidx then return warn(model, "Select the reference last.") end
  if not is_minipage(page[pidx]) then return warn(model, "Primary object must be a minipage.") end
  local indices = {}
  for i, obj, sel in page:objects() do
    if sel and is_minipage(obj) then indices[#indices + 1] = i end
  end
  if #indices == 0 then return warn(model, "No minipages selected.") end
  WidthTool:new(model, pidx, indices)
end

---------------------------------------------------------------------
--  3. Help
---------------------------------------------------------------------

local help = [[
**Sync minipage widths – quick guide**

• *Sync widths* – select minipages, reference last, run, done.

• *Interactive tool…* – select minipages, reference last, run.  Drag the
  blue helper handle to set the new width (starts at current width).
  *Esc* cancels; one undo step records everything.
]]

local function show_help(m) m:warning(help) end

---------------------------------------------------------------------
--  Menu entries
---------------------------------------------------------------------

methods = {
  { label = "Sync widths",        run = sync_widths },
  { label = "Interactive tool…",  run = interactive },
  { label = "Help / Examples",    run = show_help  },
}
