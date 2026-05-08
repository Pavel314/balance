//Auto-generated on 2026.05.06. 04:18:28
unit balance;
uses balance_basic, balance_core, balance_joints;

type

//balance_basic
Vector = balance_basic.Vector;
Matrix2 = balance_basic.Matrix2;
FixedBuf2<T> = balance_basic.FixedBuf2<T>;
Transform = balance_basic.Transform;
MinMax = balance_basic.MinMax;
BoundBox = balance_basic.BoundBox;
ViewportResizeMode = balance_basic.ViewportResizeMode;
Camera = balance_basic.Camera;
Viewport = balance_basic.Viewport;
Utils = balance_basic.Utils;
IntervalSide = balance_basic.IntervalSide;
Interval = balance_basic.Interval;
TimeTicker = balance_basic.TimeTicker;
FpsCounter = balance_basic.FpsCounter;
Material = balance_basic.Material;
Materials = balance_basic.Materials;
Damping = balance_basic.Damping;
ComplianceMode = balance_basic.ComplianceMode;
ComplianceSpec = balance_basic.ComplianceSpec;

//balance_core
Shape = balance_core.Shape;
TrShape = balance_core.TrShape;
ShapeKind = balance_core.ShapeKind;
PolygonEdge = balance_core.PolygonEdge;
Polygon = balance_core.Polygon;
Circle = balance_core.Circle;
CollisionHit = balance_core.CollisionHit;
GeomUtils = balance_core.GeomUtils;
ContactID = balance_core.ContactID;
ContactPoint = balance_core.ContactPoint;
CollisionManifold = balance_core.CollisionManifold;
SATVertexID = balance_core.SATVertexID;
SATCollisionDetector = balance_core.SATCollisionDetector;
ShapeGroup = balance_core.ShapeGroup;
ShapeQuery = balance_core.ShapeQuery;
CollisionDetector = balance_core.CollisionDetector;
RigidBody = balance_core.RigidBody;
PairUtils = balance_core.PairUtils;
ContactResolverData = balance_core.ContactResolverData;
CollisionContact = balance_core.CollisionContact;
ArbiterKey = balance_core.ArbiterKey;
ArbiterValue = balance_core.ArbiterValue;
ContactManager = balance_core.ContactManager;
IConstraint = balance_core.IConstraint;
BaseConstraint = balance_core.BaseConstraint;
GeomConstraint = balance_core.GeomConstraint;
MotorConstraint = balance_core.MotorConstraint;
Joint = balance_core.Joint;
CollisionResolver = balance_core.CollisionResolver;
ColFamilyManager = balance_core.ColFamilyManager;
PhysWorld = balance_core.PhysWorld;

//balance_joints
LineAnchor = balance_joints.LineAnchor;
PointAnchor = balance_joints.PointAnchor;
DistanceAnchor = balance_joints.DistanceAnchor;
AngleMotor = balance_joints.AngleMotor;
LineMotor = balance_joints.LineMotor;
AngleConstraint = balance_joints.AngleConstraint;
PointConstraint = balance_joints.PointConstraint;
DistanceConstraint = balance_joints.DistanceConstraint;
LineConstraint = balance_joints.LineConstraint;
GenericJoint = balance_joints.GenericJoint;
DistanceJoint = balance_joints.DistanceJoint;
RevoluteJoint = balance_joints.RevoluteJoint;
LineJoint = balance_joints.LineJoint;
Joints = balance_joints.Joints;

//balance_basic
function bl_vect(vx, vy: real) := balance_basic.bl_vect(vx, vy);
function bl_trans(pos: Vector; ang: real := 0) := balance_basic.bl_trans(pos, ang);
function bl_trans(x, y: real; ang: real := 0) := balance_basic.bl_trans(x, y, ang);
function bl_intr(min, max: real) := balance_basic.bl_intr(min, max);
function bl_intr(v: real) := balance_basic.bl_intr(v);

//balance_core
function bl_group(params parts: array of TrShape) := balance_core.bl_group(parts);
function bl_group(shap: Shape) := balance_core.bl_group(shap);
function bl_group_centered(params shapes: array of Shape) := balance_core.bl_group_centered(shapes);

const

//balance_basic
bl_vect0 = balance_basic.bl_vect0;
bl_matr2id = balance_basic.bl_matr2id;
bl_trans0 = balance_basic.bl_trans0;
bl_intr0 = balance_basic.bl_intr0;

begin
end.
