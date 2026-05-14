uses System, System.Reflection;
uses GraphWPFBase, GraphWPF, Controls, System.Windows.Input;
uses balance, balance_wpf;
uses demos_helper, demos;

type
  InputSystemWPF = class(IInputSource)
  private
    m_keyboard: KeyboardInput;
    m_mousedr: MouseDragger;
  public
    property keyboard: KeyboardInput read m_keyboard;
    property mousedr: MouseDragger read m_mousedr;
    
    constructor create(mouse_max_speed: real := 100);
    begin
      m_keyboard := new KeyboardInput();
      m_mousedr := new MouseDragger(mouse_max_speed);
    end;
    
    procedure on_mouse_down(x, y: real; md: integer; world: PhysWorld; view: Viewport);
    begin
      if md <> 2 then exit; 
      Mouse.Capture(MainDockPanel());
      mousedr.on_mouse_down(world, view.to_world(bl_vect(x, y)));
    end;
    
    procedure on_mouse_up(x, y: real; md: integer; world: PhysWorld; view: Viewport);
    begin
      Mouse.Capture(nil);
      mousedr.on_mouse_up(world);
    end;
    
    procedure on_mouse_move(x, y: real; md: integer; world: PhysWorld; view: Viewport);
    begin
      if md <> 2 then exit; 
      mousedr.on_mouse_move(view.to_world(bl_vect(x, y)));
    end;
    
    procedure on_key_down(k: Key);
    begin
      keyboard.on_key_down(k.ToString());
    end;
    
    procedure on_key_up(k: Key);
    begin
      m_keyboard.on_key_up(k.ToString());
    end;
    
    procedure on_frame(dt: real; world: PhysWorld);
    begin
      mousedr.accept_frame(world, dt);
    end;
    
    procedure reset(world: PhysWorld);
    begin
      m_keyboard.reset();
      m_mousedr.reset(world);
    end;
    
    // --- IInputSource ---
    function is_key_down(key: string) := m_keyboard.is_key_down(key);
    function is_mouse_drag() := mousedr.is_captured;
    procedure get_mouse(var btn: integer; var pos: blVector);
    begin
      var pt_pos := System.Windows.Input.Mouse.GetPosition(Canvas.WPFCanvas);
      pos := bl_vect(pt_pos.X, pt_pos.Y);
      btn := 0;
      if System.Windows.Input.Mouse.LeftButton = MouseButtonState.Pressed then 
        btn := 1
      else if System.Windows.Input.Mouse.RightButton = MouseButtonState.Pressed then 
        btn := 2;  
    end;
  end;
  
  DemoListBoxWPF = class(ListBoxWPF)
  public
    constructor(title: string; height: real);
    begin
      //lb.Focusable := false; lb.IsTabStop := false;
      inherited Create(title, height);
      Invoke(() -> begin
        lb.IsTextSearchEnabled := false; 
        lb.AddHandler(System.Windows.Controls.ListBox.KeyDownEvent, 
          System.Windows.Input.KeyEventHandler((s: object; e: System.Windows.Input.KeyEventArgs) -> 
        begin if e.Key = System.Windows.Input.Key.Space then e.Handled := false; end), true);
      end);
    end;
  end;
  
  DemoComboBoxWPF = class(ComboBoxWPF)
  private
    function get_cb: System.Windows.Controls.ComboBox;
    begin
      var p := System.Windows.Controls.Panel(self.element);
      result := System.Windows.Controls.ComboBox(p.Children[1]);
    end;
  
  public
    procedure set_selected_index(ind: integer) := Invoke(procedure(v: integer) -> get_cb().SelectedIndex := v, ind);
    procedure set_selected_text(txt: string) := Invoke(procedure(s: string) -> get_cb().SelectedItem := s, txt);
  end;
  
  DemoPanelWPF = class(PanelWPF)
  private
    m_root: System.Windows.Controls.Border;
  public
    property panel: System.Windows.Controls.StackPanel read self.element as System.Windows.Controls.StackPanel;
    property root: System.Windows.Controls.Border read m_root;
    property Visible: boolean
    read InvokeBoolean(() ->  root.Visibility = System.Windows.Visibility.Visible)
    write Invoke(procedure(v: boolean) -> root.Visibility := v ? System.Windows.Visibility.Visible : System.Windows.Visibility.Collapsed, value);
    procedure make_vert_scrollable();
    begin
      Invoke(()-> 
      begin
        var scroll := new System.Windows.Controls.ScrollViewer();
        scroll.VerticalScrollBarVisibility := System.Windows.Controls.ScrollBarVisibility.Auto;
        scroll.HorizontalScrollBarVisibility := System.Windows.Controls.ScrollBarVisibility.Disabled;
        root.Child := nil; 
        scroll.Content := panel;
        root.Child := scroll;
      end);
    end;
    
    constructor create(width: real; d: Dock; vscroll: boolean := true);
    begin
      inherited create(width, d, PanelsColor, 10);
      m_root := panel.Parent as System.Windows.Controls.Border;
      if vscroll then make_vert_scrollable();
    end;
  end;
  
  DemoUI = class
  public
    static procedure slider_set(slider: SliderWPF; v: integer);
    begin
      slider.Minimum := min(slider.Minimum, v);
      slider.Maximum := max(slider.Maximum, v);
      slider.Value := v;
    end;
    
    static procedure slider_set(slider: SliderRealWPF; v: real);
    begin
      slider.Minimum := min(slider.Minimum, v);
      slider.Maximum := max(slider.Maximum, v);
      slider.Value := v;
    end;
  
  public
    sc_list: ListBoxWPF;
    sc_reset: ButtonWPF;
    sc_show_prms: CheckBoxWPF;
    
    wrd_grav, wrd_hz: SliderRealWPF;
    
    slv_iters: SliderWPF;
    slv_warm_factor, slv_baumgarte, slv_pos_slop, slv_vel_slop: SliderRealWPF;
    
    dbg_aabb, dbg_vels, dbg_cons: CheckBoxWPF;
    
    procedure add_demos(names: IEnumerable<string>; on_demo_selected: (integer)->());
    begin
      //NOTE sc_list.clear not provided
      names.ForEach(name -> sc_list.Add(name));
      sc_list.SelectionChanged := ()->on_demo_selected(sc_list.SelectedIndex);
      sc_list.SelectedIndex := 0;
    end;
    
    procedure world_sync(world: PhysWorld; from_ui_to_solver: boolean);
    begin
      var solver := world.solver;
      if from_ui_to_solver then
      begin
        world.grav := bl_vect(0, -wrd_grav.Value);
        world.ticker.freq := wrd_hz.Value;
        solver.iters := slv_iters.Value;
        solver.warm_factor := slv_warm_factor.Value;
        solver.baumgarte := slv_baumgarte.Value;
        solver.pos_slop := slv_pos_slop.Value;
        solver.vel_slop := slv_vel_slop.Value
      end else 
      begin
        slider_set(wrd_grav, -world.grav.y);
        slider_set(wrd_hz, world.ticker.freq);
        world.ticker.freq := wrd_hz.Value;
        
        slider_set(slv_iters, solver.iters);
        slider_set(slv_warm_factor, solver.warm_factor);
        slider_set(slv_baumgarte, solver.baumgarte);
        slider_set(slv_pos_slop, solver.pos_slop);
        slider_set(slv_vel_slop, solver.vel_slop);
      end;
    end;
    
    constructor create(reset_click: ()->(); show_prms_click: boolean->());
    begin
      new DemoPanelWPF(170, Dock.Left);
      sc_list := new DemoListBoxWPF('', 130);
      
      sc_reset := Button('Reset');
      sc_reset.Click := reset_click; 
      
      sc_show_prms := CheckBox('Show parameters');
      sc_show_prms.Click := ()->show_prms_click(sc_show_prms.Checked);
      sc_show_prms.Checked := true;
      
      TextBlock('World');
      wrd_grav := SliderReal('Gravity', 0, 15, freq := 1);
      wrd_hz := SliderReal('Hertz', 5, 240, freq := 5);
      
      TextBlock('Solver');
      slv_iters := Slider('Iterations', 2, 30, freq := 2);
      slv_warm_factor := SliderReal('Warm Start', 0, 1, freq := 0.1);
      slv_baumgarte := SliderReal('Pos Correction', 0, 0.5, freq := 0.05);
      slv_pos_slop := SliderReal('Pos Slop', 0, 0.1, freq := 0.01);
      slv_vel_slop := SliderReal('Restitution Vel Slop', 0, 1.0, freq := 0.05);
      
      TextBlock('Debug');
      dbg_aabb := CheckBox('Bound boxes');
      dbg_vels := CheckBox('Velocities');
      dbg_cons := CheckBox('Contacts');
    end;
  end;
  
  UISceneWPFBuilderCtx = record
    on_reset, on_step: ()->();
    owner: object;
    ind: integer;
    constructor create(on_reset, on_step: ()->(); owner: object; ind: integer);
    begin
      self.on_reset := on_reset;
      self.on_step := on_step;
      self.owner := owner;
      self.ind := ind;
    end;
    
    function replace(owner: object; ind: integer) := new UISceneWPFBuilderCtx(on_reset, on_step, owner, ind);
    
    procedure call_step();
    begin
      if on_step <> nil then on_step();
    end;
  end;
  
  UISceneWPFBuilder = static class
  public
    static function display_text(attr: UIControlAttribute; ind: integer) := UIHelper.get_display_text(attr, ind);
    
    static procedure call_reset(ctx: UISceneWPFBuilderCtx; kind: UIAttributeKind);
    begin
      if kind = UIAttributeReset then
        ctx.on_reset();        
    end;
    
    static procedure on_changed(ctx: UISceneWPFBuilderCtx; kind: UIAttributeKind; val: object; m: MemberInfo);
    begin
      UIHelper.set_member_val(m, ctx.owner, val);
      call_reset(ctx, kind);   
    end;
    
    static procedure on_click(ctx: UISceneWPFBuilderCtx; kind: UIAttributeKind;  method: MethodInfo);
    begin
      method.Invoke(ctx.owner, nil);
      call_reset(ctx, kind);       
    end;
    
    static procedure create_element(ctx: UISceneWPFBuilderCtx; attr: UISliderIntAttribute; m: MemberInfo);
    begin
      var elem := Slider(display_text(attr, ctx.ind), attr.min, attr.max, integer(UIHelper.get_member_val(m, ctx.owner)), attr.freq);
      elem.ValueChanged := ()->on_changed(ctx, attr.kind, elem.Value, m);
    end;
    
    static procedure create_element(ctx: UISceneWPFBuilderCtx; attr: UISliderRealAttribute; m: MemberInfo);
    begin
      var elem := SliderReal(display_text(attr, ctx.ind), attr.min, attr.max, real(UIHelper.get_member_val(m, ctx.owner)), attr.freq);
      elem.ValueChanged := ()->on_changed(ctx, attr.kind, elem.Value, m);      
    end;
    
    static procedure create_element(ctx: UISceneWPFBuilderCtx; attr: UICheckboxAttribute; m: MemberInfo);
    begin
      var elem := CheckBox(display_text(attr, ctx.ind));
      elem.Checked := boolean(UIHelper.get_member_val(m, ctx.owner));
      elem.Click := ()->on_changed(ctx, attr.kind, elem.Checked, m);
    end;
    
    static procedure create_element(ctx: UISceneWPFBuilderCtx; attr: UIComboboxAttribute; m: MemberInfo);
    begin
      var elem := new DemoComboBoxWPF(display_text(attr, ctx.ind));
      var enum_type := UIHelper.get_member_type(m);
      var val_str := UIHelper.get_member_val(m, ctx.owner).ToString();
      var full_names := System.Enum.GetNames(enum_type);
      full_names.ForEach(n -> elem.Add(UIHelper.get_display_name_for_enum_item(n)));
      elem.set_selected_index(&Array.IndexOf(full_names, val_str));
      elem.SelectionChanged := () -> on_changed(ctx, attr.kind, Enum.Parse(enum_type, full_names[elem.SelectedIndex]), m);
    end;
    
    static procedure create_element(ctx: UISceneWPFBuilderCtx; attr: UIRadiobuttonAttribute; m: MemberInfo);
    begin
      var parent := controls.__ActivePanelInternal();
      new StackPanelWPF(Orientation.Vertical);
      if not string.IsNullOrEmpty(attr.text) then
        TextBlock(display_text(attr, ctx.ind));
      var enum_type := UIHelper.get_member_type(m);
      var val_str := UIHelper.get_member_val(m, ctx.owner).ToString();
      foreach var full_name in System.Enum.GetNames(enum_type) do
      begin
        var rb := RadioButton(UIHelper.get_display_name_for_enum_item(full_name));
        if full_name = val_str then rb.Checked := true;
        rb.Click := () -> on_changed(ctx, attr.kind, Enum.Parse(enum_type, full_name), m);
      end;
      //TODO SetActivePanel(parent);
      controls.__SetActivePanelInternal(parent);
    end;
    
    static procedure create_element(ctx: UISceneWPFBuilderCtx; attr: UIButtonAttribute; m: MethodInfo);
    begin
      assert(m <> nil);
      assert(m.GetParameters().Length = 0);
      var elem := Button(display_text(attr, ctx.ind));
      elem.Click := () -> on_click(ctx, attr.kind, m);
    end;
    
    static procedure build_ui_step(ctx: UISceneWPFBuilderCtx);
    begin
      var members := ctx.owner.GetType().GetMembers(BindingFlags.Instance or BindingFlags.Public).OrderBy(m -> m.MetadataToken);
      foreach var m in members do
      begin
        var ui_attr := m.GetCustomAttribute&<UIBuilderAttribute>();
        if ui_attr = nil then continue;
        ctx.call_step();
        match ui_attr with
          UIExpandAttribute(var attr): 
            begin
              var val := UIHelper.verify_expand_attr_field(m, UIHelper.get_member_val(m, ctx.owner));
              var i := 0;
              foreach var item in val do
              begin
                UIHelper.verify_expand_attr_item(item, i, m.Name);
                build_ui_step(ctx.replace(item, i));
                i += 1;
              end;
            end;
          UISliderIntAttribute(var attr): create_element(ctx, attr, m);
          UISliderRealAttribute(var attr): create_element(ctx, attr, m);
          UICheckboxAttribute(var attr): create_element(ctx, attr, m);
          UIComboboxAttribute(var attr): create_element(ctx, attr, m);
          UIRadioButtonAttribute(var attr): create_element(ctx, attr, m);
          UIButtonAttribute(var attr): create_element(ctx, attr, m as MethodInfo);
          else assert(false, $'Unimplemented attribute: {ui_attr}');
        end;
      end;
    end;
  
  public
    static function build_ui(sc: BaseScene; on_reset: ()->(); width: real; title: string): DemoPanelWPF;
    begin
      var create_scene_panel: Func<DemoPanelWPF> := ()->
      begin
        result := new DemoPanelWPF(width, Dock.Right);
        if not string.IsNullOrEmpty(title) then
          TextBlock(title);
      end;
      var sc_panel: DemoPanelWPF;// := create_scene_panel();;
      var ctx := new UISceneWPFBuilderCtx(on_reset, ()->begin if sc_panel = nil then sc_panel := create_scene_panel(); end, sc, -1);
      build_ui_step(ctx);
      result := sc_panel;
    end; 
  end;


var
  ui: DemoUI;
  input: InputSystemWPF;
  sc: BaseScene;
  sc_panel: DemoPanelWPF;

procedure reset_scene() := sc.reset(Canvas.Width, Canvas.Height);

procedure on_resize();
begin
  Canvas.resized();
  sc.resize(Canvas.Width, Canvas.Height)
end;

procedure on_show_prms_changed(checked: boolean);
begin
  if sc_panel = nil then exit;
  sc_panel.Visible := checked;
  on_resize();
end;

procedure on_demo_select(ind: integer);
begin
  if sc <> nil then input.reset(sc.world);
  sc := BaseScene(Activator.CreateInstance(all_scenes[ind]));
  sc.on_reset := sc -> input.reset(sc.world);
  reset_scene();
  ui.world_sync(sc.world, false);
  if sc_panel <> nil then Invoke(() ->MainDockPanel.Children.Remove(sc_panel.root));
  sc_panel := UISceneWPFBuilder.build_ui(sc, reset_scene, 170, 'Scene parameters');
  ui.sc_show_prms.Click();
  on_resize();
end;

procedure on_frame(dt: real);
begin
  sc.pre_frame(input);
  input.on_frame(dt, sc.world);
  ui.world_sync(sc.world, true);
  
  start_fps();
  var steps := sc.world.simulate(dt);
  var fps := stop_fps();
  
  sc.post_frame(input, steps);
  Window.Clear(colors.Black);
  dbg_draw_world(sc.world, sc.view, bbox := ui.dbg_aabb.Checked, vel := ui.dbg_vels.Checked, cons := ui.dbg_cons.Checked);
  DrawText(50, 0, 100, 10, $'Phys FPS: {fps:f0}, OBJS={sc.world.bodies.Count} ', Colors.Red);
end;


begin
  Window.Title := 'Balance Demos 02.05.2026';
  Window.Maximize();
  ui := new DemoUI(reset_scene, ch -> on_show_prms_changed(ch));
  input := new InputSystemWPF();
  ui.add_demos(all_scenes.Select(s -> s.GetCustomAttribute&<SceneNameAttribute>().name), on_demo_select);
  Pen.Color := Colors.White;
  OnKeyDown += k -> input.on_key_down(k);
  OnKeyUp += k -> input.on_key_up(k);
  OnMouseDown += (x, y, md) -> input.on_mouse_down(x, y, md, sc.world, sc.view);
  OnMouseUp += (x, y, md) -> input.on_mouse_up(x, y, md, sc.world, sc.view);
  OnMouseMove += (x, y, md) -> input.on_mouse_move(x, y, md, sc.world, sc.view);
  OnDrawFrame += on_frame;
  OnResize += on_resize;
end.