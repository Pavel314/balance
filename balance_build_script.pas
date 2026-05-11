uses System, System.IO, System.Diagnostics, System.Reflection;
//TODO[DONE] контрукторы
//TODO события
//TODO[DONE] do not export bl_unwrap_or

type
  PascalModule = class
  public
    module_name: string;
    depends: HashSet<string> := new HashSet<string>(StringComparer.OrdinalIgnoreCase);
    
    constructor create(n: string; params mods: array of PascalModule);
    begin
      self.module_name := n;
      foreach var m in mods do
      begin
        self.depends.Add(m.module_name);
        self.depends.UnionWith(m.depends);
      end;
    end;
    
    constructor create(n: string; depends: array of string);
    begin
      self.module_name := n;
      if depends <> nil then self.depends.UnionWith(depends);
    end;
  end;
  
  PascalInspector = class
    
    static type_aliases := Dict(
      ('Byte',    'byte'),
      ('Int32',   'integer'),
      ('Int64',   'int64'),
      ('UInt32',  'cardinal'),
      ('Double',  'real'),
      ('Single',  'single'),
      ('Boolean', 'boolean'),
      ('Char',    'char'),
      ('String',  'string'),
      ('Object',  'object'),
      ('Decimal', 'decimal'));
    
    static method_op_map := Dict&<string, string>(
    ('op_Addition', string('+')),
    ('op_Subtraction', string('-')),
    ('op_Multiply', string('*')),
    ('op_Division', string('/')),
    
    ('op_AdditionAssignment', '+='),
    ('op_SubtractionAssignment', '-='),
    ('op_MultiplicationAssignment', '*='),
    ('op_DivisionAssignment', '/='),
    
    ('op_Equality', string('=')),
    ('op_Inequality', '<>'),
    ('op_GreaterThan', string('>')),
    ('op_LessThan', string('<')),
    ('op_GreaterThanOrEqual', '>='),
    ('op_LessThanOrEqual', '<='),
    ('op_UnaryNegation', string('-')),
    ('op_True', 'is true'),
    ('op_False', 'is false'));
    
    static function get_type_category(t: &Type): string;
    begin
      if t.IsInterface then exit('interface');
      if t.IsEnum then exit('enum');
      if t.IsValueType then exit('record');
      if t.IsAbstract and t.IsSealed then exit('static class');
      if t.IsAbstract then exit('abstract class');
      exit('class');
    end;
    
    static function format_value(val: object): string;
    begin
      if val = nil then exit('nil');
      var t := val.GetType();
      if t = typeof(string) then exit($'''{val}''');
      if t = typeof(boolean) then exit(boolean(val) ? 'true' : 'false');
      exit(val.ToString());
    end;
    
    static function format_method_generic_params(m: MethodInfo): string;
    begin
      //TODO generics constraint
      if not m.IsGenericMethod then exit('');
      var args := m.GetGenericArguments().Select(a -> a.Name).JoinToString(', ');
      exit($'<{args}>');
    end;
    
    static function format_method_variant(m: MethodInfo): (string, string);
    begin
      if m.ReturnType = typeof(System.Void) then exit(('procedure ', ''));
      exit(('function ', $': {format_type(m.ReturnType)}'));
    end;
    
    static function format_method_params(prms: array of ParameterInfo): string;
    begin
      var groups := new List<string>;
      var i := 0;
      var can_group := (p1, p2: ParameterInfo):boolean -> 
      (p1.ParameterType = p2.ParameterType) and 
      (not p1.HasDefaultValue) and (not p2.HasDefaultValue) and
      (p1.Attributes = p2.Attributes);
      
      while i < prms.Length do
      begin
        var start := i;
        while (i < prms.Length - 1) and can_group(prms[i], prms[i + 1]) do 
          i += 1;
        
        var prm := prms[start];
        var prm_typ := prm.ParameterType;
        
        var modifer := '';
        if prm_typ.IsByRef then 
        begin
          modifer += prm.IsIn ? 'const ' : 'var ';
          prm_typ := prm_typ.GetElementType();
        end;
        if prm.IsDefined(typeof(System.ParamArrayAttribute), false) then
          modifer += 'params ';
        
        var prm_val := '';
        if prm.HasDefaultValue then
          prm_val := $' := {format_value(prm.DefaultValue)}';
        
        var names := prms[start:i + 1].Select(p -> p.Name).JoinToString(', ');
        groups.Add($'{modifer}{names}: {format_type(prm_typ)}{prm_val}');
        i += 1;
      end;
      Result := groups.JoinToString('; ');
    end;
  
  public
    static function format_type(t: &Type): string;
    begin
      var underlying := Nullable.GetUnderlyingType(t);
      if underlying <> nil then exit(format_type(underlying) + '?');      
      if t.IsArray then exit('array of ' + format_type(t.GetElementType()));      
      if t.IsGenericType then
      begin
        var base_name := t.Name.Split('`')[0];
        var args := t.GetGenericArguments().Select(a -> format_type(a)).JoinToString(', ');
        exit($'{base_name}<{args}>');
      end;
      var name: string;
      if (type_aliases.TryGetValue(t.Name, name)) then exit(name);
      exit(t.Name);
    end;
    
    static function format_field(f: FieldInfo): string;
    begin
      var prefix_part := '';
      var value_part := '';
      if f.IsStatic then prefix_part += 'static ';
      if f.IsLiteral then 
      begin
        prefix_part += 'const ';
        value_part := $' = {format_value(f.GetRawConstantValue())}';
      end;
      result := $'{prefix_part}{f.Name}: {format_type(f.FieldType)}{value_part}';
    end;
    
    static function format_constructor(c: ConstructorInfo) :=
    $'constructor({format_method_params(c.GetParameters)})';
    
    static function format_method(m: MethodInfo): string;
    begin
      var name := m.Name;
      var is_op := m.IsSpecialName and name.StartsWith('op_');
      if is_op then
      begin
        var op_symbol := '';
        if method_op_map.TryGetValue(name, op_symbol) then
          name := $'operator{op_symbol}';
      end;
      var (proc_part, ret_part) := format_method_variant(m);
      var generic_part := format_method_generic_params(m);
      var prms_part := format_method_params(m.GetParameters);
      var prefix_part := m.IsStatic ? 'static ' : '';
      result := $'{prefix_part}{proc_part}{name}{generic_part}({prms_part}){ret_part}';
    end;
    
    static function format_property(p: PropertyInfo): string;
    begin
      var p_type := format_type(p.PropertyType);
      
      var getter := p.GetGetMethod(false);
      var setter := p.GetSetMethod(false);
      var g := getter <> nil;
      var s := setter <> nil;
      
      var access := '';
      if (g) and (s) then access := '{get; set;}'
      else if g then access := '{get;}'
      else if s then access := '{set;}';
      
      var index_params := p.GetIndexParameters();
      var index_str := index_params.Length > 0 ?  $'[{format_method_params(index_params)}]' : '';
      
      var any_static := (g and getter.IsStatic) or (s and setter.IsStatic);
      var prefix := any_static ? 'static ' : '';
      
      result := $'{prefix}property {p.Name}{index_str}: {p_type} {access}';
    end;
    
    static function format_type_defination(t: &Type): string;
    begin
      var name := format_type(t);
      var parents := new List<string>;
      
      var base_type := t.BaseType;
      var has_base := (base_type <> nil) and (base_type <> typeof(object)) and (base_type <> typeof(System.ValueType));
      
      if has_base then
        parents.Add(format_type(base_type));
      
      var ign_interfaces := new HashSet<&Type>();
      if has_base then ign_interfaces.UnionWith(base_type.GetInterfaces());
      
      var all_interfaces := t.GetInterfaces();
      foreach var i in all_interfaces do
        ign_interfaces.UnionWith(i.GetInterfaces());
      
      foreach var i in all_interfaces do
        if not ign_interfaces.Contains(i) then
          parents.Add(format_type(i));
      
      var sep := ', ';
      var bases := parents.Count > 0 ? $'({parents.JoinToString(sep)})' : '';
      result := $'{name} = {get_type_category(t)}{bases}';
    end;
  end;

const
  balance_basic = new PascalModule('balance_basic.pas');
  balance_core = new PascalModule('balance_core.pas', balance_basic);
  balance_joints = new PascalModule('balance_joints.pas', balance_core, balance_basic);
  balance = new PascalModule('balance.pas', balance_joints,  balance_core, balance_basic);
  balance_api_file = 'balance_api.txt';
  
  compiler_path = 'C:\Program Files (x86)\PascalABC.NET\pabcnetc.exe';
  inv_chars = |'$', '<', '>', '%'|;
  flags = BindingFlags.Public or BindingFlags.Instance or BindingFlags.Static or BindingFlags.DeclaredOnly;
  static_flags = BindingFlags.Public or BindingFlags.Static;
  export_prefix = 'bl_';
  
  assembly_cache = false;

//var balance_private:=new HashSet<string>(|'unwrap_or'|);

function is_valid_name(n: string) := (n.IndexOfAny(inv_chars) = -1);


var
  tmp_dir := Path.GetTempPath();

function compile(module: PascalModule): Assembly;
begin
  var out_asm := Path.Combine(tmp_dir, Path.ChangeExtension(module.module_name, 'dll'));
  if  not assembly_cache then
  begin
    var content := ReadAllText(module.module_name);
    content := content.Replace('unit', 'library', 1);
    var tmp_file := Path.Combine(tmp_dir, module.module_name);
    WriteAllText(tmp_file, content); 
    if (module.depends <> nil) then
      module.depends.ForEach(m -> &File.Copy(m, Path.Combine(tmp_dir, m), true));
    var p := Process.Start(compiler_path, $'{tmp_file} {out_asm} dll');
    p.WaitForExit();
  end;
  result := Assembly.LoadFile(out_asm);
end;

function get_exported_types(asm: Assembly): IEnumerable<System.Type>;
begin
  foreach var t in asm.GetTypes do
  begin
    if (not is_valid_name(t.Name)) then continue;
    if (t.Namespace = nil) or (not t.Namespace.StartsWith('balance')) then continue;
    yield t;
  end;
end;

function build_api(): string;
begin
  var wr := new StringBuilder();
  var asm := compile(balance);
  
  foreach var t in get_exported_types(asm) do
  begin
    wr.AppendLine(PascalInspector.format_type_defination(t));
    
    foreach var f in t.GetFields(flags) do
    begin
      if not is_valid_name(f.Name) then continue;
      wr.AppendLine($' {PascalInspector.format_field(f)}');
    end;
    
    foreach var c in t.GetConstructors(flags) do
    begin
      wr.AppendLine($' {PascalInspector.format_constructor(c)}');
    end;
    
    var props := t.GetProperties(flags); 
    var props_methods :=  props.SelectMany(p -> |p.GetGetMethod(false), p.GetSetMethod(false)|).Where(m -> m <> nil).ToHashSet();
    
    foreach var m in t.GetMethods(flags) do
    begin
      if not is_valid_name(m.Name) then continue;
      if props_methods.Contains(m) then continue;
      wr.AppendLine($' {PascalInspector.format_method(m)}');
    end;
    
    foreach var p in props do
    begin
      if not is_valid_name(p.Name) then continue;
      wr.AppendLine($' {PascalInspector.format_property(p)}');
    end;
  end;
  result := wr.ToString();
end;

type
  ApiStructure = auto class
  public
    owner: string;
    consts := new List<string>();
    funcs := new List<string>();
    types := new List<string>();
    
    constructor create(owner: string) := self.owner := owner;
  end;


procedure populate_const_synonims(t: &Type; api: ApiStructure);
begin
  var fields := t.GetFields(static_flags);
  foreach var f in fields do
  begin
    if not is_valid_name(f.Name) then continue;
    if f.FieldType.IsEnum and (f.FieldType.Namespace = t.Namespace) then continue;    
    api.consts.Add($'{f.Name} = {t.Name}.{f.Name};');
  end;
end;

procedure populate_function_synonims(t: &Type; api: ApiStructure);
begin
  var methods := t.GetMethods(static_flags);
  
  foreach var m in methods do
  begin
    if not is_valid_name(m.Name) then continue;  
    //skip unwrap_or
    if not m.Name.StartsWith(export_prefix) then continue;
    
    var (proc_part, ret_part) := PascalInspector.format_method_variant(m);
    var generic_part := PascalInspector.format_method_generic_params(m);
    var prms_info := m.GetParameters();
    var prms_part := PascalInspector.format_method_params(prms_info);
    var call_args := prms_info.Select(p -> p.Name).JoinToString(', ');
    var ms := $'{proc_part}{m.Name}{generic_part}({prms_part}) := {t.Namespace}.{m.Name}{generic_part}({call_args});';
    api.funcs.Add(ms);
  end;
end;

procedure populate_type_synonims(t: &Type; api: ApiStructure);
begin
  var fmt_type := PascalInspector.format_type(t);
  api.types.Add($'{fmt_type} = {t.Namespace}.{fmt_type};');
end;

function build_synonims_from_assebmly(asm: Assembly; visited_types: Hashset<string>): ApiStructure;
begin
  result := new ApiStructure(Path.GetFileNameWithoutExtension(asm.Location));
  var current_mod_name := Path.GetFileNameWithoutExtension(asm.Location);
  foreach var t in get_exported_types(asm) do
  begin
    if not visited_types.Add(t.FullName) then continue;
    if (t.Namespace = t.Name) then
    begin
      if (t.Name <> current_mod_name) then continue;
      populate_const_synonims(t, result);
      populate_function_synonims(t, result);
    end else
      populate_type_synonims(t, result);
  end;
end;

function build_synonims(): string;
begin
  //Порядок должен быть иерархический от базовых к зависимым
  //Причина - в процессе компиляции может происходить копирование определений
  //Именно иерархический порядок способствует тому, что бы каждый алиас в balance.pas указывал источник, определивший его. 
  
  var mods := |balance_basic, balance_core, balance_joints|;
  var asms := mods.select(compile).toarray();
  
  var api := new List<ApiStructure>();
  
  var visited_types := new HashSet<string>();
  
  foreach var asm in asms do
  begin
    api.add(build_synonims_from_assebmly(asm, visited_types));
  end;
  
  var wr := new StringBuilder();
  
  var date := DateTime.Now.ToString('yyyy.MM.dd. HH:mm:ss');
  wr.AppendLine($'//Auto-generated on {date}');
  wr.AppendLine($'unit {Path.GetFileNameWithoutExtension(balance.module_name)};');
  var mods_str := mods.Select(m -> Path.GetFileNameWithoutExtension(m.module_name)).JoinToString(', ');
  wr.AppendLine($'uses {mods_str};');
  
  var add_block := (owner: string; top: string; lines: List<string>)->
  begin
    if lines.count = 0 then exit;
    wr.AppendLine($'{NewLine}//{owner}');
    foreach var ln in lines do
      wr.AppendLine(ln);    
  end;
  
  //  var add_section := (name:string; )
  
  if api.Any(a -> a.types.count > 0) then
  begin
    wr.AppendLine($'{NewLine}type');
    foreach var ap in api do
      add_block(ap.owner, 'type', ap.types);
  end;
  
  foreach var ap in api do
  begin
    add_block(ap.owner, '', ap.funcs);
  end; 
  
  if api.Any(a -> a.consts.count > 0) then
  begin
    wr.AppendLine($'{NewLine}const');
    foreach var ap in api do
      add_block(ap.owner, '', ap.consts);
  end; 
  
  wr.AppendFormat($'{NewLine}begin{NewLine}end.');
  result := wr.ToString();
end;


//================================
//  Command-line Argument Parser
//================================
type
  [AttributeUsage(AttributeTargets.Field or AttributeTargets.Property)]
  ArgAttribute = class(Attribute)
  private
    static no_command_const:=new object();
  public
    long_name, short_name, desc: string;
    
    constructor(long_name, short_name, desc: string);
    begin
      self.long_name := long_name;
      self.short_name := short_name;
      self.desc := desc;
    end;
  end;
  
  //--build-api=0 --build-api=1, build-api
  AppConfig = class
    
  private
    //static inv_comap:=System.Globalization.CultureInfo.InvariantCulture
  public
    [Arg('--build-facade=', nil, 'Generate the facade (balance.pas)')]
    build_facade: boolean := true; //NOTE. By default, facade will be generated
    
    [Arg('--build-api=', nil, 'Generate API signatures for quick reference')]
    build_api: boolean := true; //NOTE. By default, api will be generated
        
    [Arg('--yes', '-y', 'Overwrite existing files without confirmation')]
    allow_overwrite: boolean := false;
    
    [Arg('--help', '-h', 'Show this help message')]
    show_help: boolean := false;
    
    function confirm_overwrite_prompt(file_name: string): boolean;
    begin
      if allow_overwrite or not FileExists(file_name) then exit(true);
      write($'File ''{file_name}'' already exists. Overwrite? (Y/n): ');
      var ans: string;
      readln(ans);
      ans := ans.ToLower();
      result := string.IsNullOrEmpty(ans) or (ans = 'y') or (ans = 'yes');
    end;
    
    static function parse_value(val: string; typ: &Type): object;
    begin
      if typ = typeof(boolean) then
      begin
        if val = '1' then val := 'true' else
        if val = '0' then val := 'false';
      end;
      result := Convert.ChangeType(val, typ);
    end;
    
    static function get_fields() := 
    typeof(AppConfig).GetFields(BindingFlags.Public or BindingFlags.Instance)
      .Select(f -> new class(fld := f, attr := f.GetCustomAttribute&<ArgAttribute>()))
      .Where(p -> p.attr <> nil).OrderBy(p -> p.attr.long_name);
    
    static function parse_args(args: array of string): AppConfig;
    begin
      result := new AppConfig();
      var flags := BindingFlags.Public or BindingFlags.Instance;
      var fields := get_fields();//result.GetType().GetFields(flags);
      foreach var src_arg in args do
      begin
        var arg := src_arg.ToLowerInvariant();
        var val: string := nil;
        foreach var fld_attr in fields do
        begin
          var (fld, attr) := (fld_attr.fld, fld_attr.attr);
          var fld_typ := fld.FieldType;
          if attr.long_name.EndsWith('=') then
          begin
            if arg.StartsWith(attr.long_name) then
              val := arg.Substring(attr.long_name.Length)
            else if (attr.short_name <> nil) and (arg.StartsWith(attr.short_name)) then
              val := arg.Substring(attr.short_name.Length);       
          end else
          begin
            assert(fld_typ = typeof(boolean));
            if (arg = attr.long_name) or ((attr.short_name <> nil) and (arg = attr.short_name)) then
              val := 'true';
          end;
          if val <> nil then
          begin
            fld.SetValue(result, parse_value(val, fld_typ)); 
            break;
          end;
        end;
        if val = nil then
          println($'[ArgParser] Warning: Argument "{arg}" was not recognized and will be ignored.');
      end;
    end;
    
    static function get_help(): string;
    begin
      var sb := new StringBuilder();
      sb.AppendLine('=== Balance build script ===');
      sb.AppendLine($'Usage: {Path.GetFileName(GetEXEFileName())} [options]');
      sb.AppendLine();
      sb.AppendLine('Available Options:'); 
      var dflt_config := new AppConfig();
      foreach var fld_attr in get_fields() do
      begin
        var (fld, attr) := (fld_attr.fld, fld_attr.attr);
        var def_str := $'[{fld.GetValue(dflt_config).ToString().ToLowerInvariant()}]';
        var pref := attr.short_name <> nil ? $'{attr.short_name}, ' : '';
        sb.AppendLine($'{pref+attr.long_name,-20} {attr.desc} {def_str}');
      end;      
      result := sb.ToString();
    end;
  end;

begin
  var args := CommandLineArgs();
  var print_help: ()->() := ()->begin write(AppConfig.get_help()); halt(); end;

  var config := AppConfig.parse_args(args);
  if config.show_help then
    print_help();
  
  var any_action:=false;
  if config.build_facade then
  begin
    var name := Path.Combine(GetCurrentDir(), balance.module_name);
    if config.confirm_overwrite_prompt(name) then
    begin
      WriteAllText(name, build_synonims());
      writeln($'OK. Facade was generated to {Path.GetFileName(name)}');
    end;
    any_action:=true;
  end;
  
  if config.build_api then
  begin
    var name := Path.Combine(GetCurrentDir(), balance_api_file);
    if config.confirm_overwrite_prompt(name) then
    begin
      WriteAllText(name, build_api());
      writeln($'OK. API was generated to {Path.GetFileName(name)}');
    end;
    any_action:=true;
  end;
  
  if not any_action then
    print_help();
end.