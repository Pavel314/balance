unit balance_core;
//TODO kinematic body
//TODO[DONE] collision group(rigidbody property
//TODO[DONE] BoundBox у окружности масштабировать не надоS
//TODO[Cancelled, unable to clear window] BeginFrameBasedAnimation for all demos
//TODO[DONE] свойство tag у rigidbody

uses balance_basic, System.Collections.Generic;

type
  {$region PolygonsSupport}
  
  Shape = class;
  
  TrShape = record
  private
    m_shap: Shape;
    m_tr: Transform;  
    m_aabb: BoundBox;
    procedure recalc();
  public
    property shap: Shape read m_shap;
    property tr: Transform read m_tr;
    property aabb: BoundBox read m_aabb;
    
    constructor create(shap: Shape; tr: Transform := bl_trans0);
    begin
      m_shap := shap;
      m_tr := tr;
      recalc();
    end;
    
    function combine(t: Transform) := new TrShape(shap, t.combine(self.tr));
  end;
  
  
  
  ShapeKind = (ShapePolygon, ShapeCircle);
  
  Shape = abstract class
  private
    m_kind: ShapeKind;
    m_area: real;
    m_inertia: real;
    m_aabb: BoundBox;
    m_user_centroid: Vector;
  protected
    procedure init_base(area, inertia: real; aabb: BoundBox; user_centroid: Vector);
    begin
      m_area := area;
      m_inertia := inertia;
      m_aabb := aabb;      
      m_user_centroid := user_centroid;
    end;
  
  public
    property kind: ShapeKind read m_kind;
    property area: real read m_area;
    property inertia: real read m_inertia; //base inertia
    property aabb: BoundBox read m_aabb;
    property user_centroid: Vector read m_user_centroid;
    
    function get_proj(axis: Vector; tr: Transform): MinMax; abstract;
    
    function at(x, y: real; ang: real := 0.0) := new TrShape(self, bl_trans(x, y, ang));
    function at(pos: Vector; ang: real := 0.0) := new TrShape(self, bl_trans(pos, ang));
    function at(t: Transform) := new TrShape(self, t);
    
    function centered(x, y: real; ang: real := 0.0) := at(x + user_centroid.x, y + user_centroid.y, ang);
    function centered(pos: Vector := bl_vect0; ang: real := 0.0) := centered(pos.x, pos.y, ang);
    function centered(t: Transform) := centered(t.pos, t.ang);
    
    constructor create(kind: ShapeKind);
    begin
      m_kind := kind;
    end;
  end;
  
  PolygonEdge = record
    ind, ind2: integer;
    v1, v2: Vector;
    norm: vector;
    constructor create(ind, ind2: integer; v1, v2, norm: vector);
    begin
      self.ind := ind;
      self.ind2 := ind2;
      self.v1 := v1;
      self.v2 := v2;
      self.norm := norm;
    end;
    
    property edge_ind: integer read ind;
    property vert1_ind: integer read ind;
    property vert2_ind: integer read ind2;
  end;
  
  
  
  Polygon = class(Shape)
  public
    static function get_convex_orientation(verts: IReadOnlyList<Vector>): integer;
    begin
      var n := verts.Count;
      if n < 3 then exit(0);
      
      var sign := 0;
      for var i := 0 to n - 1 do
      begin
        var i1 := (i + 1) mod n;
        var i2 := (i + 2) mod n;
        var cross := Vector.Cross(verts[i1] - verts[i], verts[i2] - verts[i1]);
        if (abs(cross) <= 1e-10) then continue;
        var cur := (cross > 0) ? 1 : -1;
        if sign = 0 then sign := cur
        else if sign <> cur then exit(0);
      end;
      exit(sign);
    end;
    
    static procedure get_metrics(verts: IReadOnlyList<Vector>; var area: real; var centroid: Vector; var inertia: real);
    begin
      area := 0; centroid := bl_vect0; inertia := 0;
      var n := verts.Count;
      assert(n >= 3);
      for var i := 0 to n - 1 do
      begin
        var v1 := verts[i];
        var v2 := verts[(i + 1) mod n];
        var cross := Vector.Cross(v1, v2);
        area += cross;
        centroid += (v1 + v2) * cross;
        var factor := v1.LengthSquared + v2.LengthSquared + v1 * v2;
        inertia += cross * factor;
      end;
      area := abs(area);//support CW too
      assert(area > 1e-7);
      area := area / 2.0;
      centroid := centroid / (6.0 * area);      
      //Перенос инерции из начала координат в Центр Масс (теорема Гюйгенса-Штейнера)
      inertia := (inertia / 12.0) - area * centroid.LengthSquared;       
    end;
  
  private
    m_vertices: array of Vector; //List<Vector>;
    m_normals:  array of Vector; //List<Vector>;
  
  public
    property vertices: IReadOnlyList<Vector> read IReadOnlyList&<Vector>(m_vertices);
    property normals: IReadOnlyList<Vector> read IReadOnlyList&<Vector>(m_normals);
    
    
    constructor create(verts: IEnumerable<Vector>);
    begin
      inherited create(ShapeKind.ShapePolygon);
      
      var verts_arr := verts.ToArray();
      var count := verts_arr.Length;
      var area := 0.0;
      var inertia := 0.0;
      var aabb := BoundBox.empty();
      var user_centroid := bl_vect0;
      
      var orient := get_convex_orientation(verts_arr);
      if orient = 0 then raise new System.ArgumentException('Vertices must define a convex polygon in CCW or CW order');
      if orient = -1 then &Array.Reverse(verts_arr);
      get_metrics(verts_arr, area, user_centroid, inertia);
      
      self.m_vertices := new Vector[count];
      for var i := 0 to count - 1 do
      begin
        m_vertices[i] := verts_arr[i] - user_centroid;
        aabb.extend(m_vertices[i]);
      end;
      
      self.m_normals := new Vector[count];
      for var i := 0 to count - 1 do
        m_normals[i] := Utils.normal(m_vertices[i], m_vertices[Utils.mmod(i + 1, count)]);
      
      init_base(area, inertia, aabb, user_centroid);
    end;
    
    function get_edge(i: integer; tr: Transform): PolygonEdge;
    begin
      var i1 := Utils.mmod(i, m_vertices.Length);
      var i2 := Utils.mmod(i + 1, m_vertices.Length);
      var v1 := tr.apply(m_vertices[i1]);
      var v2 := tr.apply(m_vertices[i2]);
      var n := tr.apply_dir(m_normals[i1]);       
      result := new PolygonEdge(i1, i2, v1, v2, n);
    end;
    
    function get_proj(world_axis: Vector; tr: Transform): MinMax; override;
    begin
      result := MinMax.empty();
      var local_axis := tr.unapply_dir(world_axis);      
      for var i := 0 to m_vertices.Length - 1 do
        result.extend(m_vertices[i] * local_axis);
      var offset := tr.pos * world_axis;
      result.min += offset;
      result.max += offset;
    end;
    
    static function regular(n: integer; r: real; r1: real ? := nil; ang: real ? := nil): Polygon;
    begin
      assert(n >= 3);
      if ang = nil then ang := pi / n - pi / 2;
      if (r1 = nil) then r1 := r;
      var angv := ang.Value;
      var step := 2 * pi / n;
      var verts := new List<Vector>(n);
      for var i := 0 to n - 1 do
        verts.Add(new Vector(cos(step * i + angv) * r, sin(step * i + angv) * r1.Value));
      result := new Polygon(verts);
    end;
    
    // recalc() shifts vertices to local space (0,0) and stores the offset in user_centroid.
    // Always use .at(shape.user_centroid) to place the shape at its intended world/group position.
    
    static function extruded_line(v1, v2, n1, n2: Vector; outer, inner: real)
    := new Polygon(|v1 - n1 * inner, v1 + n1 * outer, v2 + n2 * outer, v2 - n2 * inner|);
    
    static function wall(v1, v2: Vector; thickness: real := 10): Polygon;
    begin
      var n := (v2 - v1).Norm().unortog();
      result := extruded_line(v1, v2, n, n, thickness * 0.5, thickness * 0.5);
    end;
    
    static function box(v1, v2: Vector) := new Polygon(|v1, bl_vect(v2.x, v1.y), v2, bl_vect(v1.x, v2.y)|);
    
    
    static function wall(dir: Vector; thickness: real := 10): Polygon;
    begin
      var n := dir.Norm().unortog() * (thickness * 0.5);
      result := new Polygon(arr(-n, dir - n, dir + n, n));
    end;
    
    static function box_r(hw, hh: real) := new Polygon(|bl_vect(-hw, -hh), bl_vect(hw, -hh), bl_vect( hw,  hh), bl_vect(-hw,  hh)|);
    static function box(w, h: real) := box_r(w * 0.5, h * 0.5);
  end;
  
  
  
  Circle = class(Shape)
  private
    m_radius: real;
  public
    property radius: real read m_radius;
    constructor create(r: real; centroid: Vector := bl_vect0);
    begin
      inherited create(ShapeKind.ShapeCircle);
      m_radius := r;
      var area := pi * r * r;
      var inertia := 0.5 * area * r * r;
      var aabb := BoundBox.from_minmax(-radius, radius);
      init_base(area, inertia, aabb, centroid);
    end;
    
    function get_proj(world_axis: Vector; tr: Transform): MinMax; override;
    begin
      var center_proj := tr.pos * world_axis;
      result := new MinMax(center_proj - radius, center_proj + radius);
    end;
  end;
  
  CollisionHit = record
    normal: Vector; 
    depth: real; 
    constructor create(normal: Vector; depth: real);
    begin
      self.normal := normal;
      self.depth := depth;
    end;
  end;
  
  GeomUtils = static class
  public
    static function get_closest_point_on_edge(p, a, b: Vector): Vector;
    begin
      var ab := b - a;
      var lensq := ab.LengthSquared;
      if lensq < 1e-12 then exit(a);
      var t := ((p - a) * ab) / lensq; 
      result := a + clamp(t, 0.0, 1.0) * ab;
    end;
    
    static function test_circle_point(pos: Vector; rad: real; pnt: Vector; dflt: Vector): CollisionHit?;
    begin
      var delta := pos - pnt;
      var dist_sq := delta.LengthSquared;
      if dist_sq > (rad * rad) then exit(nil);
      var dist := sqrt(dist_sq);
      result := new CollisionHit(delta.safe_div(dist, dflt), rad - dist);
    end;
    
    static function test_circle_edge(cpos: Vector; crad: real; v1, v2, norm: Vector): CollisionHit?;
    begin
      var closest := get_closest_point_on_edge(cpos, v1, v2);
      result := test_circle_point(cpos, crad, closest, norm);
    end;
    
    static function find_max_proj(vectors: IReadOnlyList<vector>; dir: Vector; var ind: integer): real;
    begin
      ind := -1;
      result := real.MinValue;
      for var i := 0 to vectors.Count - 1 do
      begin
        var proj := vectors[i] * dir;
        if proj > result then
        begin
          result := proj;
          ind := i;
        end;
      end;
    end;  
  end;
  
  ContactID = record(System.IEquatable<ContactID>)
    inc_vert, ref_edge: integer;
    is_clipped: boolean;
    part1, part2: integer;
    
    constructor create(inc_vert, ref_edge: integer; is_clipped: boolean);
    begin
      self.inc_vert := inc_vert;
      self.ref_edge := ref_edge;
      self.is_clipped := is_clipped;
    end;
    
    function set_parts(part1, part2: integer): ContactID;
    begin
      result := self;
      result.part1 := part1;
      result.part2 := part2;
    end;
    
    function to_tuple() := System.ValueTuple.Create(inc_vert, ref_edge, is_clipped, part1, part2);
    function GetHashCode: integer; override := to_tuple().GetHashCode();
    function Equals(o: ContactID) := to_tuple().Equals(o.to_tuple());
    function Equals(obj: object): boolean; override := (obj is ContactID) ? self.Equals(ContactID(obj)) : false;
  end;
  
  ContactPoint = record
    pos: Vector;
    depth: real;
    id: ContactID;
    constructor create(pos: Vector; depth: real; id: ContactID);
    begin
      self.pos := pos;
      self.depth := depth;
      self.id := id;
    end;
    
    static function empty() := new ContactPoint(bl_vect0, 0, new ContactID(0, 0, false));
  end;
  
  CollisionManifold = record
    hit: CollisionHit;
    contacts: FixedBuf2<ContactPoint>;
    dbg_ref_edge, dbg_inc_edge: PolygonEdge;
    
    constructor create(hit: CollisionHit; contacts: FixedBuf2<ContactPoint>);
    begin
      self.hit := hit;
      self.contacts := contacts;
    end;
    
    procedure set_dbg(ref_edge, inc_edg: PolygonEdge);
    begin
      dbg_ref_edge := ref_edge;
      dbg_inc_edge := inc_edg;
    end;
  end;
  
  SATVertexID = record
    pos: Vector;
    id: ContactID;
    constructor create(pos: Vector; id: ContactID);
    begin
      self.pos := pos;
      self.id := id;
    end;
  end;
  
  SATClippedLine = FixedBuf2<SATVertexID>;
  
  SATCollisionDetector = static class
  private
    static function test_sat_step(p1, p2: Polygon; const tr1, tr2, tr: Transform; normals: IReadOnlyList<Vector>; var min_overlap: real; var min_axis: Vector): boolean;
    begin
      result := false;
      for var i := 0 to normals.count - 1 do
      begin
        var norm := normals[i];
        var axis := tr.apply_dir(norm);
        var proj1 := p1.get_proj(axis, tr1);
        var proj2 := p2.get_proj(axis, tr2);
        var overlap := MinMax.overlap(proj1, proj2);
        if (overlap <= 0) then exit;
        if (MinMax.contains(proj1, proj2) or MinMax.contains(proj2, proj1)) then
          overlap += min(abs(proj1.min - proj2.min), abs(proj1.max - proj2.max));
        if overlap < min_overlap then
        begin
          min_overlap := overlap;
          min_axis := axis;
        end;         
      end;
      result := true;   
    end;
  
  
  public
    static function polygon_circle_max_sep(p: Polygon; c: Circle; local_center: Vector; var ind: integer): real;
    begin
      ind := -1;
      result := real.MinValue;
      for var i := 0 to p.vertices.Count - 1 do
      begin
        var dist := (local_center - p.vertices[i]) * p.normals[i];
        if dist > c.radius then exit(dist);
        if dist > result then
        begin
          result := dist;
          ind := i;
        end;
      end;
    end;
    
    static function get_best_edge(p: Polygon; tr: Transform; hit_norm: Vector): PolygonEdge;
    begin
      var ind := -1;
      GeomUtils.find_max_proj(p.vertices, tr.unapply_dir(hit_norm), ind);
      assert(ind >= 0);
      var left_edge := p.get_edge(ind - 1, tr);
      var right_edge := p.get_edge(ind, tr);
      var left_win := left_edge.norm * hit_norm > right_edge.norm * hit_norm;
      result := left_win ? left_edge : right_edge;
    end;
    
    static function test_sat(p1, p2: Polygon; tr1, tr2: Transform): CollisionHit?;
    begin
      var min_overlap := real.MaxValue;
      var min_axis := bl_vect0;
      if (not test_sat_step(p1, p2, tr1, tr2, tr1, p1.normals, min_overlap, min_axis)) then exit;
      if (not test_sat_step(p1, p2, tr1, tr2, tr2, p2.normals, min_overlap, min_axis)) then exit;
      
      var dir := tr2.pos - tr1.pos;
      if (dir * min_axis < 0) then
        min_axis := -min_axis;     
      result := new CollisionHit(min_axis, min_overlap);      
    end;
    
    static function clip_line_by_plane(v1, v2: SATVertexID; n: Vector; offset: real): SATClippedLine;
    begin
      var d1 := v1.pos * n - offset;
      var d2 := v2.pos * n - offset;
      if d1 >= 0 then Result.add(v1);
      if (d1 * d2 < 0) then
      begin
        var t := d1 / (d1 - d2);
        var pos := v1.pos + (v2.pos - v1.pos) * t;
        var id := (d1 < 0) ? v1.id : v2.id;
        Result.add(new SATVertexID(pos, new ContactID(id.inc_vert, id.ref_edge, true)));
      end;
      if d2 >= 0 then Result.add(v2);
    end;
    
    static function find_contact(p1, p2: Polygon; tr1, tr2: Transform; hit: CollisionHit): CollisionManifold;
    begin
      var n := hit.normal;
      
      var ref_edge := get_best_edge(p1, tr1, n);
      var inc_edge := get_best_edge(p2, tr2, -n);
      if (abs(inc_edge.norm * n) > abs(ref_edge.norm * n)) then
        swap(inc_edge, ref_edge);
      
      var ref_norm := ref_edge.norm;
      var ref_dir := ref_norm.unortog();
      
      var v1 := new SATVertexID(inc_edge.v1, new ContactID(inc_edge.vert1_ind, ref_edge.ind, false));
      var v2 := new SATVertexID(inc_edge.v2, new ContactID(inc_edge.vert2_ind, ref_edge.ind, false));
      
      var clip_line := clip_line_by_plane(v1, v2, ref_dir, ref_dir * ref_edge.v1);      
      if (clip_line.count = 2) then
        clip_line := clip_line_by_plane(clip_line[0], clip_line[1], -ref_dir, -ref_dir * ref_edge.v2);     
      
      //var ref_offset := ref_norm * ref_edge.v1;
      var ref_offset := (ref_edge.v1 + ref_edge.v2) * ref_norm / 2;
      var contacts := clip_line.map(v -> new ContactPoint(v.pos, ref_offset - v.pos * ref_norm, v.id));
      result := new CollisionManifold(hit, contacts);   
      result.set_dbg(ref_edge, inc_edge);       
    end;
    
    
    static function check(p1, p2: Polygon; t1, t2: Transform): CollisionManifold?;
    begin
      var hit := test_sat(p1, p2, t1, t2);
      if (hit <> nil) then
      begin
        result := find_contact(p1, p2, t1, t2, hit.Value);
        if (result.Value.contacts.count = 0) then begin
          result := nil; 
          //TODO assert(false, 'Collision points not found but SAT say yes');
        end;
      end;
    end;
  end;
  {$endregion}
  
  ShapeGroup = class  
  public
    static procedure get_metrics(parts: IReadOnlyList<TrShape>; var area: real; var centroid: Vector; var inertia: real);
    begin
      assert((parts <> nil) and (parts.Count > 0));
      area := 0;
      centroid := bl_vect0;
      inertia := 0;
      
      foreach var p in parts do
      begin
        area += p.shap.area;
        centroid += p.tr.pos * p.shap.area;
      end;
      
      centroid := centroid.safe_div(area, bl_vect0);
      
      foreach var p in parts do
        inertia += p.shap.inertia + p.shap.area * (p.tr.pos - centroid).LengthSquared;
    end;
  
  private
    m_parts: array of TrShape;
    m_area: real;
    m_inertia: real;
    m_centroid: Vector;
    m_aabb: BoundBox;
  
  public
    property parts:IReadOnlyList<TrShape> read IReadOnlyList&<TrShape>(m_parts);
    property area:real read m_area;
    property inertia:real read m_inertia;
    property centroid:Vector read m_centroid;
    property aabb: BoundBox read m_aabb;

    constructor create(parts: IEnumerable<TrShape>);
    begin
      m_parts := parts.ToArray();
      get_metrics(m_parts, m_area, m_centroid, m_inertia);
      for var i := 0 to m_parts.Length - 1 do
        m_parts[i] := new TrShape(m_parts[i].shap, m_parts[i].tr.moved(-m_centroid));
      m_aabb := BoundBox.empty();
      foreach var p in m_parts do
        m_aabb.extend(p.aabb);      
    end;
    
    static function make_hollow(p: Polygon; thickness: real; miter: boolean): ShapeGroup;
    begin
      var gr := new List<TrShape>();
      var n := p.vertices.Count;
      for var i := 0 to n - 1 do
      begin
        var i_p := utils.mmod(i - 1, n);
        var i_n := utils.mmod(i + 1, n);        
        var n1 := p.normals[i];
        var n2 := p.normals[i];
        if miter then
        begin
          var nip := p.normals[i_p];
          var ni := p.normals[i];
          var nin := p.normals[i_n];
          n1 := (nip + ni) / (1 + Vector.Dot(nip, ni));
          n2 := (ni + nin) / (1 + Vector.Dot(ni, nin));
        end;
        gr.Add(Polygon.extruded_line(p.vertices[i], p.vertices[i_n], n1, n2, thickness, 0).centered());
      end;
      result := new ShapeGroup(gr);
    end;
    
    static function make_lines_chain(points: IReadOnlyList<Vector>; thickness: real; miter: boolean): ShapeGroup;
    begin
      var gr := new List<TrShape>();
      var n := points.Count;
      if n < 2 then raise new System.ArgumentOutOfRangeException('points', 'A line chain must contain at least 2 points');
      var (nip, ni, nin) := (bl_vect0, utils.normal(points[0], points[1]), bl_vect0);
      for var i := 0 to n - 2 do
      begin
        if i < n - 2 then nin := utils.normal(points[i + 1], points[i + 2]);
        var (n1, n2) := (ni, ni);  
        if miter then
        begin
          if i > 0 then n1 := (nip + ni) / (1 + Vector.Dot(nip, ni));
          if i < n - 2 then n2 := (ni + nin) / (1 + Vector.Dot(ni, nin));
        end;
        gr.Add(Polygon.extruded_line(points[i], points[i + 1], n1, n2, thickness, 0).centered());
        nip := ni;
        ni := nin;
      end;
      result := new ShapeGroup(gr);
    end;
  end;
  
  ShapeQuery = static class
  private
    static procedure throw_shape() := assert(false, 'Unknown shape kind');
  public
    {$region get_aabb}
    static function get_aabb(obj: Shape; tr: Transform): BoundBox;
    begin
      if obj.kind <> ShapeKind.ShapeCircle then
        exit(obj.aabb.apply_transform(tr));
      exit(obj.aabb.translate(tr.pos));  
    end;
    
    static function get_aabb(obj: TrShape; tr: Transform) := get_aabb(obj.shap, tr.combine(obj.tr));
    static function get_aabb(obj: ShapeGroup; tr: Transform) := obj.parts.Count <> 1 ? obj.aabb.apply_transform(tr) : get_aabb(obj.parts[0], tr);
    {$endregion}
    
    {$region test_point}
    static function test_point(obj: Polygon; pt: Vector): boolean;
    begin
      if not obj.aabb.contains(pt) then exit(false); 
      for var i := 0 to obj.vertices.Count - 1 do
        if (pt - obj.vertices[i]) * obj.normals[i] > 0 then 
          exit(false);
      exit(true);
    end;
    
    static function test_point(obj: Circle; pt: Vector) :=  pt.LengthSquared <= obj.radius * obj.radius;
    static function test_point(obj: Shape; pt: Vector): boolean;
    begin
      case obj.kind of
        ShapeKind.ShapePolygon: exit(test_point(Polygon(obj), pt));
        ShapeKind.ShapeCircle: exit(test_point(Circle(obj), pt))
      else
        throw_shape();
      end;
    end;
    
    static function test_point(obj: TrShape; pt: Vector) := test_point(obj.shap, obj.tr.unapply(pt));
    static function test_point(obj: ShapeGroup; tr: Transform; pt: Vector; var part_ind: integer): boolean;
    begin
      part_ind := -1;
      pt := tr.unapply(pt);
      if not obj.aabb.contains(pt) then exit(false);
      for var i := 0 to obj.parts.Count - 1 do
        if test_point(obj.parts[i], pt) then 
        begin
          part_ind := i;
          exit(true);
        end;
      exit(false);
    end;
    {$endregion}
  end;

procedure TrShape.recalc();
begin
  self.m_aabb := ShapeQuery.get_aabb(self.m_shap, self.m_tr);
end;


type
  CollisionDetector = static class
  public    
    static function check(p1, p2: Polygon; t1, t2: Transform) := SATCollisionDetector.check(p1, p2, t1, t2); 
    
    static function check(c1, c2: Circle; t1, t2: Transform): CollisionManifold?;
    begin
      var total_rad := c1.radius + c2.radius;
      var nhit := GeomUtils.test_circle_point(t2.pos, total_rad, t1.pos, bl_vect(0, 1));
      if nhit = nil then exit(nil);
      var hit := nhit.Value;
      var con_pos := t1.pos + hit.normal * (c1.radius - hit.depth * 0.5);
      var cons := new FixedBuf2<ContactPoint>();
      cons.add(new ContactPoint(con_pos, hit.depth, new ContactID(0, 0, false)));
      result := new CollisionManifold(hit, cons);
    end;
    
    static function check(p: Polygon; c: Circle; tp, tc: Transform; flip_normal: boolean): CollisionManifold?;
    begin
      var local_center := tp.unapply(tc.pos);
      var edge_ind: integer;   
      var max_sep := SATCollisionDetector.polygon_circle_max_sep(p, c, local_center, edge_ind);
      if (max_sep > c.radius) or (edge_ind < 0) then exit(nil);            
      var edge := p.get_edge(edge_ind, tp);       
      var hit: CollisionHit;
      if max_sep > 1e-7 then 
      begin
        var nhit := GeomUtils.test_circle_edge(tc.pos, c.radius, edge.v1, edge.v2, edge.norm);
        if nhit = nil then exit(nil);
        hit := nhit.Value;
      end
      else 
        hit := new CollisionHit(edge.norm, c.radius - max_sep);
      var con_pos := tc.pos - hit.normal * (c.radius - hit.depth * 0.5);//tc.pos - h.normal * c.radius;  
      if flip_normal then hit.normal := -hit.normal;
      var contacts: FixedBuf2<ContactPoint>;//TODO ContactID maybe need to swap too
      contacts.add(new ContactPoint(con_pos, hit.depth, new ContactID(edge.edge_ind, 0, false)));
      result := new CollisionManifold(hit, contacts);
    end;
    
    static function check(s1, s2: Shape; t1, t2: Transform): CollisionManifold?;
    begin
      var flip := s1.kind > s2.kind;
      if flip then
      begin
        swap(s1, s2);
        swap(t1, t2);
      end;
      
      
      {match (s1, s2) with
        (Polygon(o1), Polygon(o2)): result := check(o1, o2, t1, t2);
        (Polygon(o1), Circle(o2)): result := check(o1, o2, t1, t2, flip);
        (Circle(o1), Circle(o2)): result := check(o1, o2, t1, t2)
        else
          assert(false, 'Unknown Pair');
      end;}
      
      var (k1, k2) := (s1.kind, s2.kind);
      if (k1 = ShapeKind.ShapePolygon) and (k2 = ShapeKind.ShapePolygon) then
        exit(check(Polygon(s1), Polygon(s2), t1, t2));
      if (k1 = ShapeKind.ShapePolygon) and (k2 = ShapeKind.ShapeCircle) then
        exit(check(Polygon(s1), Circle(s2), t1, t2, flip));
      if (k1 = ShapeKind.ShapeCircle) and (k2 = ShapeKind.ShapeCircle) then
        exit(check(Circle(s1), Circle(s2), t1, t2));
      assert(false, 'Unknown Pair');
    end;
    
    static procedure check(gr1, gr2: ShapeGroup; tr1, tr2: Transform; callback: System.Action<CollisionManifold>; test_group_aabb: boolean := true);
    begin
      if (test_group_aabb) and (not BoundBox.intersect(ShapeQuery.get_aabb(gr1, tr1), ShapeQuery.get_aabb(gr2, tr2))) then exit;  
      for var i := 0 to gr1.parts.Count - 1 do
      begin
        var p1 := gr1.parts[i].combine(tr1);
        var p1bbox := p1.aabb;
        for var j := 0 to gr2.parts.Count - 1 do
        begin
          var p2 := gr2.parts[j].combine(tr2);
          if not BoundBox.intersect(p1bbox, p2.aabb) then continue;          
          var mn := check(p1.shap, p2.shap, p1.tr, p2.tr);
          if mn <> nil then
          begin
            var m := mn.value;
            m.contacts := m.contacts.map(f -> new ContactPoint(f.pos, f.depth, f.id.set_parts(i, j)));
            callback(m);
          end;
        end;
      end;
    end;
  end;
  
  RigidBody = class
  private
    _is_static: boolean;
    procedure _set_is_static(v: boolean);
    begin
      _is_static := v;
      recalc_inv();
    end;
    
    private m_fam_ind: integer;
  
  public
    group: ShapeGroup;
    tr: Transform;  
    //Should be read only for non-static objects
    //Since it stores the last parameters that the object had before switching to static)
    //[
    vel, force: Vector;
    avel, torque: real;
    mass, inertia: real;
    vel_ps: Vector;
    avel_ps: real;
    //]
    
    //Safely to read for static and non-static objects
    //[
    inv_mass, inv_inertia: real;
    mat: Material;
    custom_mass: real?;
    damp: Damping;
    //]
    
    //Fully controlled by user
    auto property tag: object;
    property pos: Vector read tr.pos write tr.pos := value;
    property ang: real read tr.ang write tr.ang := value;
    property is_static: boolean read _is_static write _set_is_static;
    property fam_ind: integer read m_fam_ind;
    function kinetic_energy(): real;
    begin
      if is_static then exit(0);
      result := 0.5 * mass * vel.LengthSquared + 0.5 * inertia * sqr(avel);
    end;
    
    procedure recalc_inv();
    begin
      if (not is_static) then
      begin
        inv_mass := 1.0 / mass;
        inv_inertia := 1.0 / inertia;
      end
      else
      begin
        inv_mass := 0.0;
        inv_inertia := 0.0;        
      end;
    end;
    
    procedure recalc();
    begin
      mass := custom_mass <> nil ? custom_mass.value : mat.get_mass(group.area);
      inertia := group.inertia * (mass / group.area);
      _set_is_static(_is_static)
    end;
    
    constructor create(group: ShapeGroup; tr: Transform; is_static: boolean; mat: material ?:= nil; custom_mass: real ?:= nil; damp: Damping ?:= nil; tag: object := nil);
    begin
      self.group := group;//TODO[Closed, since group is immutable] should we copy group?
      self.tr := tr.combine(bl_trans(group.centroid));
      self.vel := bl_vect0;
      self.force := bl_vect0;
      self.avel := 0;
      self.torque := 0;            
      self.mass := 0;
      self.mat := mat.unwrap_or(Materials.DefaultMat);
      self.custom_mass := custom_mass;
      self.damp := damp.unwrap_or(Damping.DefaultDamp);
      self._is_static := is_static;
      self.m_fam_ind := 0;//TODO familymanager static const for default_ind
      self.tag := tag;
      recalc();
    end;
    
    property aabb: BoundBox read ShapeQuery.get_aabb(group, tr); //group.aabb.apply_transform(tr);
    
    procedure reset_dyn(vel: vector := bl_vect0; avel: real := 0; force: vector := bl_vect0; torque: real := 0);
    begin
      self.vel := vel;
      self.avel := avel;
      self.force := force;
      self.torque := torque;
    end;
    
    procedure add_force(f: Vector);
    begin
      if is_static then exit;
      force += f;
    end;
    
    procedure add_torque(t: real);
    begin
      if is_static then exit;
      torque += t;
    end;
    
    procedure add_torque_impulse(imp: real; ps: boolean := false);
    begin
      if is_static then exit;
      var dav := imp * inv_inertia;
      if not ps then
        avel += dav
      else
        avel_ps += dav;
    end;
    
    procedure add_force_at(f, world_pt: Vector);
    begin
      if is_static then exit;
      var r := world_pt - pos;
      force += f;
      torque += Vector.Cross(r, f);
    end;
    
    procedure add_impulse_r(imp: Vector; r: Vector; ps: boolean := false);
    begin
      if is_static then exit;
      var new_vel := imp * inv_mass;
      var new_avel := Vector.Cross(r, imp) * inv_inertia;
      if not ps then
      begin
        vel += new_vel;
        avel += new_avel;
      end
      else
      begin
        vel_ps += new_vel;
        avel_ps += new_avel;
      end;
    end;
    
    procedure add_impulse(imp: Vector; world_pt: Vector; ps: boolean := false) := add_impulse_r(imp, world_pt - pos, ps);
    
    function get_vel_at_r(r: Vector; ps: boolean := false): Vector;
    begin
      if is_static then exit(bl_vect0);
      if not ps then
        result := vel + avel * r.unortog()
      else
        result := vel_ps + avel_ps * r.unortog()
    end;
    
    function get_vel_at(world_pt: Vector; ps: boolean := false) := get_vel_at_r(world_pt - pos, ps);
    
    procedure integ_vel(dt: real; world_accel: Vector := bl_vect0);
    begin
      if is_static then exit;
      vel += (force * inv_mass + world_accel) * dt;
      avel += (torque * inv_inertia) * dt;
      force := bl_vect0;    
      torque := 0;  
      
      if damp.enabled then
      begin
        vel *= 1.0 / (1.0 + dt * damp.linear);
        avel *= 1.0 / (1.0 + dt * damp.angular);
      end;
    end;
    
    procedure integ_pos(dt: real);
    begin
      if is_static then exit;
      pos += (vel + vel_ps) * dt;    
      ang += (avel + avel_ps) * dt;
      vel_ps := bl_vect0;
      avel_ps := 0;
    end;
    
    procedure integ(dt: real);
    begin
      if is_static then exit;
      integ_vel(dt);
      integ_pos(dt);
    end;
  end;
  
  PairUtils = static class
  public
    static procedure add_impulse(a, b: RigidBody; imp, world_pt: Vector; ps: boolean := false);
    begin
      a.add_impulse(-imp, world_pt, ps);
      b.add_impulse(imp, world_pt, ps);
    end;
    
    static procedure add_impulse_r(a, b: RigidBody; r_a, r_b, imp: Vector; ps: boolean := false);
    begin
      a.add_impulse_r(-imp, r_a, ps);
      b.add_impulse_r(imp, r_b, ps);
    end;
    
    static procedure add_torque_impulse(a, b: RigidBody; imp: real; ps: boolean := false);
    begin
      a.add_torque_impulse(-imp, ps);
      b.add_torque_impulse(imp, ps);
    end;
    
    static function get_rel_vel_r(a, b: RigidBody; r_a, r_b: Vector; ps: boolean := false) := b.get_vel_at_r(r_b, ps) - a.get_vel_at_r(r_a, ps);
    static function get_rel_vel(a, b: RigidBody; world_pt: Vector; ps: boolean := false) := b.get_vel_at(world_pt, ps) - a.get_vel_at(world_pt, ps);
    static function get_rel_vel_ang(a, b: RigidBody; ps: boolean := false) := ps ? (b.avel_ps - a.avel_ps) : (b.avel - a.avel);
    
    static function solve_impulse(var acc: real; imp, max_imp: real): real;
    begin
      var old := acc;
      acc := clamp(old + imp, -max_imp, max_imp);
      result := acc - old;
    end;
    
    static function solve_impulse(var acc: real; imp: real; side: IntervalSide): real;
    begin
      var old := acc;
      acc += imp;
      case side of
        IntervalSide.LowerSide: acc := max(acc, 0);
        IntervalSide.UpperSide: acc := min(acc, 0);
        IntervalSide.FixedIntr:; //do nothing
      end;
      result := acc - old;
    end;
    
    static function get_bias(error, baumgarte, dt: real) := (error * baumgarte) / dt;
    
    static function get_k_mass(a, b: RigidBody; r_a, r_b, dir: Vector; softness: real) :=
    utils.get_k_mass(a.inv_mass + b.inv_mass + softness, a.inv_inertia, b.inv_inertia, r_a, r_b, dir);
    static function get_k_mass_ang(a, b: RigidBody; softness: real) := utils.inv(a.inv_inertia + b.inv_inertia + softness);
    
    static function get_k_matr(a, b: RigidBody; r_a, r_b: Vector; softness: real) :=
    Matrix2.get_contact_kmatrix(a.inv_mass + b.inv_mass + softness, a.inv_inertia, b.inv_inertia, r_a, r_b);
    
    static procedure get_world_anchors_r(a, b: RigidBody; local_a, local_b: Vector; var r_a, r_b: Vector);
    begin
      r_a := a.tr.apply_dir(local_a);
      r_b := b.tr.apply_dir(local_b);
    end;
    
    static procedure solve_1d(a, b: RigidBody; r_a, r_b, n: Vector; var acc_imp: real; k_mass, softness, bias: real; side: IntervalSide; is_soft: boolean);
    begin
      begin
        var soft_bias := is_soft ? bias : 0;
        
        var rv := get_rel_vel_r(a, b, r_a, r_b) * n;
        var imp := -k_mass * (rv + soft_bias + softness * acc_imp);
        var delta := solve_impulse(acc_imp, imp, side);
        add_impulse_r(a, b, r_a, r_b, n * delta);
      end;
      if not is_soft then
      begin
        var rv := get_rel_vel_r(a, b, r_a, r_b, ps := true) * n;
        var imp := -k_mass * (rv + bias);
        add_impulse_r(a, b, r_a, r_b, n * imp, ps := true);
      end;
    end;
  end;
  
  {$region ContactResolver}
  ContactResolverData = record
    //TODO[Done] rad_a and rad_b not used by solver
    rad_a, rad_b: Vector; 
    mass_normal, mass_tangent: real;
    
    vel_bias, pos_bias: real;
    constructor create(rad_a, rad_b: vector; mass_normal, mass_tangent: real; vel_bias, pos_bias: real);
    begin
      self.rad_a := rad_a;
      self.rad_b := rad_b;
      self.mass_normal := mass_normal;
      self.mass_tangent := mass_tangent;
      self.vel_bias := vel_bias;
      self.pos_bias := pos_bias;
    end;
  end;
  
  CollisionContact = record
  public
    body_a, body_b: RigidBody;  
    hit_normal: Vector;
    point: ContactPoint; 
    acc_imp_n, acc_imp_t: real; 
    
    resolver_data: ContactResolverData;    
    
    constructor create(body_a, body_b: RigidBody; hit_normal: Vector; point: ContactPoint; imp_n, imp_t: real);
    begin
      self.body_a := body_a;
      self.body_b := body_b;
      self.hit_normal := hit_normal;
      self.point := point;
      self.acc_imp_n := imp_n;
      self.acc_imp_t := imp_t;
    end;
  end;
  
  
  ArbiterKey = record(System.IEquatable<ArbiterKey>)
    body_a, body_b: RigidBody;
    id: ContactID;    
    constructor(a, b: RigidBody; id: ContactID);
    begin
      if Utils.get_addr(a) > Utils.get_addr(b) then
        swap(a, b);
      self.body_a := a;
      self.body_b := b;
      self.id := id;
    end;
    
    function to_tuple() := System.ValueTuple.Create(body_a, body_b, id);
    function GetHashCode: integer; override := to_tuple().GetHashCode();
    function Equals(o: ArbiterKey) := to_tuple().Equals(o.to_tuple());
    function Equals(obj: object): boolean; override := (obj is ArbiterKey) ? self.Equals(ArbiterKey(obj)) : false;
  end;
  
  ArbiterValue = record
    imp_n, imp_t: real; 
    life_time: cardinal;
    constructor create(imp_n, imp_t: real; life_time: cardinal);
    begin
      self.imp_n := imp_n;
      self.imp_t := imp_t;
      self.life_time := life_time;
    end;
  end;
  
  ContactManager = class
  private
    _remove_list := new List<ArbiterKey>();
  public
    contacts := new List<CollisionContact>();
    arbiters := new Dictionary<ArbiterKey, ArbiterValue>;
    max_life_time := 5; 
    frame_idx: cardinal := 0;
    
    procedure new_frame();
    begin
      frame_idx += 1;
      contacts.Clear();
    end;
    
    procedure add_manifold(a, b: RigidBody; m: CollisionManifold);
    begin
      for var i := 0 to m.contacts.count - 1 do
      begin
        var con := m.contacts[i];
        if (con.depth <= 0) then continue;
        var key := new ArbiterKey(a, b, con.id);
        var val := new ArbiterValue(0, 0, 0);
        if (arbiters.TryGetValue(key, val)) and ((frame_idx - val.life_time) > max_life_time) then
          val := new ArbiterValue(0, 0, 0);
        contacts.Add(new CollisionContact(a, b, m.hit.normal, con, val.imp_n, val.imp_t));        
      end;
    end;
    
    procedure solved();
    begin
      if (frame_idx mod 512 = 0) then
      begin
        _remove_list.clear();
        foreach var kv in arbiters do
          if (frame_idx - kv.Value.life_time) > max_life_time then
            _remove_list.Add(kv.Key);
        foreach var k in _remove_list do 
          arbiters.Remove(k);
      end;
      foreach var con in contacts do
      begin
        var key := new ArbiterKey(con.body_a, con.body_b, con.point.id);
        arbiters[key] := new ArbiterValue(con.acc_imp_n, con.acc_imp_t, frame_idx);
      end;     
    end;
  end;
  
  IConstraint = interface
    procedure recalc(dt: real; a, b: RigidBody);
    procedure warm_start(a, b: RigidBody);
    procedure solve(a, b: RigidBody);
  end;
  
  BaseConstraint = abstract class(IConstraint)
  private
    m_enabled: boolean;
  public
    property enabled: boolean read m_enabled write begin if m_enabled <> value then reset(); m_enabled := value; end;
    constructor create(en: boolean := true) := enabled := en;
    procedure reset(); abstract;
    procedure recalc(dt: real; a, b: RigidBody); abstract;
    procedure warm_start(a, b: RigidBody); abstract;
    procedure solve(a, b: RigidBody); abstract;
  end;
  
  
  //High priority constraint
  GeomConstraint = abstract class(BaseConstraint)
  public
    compliance: ComplianceSpec := new ComplianceSpec();
    procedure recalc(dt: real; a, b: RigidBody); override;
    begin
      if not enabled then exit;
      compliance.recalc(dt);
    end;
  end;
  
  //Low priority constraint
  MotorConstraint = abstract class(BaseConstraint)
  
  end;
  
  Joint = abstract class
  private
    m_body_a, m_body_b: RigidBody;
    m_constraints: List<BaseConstraint>;
  protected
    property core_constraints: List<BaseConstraint> read m_constraints;
  public
    property body_a: RigidBody read m_body_a;
    property body_b: RigidBody read m_body_b;
    auto property tag: object;
    
    constructor create(body_a, body_b: RigidBody; constraints: IEnumerable<BaseConstraint> := nil; tag: object := nil);
    begin
      m_body_a := body_a;
      m_body_b := body_b;   
      m_constraints := new List<BaseConstraint>();
      if constraints <> nil then
        m_constraints.AddRange(constraints);
      self.tag := tag;
    end;
    
    procedure recalc(dt: real) := for var i := 0 to m_constraints.count - 1 do m_constraints[i].recalc(dt, m_body_a, m_body_b);
    procedure warm_start() := for var i := 0 to m_constraints.count - 1 do m_constraints[i].warm_start(m_body_a, m_body_b);
    procedure solve() := for var i := 0 to m_constraints.count - 1 do m_constraints[i].solve(m_body_a, m_body_b);
    procedure set_enabled(enabled: boolean) := for var i := 0 to m_constraints.count - 1 do m_constraints[i].enabled := enabled;
    
    procedure set_compliance(comp: ComplianceSpec);
    begin
      for var i := 0 to m_constraints.count - 1 do
        if m_constraints[i] is GeomConstraint(var gc) then
          gc.compliance := comp;
    end;
  end;
  
  
  CollisionResolver = class
  public
    static function get_vel_bias(body_a, body_b: RigidBody; vn_init, vel_slop: real): real;
    begin
      if (vn_init >= 0) or (-vn_init < vel_slop) then exit(0);
      var e := Material.mix_rest(body_a.mat, body_b.mat);
      result := -e * vn_init;
    end;
  
  public
    iters: integer;
    warm_factor: real;
    baumgarte: real;
    pos_slop: real;
    vel_slop: real;
    
    constructor create(
    iters: integer := 15; warm_factor: real := 1.0; 
    baumgarte: real := 0.1; pos_slop: real := 0.03; 
    vel_slop: real := 0.2);
    begin
      self.iters := iters;
      self.warm_factor := warm_factor;
      self.baumgarte := baumgarte;
      self.pos_slop := pos_slop;
      self.vel_slop := vel_slop;
    end;
    
    procedure recalc(var con: CollisionContact; dt: real);
    begin
      with con do
      begin
        var r_a := point.pos - body_a.pos;
        var r_b := point.pos - body_b.pos;              
        var k_matr := PairUtils.get_k_matr(body_a, body_b, r_a, r_b, 0);
        var mass_normal := k_matr.effective_mass(hit_normal);
        var mass_tangent := k_matr.effective_mass(hit_normal.Ortog());
        var vn_init := PairUtils.get_rel_vel_r(body_a, body_b, r_a, r_b) * hit_normal;        
        var pos_bias := PairUtils.get_bias(max(0, point.depth - pos_slop), baumgarte, dt);  
        var vel_bias := get_vel_bias(body_a, body_B, vn_init, vel_slop);     
        con.resolver_data := new ContactResolverData(r_a, r_b, mass_normal, mass_tangent, vel_bias, pos_bias);
      end;
    end;
    
    procedure warm_start(var con: CollisionContact);
    begin
      con.acc_imp_n := con.acc_imp_n * warm_factor;
      con.acc_imp_t := con.acc_imp_t * warm_factor;
      var imp := con.hit_normal * con.acc_imp_n + con.hit_normal.ortog() * con.acc_imp_t;
      var data := con.resolver_data;
      PairUtils.add_impulse_r(con.body_a, con.body_b, data.rad_a, data.rad_b, imp);
    end;
    
    procedure solve_vel(var con: CollisionContact);
    begin
      var data := con.resolver_data;
      var (a, b) := (con.body_a, con.body_b);
      var (r_a, r_b) := (data.rad_a, data.rad_b);
      begin
        var vn := PairUtils.get_rel_vel_r(a, b, r_a, r_b) * con.hit_normal;
        var jn := (data.vel_bias - vn) * data.mass_normal;              
        var delta := PairUtils.solve_impulse(con.acc_imp_n, jn, IntervalSide.LowerSide);        
        PairUtils.add_impulse_r(a, b, r_a, r_b, con.hit_normal * delta);
      end;
      begin
        var vn := PairUtils.get_rel_vel_r(a, b, r_a, r_b, ps := true) * con.hit_normal;
        var jn := max(data.pos_bias - vn, 0.0) * data.mass_normal;
        PairUtils.add_impulse_r(a, b, r_a, r_b, con.hit_normal * jn, ps := true);
      end;
    end;
    
    procedure solve_fric(var con: CollisionContact);
    begin
      var data := con.resolver_data;
      var (a, b) := (con.body_a, con.body_b);
      var (r_a, r_b) := (data.rad_a, data.rad_b);
      var tangent := con.hit_normal.Ortog();
      var vt := PairUtils.get_rel_vel_r(a, b, r_a, r_b) * tangent;
      var jt := -vt * data.mass_tangent;
      var max_jt := con.acc_imp_n * Material.mix_fric(a.mat, b.mat);
      var delta := PairUtils.solve_impulse(con.acc_imp_t, jt, max_jt);
      PairUtils.add_impulse_r(a, b, r_a, r_b, tangent * delta);
    end;
    
    procedure solve(dt: real; contacts: IList<CollisionContact>; joints: IList<Joint>);
    begin
      for var i := 0 to contacts.Count - 1 do
      begin
        var con := contacts[i];
        recalc(con, dt);
        contacts[i] := con;
      end;
      for var i := 0 to joints.Count - 1 do
        joints[i].recalc(dt);
      
      for var i := 0 to contacts.Count - 1 do
      begin
        var con := contacts[i];
        warm_start(con);
        contacts[i] := con;
      end;
      for var i := 0 to joints.Count - 1 do
        joints[i].warm_start();
      
      loop iters do
      begin
        for var i := 0 to joints.Count - 1 do
          joints[i].solve();
        
        for var i := 0 to contacts.Count - 1 do
        begin
          var con := contacts[i];
          solve_vel(con);
          solve_fric(con);
          contacts[i] := con;
        end;
      end;      
    end;
  end;
  {$endregion}
  
  ColFamilyManager = class
  public
    ///0 means no information, -1 lack of collision, 1 has collision
    static function id_collide(a, b: integer) := (a = b) ? sign(a) : 0;
  private
    m_world: IReadOnlyList<RigidBody>;
    m_id: integer;
    
    procedure replace(old_id, new_id: integer);
    begin
      if old_id = new_id then exit;
      foreach var body in m_world do
        if body.fam_ind = old_id then
          body.m_fam_ind := new_id;      
    end;
    
    function request_id(collidable: boolean := false): integer;
    begin
      result := collidable ? m_id : -m_id;
      m_id += 1;
    end;
  
  public
    constructor create(world: IReadOnlyList<RigidBody>; start_id: integer := 1);
    begin
      self.m_world := world;
      self.m_id := start_id;
    end;
    
    property id: integer read m_id;
    
    procedure bind(collidable: boolean; params bodies: array of RigidBody);
    begin
      var id := request_id(collidable);
      bodies.ForEach(b -> ( b.m_fam_ind := id));
    end;
    
    procedure bind(params bodies: array of RigidBody) := bind(false, bodies);
    procedure adopt(parent_id: integer; params childs: array of RigidBody) := childs.ForEach(c -> ( c.m_fam_ind := parent_id));
    procedure leave(params bodies: array of RigidBody) := adopt(0, bodies);
    procedure set_collidable(id: integer; coll: boolean) := replace(id, abs(id) * (coll ? 1 : -1));
    //TODO coll not used
    function get_collidable(id: integer; coll: boolean) := m_world.First(b -> b.m_fam_ind = id).m_fam_ind >= 0;
    
    procedure unite(a, b: RigidBody);
    begin
      var a_fam := a.fam_ind;
      var b_fam := b.fam_ind;
      
      if (a_fam = b_fam) and (a_fam <> 0) then exit;
      if (a_fam = 0) and (b_fam = 0) then begin bind(false, a, b); exit; end;
      if a_fam = 0 then begin a.m_fam_ind := b.m_fam_ind; exit; end;      
      if b_fam = 0 then begin b.m_fam_ind := a.m_fam_ind; exit; end;       
      
      var (old_id, new_id) := (a_fam, b_fam);
      if abs(old_id) > abs(new_id) then swap(old_id, new_id);
      if (old_id < 0) and (new_id > 0) then swap(old_id, new_id);
      replace(old_id, new_id);
    end;   
  end;
  
  PhysWorld = class    
  private
    m_family_mgr: ColFamilyManager;
    m_cached_group_aabb: List<BoundBox>;
    m_ticker: TimeTicker;
    m_ground: RigidBody;
  public
    bodies: List<RigidBody>;
    solver: CollisionResolver;
    grav: Vector;
    bounds_body: RigidBody;
    con_mgr: ContactManager;
    joints: List<Joint>;
    
    property ground: RigidBody read m_ground;
    
    constructor create(grav: Vector := bl_vect(0, -3); freq: real := 60; max_steps: integer := 10);//TODO replace by (0,-9.8)
    begin
      bodies := new List<RigidBody>();
      solver := new CollisionResolver();
      self.grav := grav;
      con_mgr := new ContactManager();
      joints := new List<Joint>();
      m_family_mgr := new ColFamilyManager(bodies);
      m_cached_group_aabb := new List<BoundBox>();
      m_ticker := new TimeTicker(freq, max_steps);
      m_ground := new RigidBody(new ShapeGroup(|Circle.create(0).at(0, 0)|), bl_trans0, true);
    end;
    
    procedure set_bounds(group: ShapeGroup; tr: Transform := bl_trans0; mat: material ?:= nil) := bounds_body := new RigidBody(group, tr, true, mat);
    procedure set_bounds(box: BoundBox; thickness: real; mat: material ?:= nil);
    begin
      box := box.expand(-thickness);
      var p := Polygon.box(box.width, box.height);
      set_bounds(ShapeGroup.make_hollow(p, thickness, true), bl_trans(box.center), mat);
    end;
    
    property bounds: ShapeGroup read bounds_body <> nil ? bounds_body.group : nil write set_bounds(value);
    property family_mgr: ColFamilyManager read m_family_mgr;
    property ticker: TimeTicker read m_ticker;
    
    function add_body(
    shape: ShapeGroup; 
    pos: Vector := bl_vect0; 
    ang: real := 0.0;
    is_static: boolean := false;
    mat: Material ?:= nil;
    mass: real ? := nil;
    damp: Damping ?:= nil; 
    tag: object := nil): RigidBody;
    begin
      result := new RigidBody(shape, bl_trans(pos, ang), is_static, mat := mat, custom_mass := mass, damp := damp, tag := tag);
      self.bodies.Add(result);
    end;
    
    function add_joint(jnt: Joint; unite: boolean := true): Joint;
    begin
      var (a, b) := (jnt.body_a, jnt.body_b);
      assert(not ref_eql(a, b));
      var a_dflt := ref_eql(a, bounds_body) or ref_eql(a, ground);
      var b_dflt := ref_eql(b, bounds_body) or ref_eql(b, ground);
      var a_ok :=  bodies.Contains(a) or a_dflt;
      var b_ok := bodies.Contains(b) or b_dflt;
      assert(a_ok and b_ok);
      joints.Add(jnt);
      if unite and not a_dflt and not b_dflt  then family_mgr.unite(a, b);
      result := jnt;
    end;
    
    procedure remove_body(body: RigidBody);
    begin
      bodies.Remove(body);
      joints.RemoveAll(j -> ref_eql(j.body_a, body) or ref_eql(j.body_b, body));
    end;
    
    function query_point(pt: Vector; var part_ind: integer; pred: Func<RigidBody, boolean> := nil): RigidBody;
    begin
      if pred = nil then pred := b -> true;
      part_ind := -1;
      for var i := bodies.Count - 1 downto 0 do
      begin
        var body := bodies[i];
        if (pred(body)) and (ShapeQuery.test_point(body.group, body.tr, pt, part_ind)) then 
          exit(body);
      end;
      if (bounds_body <> nil) then
        if (pred(bounds_body)) and (ShapeQuery.test_point(bounds_body.group, bounds_body.tr, pt, part_ind)) then
          exit(bounds_body);
      result := nil;
    end;
    
    function query_point(pt: Vector; pred: Func<RigidBody, boolean> := nil): RigidBody;
    begin
      var dummy: integer;
      result := query_point(pt, dummy, pred);
    end;
    
    procedure check_collision(a: RigidBody; b: RigidBody);
    begin
      if ColFamilyManager.id_collide(a.m_fam_ind, b.m_fam_ind) < 0 then exit;
      if a.is_static and b.is_static then exit;        
      CollisionDetector.check(a.group, b.group, a.tr, b.tr, manifold -> con_mgr.add_manifold(a, b, manifold), test_group_aabb := False);
    end;
    
    procedure collide();
    begin
      m_cached_group_aabb.Clear();
      for var i := 0 to bodies.Count - 1 do
        m_cached_group_aabb.Add(bodies[i].aabb);      
      
      if bounds_body <> nil then
      begin
        var bounds_aabb := bounds_body.aabb;
        for var i := 0 to bodies.Count - 1 do
        begin
          if (not BoundBox.intersect(m_cached_group_aabb[i], bounds_aabb)) then continue;
          check_collision(bodies[i], bounds_body);  
        end;
      end;
      for var i := 0 to bodies.Count - 1 do
        for var j := i + 1 to bodies.Count - 1 do
        begin
          if (not BoundBox.intersect(m_cached_group_aabb[i], m_cached_group_aabb[j])) then continue;
          check_collision(bodies[i], bodies[j]);
        end;
    end;
    
    procedure step(dt: real);
    begin
      if bounds_body <> nil then assert(bounds_body.is_static);
      foreach var b in bodies do
        b.integ_vel(dt, grav);      
      con_mgr.new_frame();
      collide();
      solver.solve(dt, con_mgr.contacts, joints);
      con_mgr.solved();
      
      foreach var b in bodies do
        b.integ_pos(dt);
    end;
    
    function simulate(dt: real): integer;
    begin
      result := m_ticker.update(dt);
      loop result do
        step(m_ticker.period);
    end;
  end;

function bl_group(params parts: array of TrShape) := new ShapeGroup(parts);

function bl_group(shap: Shape) := bl_group(shap.centered());

function bl_group_centered(params shapes: array of Shape) := new ShapeGroup(shapes.Select(s -> s.centered()));

end.
