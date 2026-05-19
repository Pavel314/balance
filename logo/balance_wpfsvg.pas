{$reference WindowsBase.dll}
unit balance_wpfsvg;

uses GraphWPFBase, GraphWPF;
uses balance in '..\balance.pas';

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

function safe_bbox(self: BoundBox): BoundBox; extensionmethod;
begin
  var (p1, p2) := (self.min, self.max);
  result := BoundBox.from_minmax(Min(p1.x, p2.x), Min(p1.y, p2.y), Max(p1.x, p2.x), Max(p1.y, p2.y));
end;

function world_to_screen_bbox(view: Viewport; wb: BoundBox) := BoundBox.from_minmax(view.to_screen(wb.min), view.to_screen(wb.max)).safe_bbox();

var
  _svg_wr := new StringBuilder();

function wpnt(v: blVector) := new wpfPoint(v.X, v.Y);

function _pen_clr(c: Color?) := c <> nil ? c.value : Pen.Color;

function svg_hclr(c: Color) := $'#{c.R:X2}{c.G:X2}{c.B:X2}{c.A:X2}';

function svg_outline_style(c: Color) := $'style="stroke:{svg_hclr(c)};stroke-width:{Pen.Width};fill:none"';

function svg_fill_style(fill_clr: Color) := $'style="stroke:{svg_hclr(Pen.Color)};stroke-width:{Pen.Width};fill:{svg_hclr(fill_clr)}"';

function download_font_as_base64(font_name: string; font_weight: integer; alphabet: string): string;
begin
  var enc := System.Uri.EscapeDataString;
  //var alphabet := Range(32, 126).Select(e -> char(e)).JoinToString('');
  var css_url := $'https://fonts.googleapis.com/css2?family={enc(font_name)}:wght@{font_weight}&text={enc(alphabet)}';
  
  var web := new System.Net.WebClient();
  web.Headers.Add('User-Agent', 'Mozilla/5.0');
  
  var css_content := web.DownloadString(css_url);;
  
  var pattern := $'font-weight:\s*{font_weight};.*?url\(https://([^)]+)\)';
  var &match := System.Text.RegularExpressions.Regex.Match(css_content, pattern, 
  System.Text.RegularExpressions.RegexOptions.Singleline);
  
  assert(&match.Success);
  
  var font_url := 'https://' + &match.Groups[1].Value;
  var font_bytes := web.DownloadData(font_url);
  var font_format := font_url.EndsWith('.ttf') ? 'truetype' : 'woff2';  
  var base64 := System.Convert.ToBase64String(font_bytes);
  result := $'data:font/{font_format};base64,{base64}';
end;

function has_svg() := _svg_wr <> nil;

procedure svg_begin(bg_clr: Color; view: Viewport; crop_world_bbox: BoundBox);
begin
  var crop := world_to_screen_bbox(view, crop_world_bbox);
  crop := crop.expand(1);
  
  _svg_wr := new StringBuilder();
  _svg_wr.AppendLine($'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{crop.x} {crop.y} {crop.width} {crop.height}" width="100%" height="100%">');
  _svg_wr.AppendLine($'<rect x="{crop.x}" y="{crop.y}" width="{crop.width}" height="{crop.height}" fill="{svg_hclr(bg_clr)}" />');
end;

procedure svg_import_font(fnt_name: string; fnt_weight: integer; fnt_alphabet: string);
begin
  var fnt_data := download_font_as_base64(fnt_name, fnt_weight, fnt_alphabet);
  _svg_wr.AppendLine('<style>');
  _svg_wr.AppendLine('  @font-face {');
  _svg_wr.AppendLine($'    font-family: "{fnt_name}";');
  _svg_wr.AppendLine($'    src: url("{fnt_data}");');
  _svg_wr.AppendLine($'    font-weight: {fnt_weight};');
  _svg_wr.AppendLine('  }');
  //_svg_wr.AppendLine($'  text {{ font-family: "{fnt_name}", sans-serif; font-weight: {fnt_weight}; }}');
  _svg_wr.AppendLine('</style>');
end;

function svg_end(): string;
begin
  _svg_wr.AppendLine('</svg>');
  result := _svg_wr.ToString();
  _svg_wr := nil;
end;

procedure line(v1, v2: blVector; view: blViewport; c: Color ?:= nil);
begin
  var (p1, p2) := (view.to_screen(v1), view.to_screen(v2));
  var clr := _pen_clr(c);
  line(wpnt(p1), wpnt(p2), clr);
  if has_svg then
    _svg_wr.AppendLine($'<line x1="{p1.x}" y1="{p1.y}" x2="{p2.x}" y2="{p2.y}" {svg_outline_style(clr)} />');
end;

procedure circle(v: blVector; r: real; view: blViewport; c: Color ?:= nil);
begin
  (v, r) := (view.to_screen(v), view.to_screen(r));
  var clr := _pen_clr(c);
  circle(wpnt(v), r, clr);  
  if has_svg then
    _svg_wr.AppendLine($'<circle cx="{v.x}" cy="{v.y}" r="{r}" {svg_fill_style(clr)} />');
end;

procedure DrawCircle(v: blVector; r: real; view: blViewport; c: Color ?:= nil);
begin
  (v, r) := (view.to_screen(v), view.to_screen(r));
  var clr := _pen_clr(c);
  DrawCircle(wpnt(v), r, clr);
  if has_svg then
    _svg_wr.AppendLine($'<circle cx="{v.x}" cy="{v.y}" r="{r}" {svg_outline_style(clr)} />');
end;

procedure DrawRectangle(r: blBoundBox; view: blViewport; c: Color ?:= nil);
begin
  var box := BoundBox.from_minmax(view.to_screen(r.min), view.to_screen(r.max)).safe_bbox();
  var clr := _pen_clr(c);
  DrawRectangle(box.x, box.y, box.width, box.height, _pen_clr(c));
  if has_svg then
    _svg_wr.AppendLine($'<rect x="{box.x}" y="{box.y}" width="{box.width}" height="{box.height}" {svg_outline_style(clr)} />');
end;

procedure DrawPolygon(verts: IEnumerable<blVector>; view: blViewport; c: Color ?:= nil);
begin
  var pts := verts.Select(v -> view.to_screen(v));
  var clr := _pen_clr(c);
  DrawPolygon(pts.Select(p -> wpnt(p)).ToArray(), clr);
  if has_svg then
  begin
    var svg_pts := string.Join(' ', pts.Select(p -> $'{p.X},{p.Y}'));
    _svg_wr.AppendLine($'<polygon points="{svg_pts}" {svg_outline_style(clr)} />');
  end;
end;

procedure TextOut(p: blVector; txt: string; fnt: FontOptions; view: Viewport; angle: real := 0.0);
begin
  p := view.to_screen(p);
  
  TextOut(p.x, p.y, txt, fnt, angle := angle);
  if has_svg then
  begin
    var transform_attr := '';
    if angle <> 0.0 then
      transform_attr := $' transform="rotate({angle}, {p.x:F1}, {p.y:F1})"';
    _svg_wr.AppendLine( $'  <text x="{p.x}" y="{p.y}"' + transform_attr +
                        $' font-family="{fnt.Name}, sans-serif"' +
                        $' font-size="{fnt.Size}px"' +
                        $' fill="{svg_hclr(fnt.Color)}"' +
                        $' dominant-baseline="text-top"' +  
                        $' alignment-baseline="text-before-edge"' + 
                        $' >{txt}</text>');
    
  end;                   
end;

procedure line(x0, y0, x1, y1: real; view: blViewport; c: Color ?:= nil) :=
line(bl_vect(x0, y0), bl_vect(x1, y1), view, c);

procedure circle(x, y, r: real; view: blViewport; c: Color ?:= nil) := 
circle(bl_vect(x, y), r, view, c);

procedure DrawRectangle(x, y, w, h: real; view: blViewport; c: Color ?:= nil) :=
DrawRectangle(blBoundBox.from_xywh(x, y, w, h), view, c);



procedure draw_vector(v0, v: blVector; view: blViewport; c: color ?:= nil);
begin
  var v1 := v0 + v;
  line(v0, v1, view, c);
  circle(v1, view.to_world(3), view, c);
end;

procedure Draw(self: blPolygon; tr: blTransform; view: blViewport; c: color ?:= nil); extensionmethod;
begin
  DrawPolygon(self.vertices.Select(v -> tr.apply(v)), view, c);
end;

procedure Draw(self: blCircle; tr: blTransform; view: blViewport; c: color ?:= nil); extensionmethod;
begin
  DrawCircle(tr.pos, self.radius, view, c);
  Line(tr.pos, tr.apply(bl_vect(self.radius, 0)), view, c);
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

type
  WorldDrawStyle = class
  public
    obj: Color;
    stat: Color;
    bbox: Color?;
    vel: Color?;
    contact: Func<integer, Color>;
    
    constructor create(
    obj: Color := Color.FromArgb(255, 230, 230, 230);
    stat: Color := Color.FromArgb(178, 178, 178, 178);
    bbox: Color ?:= Color.FromArgb(120, 255, 0, 0);
    vel: Color ?:= Colors.Yellow;
    contact: Func<integer, Color> := dbg_shake_color);
    begin
      self.obj := obj;
      self.stat := stat;
      self.bbox := bbox;
      self.vel := vel;
      self.contact := contact;
    end;
  end;



procedure draw_world(world: blPhysWorld; view: blViewport; st: WorldDrawStyle);
begin
  var obj_clr := st.obj; 
  var st_color := st.stat;
  
  if world.bounds <> nil then 
    world.bounds.Draw(world.bounds_body.tr, view, obj_clr);
  
  foreach var b in world.bodies do
  begin
    b.group.Draw(b.tr, view, b.is_static ? st_color : obj_clr);
    if st.bbox <> nil then
      DrawRectangle(b.aabb, view, st.bbox.Value);
    if (st.vel <> nil) and not b.is_static then
      draw_vector(b.pos, b.vel, view, st.vel.Value);    
  end;  
  if st.contact <> nil then
  begin
    foreach var con in world.con_mgr.contacts do
    begin
      var key := new ArbiterKey(con.body_a, con.body_b, con.point.id);
      draw_vector(con.point.pos, con.hit_normal * con.point.depth, view, st.contact(key.GetHashCode()));
    end;
  end;
  
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
      DrawRectangle(b.aabb, view, Color.FromArgb(120, 255, 0, 0));
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