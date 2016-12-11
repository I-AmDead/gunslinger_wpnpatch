unit BaseGameData;

interface
  function Init:boolean;
  function WriteJump(var write_addr:cardinal; dest_addr:cardinal; addbytescount:cardinal=0; writecall:boolean=false):boolean;
  function nop_code(addr:cardinal; count:cardinal):boolean;

var
  xrGame_addr:cardinal;
  xrCore_addr:cardinal;
  hndl:cardinal;

const
  //������� ����� ������� vftable ��������� ������� ��������, ���� ��� "�����������" RTTI
  W_BM16:word=$4744;
  W_RPG7:word=$F56C;

  //����� �����
  sndReload:PChar='sndReload';
  sndReloadEmpty:PChar='sndReloadEmpty';
  snd_reload_empty:PChar='snd_reload_empty';
  snd_changecartridgetype:PChar = 'snd_changecartridgetype';
  sndChangeCartridgeType:PChar = 'sndChangeCartridgeType';

  snd_jamned:PChar = 'snd_jamned';
  sndJamned:PChar = 'sndJamned';
  snd_jamned_last:PChar = 'snd_jamned_last';
  sndJamnedLast:PChar = 'sndJamnedLast';

implementation
uses windows;

const
  xrGame:PChar='xrGame';
  xrCore:PChar='xrCore';

function Init:boolean;
begin
  result:=false;
  hndl:=GetCurrentProcess;
  xrGame_addr := GetModuleHandle(xrGame);
  xrCore_addr := GetModuleHandle(xrCore);
  if (xrGame_addr = 0) or (xrCore_addr = 0) then exit;
  xrGame_addr := (xrGame_addr shr 16) shl 16;
  xrCore_addr := (xrCore_addr shr 16) shl 16;
  result:=true;
end;

function WriteJump(var write_addr:cardinal; dest_addr:cardinal; addbytescount:cardinal=0; writecall:boolean=false):boolean;
var offsettowrite:cardinal;
    rb:cardinal;
    opcode:char;
begin
  result:=true;
  if writecall then opcode:=CHR($E8) else opcode:=CHR($E9);
  offsettowrite:=dest_addr-write_addr-5;
  writeprocessmemory(hndl, PChar(write_addr), @opcode, 1, rb);
  if rb<>1 then result:=false;
  writeprocessmemory(hndl, PChar(write_addr+1), @offsettowrite, 4, rb);
  if rb<>4 then result:=false;
  write_addr:=write_addr+addbytescount;
end;

function nop_code(addr:cardinal; count:cardinal):boolean;
const opcode:char=CHR($90);
var rb:cardinal;
    i:cardinal;
begin
  result:=true;
  for i:=addr to addr+count-1 do begin
    writeprocessmemory(hndl, PChar(i), @opcode, 1, rb);
    if rb<>1 then result:=false;
  end;
end;

end.
