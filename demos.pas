// ****************************************************************
// Some scenes are adapted from Box2D samples (box2d.org)
// Box2D created by Erin Catto, MIT License
// ****************************************************************

unit demos;

uses balance, demos_helper;

type
  [SceneName('Friction Test')]
  FrictionScene = class(BaseScene)
  public
    procedure reset(w, h: real); override;
    begin
      inherited reset(w,h);
      m_world := new PhysWorld(bl_vect(0, -9.8));
      m_view := Viewport.fixed_zoom(new Camera(bl_trans(0, 14), 35 * 0.6), w, h);
      begin
        var mat := Material.from_frd(0.2, 0, 1);
        var make_box: (real, real, real, real, real)-> RigidBody;
        make_box := (hw, hh, x, y, rot)-> world.add_body(bl_group(Polygon.box(hw * 2, hh * 2)), bl_vect(x, y), rot, mat := mat, is_static := true);;
        make_box(13, 0.25, -4, 22, -0.25);
        make_box(0.25, 1, 10.5, 19, 0);
        make_box(13, 0.25, 4, 14, 0.25);
        make_box(0.25, 1, -10.5, 11, 0);
        make_box(13, 0.25, -4, 6, -0.25);
      end;
      
      begin
        var mat := Material.from_frd(0, 0, 25);
        var box := bl_group(Polygon.box(1, 1));
        var frics := |0.75, 0.5, 0.35, 0.1, 0.0|;
        for var i := 0 to frics.Length - 1 do
          m_world.add_body(box, bl_vect(-15 + 4 * i, 28), mat := mat.replace(fric := frics[i]));  
      end;
    end;
  end;
  
  [SceneName('Domino Test')]
  DominoScene = class(BaseScene)
  public
    procedure reset(w, h: real); override;
    begin
      inherited reset(w,h);
      m_world := new PhysWorld(bl_vect(0, -9.8));
      m_view := Viewport.fixed_zoom(new Camera(bl_trans(0, 4), 200 * 0.25), w, h);
      
      var mat := Material.from_frd(0.5, 0, 1.0);
      begin
        var box := bl_group(Polygon.box(100 * 2, 1 * 2));
        world.add_body(box, bl_vect(0, -1), 0, is_static := true, mat := mat);
      end;
      
      begin
        var box := bl_group(Polygon.box(0.125 * 2, 0.5 * 2));
        var count := 15;
        for var i := 0 to count - 1 do
        begin
          var x := -0.5 * count + i;
          var domino := m_world.add_body(box, bl_vect(x, 0.5), mat := mat);
          if i = 0 then domino.add_impulse(bl_vect(0.1, 0.0), bl_vect(x, 1.0));
        end;
      end;
    end;
  end;
  
  TowersSceneShape = (TowersShape_Box, TowersShape_Circle, TowersShape_Random);
  
  [SceneName('Towers')]
  TowersScene = class(BaseScene)
  public
    const max_rows = 30;
    const max_cols = 10;
    const sz = 1;
    const gap_max = sz * 3;
    
    [UIRadioButtonAttribute(UIAttributeReset)]
    ui_shape: TowersSceneShape; 
    [UISliderInt(UIAttributeReset, 'Rows', 1, max_rows)]
    ui_rows: integer := 15;
    [UISliderInt(UIAttributeReset, 'Columns', 1, max_cols)]
    ui_cols: integer := 5;
    [UISliderReal(UIAttributeReset, 'Gap', 0, gap_max, 0.1)]
    ui_gap: real := sz * 2;
    
    procedure reset(w, h: real); override;
    begin
      inherited reset(w,h);
      var grid := new SimpleGridLayout(ui_cols, ui_rows, bl_vect(sz, sz), bl_vect(ui_gap, 0));
      m_world := new PhysWorld(bl_vect(0, -9.8));
      var bbox := grid.bbox.expand(sz * 4, sz, sz * 4, 0);
      m_view := Viewport.fixed_world(new Camera(bbox.center), bbox.width, bbox.height, w, h);
      
      m_world.bounds := ShapeGroup.make_lines_chain(|bl_vect(bbox.min.x, bbox.max.y), 
          bl_vect(bbox.min.x, bbox.min.y), 
          bl_vect(bbox.max.x, bbox.min.y), 
          bl_vect(bbox.max.x, bbox.max.y) 
        |, 0.2, true);
      
      var box_sh: ShapeGroup := bl_group(Polygon.box(sz, sz)); 
      var cir_sh: ShapeGroup := bl_group(new Circle(sz / 2)); 
      
      for var j := 0 to ui_cols - 1 do
        for var i := 0 to ui_rows - 1 do
        begin
          var sh: ShapeGroup;
          case ui_shape of 
            TowersShape_Box: sh := box_sh;
            TowersShape_Circle: sh := cir_sh;
            TowersShape_Random: sh := Random(2) = 0 ? cir_sh : box_sh;
          else assert(false, 'Unknown shape');
          end;
          world.add_body(sh, grid.get_pos(j, i));
        end;
    end;
  end;
  
  ui_spring = auto class
  public
    const mass_min = 0.1;
    const mass_max = 10;
    const mass_step = 0.1;
    const freq_min = 1;
    const freq_max = 10;
    const freq_step = 1;
    const damp_min = 0;
    const damp_max = 4;
    const damp_step = 0.1;
    
    [UISliderReal(UIAttributeHot, 'Spring{0} Mass', mass_min, mass_max, mass_step)]
    mass: real := 1;
    
    [UISliderReal(UIAttributeHot, 'Spring{0} Hertz', freq_min, freq_max, freq_step)]
    freq: real := 2;
    
    [UISliderReal(UIAttributeHot, 'Spring{0} Damp', damp_min, damp_max, damp_step)]  
    damp: real := 0.1;
    
    static function random(): ui_spring;
    begin
      Result := new ui_spring(
      random_step(mass_min, mass_max, mass_step),
      random_step(freq_min, freq_max, freq_step),
      random_step(damp_min, damp_max, damp_step));
    end;
  end;
  
  [SceneName('Springs')]
  SpringsScene = class(BaseScene)
    static function cr_spring(not_used: integer) := new ui_spring();
  private
    j_springs := new List<LineJoint>();
  public
    const sz = 1;
    const gap = 3;
    const scene_h = 16;
    const anchor_y = 14;
    const cargo_y = 12;
    const springs_count = 3;
    
    [UISliderReal(UIAttributeReset, 'Pull Offset', 0, 10, 0.5)]
    ui_pull_offset: real := 2;
    
    [UIExpand]
    ui_springs := SeqGen(springs_count, cr_spring).ToArray();
    
    procedure reset(w, h: real); override;
    begin
      inherited reset(w,h);
      var grid := new SimpleGridLayout(springs_count, 1, bl_vect(sz, scene_h), bl_vect(gap, 0));
      var bbox := grid.bbox;
      
      m_world := new PhysWorld(bl_vect(0, -9.8));
      m_view := Viewport.fixed_world(new Camera(bbox.center, 1), bbox.width, bbox.height, w, h);
      
      var box := bl_group(Polygon.box(sz, sz));
      var circle := bl_group(new Circle(sz / 2));
      
      j_springs.Clear();
      for var i := 0 to ui_springs.Length - 1 do
      begin
        var x := grid.get_pos(i, 0).x;
        var anchor := m_world.add_body(box, bl_vect(x, anchor_y), is_static := true);
        var ui := ui_springs[i];
        var cargo := m_world.add_body(circle, bl_vect(x, cargo_y), mass := ui.mass);
        var j := Joints.SliderSpring(anchor, cargo, anchor.pos, bl_vect(0, 1), ui.freq, ui.damp);
        j.side_const.compliance.set_hard(baumgarte := 0.5);
        j_springs.Add(j);
        m_world.add_joint(j);
        cargo.pos -= bl_vect(0, ui_pull_offset);
      end;
    end;
    
    procedure pre_frame(input: IInputSource); override;
    begin
      inherited pre_frame(input);
      for var i := 0 to springs_count - 1 do
      begin
        var spring := j_springs[i];
        var ui := ui_springs[i];
        var cargo := spring.body_b;
        if cargo.custom_mass <> ui.mass then
        begin
          cargo.custom_mass := ui.mass;
          cargo.recalc();
        end;
        spring.lin_const.compliance.set_soft(ui.freq, ui.damp);
      end;
    end;
  end;
  
  
  [SceneName('Newton Cradle')]
  NewtonCradleScene = class(BaseScene)
  private
    demo_tag := new object();
  public
    const sz = 1.0;
    const border_h = 0.5;
    
    [UISliderInt(UIAttributeReset, 'Ball Count', 1, 20)]
    ui_ball_count: integer := 5;
    
    [UISliderReal(UIAttributeReset, 'Start Angle', 0, 80, 1)]
    ui_init_angle: real := 60;
    
    [UISliderReal(UIAttributeReset, 'Thread Length', sz, 20, 0.5)]
    ui_thread_length: real := 3.0;
    
    [UISliderReal(UIAttributeHot, 'Restitution', 0, 1, 0.05)]
    ui_restitution: real := 1.0;   
    
    procedure reset(w, h: real); override;
    begin
      inherited reset(w,h);
      var scene_h := ui_thread_length + border_h;
      var grid := new SimpleGridLayout(ui_ball_count, 1, bl_vect(sz, scene_h), bl_vect(sz / 20, 0), bl_vect(0, 0.5));
      
      m_world := new PhysWorld(bl_vect(0, -9.8));
      
      var bbox := grid.bbox.expand(ui_thread_length);
      m_view := Viewport.fixed_world(new Camera(bbox.center), bbox.width, bbox.height, w, h);
      
      var border_sh := bl_group(Polygon.box(bbox.width, border_h));
      m_world.add_body(border_sh, bl_vect(0, scene_h), is_static := true);
      
      var ball_sh := bl_group(new Circle(sz / 2));
      var anchor_sh := bl_group(Polygon.box(sz / 2, sz / 2));
      var mat := Material.from_frd(0, ui_restitution, 1);
      
      for var i := 0 to ui_ball_count - 1 do
      begin
        var x := grid.get_pos(i, 0).x;
        var anchor := m_world.add_body(anchor_sh, bl_vect(x, ui_thread_length), is_static := true);
        var ball := m_world.add_body(ball_sh, bl_vect(x, 0), mat := mat, tag := demo_tag);
        m_world.add_joint(Joints.Rope(anchor, ball, anchor.pos, ball.pos));
        if i = 0 then 
        begin
          var ang := degtorad(270 - ui_init_angle);
          ball.pos := anchor.pos + (bl_vect(cos(ang), sin(ang)) * ui_thread_length);
        end;
      end;
    end;
    
    procedure pre_frame(input: IInputSource); override;
    begin
      inherited pre_frame(input);
      foreach var b in m_world.bodies do
      begin
        if object.ReferenceEquals(b.tag, demo_tag) then
          b.mat := b.mat.replace(rest := ui_restitution);
      end;
    end;
  end;
  
  
  [SceneName('Car Driving')]
  CarDrivingScene = class(BaseScene)
  public
    car: CarBody;
    
    [UISliderReal(UIAttributeHot, 'Spring Hertz', 1, 20, 1)]  
    ui_spring_hz: real := 5;
    [UISliderReal(UIAttributeHot, 'Spring Damp', 0, 10, 0.1)]  
    ui_spring_damp: real := 0.7;
    [UISliderReal(UIAttributeHot, 'Speed', 0, 50, 5)]
    ui_speed: real := 35;
    [UISliderReal(UIAttributeHot, 'Torque', 0, 10, 0.1)]
    ui_torque: real := 5;   
    [UICheckbox(UIAttributeHot, 'Auto gas')]
    ui_autogas: boolean := false;
    [UIRadioButton(UIAttributeHot)]
    ui_drive_mode: CarDriveMode := CarDriveMode.Car_AWD;
    
    procedure reset(w, h: real); override;
    begin
      inherited reset(w,h);
      m_world := new PhysWorld(bl_vect(0, -9.8));
      m_view := Viewport.fixed_height(new Camera(bl_vect(0, 4)), 20, w, h);
      
      var road: RigidBody := nil;
      begin
        var road_mat := Material.from_frd(0.5, 0.2, 0.6);
        var hs := |0.25, 1.0, 4.0, 0.0, 0.0, -1.0, -2.0, -2.0, -1.25, 0.0|;
        var x := 20.0;
        var dx := 5.0;
        var pts := new List<Vector>(|bl_vect(-20, -20), bl_vect(-20,   0), bl_vect( 20,   0)|);
        for var j := 0 to 1 do
          for var i := 0 to 9 do
          begin
            x += dx;
            pts.Add(bl_vect(x, hs[i]));
          end;
        pts.Add(bl_vect(x + 40.0,   0));
        pts.Add(bl_vect(x + 40.0, -20));
        var segment: Func<array of Vector, RigidBody> := pts -> world.add_body(ShapeGroup.make_lines_chain(pts, 0.1, false), is_static := true, mat:=road_mat);
        road := segment(pts.ToArray());
        x += 80;
        segment(|bl_vect(x, 0), bl_vect(x + 40, 0), bl_vect(x + 50, 5)|);
        x += 60;
        segment(|bl_vect(x, 0), bl_vect(x + 40, 0),  bl_vect(x + 40, 20)|);
      end;
      begin
        var pos := bl_vect(140.0, 1.0);
        var box := Polygon.box(20.0, 0.5); 
        var teeter := world.add_body(bl_group(box), pos, is_static := false);
        teeter.avel := 1.0;
        var lim := DegToRad(8.0);
        world.add_joint(Joints.Revolute(world.ground, teeter, pos).with_ang_limit(-lim, lim)); 
        world.family_mgr.unite(road, teeter);
      end;
      begin
        var box := Polygon.box(2, 0.25);
        var start_pt := bl_vect(160, -0.1);
        var end_pt   := bl_vect(200, -0.1);
        add_bridge(world, world.ground, world.ground, start_pt, end_pt, bl_group(box), 20, nil);
      end;
      begin
        var box := Polygon.box(1.0, 1.0);
        var box_mat := Material.from_frd(0.25, 0.25, 0.25); 
        for var i := 0 to 4 do
        begin
          var x_pos := 230.0;
          var y_pos := 0.5 + i * 1.0;
          world.add_body(bl_group(box), bl_vect(x_pos, y_pos), mat := box_mat);
        end;
      end;
      
      car := new CarBody(bl_vect(0, 0), 1);
      car.add_to_world(world); 
    end;
    
    procedure pre_frame(input: IInputSource); override;
    begin
      inherited pre_frame(input);
      var is_down := input.is_key_down;
      if is_down('D') then car.run_motor(-ui_speed, ui_torque, mode := ui_drive_mode)
      else if is_down('A') then car.run_motor(ui_speed, ui_torque, mode := ui_drive_mode)
      else if is_down('S') then car.run_motor(speed := 0.0, mode := ui_drive_mode)
      else if not ui_autogas then car.run_motor(en := false, mode := ui_drive_mode);
      car.set_soft(ui_spring_hz, ui_spring_damp);   
    end;
    
    procedure post_frame(input: IInputSource; steps: integer); override;
    begin
      if input.is_mouse_drag() then exit;
      view.cam.pos := Vector.Lerp(car.chassis.tr.pos, view.cam.pos, Power(1.0 - 0.1, steps)); 
    end;
  end;
  
  [SceneName('Pinball')]
  PinballScene = class(BaseScene)
  private
    l_flipj, r_flipj: RevoluteJoint;
    ball: RigidBody;
  
  public
    procedure reset(w, h: real); override;
    begin
      inherited reset(w,h);
      m_world := new PhysWorld(bl_vect(0, -9.8));
      var ground: RigidBody;
      // Ground
      begin
        var pts := |bl_vect(-8, 6), bl_vect(-8, 20), bl_vect(8, 20), bl_vect(8, 6), bl_vect(0, -2)|;
        var poly := new Polygon(pts);
        ground := m_world.add_body(ShapeGroup.make_hollow(poly, 0.3, true), poly.user_centroid, is_static := true);
      end;
      var bbox := ground.aabb.expand(2);
      m_view := Viewport.fixed_world(new Camera(bbox.center), bbox.width, bbox.height, w, h);
      
      // Flippers
      begin
        var (p1, p2) := (bl_vect(-2, 0), bl_vect(2, 0));
        
        var box_sh := bl_group(Polygon.box(1.75 * 2, 0.2 * 2));
        
        var l_flip := m_world.add_body(box_sh, p1);
        var r_flip := m_world.add_body(box_sh, p2);
        
        l_flipj := Joints.Revolute(ground, l_flip, p1);
        l_flipj.with_ang_motor(0, 1000).with_ang_limit(DegToRad(-30), DegToRad(5));
        
        r_flipj := Joints.Revolute(ground, r_flip, p2);
        r_flipj.with_ang_motor(0, 1000).with_ang_limit(DegToRad(-5), DegToRad(30));
        
        m_world.add_joint(l_flipj);
        m_world.add_joint(r_flipj);
      end;
      
      // Spinners
      begin
        var spin_sh := Polygon.box(3.0, 0.3);
        add_spinner(world, spin_sh, bl_vect(-4, 17), 2).with_ang_motor(0.0, 1);
        add_spinner(world, spin_sh, bl_vect(4, 8), 2).with_ang_motor(0.0, 1);
      end;
      
      // Bumpers
      begin
        var mat := Material.from_frd(0.5, 20, 1.0);
        var bumper_sh := bl_group(new Circle(1.3));
        m_world.add_body(bumper_sh, bl_vect(-4, 8), mat := mat, is_static := true);
        m_world.add_body(bumper_sh, bl_vect(4, 17), mat := mat, is_static := true);
      end;
      
      // Ball
      begin
        var mat := Material.from_frd(0.1, 0.05, 2.5);
        var ball_sh := bl_group(new Circle(0.3));
        ball := m_world.add_body(ball_sh, bl_vect(1, 15), mat := mat);
      end;
    end;
    
    procedure pre_frame(input: IInputSource); override;
    begin
      inherited pre_frame(input);
      if input.is_key_down('Space') then
      begin
        l_flipj.ang_motor.run(20.0);
        r_flipj.ang_motor.run(-20.0);
      end
      else
      begin
        l_flipj.ang_motor.run(-10.0);
        r_flipj.ang_motor.run(10.0);
      end;
      limit_velocity(ball, 35);
    end;
  end;
  
  MiniShapesParamHelper = class
  public
    static function pnt_cmp(v1, v2: Vector; bbox: BoundBox): integer;
    begin
      var n := 512;
      var grid := BoundBox.from_xywh(0, 0, n - 1, n - 1);
      var (p1, p2) := (bbox.remap(v1, grid), bbox.remap(v2, grid));
      var ind1 := pos_to_index_hilbert(Round(p1.x), Round(p1.y), n);
      var ind2 := pos_to_index_hilbert(Round(p2.x), Round(p2.y), n);      
      result := ind1.CompareTo(ind2);
    end;
  
  private
    points: array of Vector;
    targets: Dictionary<RigidBody, Vector>;
    param_ind: integer;
  public
    procedure add_new_body(b: RigidBody);
    begin
      targets.Add(b, points[param_ind]);  
      param_ind += 1;
    end;
    
    procedure generate_targets(bodies: IEnumerable<RigidBody>; max_count: integer; view: Viewport; curve: ParametricCurve);
    begin
      param_ind := 0;
      var bbox := view.get_world_bbox();
      points :=  curve.generate_points(max_count, bbox.inflated(-0.1));
      points.Sort((v1, v2) -> pnt_cmp(v1, v2, bbox));
      var lbodies := bodies.ToList();
      assert(lbodies.Count <= max_count);
      lbodies.Sort((b1, b2) -> pnt_cmp(b1.pos, b2.pos, bbox));
      targets := new Dictionary<RigidBody, Vector>(max_count, new ReferenceEqualityComparer<RigidBody>());
      for var i := 0 to lbodies.Count - 1 do
        add_new_body(lbodies[i]);
    end;
    
    function get_target(b: RigidBody) := targets[b];
  end;

type
  MiniShapesParamCurve = (Param_None, Param_Circle, Param_Square, Param_Astroid, Param_Lissajous, Param_Spiral, Param_Star, Param_Flower5, Param_Flower4, Param_Infinity, Param_Heart);
  
  [SceneName('Mini Shapes')]
  MiniShapesScene = class(BaseScene)
  public
    static curves: Dictionary<MiniShapesParamCurve, ParametricCurve>;
    static constructor();
    begin
      var polar := ParametricCurve.polar;
      var param := ParametricCurve.param;
      curves := dict(
      (Param_None, ParametricCurve(nil)),
      (Param_Circle, polar(0, 2 * pi, t -> 1)),
      (Param_Square, polar(0, 2 * pi, t -> 1 / (abs(cos(t)) + abs(sin(t))))),
      (Param_Astroid, param( 0, 2 * pi, t -> bl_vect(power(cos(t), 3), power(sin(t), 3)))),
      (Param_Lissajous, param( 0, 2 * pi, t -> bl_vect(sin(3 * t), sin(2 * t)))),
      (Param_Spiral, polar(0, 8 * pi, t -> 1 - (t / (8 * PI)))),
      (Param_Star, ParametricCurve.star_polygon(5, 5 * 2 / 4)),
      (Param_Flower5, ParametricCurve.flower1(5)),
      (Param_Flower4, polar(0, 2 * PI, t -> (cos(t) * sin(t)) / (abs(cos(2 * t)) + abs(sin(2 * t))))),
      (Param_Infinity, param(0, 2 * pi, t -> bl_vect(cos(t), sin(t) * cos(t)) / (1 + sin(t) ** 2))),
      (Param_Heart, param( 0, 2 * PI, t -> bl_vect(16 * sin(t) ** 3, 13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)))));
      assert(curves.Count = System.Enum.GetNames(typeof(MiniShapesParamCurve)).Length, 'Parametric curves count does not match');
    end;
    
    public static procedure add_pd_force(b: RigidBody; target: Vector; stiffness, damping: real);
    begin
      var dist := target - b.pos;
      var force := dist * stiffness - b.vel * damping;
      b.add_force(force * b.mass); 
    end;
  
  private
    demo_tag := new object();
    mouse_follow_damp := new Damping(0.9, 0.9, en := false);
    m_helper: MiniShapesParamHelper;
  
  public
    const sz = 0.5;
    const start_avel = 6*pi;
    
    [UISliderInt(UIAttributeReset, 'Max Objects', 10, 800, 10)]
    ui_objs_count: integer := 100;
    
    [UISliderReal(UIAttributeHot, 'Start Speed', 0, 10, 1)]
    ui_start_speed: real := 6;
    
    [UISliderReal(UIAttributeReset, 'Circle probability', 0, 1, 0.1)]
    ui_circle_prob: real := 0.3;
    
    [UISliderReal(UIAttributeHot, 'Friction', 0, 1, 0.05)]
    ui_fric: real := 0.0;
    
    [UISliderReal(UIAttributeHot, 'Restitution', 0, 1, 0.1)]
    ui_rest: real := 1.0;
    
    [UICheckbox(UIAttributeHot, 'Mouse Follow')]
    ui_mouse_follow: boolean := false;
    
    [UIComboBox(UIAttributeHot, 'Parametric Curve')]
    ui_param_curve: MiniShapesParamCurve := MiniShapesParamCurve.Param_None;
    
    last_param_curve: MiniShapesParamCurve ? := nil;
    
    [UIButton(UIAttributeHot, 'Add speed')]
    procedure add_speed();
    begin
      for var i := 0 to m_world.bodies.Count - 1 do
      begin
        var b := m_world.bodies[i];
        if not object.ReferenceEquals(b.tag, demo_tag) then continue;
        b.vel += b.pos.Unortog().norm() * ui_start_speed;
        b.avel += random(-start_avel, start_avel);
      end;
    end;
    
    function has_parametric() := ui_param_curve <> MiniShapesParamCurve.Param_None;
    
    procedure resize(w, h: real); override:=reset(w,h);
    
    function add_random_shape(pos: Vector): RigidBody;
    begin
      var r := sz * 0.5;
      var shape: Shape;
      if (Random() < ui_circle_prob) then
        shape := new Circle(r)
      else
        shape := Polygon.regular(Random(3, 12), r);
      var b := m_world.add_body(bl_group(shape), pos, damp := mouse_follow_damp, tag := demo_tag);
      b.vel := rand_unit_vect() * random(ui_start_speed);
      b.avel := random(-start_avel, start_avel);
      if has_parametric then m_helper.add_new_body(b);
      result := b;
    end;
    
    procedure reset(w, h: real); override;
    begin
      inherited reset(w,h);
      m_world := new PhysWorld(bl_vect0);
      var side := sqrt(ui_objs_count) * sz * 2.5;
      m_view := Viewport.fixed_zoom(new Camera(bl_vect0, Min(w / side, h / side)), w, h);
      world.set_bounds(m_view.get_world_bbox(), -5);
      
      last_param_curve := nil;
      m_helper :=  new MiniShapesParamHelper();
    end;
    
    procedure pre_frame(input: IInputSource); override;
    begin
      inherited pre_frame(input);
      
      var ref_eql := object.ReferenceEquals;
      if (ui_param_curve <> last_param_curve) then
      begin
        if has_parametric then
          m_helper.generate_targets(m_world.bodies.Where(b -> ref_eql(b.tag, demo_tag)), ui_objs_count, m_view, curves[ui_param_curve]);
        last_param_curve := ui_param_curve;
      end;
      
      var mat := Material.from_frd(ui_fric, ui_rest, 1.0);
      m_world.bounds_body.mat := mat;
      var mouse_btn: integer;
      var mouse_pos: Vector;
      if ui_mouse_follow then 
      begin
        input.get_mouse(mouse_btn, mouse_pos);
        mouse_pos := m_view.to_world(mouse_pos);
      end;
      
      for var i := 0 to m_world.bodies.Count - 1 do
      begin
        var b := m_world.bodies[i];
        if not ref_eql(b.tag, demo_tag) then continue;
        b.mat := mat;
        b.damp.enabled := false;
        
        if has_parametric then
        begin
          add_pd_force(b, m_helper.get_target(b), 2, 2);
          b.damp.enabled := true;
        end;
        
        if ui_mouse_follow then 
        begin
          add_pd_force(b, mouse_pos, 2, 1.5);
          b.damp.enabled := true; 
        end;
      end;
      
      if m_world.bodies.Count < ui_objs_count then
        add_random_shape(bl_vect0);
    end;
    
    public add_speedd := add_speed; // Keep delegate to prevent dead code compiler optimization
  end;

const
  all_scenes = |typeof(FrictionScene),
  typeof(DominoScene),
  typeof(TowersScene),
  typeof(SpringsScene),
  typeof(NewtonCradleScene),
  typeof(CarDrivingScene),
  typeof(PinballScene),
  typeof(MiniShapesScene)
  |;

begin

end. 