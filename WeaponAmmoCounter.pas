unit WeaponAmmoCounter;

interface
function Init:boolean;

implementation
uses BaseGameData, GameWrappers, windows, WeaponAdditionalBuffer, WpnUtils;

var
  addr:cardinal;

procedure SelectAmmoInMagCount(wpn:pointer; default_value:integer); stdcall;
var curammocnt:integer;
    cls:string;
begin
  WeaponAdditionalBuffer.GetBuffer(wpn).SetReloadAmmoCnt(default_value);
  
  if ((WpnUtils.GetGLStatus(wpn)=1) or (WpnUtils.IsGLAttached(wpn))) and WpnUtils.IsGLEnabled(wpn) then exit;

  curammocnt:=WpnUtils.GetAmmoInMagCount(wpn);
  
  if WpnUtils.IsWeaponJammed(wpn) then begin
    WpnUtils.SetAmmoTypeChangingStatus(wpn, $FF);
    WeaponAdditionalBuffer.GetBuffer(wpn).SetReloadAmmoCnt(curammocnt);
    exit;
  end;

  cls:=WpnUtils.GetClassName(wpn);
  if (cls = 'WP_BM16') or (cls = 'WP_RPG7') then exit; 

  if (curammocnt=0) or (WpnUtils.GetAmmoTypeChangingStatus(wpn)<>$FF) then begin
    WeaponAdditionalBuffer.GetBuffer(wpn).SetReloadAmmoCnt(default_value-1);
    exit;
  end;
end;

procedure SelectAmmoInMagCount_Patch; stdcall;
//� ������� ��������� ������� �� 1 �������, ��� � ��������!
begin
  asm
    lea ecx, [esi-$2E0]

    pushad
    pushfd

    push [ecx+$694]
    push ecx
    call SelectAmmoInMagCount

    popfd
    popad
    ret

  end;
end;

//--------------------------------�������� ������������ ��������----------------

function GetSavedValue(wpn:pointer):cardinal;stdcall;
begin
  result:=WeaponAdditionalBuffer.GetBuffer(wpn).GetReloadAmmoCnt;
end;

procedure DoCompareMagCapacity(count:cardinal);stdcall;
//������ �� ����������, �� ���������� �����!
//� esi ������� ����� ������
begin
  asm
    pushad

    push esi
    call GetSavedValue
    cmp count, eax

    popad
  end;
end;

procedure OnCartridgeAdded; stdcall;
begin
  asm
    //TODO:��� ����� ���� �������� �������� ������� ����� ������ � ������ � ����������
    
    //�������� ���������� ��������
    push eax //[esi+$690]
    call DoCompareMagCapacity
    ret
  end;
end;
//------------------------------------------------------------------------------

function Init:boolean;
var rb:cardinal;
    debug_bytes:array of byte;
    debug_addr:cardinal;
begin
  result:=false;
  setlength(debug_bytes, 8);
  ////////////////////////////////////////////////////
  //��������� ������������ ����� ���� �������� ��� �����������, ����� � ��� �� ������� �������� �������� ���� �� ������� ��������
  //TODO: �����, ������� ��� �� ��� ��������� ����� ������?
  debug_bytes[0]:=$C7;
  debug_addr:=xrGame_addr+$2D0185;
  writeprocessmemory(hndl, PChar(debug_addr), @debug_bytes[0], 1, rb);
  if rb<>1 then exit;
  ////////////////////////////////////////////////////
  //�������� ����� �������� ��� �����
  debug_bytes[0]:=$EB;
  debug_addr:=xrGame_addr+$2D0FF8;
  writeprocessmemory(hndl, PChar(debug_addr), @debug_bytes[0], 1, rb);
  if rb<>1 then exit;   
  ////////////////////////////////////////////////////
  //������� ������ ������� ���������, ������� ��������������� mov'� �� push'�
  debug_bytes[0]:=$FF; debug_bytes[1]:=$B6; debug_bytes[2]:=$90; debug_bytes[3]:=$06; debug_bytes[4]:=$00; debug_bytes[5]:=$00;
  debug_bytes[6]:=$90; debug_bytes[7]:=$7D;
  //----------------------------------------------------
  addr:=xrGame_addr+$2D1150;
  writeprocessmemory(hndl, PChar(addr), debug_bytes, 6, rb);
  if rb<>6 then exit;
  addr:=addr+6;
  if not WriteJump(addr, cardinal(@DoCompareMagCapacity), 5, true) then exit;
  writeprocessmemory(hndl, PChar(addr), @debug_bytes[6], 1, rb);
  if rb<>1 then exit;
  //----------------------------------------------------
  addr:=xrGame_addr+$2D1214;
  writeprocessmemory(hndl, PChar(addr), debug_bytes, 6, rb);
  if rb<>6 then exit;
  addr:=addr+6;
  if not WriteJump(addr, cardinal(@DoCompareMagCapacity), 5, true) then exit;
  writeprocessmemory(hndl, PChar(addr), @debug_bytes[6], 2, rb);
  if rb<>2 then exit;
  //----------------------------------------------------


  addr:=xrGame_addr+$2CCDA0;
  if not WriteJump(addr, cardinal(@SelectAmmoInMagCount_Patch), 6, true) then exit;

  addr:=xrGame_addr+$2D11DA;
  if not WriteJump(addr, cardinal(@OnCartridgeAdded), 6, true) then exit;
  result:=true;
end;


end.
