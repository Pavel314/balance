{$reference WindowsBase.dll}
unit balance_wpf;

uses GraphWPFBase, GraphWPF, balance;

type
  wpf_vect = System.Windows.Vector;
  wpf_point = System.Windows.Point;
  blVector = balance.Vector;
  blInterval = balance.Interval;
  blCircle = balance.Circle;
  blPolygon = balance.Polygon;
  blShape = balance.Shape;

function vpnt(v: Vector) := new wpf_point(v.X, v.Y);

function _pen_clr(c: Color?) := c <> nil ? c.value : Pen.Color;



procedure line(v1, v2: Vector; view: Viewport; c: Color ?:= nil);
begin
  v1 := view.to_screen(v1);
  v2 := view.to_screen(v2);
  line(vpnt(v1), vpnt(v2), _pen_clr(c));
end;

procedure line(x0, y0, x1, y1: real; view: Viewport; c: Color ?:= nil);
begin
  var v1 := view.to_screen(new Vector(x0, y0));
  var v2 := view.to_screen(new Vector(x1, y1));
  line(vpnt(v1), vpnt(v2), _pen_clr(c));
end;

procedure circle(v: Vector; r: real; view: Viewport; c: Color ?:= nil);
begin
  v := view.to_screen(v);
  circle(v.x, v.y, r, _pen_clr(c));//TODO r*view.radius
end;

procedure rectangle(r: BoundBox; view: Viewport; c: Color ?:= nil);
begin
  var pos := view.to_screen(r.min);
  var wh := view.to_screen(r.max) - pos;
  DrawRectangle(pos.x, pos.y, wh.x, wh.y, _pen_clr(c));
end;

procedure draw_vector(v0, v: Vector; view: Viewport; c: color ?:= nil);
begin
  var v1 := v0 + v;
  line(v0, v1, view, c);
  circle(v1, 3, view, c);
end;

{procedure draw_polygon(points:array of Vector; view: viewera; c: color ?:= nil);
begin
  c:=_pen_clr(c);
  DrawPolygon(points.Select(v -> vpnt(view.to_screen(tr.apply(v)))).ToArray(), c.Value);
end;}



procedure Draw(self: balance.Polygon; tr: Transform; view: Viewport; c: color ?:= nil); extensionmethod;
begin
  var points := self.vertices.Select(v -> vpnt(view.to_screen(tr.apply(v)))).ToArray();
  DrawPolygon(points, _pen_clr(c));
end;

procedure Draw(self: balance.Circle; tr: Transform; view: Viewport; c: color ?:= nil); extensionmethod;
begin
  var p := vpnt(view.to_screen(tr.pos));
  var r := view.to_screen(self.radius);
  var col := _pen_clr(c);
  //circle(tr.pos, self.radius * view.zoom, view, c);
  DrawCircle(p, r, _pen_clr(c));
  
  var p1 := vpnt(view.to_screen(tr.apply(bl_vect(self.radius, 0))));
  
  Line(p.X, p.Y, p1.x, p1.y, col);
end;

procedure Draw(self: balance.Shape; tr: Transform; view: Viewport; c: color ?:= nil); extensionmethod;
begin
  case self.kind of
    ShapeKind.ShapePolygon: (balance.Polygon(self)).Draw(tr, view, c);
    ShapeKind.ShapeCircle: (balance.Circle(self)).Draw(tr, view, c)
  else assert(false, 'Unknown shape');
  end;
end;

procedure Draw(self: ShapeGroup; tr: Transform; view: Viewport; c: color ?:= nil); extensionmethod;
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


procedure draw_world(world: PhysWorld; view: Viewport);
begin
  if (world.bounds <> nil) then 
    world.bounds.Draw(world.bounds_body.tr, view);
  foreach var body in world.bodies do
    body.group.Draw(body.tr, view);
end;

procedure dbg_draw_world(world: PhysWorld; view: Viewport; bbox: boolean := true; vel: boolean := true; cons: boolean := true);
begin
  var base_color := GraphWPF.Pen.Color; 
  var static_color := Color.Multiply(base_color, 0.7);
  
  if (world.bounds <> nil) then 
    world.bounds.Draw(world.bounds_body.tr, view);
  
  foreach var body in world.bodies do
  begin
    body.group.Draw(body.tr, view, body.is_static ? static_color : base_color);
    if bbox then
      rectangle(body.aabb, view, Color.FromArgb(120, 255, 0, 0));
    if vel and not body.is_static then
      draw_vector(body.pos, body.vel, view, Colors.Yellow);    
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



{procedure dDraw(self: Polygon; tr: Transform; view:viewera; bbox:boolean:=true); extensionmethod;
begin
  self.Draw(tr, view);
  rectangle(self.aabb, view, Colors.Red);
end;}


type
  GraphCanvas = class
  private
    m_canvas: System.Windows.Controls.Canvas;
    m_w:real:=real.NaN;
    m_h: real:=real.NaN;
    procedure resizedd();
    begin
      if m_canvas=nil then
      begin
        m_canvas := MainDockPanel.Children.OfType&<System.Windows.Controls.Canvas>().FirstOrDefault();
        assert(m_canvas <> nil);
      end;
      m_canvas.UpdateLayout();
      m_w := m_canvas.ActualWidth;
      m_h := m_canvas.ActualHeight;
    end;
  
  public
    procedure resized():=Invoke(resizedd);
    property WPFCanvas:System.Windows.Controls.Canvas read m_canvas;
    property Width:real read m_w<>m_w?GraphWindow.Width:m_w;
    property Height:real read m_h<>m_h?GraphWindow.Height:m_h;
  end;

//При использовании модуля Controls, размеры доступные для рисования, находятся таким образом
{function CanvasWidth() :=  InvokeReal(() -> get_canvas().ActualWidth);
function CanvasHeight() := InvokeReal(() -> get_canvas().ActualHeight);}

var Canvas:=new GraphCanvas();

begin
end. 