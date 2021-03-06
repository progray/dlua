program min;

{$APPTYPE CONSOLE}

// defines to configure freepascal
{$IFDEF FPC}
  {$MODE Delphi}

  {$IFNDEF WINDOWS}
    {$LINKLIB c}
  {$ENDIF}
{$ENDIF}

uses
  SysUtils,
  Classes,
  dlua;

//function to print lua data via delphi
function lua_print(L: Plua_State): Integer; cdecl;
var
  i, n: Integer;
begin
  write('Lua: ');
  n := lua_gettop(L);
  for i := 1 to n do
  begin
    if i > 1 then
      Write(#9);
    if lua_isstring(L, i) then
      Write(lua_tostring(L, i))
    else
      Write(Format('%s:%p', [lua_type(L, i), lua_topointer(L, i)]));
  end;
  WriteLn;
  Result := 0;
end;

//this is the class we want to use from lua
type
  TNumArray = class
    size: integer;
    values: array of single;
  end;
  PNumArray = ^TNumArray;

//makes a new delphi array (class) structure from lua
function lua_newarray(L: Plua_State): Integer; cdecl;
var
  n: integer;
  nbytes: integer;
  a: PNumArray;
begin
  writeln('1');
  n:=round(lua_tonumber(L,1));
  writeln('DEBUG: '+inttostr(n));
  nbytes:=sizeof(TNumArray) + (n-1) * sizeof(single);
  writeln('DEBUG: '+inttostr(nbytes));
  a:=lua_newuserdata(L, nbytes); //assign memory for object to lua
  a^:=TNumArray.Create(); //create the object
  SetLength(a^.values, n);
  a^.size:=n;
  result:=1;
end;

//stores a value in the array
function lua_setarray(L: Plua_State): Integer; cdecl;
var
  a: TNumArray;
  index: integer;
  value: single;
begin
  a:=PNumArray(lua_touserdata(L, 1))^;
  index:= Round(lua_tonumber(L, 2));
  value:= lua_tonumber(L, 3);
  //do some error checking here....
  a.values[index-1]:=value;
  result:=0;
end;

//returns a value from the array
function lua_getarray(L: Plua_State): Integer; cdecl;
var
  a: TNumArray;
  index: integer;
begin
  a:=PNumArray(lua_touserdata(L, 1))^;
  index:= Round(lua_tonumber(L, 2));
  // do some error checking here....
  lua_pushnumber(L, a.values[index-1]);
  result:=1;
end;

//retuns the size of the array to lua
function lua_getsize(L: Plua_State): Integer; cdecl;
var
  a: TNumArray;
begin
  a:=PNumArray(lua_touserdata(L, 1))^;
  lua_pushnumber(L, a.size);
  result:=1;
end;

//retuns the size of the array to lua
function lua_freearray(L: Plua_State): Integer; cdecl;
var
  a: TNumArray;
begin
  a:=PNumArray(lua_touserdata(L, 1))^;
  freeAndNil(a);
  result:=1;
end;

//structure for delphi array (class) to lua
const
  arraylib: array [0..5] of luaL_reg = (
   (name:'new';func:lua_newarray),
   (name:'set';func:lua_setarray),
   (name:'get';func:lua_getarray),
   (name:'size';func:lua_getsize),
   (name:'free';func:lua_freearray),
   (name:nil;func:nil)
   );

//bring delphi array (class) to lua
function luaopen_array(L: Plua_state): boolean;
begin
  writeln('a1');
  //luaL_openlib(L, 'array', arraylib, 0);
  luaL_newmetatable(L, 'delphi.array');
  luaL_register(L,'array', arraylib);

  writeln('a3');
  result:=true;
end;

var
  L: Plua_State = nil; //lua state
  script: tstringlist; //a stringlist to hold the lua script
  result: integer;     //0 if script executes ok
  pscript: pchar;
begin

  {$IFDEF DEBUG}
  // Assuming your build mode sets -dDEBUG in Project Options/Other when defining -gh
  // This avoids interference when running a production/default build without -gh

  // Set up -gh output for the Leakview package:
  if FileExists('heap.trc') then
     DeleteFile('heap.trc');
  SetHeapTraceOutput('heap.trc');
  {$ENDIF DEBUG}

  if ParamCount <= 0 then
  begin
    WriteLn('Usage: min.exe filename');
    Exit;
  end;

  WriteLn('load');
  //init lua dll
  LoadLua;

  WriteLn('about to open lua');

  L := lua_open;

  WriteLn('about to register');
  //register pseudo delphi array (class) in lua
  luaopen_array(L);

  WriteLn('4');
  //Register a delphi procedure/funtion for use in Lua
  lua_register(L, 'print', lua_print);

  WriteLn('5');

  //Load a lua script from a buffer
  script:=tstringList.Create;
  script.LoadFromFile(PChar(ParamStr(1)));
  pscript:=script.GetText;
  lual_loadbuffer(L, pscript, length(pscript), 'myluascript');
  StrDispose(pscript); //clean up pchar passed to lua
  freeAndNil(script); //clean up

  WriteLn('6');

  //Ask Lua to run our little script
  result := 0;
  result := lua_pcall(l, 0, LUA_MULTRET, 0);
  if result>0 then
  begin
    writeln('bad, bad script'); //should provide more usefull info
    lua_error(L);
    Writeln('press [ENTER] key to exit...');
    ReadLn;
    exit;                       //stop the program
  end;

  writeln('done with script');

  //close lua dll
  lua_close(L);
  UnLoadLua;

  Writeln('press [ENTER] key to exit...');
  ReadLn;

end.
