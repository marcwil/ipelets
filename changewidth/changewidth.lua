----------------------------------------------------------------------
--  Sync Minipage Widths Ipelet  –  rotation‑aware helper line
----------------------------------------------------------------------
--  • “Sync widths”         – copy primary visual width to other selected
--  • “Interactive tool…”  – blue helper line & handle that follow the
--                            minipage’s own X‑axis (rotation + uniform
--                            scale handled) and start at current width
--  • “Help / Examples”    – quick in‑Ipe reference
----------------------------------------------------------------------

label = "Sync minipage widths"

about = [[
Synchronise the **visual** width of the *primary‑selected* minipage with
all other selected minipages (batch Alt+W).  The interactive tool shows
a blue helper line that starts at the current visual width and moves
strictly along the minipage’s local horizontal axis, so rotation and
uniform scaling are honoured. *Esc* cancels; one undo step records
everything.
]]

---------------------------------------------------------------------
--  Helpers & shortcuts (copy‑tools conventions)
---------------------------------------------------------------------

type = _G.type
V    = ipe.Vector

local function dot(a,b) return a.x*b.x + a.y*b.y end
local function len(v)   return math.sqrt(dot(v,v)) end
local function unit_dir(v) local l=len(v); if l==0 then return V(1,0),1 end; return (1/l)*v,l end

local MARK_TYPE = { vertex = 1, splineCP = 2, center = 3,
                    radius = 4, minor = 5, current = 6, scissor = 7 }

local function warn(m,s) m:warning(s) end
local function is_minipage(o) return o:type()=="text" and o:get("minipage") end
local function get_width(o)   return ({ o:dimensions() })[1] end
local function ui(m)          return m.ui or m end

---------------------------------------------------------------------
--  1. One‑shot “Sync widths” (visual width)
---------------------------------------------------------------------

local function sync_widths(model)
  local page  = model:page()
  local pidx  = page:primarySelection()
  if not pidx then return warn(model, "Select the reference last.") end
  local ref   = page[pidx]
  if not is_minipage(ref) then return warn(model, "Primary object must be a minipage.") end

  -- visual width of reference = property width × uniform X‑scale
  local ref_prop_w = get_width(ref) or 0
  local ref_scale  = len(ref:matrix()*V(1,0) - ref:matrix()*V(0,0))
  local target_vis_w = ref_prop_w * ref_scale

  local newpage = page:clone()
  local changed = false

  for i, obj, sel in newpage:objects() do
    if sel and i ~= pidx and is_minipage(obj) then
      local scale_i = len(obj:matrix()*V(1,0) - obj:matrix()*V(0,0))
      if scale_i > 1e-9 then
        local desired_prop = target_vis_w / scale_i
        if math.abs((obj:get("width") or 0) - desired_prop) > 1e-7 then
          obj:set("width", desired_prop)
          changed = true
        end
      end
    end
  end

  if not changed then
    return warn(model, "All selected minipages already have that visual width.")
  end

  model:register{
    label    = "sync minipage widths (visual)",
    pno      = model.pno,
    vno      = model.vno,
    original = page:clone(),
    final    = newpage,
    undo     = _G.revertOriginal,
    redo     = _G.revertFinal,
  }
end

---------------------------------------------------------------------
--  2. Interactive tool (rotation + uniform scale aware)
---------------------------------------------------------------------

local WidthTool = {}; WidthTool.__index = WidthTool

local function line_shape(a,b)
  return { { type="curve", closed=false, { type="segment", a, b } } }
end

function WidthTool:new(model, pidx, indices)
  local page, ref = model:page(), model:page()[pidx]
  local m         = ref:matrix()
  local dir_raw   = m*V(1,0) - m*V(0,0)           -- local X‑axis
  local dir, _    = unit_dir(dir_raw)

  -- anchor at baseline (matrix * position)
  local anchor = m * ref:position()

  -- project bbox corners onto axis to get current visual width
  local bb = page:bbox(pidx)
  local max_proj = 0
  for _,c in ipairs{ bb:bottomLeft(), V(bb:right(),bb:bottom()), bb:topRight(), V(bb:left(),bb:top()) } do
    local d = dot(c-anchor, dir); if d>max_proj then max_proj=d end
  end

  local stored_w = get_width(ref) or 0
  local scale    = (stored_w>0) and (max_proj/stored_w) or 1

  local t = { model=model, page=page, indices=indices,
              anchor=anchor, dir=dir, scale=scale,
              handle=anchor + dir*max_proj, dragging=false }
  _G.setmetatable(t, WidthTool)
  ui(model):shapeTool(t)
  t.setColor(0.0,0.5,1.0)
  t:update_visuals()
  return t
end

function WidthTool:update_visuals()
  self.setShape(line_shape(self.anchor, self.handle), 1)
  self.setMarks({ self.anchor, MARK_TYPE.center, self.handle, MARK_TYPE.current })
end

function WidthTool:project_mouse()
  local proj = dot(ui(self.model):pos()-self.anchor, self.dir)
  if proj < 0 then proj = 0 end
  self.handle = self.anchor + self.dir*proj
  return proj
end

function WidthTool:mouseButton(btn,_,press)
  if btn~=1 then return false end
  if press then
    self.dragging=true; self:project_mouse(); self:update_visuals(); return true
  else
    if not self.dragging then return false end
    self.dragging=false
          local user_w = self:project_mouse();
      self:update_visuals()
      if user_w > 1e-7 then
        local newpage = self.page:clone()
        for _, idx in ipairs(self.indices) do
          local obj = newpage[idx]
          local s = len(obj:matrix()*V(1,0) - obj:matrix()*V(0,0))
          if s > 1e-9 then obj:set("width", user_w / s) end
        end
        self.model:register{
          label="interactive sync minipage widths (visual)",
          pno=self.model.pno, vno=self.model.vno,
          original=self.page:clone(), final=newpage,
          undo=_G.revertOriginal, redo=_G.revertFinal }
      end
      ui(self.model):finishTool(); return true
  end
end

function WidthTool:mouseMove()
  if self.dragging then
    self:project_mouse(); self:update_visuals(); ui(self.model):update(false)
  end
  return false
end

function WidthTool:key(t) if t=="\027" then ui(self.model):finishTool(); return true end end

local function interactive(model)
  local page,pidx = model:page(), model:page():primarySelection()
  if not pidx then return warn(model,"Select the reference last.") end
  if not is_minipage(page[pidx]) then return warn(model,"Primary object must be a minipage.") end
  local idx={}; for i,obj,sel in page:objects() do if sel and is_minipage(obj) then idx[#idx+1]=i end end
  if #idx==0 then return warn(model,"No minipages selected.") end
  WidthTool:new(model,pidx,idx)
end

---------------------------------------------------------------------
--  3. Help dialog
---------------------------------------------------------------------

local help = [[
**Sync minipage widths – quick guide**

• *Sync widths* – equalise visual widths: select minipages, reference
  last, run, done.

• *Interactive tool…* – select minipages, reference last, run. Drag the
  blue handle; it starts at the current visual width and stays on the
  minipage’s own X‑axis. Rotation & uniform scale handled. *Esc* cancels.
]]

local function show_help(m) m:warning(help) end

---------------------------------------------------------------------
--  Menu entries
---------------------------------------------------------------------

methods = {
  { label="Sync widths",       run=sync_widths },
  { label="Interactive tool…", run=interactive },
  { label="Help / Examples",   run=show_help  },
}
