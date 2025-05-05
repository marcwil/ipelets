----------------------------------------------------------------------
--  Sync Minipage Widths Ipelet  –  rotation‑aware helper line
----------------------------------------------------------------------
--  • “Sync widths”         – copy primary width to other selected
--  • “Interactive tool…”  – blue helper line & handle that follow the
--                            minipage’s own X‑axis (rotation + uniform
--                            scale handled) and start at current width
--  • “Help / Examples”    – quick in‑Ipe reference
----------------------------------------------------------------------

label = "Sync minipage widths"

about = [[
Synchronise the width of the *primary‑selected* minipage with all other
selected minipages (batch Alt+W).  The interactive tool shows a blue
helper line that starts at the current visual width and moves strictly
along the minipage’s own horizontal axis, so rotation and uniform
scaling are honoured. *Esc* cancels; one undo step records everything.
]]

---------------------------------------------------------------------
--  Helpers & shortcuts (same conventions as copy‑tools)
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
--  1. One‑shot command (unchanged)
---------------------------------------------------------------------

local function sync_widths(model)
  local page,pidx = model:page(), model:page():primarySelection()
  if not pidx then return warn(model,"Select the reference last.") end
  if not is_minipage(page[pidx]) then return warn(model,"Primary object must be a minipage.") end

  local w,changed,newpage = get_width(page[pidx]),false,page:clone()
  for i,obj,sel in newpage:objects() do
    if sel and i~=pidx and is_minipage(obj) and math.abs((obj:get("width") or 0)-w) > 1e-7 then
      obj:set("width",w); changed=true end
  end
  if not changed then return warn(model,"All selected minipages already have that width.") end
  model:register{ label="sync minipage widths", pno=model.pno, vno=model.vno,
    original=page:clone(), final=newpage, undo=_G.revertOriginal, redo=_G.revertFinal }
end

---------------------------------------------------------------------
--  2. Interactive tool (rotation + uniform scale aware)
---------------------------------------------------------------------

local WidthTool = {}; WidthTool.__index = WidthTool

local function line_shape(a,b) return { { type="curve", closed=false, { type="segment", a, b } } } end

function WidthTool:new(model, pidx, indices)
  local page, ref = model:page(), model:page()[pidx]
  local m         = ref:matrix()
  local dir_raw   = m*V(1,0) - m*V(0,0)          -- local X‑axis in user space
  local dir, _    = unit_dir(dir_raw)

  -- anchor = baseline position
  local anchor = m * ref:position()

  -- determine current visual width along dir using bbox projection
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
  if proj<0 then proj=0 end
  self.handle = self.anchor + self.dir*proj
  return proj
end

function WidthTool:mouseButton(btn,_,press)
  if btn~=1 then return false end
  if press then
    self.dragging=true; self:project_mouse(); self:update_visuals(); return true
  else
    if not self.dragging then return false end
    self.dragging=false; local user_w=self:project_mouse(); self:update_visuals()
    local new_prop_w = user_w / self.scale
    if new_prop_w>1e-7 then
      local newpage=self.page:clone(); for _,i in ipairs(self.indices) do newpage[i]:set("width",new_prop_w) end
      self.model:register{ label="interactive sync minipage widths", pno=self.model.pno, vno=self.model.vno,
        original=self.page:clone(), final=newpage, undo=_G.revertOriginal, redo=_G.revertFinal }
    end
    ui(self.model):finishTool(); return true
  end
end

function WidthTool:mouseMove()
  if self.dragging then self:project_mouse(); self:update_visuals(); ui(self.model):update(false) end
  return false
end

function WidthTool:key(txt) if txt=="\027" then ui(self.model):finishTool(); return true end end

local function interactive(model)
  local page,pidx = model:page(), model:page():primarySelection()
  if not pidx then return warn(model,"Select the reference last.") end
  if not is_minipage(page[pidx]) then return warn(model,"Primary object must be a minipage.") end
  local idx={}; for i,obj,sel in page:objects() do if sel and is_minipage(obj) then idx[#idx+1]=i end end
  if #idx==0 then return warn(model,"No minipages selected.") end
  WidthTool:new(model,pidx,idx)
end

---------------------------------------------------------------------
--  3. Help
---------------------------------------------------------------------

local help=[[**Sync minipage widths – quick guide**

• *Sync widths* – select minipages, reference last, run, done.

• *Interactive tool…* – select minipages, reference last, run. Drag the
  blue handle; it starts at the current visual width and stays on the
  minipage’s own X‑axis. Rotation & uniform scale handled. *Esc* cancels.]]

local function show_help(m) m:warning(help) end

---------------------------------------------------------------------
--  Menu entries
---------------------------------------------------------------------

methods={
  { label="Sync widths",       run=sync_widths },
  { label="Interactive tool…", run=interactive },
  { label="Help / Examples",   run=show_help  },
}
