{$reference WindowsBase.dll}
unit balance_wpf;

uses GraphWPFBase, GraphWPF, balance;

//TODO Frustum Culling

type
  wpfVector = System.Windows.Vector;
  wpfPoint = System.Windows.Point;
  blVector = balance.Vector;
  blInterval = balance.Interval;
  blShape = balance.Shape;
  blCircle = balance.Circle;
  blPolygon = balance.Polygon;
  blShapeGroup = balance.ShapeGroup;
  blViewport = balance.Viewport;
  blBoundBox = balance.BoundBox;
  blTransform = balance.Transform;
  blPhysWorld = balance.PhysWorld;

function wpnt(v: blVector) := new wpfPoint(v.X, v.Y);

function _pen_clr(c: Color?) := c <> nil ? c.value : Pen.Color;

procedure line(v1, v2: blVector; view: blViewport; c: Color ?:= nil) :=
line(wpnt(view.to_screen(v1)), wpnt(view.to_screen(v2)), _pen_clr(c));

procedure line(x0, y0, x1, y1: real; view: blViewport; c: Color ?:= nil) :=
line(bl_vect(x0, y0), bl_vect(x1, y1), view, c);

procedure circle(v: blVector; r: real; view: blViewport; c: Color ?:= nil) :=
circle(wpnt(view.to_screen(v)), view.to_screen(r), _pen_clr(c));

procedure circle(x, y, r: real; view: blViewport; c: Color ?:= nil) := 
circle(bl_vect(x, y), r, view, c);

procedure rectangle(r: blBoundBox; view: blViewport; c: Color ?:= nil);
begin
  var pos := view.to_screen(r.min);
  var wh := view.to_screen(r.max) - pos;
  DrawRectangle(pos.x, pos.y, wh.x, wh.y, _pen_clr(c));
end;

procedure rectangle(x, y, w, h: real; view: blViewport; c: Color ?:= nil) :=
rectangle(blBoundBox.from_xywh(x, y, w, h), view, c);



procedure draw_vector(v0, v: blVector; view: blViewport; c: color ?:= nil);
begin
  var v1 := v0 + v;
  line(v0, v1, view, c);
  circle(v1, view.to_world(3), view, c);
end;

procedure Draw(self: blPolygon; tr: blTransform; view: blViewport; c: color ?:= nil); extensionmethod;
begin
  var points := self.vertices.Select(v -> wpnt(view.to_screen(tr.apply(v)))).ToArray();
  DrawPolygon(points, _pen_clr(c));
end;

procedure Draw(self: blCircle; tr: blTransform; view: blViewport; c: color ?:= nil); extensionmethod;
begin
  var p := view.to_screen(tr.pos);
  var r := view.to_screen(self.radius);
  var clr := _pen_clr(c);
  var p1 := view.to_screen(tr.apply(bl_vect(self.radius, 0)));
  DrawCircle(p.x, p.y, r, clr);
  Line(p.x, p.y, p1.x, p1.y, clr);
end;

procedure Draw(self: blShape; tr: blTransform; view: blViewport; c: color ?:= nil); extensionmethod;
begin
  case self.kind of
    ShapeKind.ShapePolygon: balance.Polygon(self).Draw(tr, view, c);
    ShapeKind.ShapeCircle: balance.Circle(self).Draw(tr, view, c)
  else assert(false, 'Unknown shape');
  end;
end;

procedure Draw(self: blShapeGroup; tr: blTransform; view: blViewport; c: color ?:= nil); extensionmethod;
begin  
  foreach var p in self.parts do
    p.shap.Draw(tr.combine(p.tr), view, c);
end;

function dbg_shake_color(c: integer): Color;
begin
  var x := system.UInt32(c) * $45d9f3b;
  x := x xor (x shr 16);  
  result := Color.FromRgb(byte(x), byte(x shr 8), byte(x shr 16));
end;


procedure draw_world(world: blPhysWorld; view: blViewport);
begin
  if world.bounds <> nil then 
    world.bounds.Draw(world.bounds_body.tr, view);
  foreach var b in world.bodies do
    b.group.Draw(b.tr, view);
end;

procedure dbg_draw_world(world: blPhysWorld; view: blViewport; bbox: boolean := true; vel: boolean := true; cons: boolean := true);
begin
  var base_color := GraphWPF.Pen.Color; 
  var static_color := Color.Multiply(base_color, 0.7);
  
  if world.bounds <> nil then 
    world.bounds.Draw(world.bounds_body.tr, view);
  
  foreach var b in world.bodies do
  begin
    b.group.Draw(b.tr, view, b.is_static ? static_color : base_color);
    if bbox then
      rectangle(b.aabb, view, Color.FromArgb(120, 255, 0, 0));
    if vel and not b.is_static then
      draw_vector(b.pos, b.vel, view, Colors.Yellow);    
  end;  
  
  if cons then
  begin
    foreach var con in world.con_mgr.contacts do
    begin
      var key := new ArbiterKey(con.body_a, con.body_b, con.point.id);
      draw_vector(con.point.pos, con.hit_normal * con.point.depth, view, dbg_shake_color(key.GetHashCode()));
    end;
  end;
end;


type
  GraphCanvas = class
  private
    m_canvas: System.Windows.Controls.Canvas;
    m_w: real := real.NaN;
    m_h: real := real.NaN;
    procedure resizedd();
    begin
      if m_canvas = nil then
      begin
        m_canvas := MainDockPanel.Children.OfType&<System.Windows.Controls.Canvas>().FirstOrDefault();
        assert(m_canvas <> nil);
      end;
      m_canvas.UpdateLayout();
      m_w := m_canvas.ActualWidth;
      m_h := m_canvas.ActualHeight;
    end;
  
  public
    procedure resized() := Invoke(resizedd);
    property WPFCanvas: System.Windows.Controls.Canvas read m_canvas;
    property Width: real read m_w <> m_w ? GraphWindow.Width : m_w;
    property Height: real read m_h <> m_h ? GraphWindow.Height : m_h;
  end;

var
  Canvas := new GraphCanvas();

begin
end. 