unit demos_helper;

uses system, system.Reflection, balance;

//****************************
// Types for UI representation
//****************************
type
  UIAttribute = abstract class(Attribute) 
  end;
  
  //  UIDisplayAttribute = abstract class(UIAttribute) 
  //  end;
  //  
  //  [AttributeUsage(AttributeTargets.Field)]
  //  UIEnumNameAttribute = class(UIDisplayAttribute)
  //  public
  //    name: string;
  //    constructor(name: string) := self.name := name;
  //  end;
  
  UIBuilderAttribute = abstract class(UIAttribute)
    public constructor();begin end;
  end;
  
  [AttributeUsage(AttributeTargets.Field or AttributeTargets.Property)]
  UIExpandAttribute = class(UIBuilderAttribute)
  public
    constructor();begin end;
  end;
  
  UIAttributeKind = (UIAttributeReset, UIAttributeHot);
  
  UIControlAttribute = abstract class(UIBuilderAttribute)
  public
    kind: UIAttributeKind;
    text: string;
    constructor(kind: UIAttributeKind; text: string);
    begin
      self.kind := kind;
      self.text := text;
    end;
  end;
  
  [AttributeUsage(AttributeTargets.Field or AttributeTargets.Property, AllowMultiple = false, &Inherited = true)]
  UIDataAttribute  = class(UIControlAttribute)
    public constructor(kind: UIAttributeKind; text: string) := inherited create(kind, text);
  end;
  
  [AttributeUsage(AttributeTargets.Method, AllowMultiple = false, &Inherited = true)]
  UIActionAttribute  = class(UIControlAttribute)
    public constructor(kind: UIAttributeKind; text: string) := inherited create(kind, text);
  end;
  
  UISliderAttribute<T> = class(UIDataAttribute)
  public
    min, max, freq: T;
    constructor(kind: UIAttributeKind; text: string; min, max, freq: T);
    begin
      inherited create(kind, text);
      (self.min, self.max, self.freq) := (min, max, freq); 
    end;
  end;
  
  UISliderIntAttribute = class(UISliderAttribute<integer>)
    public constructor(kind: UIAttributeKind; text: string; min, max: integer; freq: integer := 1) := inherited create(kind, text, min, max, freq);
  end;
  
  UISliderRealAttribute = class(UISliderAttribute<real>)
    public constructor(kind: UIAttributeKind; text: string; min, max, freq: real) := inherited create(kind, text, min, max, freq);
  end;
  
  UICheckBoxAttribute = class(UIDataAttribute)
    public constructor(kind: UIAttributeKind; text: string) := inherited create(kind, text);
  end;
  
  UIComboBoxAttribute = class(UIDataAttribute)
    public constructor(kind: UIAttributeKind; text: string := '') := inherited create(kind, text);
  end;
  
  UIRadioButtonAttribute = class(UIDataAttribute)
    public constructor(kind: UIAttributeKind; text: string := '') := inherited create(kind, text);
  end;
  
  UIButtonAttribute = class(UIActionAttribute)
    public constructor(kind: UIAttributeKind; text: string) := inherited create(kind, text);
  end;
  
  UIHelper = static class
  public
    static function get_member_val(m: MemberInfo; owner: object): object;
    begin
      match m with
        FieldInfo(var i): exit(i.GetValue(owner));
        PropertyInfo(var i): exit(i.GetValue(owner));
        else raise new System.ArgumentException('Member must be Field or Property');
      end;      
    end;
    
    static procedure set_member_val(m: MemberInfo; owner: object; v: object);
    begin
      match m with
        FieldInfo(var i): i.SetValue(owner, v);
        PropertyInfo(var i): i.SetValue(owner, v);
        else raise new System.ArgumentException('Member must be Field or Property');
      end;      
    end;
    
    static function get_member_type(m: MemberInfo): &Type;
    begin
      match m with
        FieldInfo(var f): result := f.FieldType;
        PropertyInfo(var p): result := p.PropertyType;
        else raise new System.ArgumentException('Member must be Field or Property');
      end;
    end;
    
    static function get_display_name_for_enum_item(enum_item: string): string;
    begin
      var base_name := enum_item.Substring(enum_item.LastIndexOf('_') + 1);
      if String.IsNullOrEmpty(base_name) then exit(enum_item);
      var sb := new StringBuilder();
      sb.Append(base_name[1]); 
      var is_upper := char.IsUpper;
      for var i := 2 to base_name.Length do
      begin
        var (prev, cur) := (base_name[i - 1], base_name[i]);
        var space_needed := is_upper(cur) and (not is_upper(prev) or ((i < base_name.Length) and not is_upper(base_name[i + 1])));
        if space_needed then sb.Append(' ');
        sb.Append(cur);
      end;
      result := sb.ToString();
    end;
    
    static function get_display_text(attr: UIControlAttribute; ind: integer) := ind >= 0 ? string.Format(attr.text, ind + 1) : attr.text;
    
    static function verify_expand_attr_field(m: MemberInfo; val: object): System.Collections.IEnumerable;
    begin
      if val = nil then
        raise new Exception($'UIBuilder Error: [UIExpand] field {m.Name} is nil');
      var cont := val as System.Collections.IEnumerable;
      if cont = nil then
        raise new Exception($'UIBuilder Error: [UIExpand] applied to {m.Name}, but {val.GetType().Name} is not implement IEnumerable');
      result := cont;
    end;
    
    static procedure verify_expand_attr_item(item: object; index: integer; field_name: string);
    begin
      if item = nil then
        raise new Exception($'UIBuilder Error: Element at index {index} in {field_name} is nil');
      if not item.GetType.IsClass then
        raise new Exception($'UIExpand item [{index}] in {field_name} must be a class, actual type is {item.GetType.Name}');
    end;
  
  end;

//**************************
// Backend independent types
//**************************
type
  IInputSource = interface
    function is_key_down(key: string): boolean;
    function is_mouse_drag(): boolean;
    /// btn: 0=No pressed, 1 - Left, 2=Right; pos: current screen position
    procedure get_mouse(var btn: integer; var pos: Vector);
  end;
  
  MouseDragger = class
  private
    last_pos: Vector;
    is_button_down: boolean;
    acc_delta: Vector;
    
    mouse_joint: RevoluteJoint;
    vel: Vector;
    
    procedure capture_body(world: PhysWorld);
    begin
      if (is_button_down) and (mouse_joint = nil) then
      begin
        var target := world.query_point(last_pos, body -> not body.is_static);
        if target <> nil then
        begin
          mouse_joint := Joints.Revolute(world.ground, target, last_pos);
          world.joints.add(mouse_joint);
        end;     
      end;
    end;
    
    procedure release_body(world: PhysWorld);
    begin
      if not is_button_down and (mouse_joint <> nil) then
      begin
        var target := mouse_joint.body_b;
        target.add_impulse((vel - target.vel) * target.mass, mouse_joint.anchor.world_b(target.tr));
        world.joints.remove(mouse_joint);
        mouse_joint := nil;
      end; 
    end;
  
  
  public
    mouse_max_speed: real;
    property is_captured: boolean read mouse_joint <> nil;
    property captured_body: RigidBody read (mouse_joint <> nil) ? mouse_joint.body_b : nil;
    
    /// Should be called before world reference invalidation
    procedure reset(world: PhysWorld);
    begin
      if (world <> nil) and (mouse_joint <> nil) then world.joints.remove(mouse_joint);
      mouse_joint := nil;
      is_button_down := false;
      acc_delta := bl_vect0;
      vel := bl_vect0;
      last_pos := bl_vect0;
    end;
    
    constructor create(mouse_max_speed: real := 100);
    begin
      self.mouse_max_speed := mouse_max_speed;
      reset(nil);
    end;
    
    procedure on_mouse_down(world: PhysWorld; pt: Vector);
    begin
      is_button_down := true; 
      last_pos := pt;
      vel := bl_vect0;
      acc_delta := bl_vect0;
      capture_body(world);
    end;
    
    procedure on_mouse_up(world: PhysWorld);
    begin
      is_button_down := false; 
      release_body(world);
    end;
    
    procedure on_mouse_move(pt: Vector);
    begin
      if is_button_down then
        acc_delta += (pt - last_pos);
      last_pos := pt;
    end;
    
    procedure accept_frame(world: PhysWorld; dt: real);
    begin
      if is_button_down and (mouse_joint <> nil) then
      begin
        if acc_delta.Length > 0.0001 then
        begin
          var vel := (acc_delta / dt).clamp(mouse_max_speed);
          self.vel := Vector.lerp(self.vel, vel, 0.3)
        end
        else
          self.vel := self.vel * power(0.1, dt); 
        mouse_joint.anchor := mouse_joint.anchor.replace(local_a := world.ground.tr.unapply(last_pos));
      end;
      acc_delta := bl_vect0;
    end;
  end;
  
  KeyboardInput = class
  private
    pressed_keys := new HashSet<string>(StringComparer.OrdinalIgnoreCase); 
  public
    procedure on_key_down(k: string) := pressed_keys.Add(k);
    procedure on_key_up(k: string) := pressed_keys.Remove(k);
    function is_key_down(k: string) := pressed_keys.Contains(k);
    procedure reset() := pressed_keys.Clear();
    constructor create();begin end; 
  end;
  
  // Using underscore as a naming convention for UIRadioButtonAttribute (text after '_' is used in RadioButtons)
  CarDriveMode = (Car_RWD, Car_FWD, Car_AWD);
  
  CarBody = class
  public
    chassis: RigidBody;
    wheel_r, wheel_f: RigidBody;
    sus_r, sus_f: LineJoint;
    
    constructor create(pos: Vector; scale: real := 1);
    begin
      var car_points := |(-1.5, -0.5), (1.5, -0.5), (1.5,  0.0), (0.0,  0.9), (-1.15, 0.9), (-1.5,  0.2)|;
      var points := car_points.Select(v -> bl_vect(v.Item1, v.Item2) * scale);
      
      var chassis_mat := Material.from_frd(0.2, 0.2, 1.0 / scale);
      var wheel_mat   := Material.from_frd(1.5, 0.1, 2.0 / scale);
      
      var chassis_gr := bl_group(Polygon.create(points).centered());
      chassis := new RigidBody(chassis_gr, bl_trans(pos + bl_vect(0, 1.0 * scale)), false, chassis_mat, nil);
      
      var wheel_gr := bl_group(new Circle(0.4 * scale));
      wheel_r := new RigidBody(wheel_gr, bl_trans(pos + bl_vect(-1.1 * scale, 0.5 * scale)), false, wheel_mat);
      wheel_f := new RigidBody(wheel_gr, bl_trans(pos + bl_vect(1.1 * scale, 0.5 * scale)), false, wheel_mat);
      
      var spring_freq := 5.0;
      var spring_damp := 0.7;
      var spring_lim := 0.25 * scale;
      
      sus_r := Joints.Absorber(chassis, wheel_r, wheel_r.pos, bl_vect(0, 1), spring_freq, spring_damp, -spring_lim, spring_lim);
      sus_f := Joints.Absorber(chassis, wheel_f, wheel_f.pos, bl_vect(0, 1), spring_freq, spring_damp, -spring_lim, spring_lim);
    end;
    
    procedure run_motor(speed: real ?:= nil; max_torque: real ?:= nil; mode: CarDriveMode := CarDriveMode.Car_AWD; en: boolean := true);
    begin
      var r_en := (mode = CarDriveMode.Car_RWD) or (mode = CarDriveMode.Car_AWD);
      var f_en := (mode = CarDriveMode.Car_FWD) or (mode = CarDriveMode.Car_AWD);
      
      sus_r.ang_motor.run(speed, max_torque, en and r_en);
      sus_f.ang_motor.run(speed, max_torque, en and f_en);
    end;
    
    procedure set_soft(freq: real ?:= nil; damping: real ?:= nil);
    begin
      sus_r.lin_const.compliance.set_soft(freq, damping);
      sus_f.lin_const.compliance.set_soft(freq, damping);      
    end;
    
    procedure add_to_world(world: PhysWorld);
    begin
      world.bodies.Add(chassis);
      world.bodies.Add(wheel_r);
      world.bodies.Add(wheel_f);
      world.family_mgr.unite(wheel_r, chassis);
      world.family_mgr.unite(wheel_f, chassis);
      world.joints.Add(sus_r);
      world.joints.Add(sus_f);
    end;
  end;

procedure add_bridge(
world: PhysWorld; 
body_a, body_b: RigidBody; 
anchor_a, anchor_b: Vector;
segment: ShapeGroup;
count: integer;
mat: Material ? := nil);
begin
  var dir := anchor_b - anchor_a;
  var angle := Atan2(dir.y, dir.x); 
  var step := dir / count;
  var prev_body := body_a;
  for var i := 0 to count - 1 do
  begin
    var pivot := anchor_a + step * i;
    var body := world.add_body(segment, pivot + step * 0.5, angle, mat := mat);
    world.add_joint(Joints.Revolute(prev_body, body, pivot));
    prev_body := body;
  end;
  world.add_joint(Joints.Revolute(prev_body, body_b, anchor_b));
end;

function add_spinner(world: PhysWorld; segment: Shape; pos: Vector; count: integer; mat: Material ? := nil): RevoluteJoint;
begin
  var step := PI / count;
  var gr := SeqGen(count, i -> new TrShape(segment, bl_trans(segment.user_centroid, i * step))).ToArray();
  var spinner := world.add_body(new ShapeGroup(gr), pos, mat := mat);
  var j := Joints.Revolute(world.ground, spinner, pos);
  world.add_joint(j);
  result := j;
end;

procedure limit_velocity(b: RigidBody; max_vel: real);
begin
  var v := b.vel;
  if v.LengthSquared() > sqr(max_vel) then
    b.vel := v.norm() * max_vel;
end;

var
  __fps := new FpsCounter();

procedure start_fps() := __fps.start();

function stop_fps() := __fps.stop();

type
  SimpleGridLayout = record
    step: Vector;
    total_sz: Vector;
    starts: Vector;
    bbox: BoundBox;
    
    constructor create(cols, rows: integer; sz, gap, pivot: Vector);
    begin
      step := bl_vect(gap.x + sz.x, gap.y + sz.y);
      total_sz := bl_vect((cols - 1) * step.x, (rows - 1) * step.y) + sz;
      bbox := BoundBox.from_center(total_sz.x, total_sz.y, bl_vect(total_sz.x * pivot.x, total_sz.y * pivot.y));
      starts := bbox.min + sz * 0.5;
    end;
    
    constructor create(cols, rows: integer; sz, gap: Vector) := create(cols, rows, sz, gap, bl_vect(0, 0.5));   
    static function one_row(cols: integer; sz: Vector; gap_x: real): SimpleGridLayout := 
    new SimpleGridLayout(cols, 1, sz, bl_vect(gap_x, 0));
    
    
    function get_pos(col, row: integer) := bl_vect(starts.x + col * step.x, starts.y + row * step.y);
  end;
  
  //*********************************
  //Abstract Base Class for all demos
  //*********************************
  [AttributeUsage(AttributeTargets.&Class)]
  SceneNameAttribute = class(Attribute)
  public
    name: string;
    constructor(name: string) := self.name := name;
  end;
  
  BaseScene = abstract class
  private
    m_reset_on_resize:boolean;
  protected
    m_world: PhysWorld;
    m_view: Viewport;
  public
    property world: PhysWorld read m_world;
    property view: Viewport read m_view;
    function reset_on_resize():boolean; virtual := false;
    procedure reset(w, h: real); abstract;
    procedure pre_frame(input: IInputSource); virtual;begin end;
    procedure post_frame(input: IInputSource; steps: integer); virtual;begin end;
  end;

function random_step(min, max, step: real) := min + pabcsystem.Random(Round((max - min) / step) + 1) * step;

begin

end. 