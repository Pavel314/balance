uses System.Collections.Generic, GraphWPF, GraphWPFBase, System.Windows.Input;
uses balance_wpfsvg;
uses balance in '..\balance.pas';
uses demos_helper in '..\demos_helper.pas';

const
  tick = 0.4;
  trin_r = 1;
  lever_r = tick + 0.2;
  snapshot_frame = 635;
  bg_clr = Colors.GhostWhite;//Colors.Black;
  balance_sign = 'Balance';

function color_to_gray(c: System.Windows.Media.Color): System.Windows.Media.Color;
begin
  var gray := Convert.ToByte(0.299 * c.R + 0.587 * c.G + 0.114 * c.B);
  result := Color.FromArgb(c.A, gray, gray, gray);
end;

var
  obj_clr := Color.FromArgb(255, 100, 100, 100);
  fnt_clr := Color.FromArgb(255, 110, 110, 110);
  
  world: PhysWorld;
  view: Viewport;
  fps := new FpsCounter();
  poly_cnt := -1;
  frame := 0;

var
  contact_f: Func<integer, Color> := hash -> color_to_gray(dbg_shake_color(hash));

var
  draw_style := new WorldDrawStyle(
  obj := obj_clr,
  stat := Color.Multiply(obj_clr, 0.5),
  bbox := Color.Multiply(obj_clr, 0.1),
  vel := obj_clr, //color_to_gray(Colors.Yellow),
  contact := contact_f);

var
  reps := new List<(integer, integer, integer)>;
  rep_ind := 0;
  rep_clock := new TimeTicker(3);
  svg_fnt: FontOptions;
  svg_fnt_weight := 200;

var
  dragger: MouseDragger;

function add_body(pos: blVector; verts: integer): RigidBody;
begin
  var b: blShape;
  if verts = -1 then
    b := new blCircle(trin_r)
  else
    b := Polygon.regular(verts, trin_r);
  result := world.add_body(bl_group(b), pos := pos)
end;

procedure on_md(x, y: real; md: integer);
begin
  var pos := view.to_world(bl_vect(x, y));
  if (md = 1) then
    add_body(pos, poly_cnt)
  else
  if (md = 2) then
  begin
    Mouse.Capture(MainDockPanel()); 
    dragger.on_mouse_down(world, pos);
  end;
end;

procedure on_mm(x, y: real; md: integer);
begin
  if md <> 2 then exit; 
  dragger.on_mouse_move(view.to_world(bl_vect(x, y)));
end;

procedure on_mu(x, y: real; md: integer);
begin
  Mouse.Capture(nil);
  dragger.on_mouse_up(world);
end;

procedure renderer();
begin
  Window.Clear(bg_clr);
  draw_world(world, view, draw_style);
  //dbg_draw_world(world, view);
  TextOut(10, 10, $'Phys FPS: {fps.fps:f0}, OBJS={world.bodies.Count} ', Colors.Red);
  
  
  TextOut(bl_vect(8.6, 9), balance_sign, svg_fnt, view);
end;

procedure take_snapshot();
begin
  var crop := view.get_world_bbox;
  crop.max_y -= 2.3;
  world.set_bounds(crop, 0.2);
  
  svg_begin(bg_clr, view, crop);
  svg_import_font(svg_fnt.Name, svg_fnt_weight, balance_sign);
  renderer();
  
  
  WriteAllText('logo.svg', svg_end());
  
  
end;



procedure on_frame(dt: real);
begin
  dt := 1 / 60;
  if frame >= snapshot_frame then
  begin
    if frame = snapshot_frame then
    begin
      take_snapshot();
      frame += 1
    end else
      renderer();
    exit;
  end;
  
  fps.start();
  dragger.accept_frame(world, dt);
  world.step(dt);
  fps.stop();
  
  if (rep_ind < reps.Count) then
  begin
    loop rep_clock.update(dt) do
    begin
      poly_cnt := reps[rep_ind].Item3;
      on_md(reps[rep_ind].Item1, reps[rep_ind].Item2, 1); 
      rep_ind += 1;
      if (rep_ind >= reps.Count) then break;
    end;   
  end;
  
  renderer();
  
  frame += 1;
end;





procedure on_kd(k: Key);
begin
  case k of 
    Key.D0: poly_cnt := -1;
    Key.D3: poly_cnt := 3;
    Key.D4: poly_cnt := 4;
    Key.D5: poly_cnt := 5;
    Key.D6: poly_cnt := 6;
    Key.D7: poly_cnt := 7;
    Key.D8: poly_cnt := 8;
    Key.D9: poly_cnt := 9;
  end;
end;


procedure on_resize();
begin
  view.resize(Window.Width, Window.Height);
  world.set_bounds(view.get_world_bbox(), 0.2);
end;

begin
  svg_fnt := new FontOptions();
  svg_fnt.Color :=  fnt_clr;
  svg_fnt.Name := 'Noto Sans';
  svg_fnt.Size := 84;
  
  Damping.DefaultDamp.run(0.60606, 0.60606);
  world := new PhysWorld(grav := bl_vect(0, -3));
  view := Viewport.fixed_zoom(new Camera(bl_vect0, 50), Window.Width, Window.Height);
  view.cam.moved(view.get_world_bbox().half_extents);
  
  var vbox := view.get_world_bbox();
  var (w, h) := (vbox.width, vbox.height);
  on_resize();
  
  var trin := Polygon.regular(3, trin_r);
  var lever := Polygon.wall(bl_vect(w - lever_r * 2, 0), tick);
  var tb := world.add_body(bl_group(trin), pos := bl_vect(w / 2, trin_r), is_static := true);
  world.add_body(bl_group(lever), pos := bl_vect(lever_r, tb.pos.y + trin_r + 0.7), is_static := false);
  
  dragger := new MouseDragger();
  
  Pen.Color := bg_clr;
  OnDrawFrame += on_frame;
  OnKeyDown += on_kd;
  OnResize += on_resize;
  
  OnMouseDown += on_md;
  OnMouseUp += on_mu;
  OnMouseMove += on_mm;
  
  reps.AddRange(|(760, 538, 4),
  (43, 526, 4),
  (44, 513, 4),
  (43, 472, 4),
  (45, 411, 4),
  (82, 241, 4),
  (180, 267, 4),
  (380, 341, 4),
  (575, 371, 4),
  (693, 420, 4),
  (735, 453, 4),
  (323, 327, 4),
  (265, 309, 4),
  (504, 365, 4),
  (470, 379, 4),
  (69, 269, 4),
  (93, 67, -1)|);
end.