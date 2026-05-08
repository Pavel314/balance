unit balance_basic;
//TODO MethodImplOptions.AggressiveInlining 

function unwrap_or<T>(self: T?; def: T): T; extensionmethod; where T: record;
begin
  result := self.GetValueOrDefault(def);
end;

function ref_eql(a, b: object) := object.ReferenceEquals(a, b);

function ref_eql_all(a, b, c: object) := ref_eql(a, b) and ref_eql(b, c);

function ref_eql_any(a, b, c: object) := ref_eql(a, b) or ref_eql(a, c) or ref_eql(b, c);

type
  Vector = record
    x, y: real;
    constructor create(x, y: real);
    begin
      self.x := x;
      self.y := y;
    end;
    
    function LengthSquared() := x * x + y * y;
    function Length() := Sqrt(x * x + y * y);
    
    function Ortog() := new Vector(y, -x);
    function Unortog() := new Vector(-y, x);
    function safe_div(s: real; dflt: Vector): Vector := s < 1e-12 ? dflt : self / s;
    
    function norm() : Vector := safe_div(Length(), new Vector(0, 0));
    function clamp(max_len: real): Vector := LengthSquared() > (max_len * max_len) ? self * (max_len / Length()) : self;
    
    static function Dot(v1: Vector; v2: Vector) := v1.x * v2.x + v1.y * v2.y;
    static function Cross(v1: Vector; v2: Vector) := v1.x * v2.y - v1.y * v2.x;
    static function Lerp(v1, v2: Vector; t: real): Vector := v1 * (1 - t) + v2 * t;
    
    static function operator+(v1: Vector; v2: Vector) := new vector(v1.x + v2.x, v1.y + v2.y);
    static function operator-(v1: Vector; v2: Vector) := new vector(v1.x - v2.x, v1.y - v2.y);
    static function operator*(v: Vector; s: real) := new Vector(v.x * s, v.y * s);
    static function operator*(v1, v2: Vector) := Dot(v1, v2);
    static function operator/(v: Vector; s: real) := new Vector(v.x / s, v.y / s); 
    
    static procedure operator+=(var v: Vector; n: Vector) := v := v + n;
    static procedure operator-=(var v: Vector; n: Vector) := v := v - n;
    static procedure operator*=(var v: Vector; s: real) := v := v * s;
    static procedure operator/=(var v: Vector; s: real) := v := v / s; 
    
    static function operator-(v: Vector) := new Vector(-v.x, -v.y);
    static function operator*(s: real; v: Vector) := v * s;
  end;
  
  Matrix2 = record
  public
    m11, m21: real;
    m12, m22: real;
    
    property col1: Vector read new Vector(m11, m21) write (m11, m21) := (value.x, value.y);
    property col2: Vector read new Vector(m12, m22) write (m12, m22) := (value.x, value.y);
    property row1: Vector read new Vector(m11, m12) write (m11, m12) := (value.x, value.y);
    property row2: Vector read new Vector(m21, m22) write (m21, m22) := (value.x, value.y);
    
    constructor create(col1, col2: Vector);
    begin
      self.col1 := col1;
      self.col2 := col2;
    end;
    
    constructor create(v11, v21, v12, v22: real);
    begin
      m11 := v11; m21 := v21;
      m12 := v12; m22 := v22;
    end;
    
    static function identity(v: real := 1): Matrix2 := new Matrix2(v, 0, 0, v);
    
    static function from_angle(ang: real): Matrix2;
    begin
      var c := cos(ang);
      var s := sin(ang);
      result := new Matrix2(c, s, -s, c);
    end;
    
    // For help with (r.y^2, -r.x*r.y, -r.x*r.y, r.x^2) * invI (вращательная инерция плеча r)
    static function get_inertia_matrix(r: Vector; inv_i: real): Matrix2 :=
    new Matrix2(r.y * r.y * inv_i, -r.x * r.y * inv_i, -r.x * r.y * inv_i, r.x * r.x * inv_i);
    
    static function get_contact_kmatrix(total_inv_mass, inv_inertia_a, inv_inertia_b: real; r_a, r_b: Vector): Matrix2 :=
    Matrix2.identity(total_inv_mass) + 
        get_inertia_matrix(r_a, inv_inertia_a) +
        get_inertia_matrix(r_b, inv_inertia_b)
    ;
    
    
    static function operator*(a: Matrix2; b: Vector) := a.col1 * b.x + a.col2 * b.y;
    static function operator*(a, b: Matrix2) := new Matrix2(a * b.col1, a * b.col2);
    static function operator*(a: Matrix2; b: real) := new Matrix2(a.col1 * b, a.col2 * b);
    static function operator+(a, b: Matrix2) := new Matrix2(a.col1 + b.col1, a.col2 + b.col2);
    static function operator-(a, b: Matrix2) := new Matrix2(a.col1 - b.col1, a.col2 - b.col2);
    
    static procedure operator*=(var m: Matrix2; s: real) := m := m * s; 
    static procedure operator+=(var a: Matrix2; b: Matrix2) := a := a + b;   
    static procedure operator-=(var a: Matrix2; b: Matrix2) := a := a - b;  
    
    function det() := m11 * m22 - m12 * m21;
    function invert(): Matrix2;
    begin
      var d := det();
      assert(Abs(d) > 1e-12, 'determinant too small ');
      d := 1.0 / d;
      result := new Matrix2(m22 * d, -m21 * d, -m12 * d, m11 * d);
    end;
    
    function transpose(): Matrix2 := new Matrix2(m11, m12, m21, m22);
    function solve(b: Vector) := invert() * b;
    function scalar_proj(dir: Vector) := dir * (self * dir);
    function effective_mass(dir: Vector): real;
    begin
      var proj := scalar_proj(dir);
      result := (proj > 1e-12) ? 1.0 / proj : 0.0;
    end;
  end;
  
  FixedBuf2<T> = record
  private
    v1, v2: T;
    m_count: integer;
  public
    property count: integer read m_count;
    procedure add(item: T);
    begin
      case m_count of
        0: v1 := item;
        1: v2 := item;
      else 
        raise new System.IndexOutOfRangeException('Buffer is full');
      end;
      m_count += 1;      
    end;
    
    function get(ind: integer): T;
    begin
      if (ind < 0) or (ind >= count) then
        raise new System.IndexOutOfRangeException('Out of range'); 
      case ind of
        0: exit(v1);
        1: exit(v2);
      end;
    end;
    
    function map<TRet>(f: T-> TRet): FixedBuf2<TRet>;
    begin
      result := new FixedBuf2<TRet>();
      if (self.count >= 1) then
        result.add(f(self.v1));
      if (self.count = 2) then
        result.add(f(self.v2));
    end;
    
    function filter(pred: T-> boolean): FixedBuf2<T>;
    begin
      result := new FixedBuf2<T>();      
      if (self.count >= 1) and pred(self.v1) then
        result.add(self.v1);
      if (self.count = 2) and pred(self.v2) then
        result.add(self.v2);
    end;
    
    property items[i: integer]: T read get(i);default;
    
    //static function create_filled(v1, v2: T): FixedBuf2<T> := (new fixed_buf2<T>()).add(v1).add(v2);
    
    function ToArray(): array of T;
    begin
      case count of 
        2: exit(new T[](v1, v2));
        1: exit(new T[](v1))
      else
        exit(new T[0]());
      end;
    end;    
  end;
  
  Transform = record
  private
    _ang, _cos, _sin: real;
  public
    pos: vector;
    procedure _set_ang(v: real);
    begin
      _ang := v;
      _cos := cos(v);
      _sin := sin(v);
    end;
    
    property ang: real read _ang write _set_ang;
    
    constructor create(pos: Vector; ang: real);
    begin
      self.pos := pos;
      self.ang := ang;
    end;
    
    function abs_apply_dir(v: Vector) := new Vector(abs(v.x * _cos) + abs(v.y * _sin), abs(v.x * _sin) + abs(v.y * _cos));
    function apply_dir(v: Vector) := new Vector(v.x * _cos - v.y * _sin, v.x * _sin + v.y * _cos);
    function apply(v: Vector) := apply_dir(v) + pos;
    function unapply_dir(v: Vector) := new Vector(v.x * _cos + v.y * _sin, -v.x * _sin + v.y * _cos);
    function unapply(v: Vector) := unapply_dir(v - pos);
    function combine(o: Transform) := new Transform(apply(o.pos), ang + o.ang);
    function moved(delta: Vector) := new Transform(pos + delta, ang);
    function rotated(delta: real) := new Transform(pos, ang + delta);
  end;
  
  MinMax = record
    min, max: real;
    constructor create(min, max: real);
    begin
      self.min := min;
      self.max := max;
    end;
    
    static function empty() := new MinMax(real.MaxValue, real.MinValue);
    procedure extend(v: real);
    begin
      if v < min then min := v;
      if v > max then max := v;     
    end;
    
    static function overlap(l, r: MinMax) := pabcsystem.min(l.max, r.max) - pabcsystem.max(l.min, r.min);//pabcsystem.Min(r.max - l.min, l.max - r.min); //
    static function contains(l, r: MinMax) := (l.min <= r.min) and (l.max >= r.max);
  end;
  
  BoundBox = record
    min_x, min_y, max_x, max_y: real;
    constructor create(min_x, min_y, max_x, max_y: real);
    begin
      self.min_x := min_x;
      self.min_y := min_y;
      self.max_x := max_x;
      self.max_y := max_y;
    end;
    
    property x: real read min_x;
    property y: real read min_y;
    property width: real read max_x - min_x;
    property height: real read max_y - min_y;
    property min: Vector read new Vector(min_x, min_y);
    property max: Vector read new Vector(max_x, max_y);
    
    
    static function from_minmax(min_x, min_y, max_x, max_y: real) := new BoundBox(min_x, min_y, max_x, max_y);
    static function from_minmax(min, max: real) := new BoundBox(min, min, max, max);
    static function from_minmax(min, max: Vector) := from_minmax(min.x, min.y, max.x, max.y);
    static function from_center(w, h: real) := new BoundBox(-w * 0.5, -h * 0.5, w * 0.5, h * 0.5);
    static function from_center(w, h: real; center: Vector): BoundBox := from_center(w, h).translate(center);
    
    
    static function from_xywh(x, y, w, h: real) := new BoundBox(x, y, x + w, y + h);
    static function empty() := new BoundBox(real.MaxValue, real.MaxValue, real.MinValue, real.MinValue);
    
    procedure extend(v: Vector);
    begin
      if v.x < min_x then min_x := v.x;
      if v.y < min_y then min_y := v.y;
      if v.x > max_x then max_x := v.x;
      if v.y > max_y then max_y := v.y;
    end;
    
    procedure extend(o: BoundBox);
    begin
      if o.min_x < min_x then min_x := o.min_x;
      if o.min_y < min_y then min_y := o.min_y;
      if o.max_x > max_x then max_x := o.max_x;
      if o.max_y > max_y then max_y := o.max_y;
    end;
    
    function expand(left, top, right, bottom: real) := new BoundBox(min_x - left, min_y - bottom, max_x + right, max_y + top);
    function expand(hor, ver: real) := expand(hor, ver, hor, ver);
    function expand(pad: real) := expand(pad, pad);
    
    
    function inflated(factor: real) := expand(width * factor * 0.5, height * factor * 0.5);
    
    function contains(inn: BoundBox) := (inn.min_x >= min_x) and (inn.max_x <= max_x) and (inn.min_y >= min_y) and (inn.max_y <= max_y);
    function contains(inn: BoundBox; max_ratio: real) := contains(inn) and (width <= inn.width * max_ratio) and (height <= inn.height * max_ratio);
    function contains(v: Vector) := (v.x >= min_x) and (v.x <= max_x) and (v.y >= min_y) and (v.y <= max_y);
    
    static function crop(a, b: BoundBox) := new BoundBox(
    pabcsystem.max(a.min_x, b.min_x), pabcsystem.max(a.min_y, b.min_y),
    pabcsystem.min(a.max_x, b.max_x), pabcsystem.min(a.max_y, b.max_y));
    
    function translate(v: Vector) := new BoundBox(min_x + v.x, min_y + v.y, max_x + v.x, max_y + v.y);
    
    function apply_transform(tr: Transform): BoundBox;
    begin
      var h := self.half_extents;
      var wide := tr.abs_apply_dir(h);
      var center := tr.apply(self.center);
      result := BoundBox.from_minmax(center - wide, center + wide);
    end;
    
    static function intersect(a, b: BoundBox) := (a.min_x <= b.max_x) and (a.max_x >= b.min_x) and (a.min_y <= b.max_y) and (a.max_y >= b.min_y);
    
    property center: Vector read new Vector((min_x + max_x) * 0.5, (min_y + max_y) * 0.5);
    property half_extents: Vector read new Vector((max_x - min_x) * 0.5, (max_y - min_y) * 0.5);
  end;
  
  
  Camera = class
  public
    tr: Transform;
    zoom: real;    
    property pos: vector read tr.pos write tr.pos := value;
    property ang: real read tr.ang write tr.ang := value;
    
    constructor create(tr: Transform; zoom: real := 1);
    begin
      self.tr := tr;
      self.zoom := zoom;
    end;
    
    constructor create(pos: Vector; zoom: real := 1; ang: real := 0) := create(new Transform(pos, ang), zoom);
    
    procedure lerp_pos(pos: Vector; t: real) := self.pos := Vector.Lerp(self.pos, pos, t);
    procedure lerp_zoom(zoom: real; t: real) := self.zoom := lerp(self.zoom, zoom, t);
    procedure moved(delta: Vector) := tr := tr.moved(delta);
    procedure rotated(delta: real) := tr := tr.rotated(delta);
  end;
  
  ViewportResizeMode = (
    /// Объекты сохраняют размер в пикселях, видимая область мирвого пространства меняется
    ViewportFixedZoom,
    /// Мировое пространство всегда вписано в экран, края не фиксированы
    ViewportFixedWorld,
    /// Фиксированная ширина мира, вертикаль заполняется всем доступным мировым пространством
    ViewportFixedWidth,
    /// Фиксированная высота мира, горизонталь заполняется всем доступным мировым пространством
    ViewportFixedHeight);
  
  Viewport = class
  private
    m_base_zoom: real;
  public
    cam: Camera;
    mode: ViewportResizeMode; 
    /// Эталонные размеры в метрах
    ref_w, ref_h: real;
    /// Область вывода на экране (в пикселях)
    screen: BoundBox;
    
    property base_zoom: real read m_base_zoom;
    property total_zoom: real read cam.zoom * base_zoom;
    
    constructor create(cam: Camera; ref_w, ref_h: real; screen: BoundBox; mode: ViewportResizeMode);
    begin
      self.cam := cam;
      (self.ref_w, self.ref_h) := (ref_w, ref_h);
      self.screen := screen;
      self.mode := mode;
      self.m_base_zoom := 1.0;
      resize(screen);
    end;
    
    
    constructor create(cam: Camera; ref_w, ref_h: real; screen_w, screen_h: real; mode: ViewportResizeMode) := create(cam, ref_w, ref_h, BoundBox.from_xywh(0, 0, screen_w, screen_h), mode);
    
    static function fixed_zoom(cam: Camera; screen_w, screen_h: real): Viewport :=
    new Viewport(cam, real.PositiveInfinity, real.PositiveInfinity, screen_w, screen_h, ViewportFixedZoom);
    
    static function fixed_height(cam: Camera; h_meters: real; screen_w, screen_h: real): Viewport :=
    new Viewport(cam, 0, h_meters, screen_w, screen_h, ViewportFixedHeight);
    
    static function fixed_world(cam: Camera; ref_w, ref_h: real; screen_w, screen_h: real): Viewport :=
    new Viewport(cam, ref_w, ref_h, screen_w, screen_h, ViewportFixedWorld);
    
    procedure enter_world_bbox(box: BoundBox; pad: real := 1);
    begin
      cam.pos := box.center;
      cam.zoom := Min(screen.width / box.width, screen.height / box.height) / (m_base_zoom * pad);
    end;
    
    function get_world_bbox() := BoundBox.from_center(screen.width / total_zoom, screen.height / total_zoom).apply_transform(cam.tr);
    
    procedure resize(screen: BoundBox);
    begin
      self.screen := screen;
      case Mode of
        ViewportFixedZoom:   m_base_zoom := 1.0;
        ViewportFixedHeight: m_base_zoom := screen.height / ref_h;
        ViewportFixedWidth:  m_base_zoom := screen.width / ref_w;
        ViewportFixedWorld:  m_base_zoom := Min(screen.width / ref_w, screen.height / ref_h);
      end;
    end;
    
    procedure resize(w, h: real) := resize(BoundBox.from_xywh(screen.x, screen.y, w, h));
    
    function to_screen(world: Vector): Vector;
    begin
      var local := cam.tr.unapply(world) * total_zoom;
      var sc := self.screen.center;
      result := new Vector(local.x + sc.x, -local.y + sc.y);
    end;
    
    function to_screen(world: real) := world * total_zoom;
    function to_world(screen: Vector): Vector;
    begin
      var sc := self.screen.center;
      var local := new Vector((screen.x - sc.x), sc.y - screen.y);
      result := cam.tr.apply(local / total_zoom);
    end;
    
    function to_world(world: real) := world / total_zoom;
  end;  
  
  Utils = static class 
  public
    static function mmod(a, b: integer): integer;
    begin
      result := a mod b;
      if (result < 0) then result += b;
    end;
    
    static function norm_ang(ang: real) := ang - 2 * pi * floor((ang + pi) / (2 * pi));
    static function normal(v1, v2: Vector) := (v2 - v1).Ortog().Norm();//TODO сделать частью Vector as static
    static function isfinite(self: real) := (self < real.PositiveInfinity) and (self > real.NegativeInfinity);
    static function get_addr(o: object) := System.Runtime.CompilerServices.RuntimeHelpers.GetHashCode(o);
    static function inv(v: real; dflt: real := 0) := (v > 1e-12) ? 1 / v : dflt;
    static function get_k_mass(total_inv_mass, inv_inertia_a, inv_inertia_b: real; r_a, r_b, dir: Vector): real;
    begin
      var k_matr := Matrix2.get_contact_kmatrix(total_inv_mass, inv_inertia_a, inv_inertia_b, r_a, r_b);
      result := k_matr.effective_mass(dir);
    end;
    //TODO replace by more fast impl
          {var kn := a.inv_mass + b.inv_mass + softness;
      kn += sqr(Vector.Cross(r_a, n)) * a.inv_inertia;
      kn += sqr(Vector.Cross(r_b, n)) * b.inv_inertia;
      result := (kn > 0) ? 1.0 / kn : 0;}
  end;
  
  IntervalSide = (LowerSide, Inside, UpperSide, FixedIntr);
  
  Interval = record
    min, max: real;
    constructor create(min, max: real);
    begin
      assert(min <= max);
      self.min := min;
      self.max := max;
    end;
    
    constructor create(v: real) := create(v, v);
    static function from_unsort(min, max: real) := (max > min) ? (new Interval(min, max)) : (new Interval(max, min));
    static function min_limit(v: real): Interval := new Interval(v, real.PositiveInfinity);
    static function max_limit(v: real): Interval := new Interval(real.NegativeInfinity, v);
    static function unbounded(): Interval := new Interval(real.NegativeInfinity, real.PositiveInfinity);
    
    function replace(min: real ?:= nil; max: real ?:= nil) := from_unsort(min.unwrap_or(self.min), max.unwrap_or(self.max));
    
    static function operator implicit(v: real): Interval := new Interval(v);
    static function operator explicit(v: real): Interval := new Interval(v);
    static function operator implicit(v: integer): Interval := new Interval(v);
    static function operator explicit(v: integer): Interval := new Interval(v);
    
    function size() := max - min;
    function has(v: real) := (v >= min) and (v <= max);
    function is_fixed() := min = max;
    function get_offset(v: real): real;
    begin
      if v < min then result := v - min
      else if v > max then result := v - max
      else result := 0;
    end;
    
    function get_side(v: real): IntervalSide;
    begin
      if is_fixed() then exit(IntervalSide.FixedIntr);
      if v < min then exit(IntervalSide.LowerSide);
      if v > max then exit(IntervalSide.UpperSide);
      exit(IntervalSide.Inside);
    end;
  end;
  
  TimeTicker = class
  private
    m_progress: real;
    m_freq: real;
    m_max_count: integer;
    m_max_dt: real;
    m_period: real;
    m_total_ticks: int64;
  public
    property freq: real read m_freq write begin assert(value > 0); m_freq := value; m_period := 1.0 / value; end;
    property period: real read m_period;
    property max_count: integer read m_max_count write begin assert((value = -1) or (value > 0));  m_max_count := value; end;
    property max_dt: real read m_max_dt write begin assert(value >= 0); m_max_dt := value;  end;
    property progress: real read m_progress;
    property total_ticks: int64 read m_total_ticks;
    
    constructor create(freq: real; max_count: integer := -1; max_dt: real := real.PositiveInfinity);
    begin
      self.m_progress := 0;
      self.freq := freq;
      self.max_count := max_count;
      self.max_dt := max_dt;
      self.m_total_ticks := 0;
    end;
    
    function update(dt: real): integer;
    begin
      if dt <= 0 then exit(0);
      if dt > max_dt then dt := max_dt;
      var prog := m_progress + freq * dt;
      var count := trunc(prog);
      if (m_max_count <> -1) and (count > m_max_count) then
        (count, prog) := (m_max_count, 0)
      else
        prog -= count;
      m_progress := prog;
      m_total_ticks += count;
      result := count;
    end;
    
    procedure reset();
    begin
      m_progress := 0;
      m_total_ticks := 0;
    end;
  end;
  
  FpsCounter = class
  public
    const weight: real = 0.85;
    static function smooth_fps(fps, dt_secs: real): real;
    begin
      if dt_secs <= 1e-9 then 
      begin
        result := real.PositiveInfinity;
        exit;
      end;
      var shaky_fps := 1.0 / dt_secs;
      result := utils.isfinite(fps) ? (weight * fps + (1 - weight) * shaky_fps) : shaky_fps;
    end;
    
    static procedure start_new() := (new FpsCounter()).start();
  private
    _fps: real;
    _sw: System.Diagnostics.Stopwatch := new System.Diagnostics.Stopwatch();
    
    function _get_fps(): real;
    begin
      if _sw.IsRunning then raise new System.InvalidOperationException('Timer is running');
      result := _fps;
    end;
  
  public
    procedure update(dt_secs: real);
    begin
      _fps := smooth_fps(_fps, dt_secs);
    end;
    
    procedure start() := _sw.Restart();
    function stop(): real;
    begin
      _sw.Stop();
      update(_sw.ElapsedMilliseconds / 1000);
      result := _fps;
    end;
    
    function ToString(): string; override := $'FPS: {_fps:f0}';
    property fps: real read _get_fps;
  end;
  
  Material = record
    friction: real;
    restitution: real;
    density: real;
    
    constructor create(fric, rest, density: real);
    begin
      self.friction := fric;
      self.restitution := rest;
      self.density := density;
    end;
    
    static function from_frd(fric, rest, density: real): Material := new Material(fric, rest, density);
    
    function replace(fric: real ?:= nil; rest: real ?:= nil; density: real ?:= nil) := new Material(
    fric.unwrap_or(self.friction), 
    rest.unwrap_or(self.restitution), 
    density.unwrap_or(self.density));
    
    function get_mass(area: real) := density * area;
    
    static function mix_fric(f1, f2: real) := sqrt(f1 * f2);
    static function mix_rest(r1, r2: real) := sqrt(r1 * r2); //vs max vs min;
    static function mix_fric(m1, m2: Material) := mix_fric(m1.friction, m2.friction);
    static function mix_rest(m1, m2: Material) := mix_rest(m1.restitution, m2.restitution);
  end;
  
  Materials = static class
  public
    static Wood := Material.from_frd(0.5, 0.3, 0.6);
    static Steel := Material.from_frd(0.2, 0.1, 7.8);
    static Rubber := Material.from_frd(0.8, 0.9, 1.1);
    static Clay := Material.from_frd(0.9, 0.0, 1.8);
    static Ice := Material.from_frd(0.02, 0.05, 0.9);
    static Stone := Material.from_frd(0.6, 0.2, 2.5);
    static DefaultMat: Material := Wood;
  end;
  
  Damping = record
    linear: real;
    angular: real;
    enabled: boolean;
    constructor create(linear: real; angular: real; en: boolean := true);
    begin
      self.linear := linear;
      self.angular := angular;
      self.enabled := en;
    end;
    
    constructor create() := create(0, 0, false);
    procedure run(linear: real ?:= nil; angular: real ?:= nil; en: boolean ?:= true);
    begin
      self.linear := linear.unwrap_or(self.linear);
      self.angular := angular.unwrap_or(self.angular);
      self.enabled := en.unwrap_or(self.enabled);
    end;
    
    public static DefaultDamp := new Damping(0, 0, false);
  end;
  
  ComplianceMode = (ComplianceHard, ComplianceSoftSpring, ComplianceSoftCustom);
  
  ComplianceSpec = record
  public
    //Provides maximum stiffness with guaranteed numerical stability for the solver
    const default_softness: real = 0.001;
    const default_baumgarte: real = 0.1;
    //Some values so that everything behaves well when switching first to spring mode
    const default_freq: real = 15.0;
    const default_damping: real = 0.7;
    
    static procedure recalc_spring(freq, damping, dt: real; var softness, baumgarte: real);
    begin
      var omega := 2.0 * PI * freq;
      var k := omega * omega;
      var d := 2.0 * damping * omega;
      var denom := d + dt * k;
      if denom > 1e-12 then
      begin
        softness := 1.0 / (dt * denom);
        baumgarte := (dt * k) / denom
      end else
      begin
        //assert(false);
        softness := default_softness;
        baumgarte := default_baumgarte;
      end;
    end;
  
  private
    m_mode: ComplianceMode;
    m_last_dt: real;    
    m_freq, m_damping: real;
    m_softness, m_baumgarte: real;    
    m_actual_softness, m_actual_baumgarte: real;
    
    procedure set_mode(v: ComplianceMode; force: boolean := false);
    begin
      if (not force) and (m_mode = v) then exit;
      m_mode := v;
      m_last_dt := real.NaN;
    end;
  
  public
    property mode: ComplianceMode read m_mode write set_mode(value);
    property is_soft: boolean read m_mode <> ComplianceMode.ComplianceHard;
    property softness: real read m_softness;
    property baumgarte: real read m_baumgarte;
    property freq: real read m_freq;
    property damping: real read m_damping;
    property actual_softness: real read m_actual_softness;
    property actual_baumgarte: real read m_actual_baumgarte;
    
    constructor create(softness: real := default_softness; baumgarte: real := default_baumgarte);
    begin
      set_custom(
        softness := softness, baumgarte := baumgarte, 
        freq := default_freq, damping := default_damping, 
        mode := ComplianceMode.ComplianceHard);
    end;
    
    static function hard(softness: real := default_softness; baumgarte: real := default_baumgarte): ComplianceSpec;
    begin
      result := new ComplianceSpec();
      result.set_hard(softness, baumgarte);
    end;
    
    static function soft(freq: real; damping: real): ComplianceSpec;
    begin
      result := new ComplianceSpec();
      result.set_soft(freq, damping);
    end;
    
    procedure set_custom(
      softness: real ?:= nil; baumgarte: real ?:= nil; 
      freq: real ?:= nil; damping: real ? := nil;
      mode: ComplianceMode ?:= nil);
    begin
      m_softness := softness.unwrap_or(m_softness);
      m_baumgarte := baumgarte.unwrap_or(m_baumgarte);
      m_freq := freq.unwrap_or(m_freq);
      m_damping := damping.unwrap_or(m_damping); 
      
      if mode <> nil then set_mode(mode.Value, true);
      if m_mode <> ComplianceMode.ComplianceSoftSpring then 
      begin
        m_actual_softness := m_softness;
        m_actual_baumgarte := m_baumgarte;
      end;
    end;
    
    procedure set_hard(softness: real ?:= nil; baumgarte: real ? := nil) :=
    set_custom(softness := softness, baumgarte := baumgarte, mode := ComplianceMode.ComplianceHard);
    
    procedure set_soft_custom(softness: real ?:= nil; baumgarte: real ? := nil) :=
    set_custom(softness := softness, baumgarte := baumgarte, mode := ComplianceMode.ComplianceSoftCustom);
    
    procedure set_soft(freq: real ?:= nil; damping: real ? := nil);
    begin
      if (freq.unwrap_or(self.freq) <> self.freq) or (damping.unwrap_or(self.damping) <> self.damping) or (self.mode <> ComplianceMode.ComplianceSoftSpring) then
        set_custom(freq := freq, damping := damping, mode := ComplianceMode.ComplianceSoftSpring)
    end;
    
    procedure recalc(dt: real);
    begin
      if m_last_dt = dt then exit;
      if m_mode = ComplianceMode.ComplianceSoftSpring then
      begin
        recalc_spring(m_freq, m_damping, dt, m_actual_softness, m_actual_baumgarte);
      end else
      begin
        m_actual_softness := m_softness;
        m_actual_baumgarte := m_baumgarte
      end;
      m_last_dt := dt;
    end;
  end;


function bl_vect(vx, vy: real) := new Vector(vx, vy);

function bl_trans(pos: Vector; ang: real := 0.0) := new Transform(pos, ang);

function bl_trans(x, y: real; ang: real := 0.0) := new Transform(bl_vect(x, y), ang);

function bl_intr(min, max: real) := new Interval(min, max);

function bl_intr(v: real) := new Interval(v);

const
  bl_vect0 = new Vector(0, 0);
  bl_matr2id = new Matrix2(1, 0, 0, 1);
  bl_trans0 = new Transform(bl_vect(0, 0), 0);
  bl_intr0 = new Interval(0, 0);


begin

end. 