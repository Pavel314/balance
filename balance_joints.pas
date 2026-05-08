unit balance_joints;

uses balance_basic, balance_core;

type
  LineAnchor = record
    local_a, local_b: Vector;
    local_axis: Vector;
    
    static function local(a, b, axis: Vector): LineAnchor;
    begin
      result := new LineAnchor();
      result.local_a := a;
      result.local_b := b;
      result.local_axis := axis;
    end;
    
    static function world(tr_a, tr_b: Transform; world_anchor, world_axis: Vector) :=
    local(tr_a.unapply(world_anchor), tr_b.unapply(world_anchor), tr_a.unapply_dir(world_axis).Norm());
    
    function replace(local_a: Vector ?:= nil; local_b: Vector ? := nil; local_axis: Vector ?:= nil) :=
    LineAnchor.local(
    local_a.unwrap_or(self.local_a), local_b.unwrap_or(self.local_b),
    local_axis.unwrap_or(self.local_axis));
    
    function rotated90() := LineAnchor.local(local_a, local_b, local_axis.Unortog());
    
    function world_a(tr_a: Transform) := tr_a.apply(local_a);
    function world_b(tr_b: Transform) := tr_b.apply(local_b);
    function world_axis(tr_a: Transform) := tr_a.apply_dir(local_axis);
  end;
  
  PointAnchor = record
    local_a, local_b: Vector;
    static function local(a, b: Vector): PointAnchor;
    begin
      result := new PointAnchor();
      result.local_a := a;
      result.local_b := b;
    end;
    
    static function world(tr_a, tr_b: Transform; world_anchor: Vector) :=
    local(tr_a.unapply(world_anchor), tr_b.unapply(world_anchor));
    
    function replace(local_a: Vector ?:= nil; local_b: Vector ? := nil) :=
    PointAnchor.local(local_a.unwrap_or(self.local_a), local_b.unwrap_or(self.local_b));
    
    function world_a(tr_a: Transform) := tr_a.apply(local_a);
    function world_b(tr_b: Transform) := tr_b.apply(local_b);
    function world_center(tr_a, tr_b: Transform) := (world_a(tr_a) + world_b(tr_b)) * 0.5;
  end;
  
  DistanceAnchor = record
    local_a, local_b: Vector;
    static function local(a, b: Vector): DistanceAnchor;
    begin
      result := new DistanceAnchor();
      result.local_a := a;
      result.local_b := b;
    end;
    
    static function world(tr_a, tr_b: Transform; world_a, world_b: Vector) := local(tr_a.unapply(world_a), tr_b.unapply(world_b));
    
    function replace(local_a: Vector ?:= nil; local_b: Vector ? := nil) :=
    DistanceAnchor.local(local_a.unwrap_or(self.local_a), local_b.unwrap_or(self.local_b));
    
    function world_a(tr_a: Transform) := tr_a.apply(local_a);
    function world_b(tr_b: Transform) := tr_b.apply(local_b);
  
  end;
  
  
  AngleMotor = class(MotorConstraint)
  private
    acc_imp: real;
    max_torque_dt: real;
    k_mass: real;
  public
    speed: real; 
    max_torque: real;
    
    constructor create(speed: real; max_torque: real; en: boolean := true);
    begin
      inherited create(en);
      self.speed := speed;
      self.max_torque := max_torque;
    end;
    
    procedure run(speed: real ?:= nil; max_torque: real ?:= nil; en: boolean ?:= true);
    begin
      self.speed := speed.unwrap_or(self.speed);
      self.max_torque := max_torque.unwrap_or(self.max_torque);
      self.enabled := en.unwrap_or(self.enabled);
    end;
    
    procedure reset(); override;
    begin
      acc_imp := 0;
    end;
    
    procedure recalc(dt: real; a, b: RigidBody); override;
    begin
      if not enabled then begin reset(); exit; end;
      max_torque_dt := max_torque * dt;
      k_mass := PairUtils.get_k_mass_ang(a, b, 0);
    end;
    
    procedure warm_start(a, b: RigidBody); override;
    begin
      if not enabled then exit;
      PairUtils.add_torque_impulse(a, b, acc_imp); 
    end;
    
    procedure solve(a, b: RigidBody); override;
    begin
      if not enabled then exit;      
      var rv := PairUtils.get_rel_vel_ang(a, b);
      var imp := (rv - speed) * -k_mass;
      var delta := PairUtils.solve_impulse(acc_imp, imp, max_torque_dt);
      PairUtils.add_torque_impulse(a, b, delta);
    end;    
  end;
  
  LineMotor = class(MotorConstraint)
  private
    acc_imp: real;
    max_force_dt: real;
    world_axis: Vector;
    r_a, r_b: Vector;
    k_mass: real;
  public
    anchor: LineAnchor;
    speed: real; 
    max_force: real; 
    
    constructor create(anchor: LineAnchor; speed: real; max_force: real; en: boolean := true);
    begin
      inherited create(en);
      self.anchor := anchor;
      self.speed := speed;
      self.max_force := max_force;
    end;
    
    procedure run(speed: real ?:= nil; max_force: real ?:= nil; anchor: LineAnchor ? := nil; en: boolean ?:= true);
    begin
      self.speed := speed.unwrap_or(self.speed);
      self.max_force := max_force.unwrap_or(self.max_force);
      self.anchor := anchor.unwrap_or(self.anchor);
      self.enabled := en.unwrap_or(self.enabled);
    end;
    
    procedure reset(); override;
    begin
      acc_imp := 0;
    end;
    
    procedure recalc(dt: real; a, b: RigidBody); override;
    begin
      if not enabled then begin reset(); exit; end;
      max_force_dt := max_force * dt;
      world_axis := a.tr.apply_dir(anchor.local_axis);
      PairUtils.get_world_anchors_r(a, b, anchor.local_a, anchor.local_b, r_a, r_b);
      k_mass := PairUtils.get_k_mass(a, b, r_a, r_b, world_axis, 0);
    end;
    
    procedure warm_start(a, b: RigidBody); override;
    begin
      if not enabled then exit;
      PairUtils.add_impulse_r(a, b, r_a, r_b, world_axis * acc_imp);
    end;
    
    procedure solve(a, b: RigidBody); override;
    begin
      if not enabled then exit;
      var rv := PairUtils.get_rel_vel_r(a, b, r_a, r_b) * world_axis;
      var imp := (rv - speed) * -k_mass;
      var delta := PairUtils.solve_impulse(acc_imp, imp, max_force_dt);
      PairUtils.add_impulse_r(a, b, r_a, r_b, delta * world_axis);
    end;
  end;
  
  
  
  
  AngleConstraint = class(GeomConstraint)
  private
    k_mass: real;
    bias: real;
    acc_imp: real;
    active_side: IntervalSide;
  public
    limit: Interval;
    
    constructor create(limit: Interval; en: boolean := true);
    begin
      inherited create(en);
      self.limit := limit;
    end;
    
    procedure run(min: real ?:= nil; max: real ? := nil; en: boolean ? := true);
    begin
      self.limit := self.limit.replace(min, max);
      self.enabled := en.unwrap_or(self.enabled);
    end;
    
    procedure reset(); override;
    begin
      acc_imp := 0;
    end;
    
    procedure recalc(dt: real; a, b: RigidBody); override;
    begin
      if not enabled then exit;
      var ang := Utils.norm_ang(b.ang - a.ang);      
      active_side := limit.get_side(ang);
      if (active_side <> IntervalSide.Inside) then
      begin
        k_mass := PairUtils.get_k_mass_ang(a, b, compliance.actual_softness);
        var err := Utils.norm_ang(limit.get_offset(ang));
        bias := PairUtils.get_bias(err, compliance.actual_baumgarte, dt);
      end else
        reset()
    end;
    
    procedure warm_start(a, b: RigidBody); override;
    begin
      if not enabled then exit;
      if active_side = IntervalSide.Inside then exit;
      PairUtils.add_torque_impulse(a, b, acc_imp);
    end;
    
    procedure solve(a, b: RigidBody); override;
    begin
      if not enabled then exit;
      if active_side = IntervalSide.Inside then exit;
      
      var soft_bias := compliance.is_soft ? bias : 0;
      begin
        var rv := PairUtils.get_rel_vel_ang(a, b);
        var imp := -k_mass * (rv + soft_bias + compliance.actual_softness * acc_imp);
        var delta := PairUtils.solve_impulse(acc_imp, imp, active_side);
        PairUtils.add_torque_impulse(a, b, delta);
      end;
      if not compliance.is_soft then
      begin
        var rv := PairUtils.get_rel_vel_ang(a, b, ps := true);
        var imp := -k_mass * (rv + bias);
        PairUtils.add_torque_impulse(a, b, imp, ps := true);
      end;
    end;
  end;
  
  
  
  PointConstraint = class(GeomConstraint)
  private
    k_matrix: Matrix2;
    acc_imp: Vector;
    bias: Vector;
    r_a, r_b: Vector;
  public
    anchor: PointAnchor;
    
    constructor create(anchor: PointAnchor; en: boolean := true);
    begin
      inherited create(en);
      self.anchor := anchor;
    end;
    
    procedure run(anchor: PointAnchor ?:= nil; en: boolean ? := true);
    begin
      self.anchor := anchor.unwrap_or(self.anchor);
      self.enabled := en.unwrap_or(self.enabled);
    end;
    
    procedure reset(); override;
    begin
      acc_imp := bl_vect0;
    end;
    
    procedure recalc(dt: real; a, b: RigidBody); override;
    begin
      if not enabled then exit;
      inherited recalc(dt, a, b);
      PairUtils.get_world_anchors_r(a, b, anchor.local_a, anchor.local_b, r_a, r_b);
      k_matrix := PairUtils.get_k_matr(a, b, r_a, r_b, compliance.actual_softness).invert();
      var sep := (b.pos + r_b) - (a.pos + r_a);
      bias := sep * (compliance.actual_baumgarte / dt); //TODO PairUtils.get_bias(sep, baumgarte , dt);
    end;
    
    procedure warm_start(a, b: RigidBody); override;
    begin
      if not enabled then exit;
      PairUtils.add_impulse_r(a, b, r_a, r_b, acc_imp); 
    end;
    
    procedure solve(a, b: RigidBody); override;
    begin
      if not enabled then exit;
      var soft_bias := compliance.is_soft ? bias : bl_vect0;
      begin
        var rv := PairUtils.get_rel_vel_r(a, b, r_a, r_b);   
        var imp := k_matrix * -(rv + soft_bias + acc_imp * compliance.actual_softness); 
        acc_imp += imp;
        PairUtils.add_impulse_r(a, b, r_a, r_b, imp);
      end;
      if not compliance.is_soft then
      begin
        var rv := PairUtils.get_rel_vel_r(a, b, r_a, r_b, ps := true);
        var imp := k_matrix * -(rv + bias);
        PairUtils.add_impulse_r(a, b, r_a, r_b, imp, ps := true);
      end;
    end;
  end;
  
  DistanceConstraint = class(GeomConstraint)
  private
    r_a, r_b: Vector; 
    n: Vector;       
    k_mass: real;
    bias: real;
    acc_imp: real;
    active_side: IntervalSide;
  public
    limit: Interval;
    anchor: DistanceAnchor;
    
    constructor create(limit: Interval; anchor: DistanceAnchor; en: boolean := true);
    begin
      inherited create(en);
      self.anchor := anchor;
      self.limit := limit;
    end;
    
    constructor create(limit: Interval; local_a, local_b: Vector) := create(limit, DistanceAnchor.local(local_a, local_b));
    
    procedure run(min: real ?:= nil; max: real ?:= nil; anchor: DistanceAnchor ?:= nil; en: boolean ?:= true);
    begin
      self.limit := self.limit.replace(min, max);
      self.anchor := anchor.unwrap_or(self.anchor);
      self.enabled := en.unwrap_or(self.enabled);
    end;
    
    procedure reset(); override;
    begin
      acc_imp := 0;
    end;
    
    procedure recalc(dt: real; a, b: RigidBody); override;
    begin
      if not enabled then exit;
      inherited recalc(dt, a, b);
      PairUtils.get_world_anchors_r(a, b, anchor.local_a, anchor.local_b, r_a, r_b);
      var delta := (b.pos + r_b) - (a.pos + r_a);
      var dist := delta.Length();
      active_side := limit.get_side(dist);
      if (active_side <> IntervalSide.Inside) then
      begin
        n := (dist > 1e-12) ? delta / dist : bl_vect0;
        k_mass := PairUtils.get_k_mass(a, b, r_a, r_b, n, compliance.actual_softness); 
        var err := limit.get_offset(dist);
        bias := PairUtils.get_bias(err, compliance.actual_baumgarte, dt);
      end else
        reset();
    end;
    
    procedure warm_start(a, b: RigidBody); override;
    begin
      if (not enabled) or (active_side = IntervalSide.Inside) then exit;
      PairUtils.add_impulse_r(a, b, r_a, r_b, n * acc_imp);
    end;
    
    procedure solve(a, b: RigidBody); override;
    begin
      if (not enabled) or (active_side = IntervalSide.Inside) then exit;
      PairUtils.solve_1d(a, b, r_a, r_b, n, acc_imp, k_mass, compliance.actual_softness, bias, active_side, compliance.is_soft);
    end;
  end;
  
  LineConstraint = class(GeomConstraint)
  private
    r_a, r_b: Vector; 
    n: Vector;       
    k_mass: real;
    bias: real;
    acc_imp: real;
    active_side: IntervalSide;
  public
    limit: Interval;
    anchor: LineAnchor;
    
    constructor create(limit: Interval; anchor: LineAnchor; en: boolean := true);
    begin
      inherited create(en);
      self.anchor := anchor;
      self.limit := limit;
    end;
    
    constructor create(limit: Interval; local_a, local_b, local_axis: Vector) := 
    create(limit, LineAnchor.local(local_a, local_b, local_axis));
    
    procedure run(min: real ?:= nil; max: real ?:= nil; anchor: LineAnchor ? := nil; en: boolean ? := true);
    begin
      self.limit := self.limit.replace(min, max);
      self.anchor := anchor.unwrap_or(self.anchor);
      self.enabled := en.unwrap_or(self.enabled);
    end;
    
    procedure reset(); override;
    begin
      acc_imp := 0;
    end;
    
    procedure recalc(dt: real; a, b: RigidBody); override;
    begin
      if not enabled then exit;
      inherited recalc(dt, a, b);
      PairUtils.get_world_anchors_r(a, b, anchor.local_a, anchor.local_b, r_a, r_b);
      n := a.tr.apply_dir(anchor.local_axis);
      var delta := (b.tr.pos + r_b) - (a.tr.pos + r_a);
      var dist := delta * n;
      active_side := limit.get_side(dist);      
      if (active_side <> IntervalSide.Inside) then
      begin
        k_mass := PairUtils.get_k_mass(a, b, r_a, r_b, n, compliance.actual_softness); 
        var err := limit.get_offset(dist);
        bias := PairUtils.get_bias(err, compliance.actual_baumgarte, dt);
      end else
        reset();
    end;
    
    procedure warm_start(a, b: RigidBody); override;
    begin
      if (not enabled) or (active_side = IntervalSide.Inside) then exit;
      PairUtils.add_impulse_r(a, b, r_a, r_b, n * acc_imp);
    end;
    
    procedure solve(a, b: RigidBody); override;
    begin
      if (not enabled) or (active_side = IntervalSide.Inside) then exit;
      PairUtils.solve_1d(a, b, r_a, r_b, n, acc_imp, k_mass, compliance.actual_softness, bias, active_side, compliance.is_soft);
    end;
  end;
  
  
  
  GenericJoint = class(Joint)
  public
    property constraints: List<BaseConstraint> read get_core_constraints;
    constructor create(body_a, body_b: RigidBody; constraints: IEnumerable<BaseConstraint> := nil) := inherited create(body_a, body_b, constraints);
    constructor create(j: Joint) := create(j.body_a, j.body_b, j.core_constraints);
  
  end;
  
  DistanceJoint = class(Joint)
  private
    m_distance: DistanceConstraint;
  public
    constructor create(a, b: RigidBody; anchor: DistanceAnchor);
    begin
      inherited create(a, b);
      var dist := (anchor.world_b(b.tr) - anchor.world_a(a.tr)).length();
      m_distance := new DistanceConstraint(dist, anchor);
      core_constraints.Add(m_distance);
    end;
    
    static function world(a, b: RigidBody; world_anchor_a, world_anchor_b: Vector) := new DistanceJoint(a, b, DistanceAnchor.world(a.tr, b.tr, world_anchor_a, world_anchor_b));
    
    function with_lin_limit(v: real): DistanceJoint;
    begin
      m_distance.run(v, v);
      result := self;     
    end;
    
    function with_lin_limit(min: real?; max: real?): DistanceJoint;
    begin
      m_distance.run(min, max);
      result := self;
    end;
    
    function with_soft(freq, damping: real): DistanceJoint;
    begin
      m_distance.compliance := ComplianceSpec.soft(freq, damping);
      result := self;
    end;
    
    function with_hard(): DistanceJoint;
    begin
      m_distance.compliance := ComplianceSpec.hard();
      result := self;
    end;
    
    property anchor: DistanceAnchor read m_distance.anchor write m_distance.anchor := value;
    property distance: DistanceConstraint read m_distance;
  end;
  
  RevoluteJoint = class(Joint)
  private
    m_ang_motor: AngleMotor;
    m_ang_const: AngleConstraint;
    m_hard_const: AngleConstraint; 
    m_pnt_const: PointConstraint;
  public
    constructor create(a, b: RigidBody; anchor: PointAnchor);
    begin
      inherited create(a, b);
      var ang := b.ang - a.ang;
      m_ang_motor := new AngleMotor(0, 0, false);
      m_ang_const := new AngleConstraint(ang, false);
      m_hard_const := new AngleConstraint(ang, false);
      m_pnt_const := new PointConstraint(anchor);
      core_constraints.Add(m_ang_motor);
      core_constraints.Add(m_ang_const);
      core_constraints.Add(m_hard_const);
      core_constraints.Add(m_pnt_const);
    end;
    
    static function world(a, b: RigidBody; world_anchor: Vector) := new RevoluteJoint(a, b, PointAnchor.world(a.tr, b.tr, world_anchor));
    
    function with_ang_motor(speed, max_torque: real): RevoluteJoint;
    begin
      m_ang_motor.run(speed, max_torque);
      result := self;
    end;
    
    //TODO Refactor into two overloads (see DistanceJoint for more details)
    function with_ang_limit(min: real  ?:= nil; max: real ?:= nil): RevoluteJoint;
    begin
      m_ang_const.run(min, max <> nil ? max : min);
      Result := self;
    end;
    
    function with_ang_spring(freq, damping: real; ang: real; lim: Interval ?:= nil): RevoluteJoint;
    begin
      m_ang_const.compliance := ComplianceSpec.soft(freq, damping);
      m_ang_const.run(ang, ang);      
      if lim <> nil then
      begin
        assert(lim.Value.has(ang));
        m_hard_const.compliance := ComplianceSpec.hard();
        m_hard_const.run(lim.Value.min, lim.Value.max, en := true);
      end
      else
        m_hard_const.run(en := false);
      Result := self;
    end;
    
    property anchor: PointAnchor read m_pnt_const.anchor write m_pnt_const.anchor := value;
    property ang_motor: AngleMotor read m_ang_motor;
    property ang_const: AngleConstraint read m_ang_const;
    property hard_const: AngleConstraint read m_hard_const;
    property pnt_const: PointConstraint read m_pnt_const;
  end;
  
  LineJoint = class(Joint)
  private
    m_lin_motor: LineMotor;  
    m_ang_motor: AngleMotor; 
    m_lin_const: LineConstraint;
    m_side_const: LineConstraint;
    m_ang_const: AngleConstraint;
    m_hard_const: LineConstraint;
  public
    constructor create(a, b: RigidBody; anchor: LineAnchor);
    begin
      inherited create(a, b);
      m_lin_motor := new LineMotor(anchor, 0, 0, false);
      m_ang_motor := new AngleMotor(0, 0, false);
      m_lin_const := new LineConstraint(bl_intr(0, 0), anchor, false);
      m_side_const := new LineConstraint(bl_intr(0, 0), anchor.rotated90(), true);
      m_ang_const := new AngleConstraint(b.ang - a.ang, false);
      m_hard_const := new LineConstraint(bl_intr(0, 0), anchor, false);
      core_constraints.Add(m_lin_motor);
      core_constraints.Add(m_ang_motor);
      core_constraints.Add(m_lin_const);
      core_constraints.Add(m_side_const);
      core_constraints.Add(m_ang_const);
      core_constraints.Add(m_hard_const);
    end;
    
    static function world(a, b: RigidBody; world_anchor, world_axis: Vector) := new LineJoint(a, b, LineAnchor.world(a.tr, b.tr, world_anchor, world_axis));
    
    function with_lin_motor(speed, max_force: real): LineJoint;
    begin
      m_lin_motor.run(speed, max_force);
      Result := self;
    end;
    
    function with_ang_motor(speed, max_torque: real): LineJoint;
    begin
      m_ang_motor.run(speed, max_torque);
      Result := self;
    end;
    
    //TODO Refactor into two overloads (see DistanceJoint for more details)
    function with_lin_limit(min: real; max: real ? := nil): LineJoint;
    begin
      m_lin_const.run(min, max <> nil ? max : min);
      Result := self;
    end;
    
    function with_lin_spring(freq, damping: real; val: real; lim: Interval ?:= nil): LineJoint;
    begin
      m_lin_const.compliance.set_soft(freq, damping); 
      m_lin_const.run(val, val);
      if lim <> nil then
      begin
        assert(lim.Value.has(val));
        m_hard_const.compliance.set_hard();
        //m_hard_const.compliance := ComplianceSpec.hard();
        m_hard_const.run(lim.Value.min, lim.Value.max, en := true)
      end
      else
        m_hard_const.run(en := false);
      Result := self;
    end;
    
    //TODO Refactor into two overloads (see DistanceJoint for more details)
    function with_ang_limit(min: real ? := nil; max: real ? := nil): LineJoint;
    begin
      m_ang_const.run(min, max <> nil ? max : min);
      Result := self;
    end;
    
    property anchor: LineAnchor read m_lin_const.anchor write 
      begin
        m_lin_motor.anchor := value;
        m_lin_const.anchor := value;
        m_hard_const.anchor := value;
        m_side_const.anchor := value.rotated90();
      end;
    
    property lin_motor: LineMotor read m_lin_motor;
    property ang_motor: AngleMotor read m_ang_motor;
    property lin_const: LineConstraint read m_lin_const;
    property side_const: LineConstraint read m_side_const;
    property ang_const: AngleConstraint read m_ang_const;
    property hard_const: LineConstraint read m_hard_const;
  end;
  
  Joints = static class
  public
    // All variants basic of DistanceJoint[
    static function Distance(a, b: RigidBody; world_anchor_a, world_anchor_b: Vector) := 
    DistanceJoint.world(a, b, world_anchor_a, world_anchor_b);
    
    /// Стержень: жесткая связь, удерживающая фиксированную дистанцию
    static function Rod(a, b: RigidBody; world_anchor_a, world_anchor_b: Vector) :=
    DistanceJoint.world(a, b, world_anchor_a, world_anchor_b);
    
    /// Веревка: ограничивает максимальное расстояние, но позволяет сближаться
    static function Rope(a, b: RigidBody; world_anchor_a, world_anchor_b: Vector; min: real := 0.0; max: real ? := nil) := 
    DistanceJoint.world(a, b, world_anchor_a, world_anchor_b).with_lin_limit(min, max);  
    
    static function Spring(a, b: RigidBody; world_a, world_b: Vector; freq, damping: real) := 
    DistanceJoint.world(a, b, world_a, world_b).with_soft(freq, damping);
    //]
    
    // All variants basic of RevoluteJoint[
    /// Шарнир: тела вращаются вокруг общей точки
    static function Revolute(a, b: RigidBody; world_anchor: Vector) := 
    RevoluteJoint.world(a, b, world_anchor); 
    
    /// Сварка: тела намертво склеены в точке (точка + угол)
    static function Weld(a, b: RigidBody; world_anchor: Vector; ang: real ?:= nil) := 
    RevoluteJoint.world(a, b, world_anchor).with_ang_limit(ang);
    
    /// Угловая пружина: удерживает тела под определенным углом (торсион)
    static function AngSpring(a, b: RigidBody; world_anchor: Vector; freq, damping: real; ang: real ?:= nil) := 
    RevoluteJoint.world(a, b, world_anchor).with_ang_spring(freq, damping, ang.unwrap_or(b.ang - a.ang));
    
    /// Петля: шарнир с ограниченным углом вращения
    static function Hinge(a, b: RigidBody; world_anchor: Vector; min, max: real) := 
    RevoluteJoint.world(a, b, world_anchor).with_ang_limit(min, max);
    
    /// Угловой поглотитель: мягкий шарнир с пружиной и жесткими стопорами
    static function AngAbsorber(a, b: RigidBody; world_anchor: Vector; freq, damping, min, max: real; target: real ?:= nil) := 
    RevoluteJoint.world(a, b, world_anchor)
      .with_ang_spring(freq, damping, target.unwrap_or((min + max) * 0.5), bl_intr(min, max));
    //]
    
    // All variants basic of LineJoint[
    /// Универсальное осевое соединение для кастомной настройки
    static function Line(a, b: RigidBody; world_anchor, world_axis: Vector) := 
    LineJoint.world(a, b, world_anchor, world_axis);
    
    /// Слайдер: неограниченное движение по оси без вращения
    static function Slider(a, b: RigidBody; world_anchor, world_axis: Vector; ang: real ?:= nil) := 
    LineJoint.world(a, b, world_anchor, world_axis).with_ang_limit(ang);
    
    /// Поршень: осевое движение с лимитами и мотором
    static function Piston(a, b: RigidBody; world_anchor, world_axis: Vector; min, max: real; ang: real ?:= nil) := 
    LineJoint.world(a, b, world_anchor, world_axis).with_lin_limit(min, max).with_ang_limit(ang);
    
    /// Амортизатор: мягкое осевое соединение с пружиной и жесткими стопорами по краям
    static function Absorber(a, b: RigidBody; world_anchor, world_axis: Vector; freq, damping, min, max: real; target: real ?:= nil) := 
    LineJoint.world(a, b, world_anchor, world_axis).with_lin_spring(freq, damping, target.unwrap_or((min + max) * 0.5), bl_intr(min, max)); 
    
    /// SliderSpring: осевая пружина без лимитов (бесконечная мягкая рельса)
    static function SliderSpring(a, b: RigidBody; world_anchor, world_axis: Vector; freq, damping: real; target: real := 0.0) := 
    LineJoint.world(a, b, world_anchor, world_axis).with_lin_spring(freq, damping, target).with_ang_limit();
    //]
  end;

begin

end. 