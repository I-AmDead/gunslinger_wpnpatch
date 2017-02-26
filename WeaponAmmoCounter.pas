unit WeaponAmmoCounter;

{$define DISABLE_AUTOAMMOCHANGE}  //��������� �������������� ����� ���� �������� �� ������� ������� ������� ��� ��������� �������� �������� ����; ��� ������ ���������� ���������, ����� � ��������� ��������� ������!
{$define NEW_BRIEF_MODE}//� ������ ������������ ������ ���� �������� �� ���� ����� ���������� ��� ����������� �������, ���� �� ������� - ����� ���������� ��� ��������, ���������� � ������

interface
  procedure CWeaponMagazined__OnAnimationEnd_DoReload(wpn:pointer); stdcall;
  function CWeaponShotgun__OnAnimationEnd_OnAddCartridge(wpn:pointer):boolean; stdcall;  

function Init:boolean;

implementation
uses BaseGameData, WeaponAdditionalBuffer, HudItemUtils, xr_Cartridge, ActorUtils, strutils, ActorDOF;


procedure SwapFirstLastAmmo(wpn:pointer);stdcall;
var
  cs, ce:pCCartridge;
  tmp:CCartridge;
  cnt:cardinal;
begin
  if ((GetGLStatus(wpn)=1) or (IsGLAttached(wpn))) and IsGLEnabled(wpn) then exit;
  cnt:=GetAmmoInMagCount(wpn);
  if cnt>1 then begin
    cnt:=cnt-1;
    cs:=GetCartridgeFromMagVector(wpn,0);
    ce:=GetCartridgeFromMagVector(wpn,cnt);
    CopyCartridge(cs^, tmp);
    CopyCartridge(ce^, cs^);
    CopyCartridge(tmp, ce^);
  end;
end;

procedure SwapLastPrevAmmo(wpn:pointer);stdcall;
var
  cs, ce:pCCartridge;
  tmp:CCartridge;
  cnt:cardinal;
begin
  if ((GetGLStatus(wpn)=1) or (IsGLAttached(wpn))) and IsGLEnabled(wpn) then exit;
  cnt:=GetAmmoInMagCount(wpn);
  if cnt>1 then begin
    cnt:=cnt-1;
    cs:=GetCartridgeFromMagVector(wpn,cnt-1);
    ce:=GetCartridgeFromMagVector(wpn,cnt);
    CopyCartridge(cs^, tmp);
    CopyCartridge(ce^, cs^);
    CopyCartridge(tmp, ce^);
  end;
end;


//---------------------------------------------------���� ����� �������� � �������-------------------------
procedure CWeaponMagazined__OnAnimationEnd_DoReload(wpn:pointer); stdcall;
var
  buf: WpnBuf;
  def_magsize, mod_magsize, curammocnt:integer;
begin
  buf:=GetBuffer(wpn);
  //���� ������ ��� ��� �� ��� ������������c� ��� � ��� ����� ��������� - ������ ���������� �� ������
  if (buf=nil) then begin virtual_CWeaponMagazined__ReloadMagazine(wpn); exit; end;

  if buf.IsReloaded() then begin buf.SetReloaded(false); exit; end;
  if (((GetGLStatus(wpn)=1) or (IsGLAttached(wpn))) and IsGLEnabled(wpn)) then begin virtual_CWeaponMagazined__ReloadMagazine(wpn); exit; end;

  //���������, ����� ������ �������� � ������ � ������� �������� � ��� ������
  def_magsize:=GetMagCapacityInCurrentWeaponMode(wpn);
  curammocnt:=GetCurrentAmmoCount(wpn);

  //������ ��������� �� ��������� ������ � ��������, ������� �������� � ���� ���������
  if IsWeaponJammed(wpn) then begin
    SetAmmoTypeChangingStatus(wpn, $FF);
    mod_magsize:=curammocnt;
  end else if (GetClassName(wpn)='WP_BM16') then begin
    mod_magsize:=buf.ammo_cnt_to_reload;
  end else if buf.IsAmmoInChamber() and ((curammocnt=0) or ((GetAmmoTypeChangingStatus(wpn)<>$FF) and not buf.SaveAmmoInChamber() )) then begin
    mod_magsize:=def_magsize-1;
  end else begin
    mod_magsize:=def_magsize;
  end;

  //������� ������� ��������, ������������ �� ��� � ����������� ������ ��������
  SetMagCapacityInCurrentWeaponMode(wpn, mod_magsize);
  virtual_CWeaponMagazined__ReloadMagazine(wpn);
  SetMagCapacityInCurrentWeaponMode(wpn, def_magsize);
end;


procedure CWeaponMagazined__OnAnimationEnd_DoReload_Patch(); stdcall;
asm
  pushad
    sub esi, $2e0
    push esi
    call CWeaponMagazined__OnAnimationEnd_DoReload
  popad
end;


//---------------------------------------------------������� ���� ������� � ���������� � �������-------------------------
procedure NeedNotUnloadLastCartridge(wpn:pointer); stdcall;
var
  buf:WpnBuf;
begin
  buf:=GetBuffer(wpn);
  if
    not(((GetGLStatus(wpn)=1) or (IsGLAttached(wpn))) and IsGLEnabled(wpn))
  and
    (buf<>nil)    
  and
    buf.IsAmmoInChamber()
  and
    buf.SaveAmmoInChamber()

  then begin
    SwapFirstLastAmmo(wpn);
    buf.is_firstlast_ammo_swapped:=true;
    ChangeAmmoVectorStart(wpn, sizeof(CCartridge));
    virtual_CWeaponMagazined__UnloadMagazine(wpn);
    ChangeAmmoVectorStart(wpn, (-1)*sizeof(CCartridge));    
  end else begin
    if buf <> nil then begin
      buf.is_firstlast_ammo_swapped:=false;
    end;
    virtual_CWeaponMagazined__UnloadMagazine(wpn);
  end;
end;

procedure CWeaponMagazined__ReloadMagazine_OnUnloadMag_Patch(); stdcall;
asm
  pushad
    push esi
    call NeedNotUnloadLastCartridge
  popad
  @finish:
end;

procedure CWeaponMagazined__ReloadMagazine_OnFinish(wpn:pointer); stdcall;
var
  buf:WpnBuf;
begin
  buf:=GetBuffer(wpn);
  if (buf<>nil) and (buf.is_firstlast_ammo_swapped) then begin
    buf.is_firstlast_ammo_swapped:=false;
    SwapFirstLastAmmo(wpn);
  end;
end;

procedure CWeaponMagazined__ReloadMagazine_OnFinish_Patch(); stdcall;
asm
  pushad
    push esi
    call CWeaponMagazined__ReloadMagazine_OnFinish
  popad

  pop esi
  pop ebp
  add esp, $48
end;


{$ifdef DISABLE_AUTOAMMOCHANGE}
procedure CWeaponmagazined__TryReload_Patch();stdcall;
asm
  //���������, ���� �� �� ����� ������� �� ����� ������

  cmp byte ptr [esi+$6C7], $FF //if m_set_next_ammoType_on_reload<>-1 then jmp
  jne @orig
  mov eax, 0                    //�������, ��� � ������ 0 ��������� ����� �������� ;)

  @orig:
  //������ ����������
  sar eax, 02
  test al, al
  ret
end;

procedure CWeaponShotgun__HaveCartridgeInInventory_Patch(); stdcall;
asm
  cmp byte ptr [esi+$6c7], $FF
  je @false

  mov [esi+$6C7], bl
  mov eax, 1
  jmp @finish

  @false:
  xor eax, eax
  
  @finish:
  pop ebx
  cmp edi, ebp  //??? �� ��� � ���������
  pop edi
  pop ebp
  pop esi
  ret 4
end;
{$endif}

//---------------------------------������� � ���������� ��� ����������----------------------------

function CWeaponShotgun__OnAnimationEnd_OnAddCartridge(wpn:pointer):boolean; stdcall;
//����������, ����� �� ���������� �������� ������� � TriStateReload, ��� ������ ��� :)
var
  buf:WpnBuf;
begin
  buf:=GetBuffer(wpn);
  if buf<>nil then begin
    if not buf.IsReloaded then begin
      virtual_CWeaponShotgun__AddCartridge(wpn, 1);
      if buf.IsAmmoInChamber() and buf.SaveAmmoInChamber() then begin
        SwapLastPrevAmmo(wpn);
      end;
    end;
  end else begin
    virtual_CWeaponShotgun__AddCartridge(wpn, 1); //���� ������������� ���� ;)
  end;
  result:=CWeaponShotgun__HaveCartridgeInInventory(wpn, 1);
end;

procedure CWeaponShotgun__OnAnimationEnd_OnAddCartridge_Patch(); stdcall;
asm
  pushad
    sub esi, $2e0
    push esi
    call CWeaponShotgun__OnAnimationEnd_OnAddCartridge
    cmp al, 01
  popad
end;

//-----------------------------------------anm_close � ������ ������� ���������� �������----------------------------
procedure CWeaponShotgun__Action_OnStopReload(wpn:pointer); stdcall;
begin
  if (GetSubState(wpn)=EWeaponSubStates__eSubStateReloadEnd) or (IsWeaponJammed(wpn)) then exit;
  if not IsActionProcessing(wpn) then begin
    SetSubState(wpn, EWeaponSubStates__eSubStateReloadEnd);
    virtual_CHudItem_SwitchState(wpn,EWeaponStates__eReload);
  end else begin
    SetActorKeyRepeatFlag(kfFIRE, true);
  end;
end;

procedure CWeaponShotgun__Action_OnStopReload_Patch(); stdcall;
asm
  pushad
  push esi
  call CWeaponShotgun__Action_OnStopReload
  popad
end;

//----------------------------------------------���������� ������� � open-------------------------------------------
procedure CWeaponMagazined__OnAnimationEnd_anm_open(wpn:pointer); stdcall;
var
  buf:WpnBuf;
begin
  if IsWeaponJammed(wpn) then begin
    SetWeaponMisfireStatus(wpn, false);
    SetSubState(wpn, EWeaponSubStates__eSubStateReloadBegin);
    virtual_CHudItem_SwitchState(wpn, EHudStates__eIdle);
    exit;
  end;

  SetSubState(wpn, EWeaponSubStates__eSubStateReloadInProcess); //����������
  buf:=GetBuffer(wpn);
  if (buf<>nil) and buf.AddCartridgeAfterOpen() then begin
    CWeaponShotgun__OnAnimationEnd_OnAddCartridge(wpn);
  end;
  virtual_CHudItem_SwitchState(wpn, EWeaponStates__eReload);
end;

procedure CWeaponMagazined__OnAnimationEnd_anm_open_Patch(); stdcall;
asm
  pushad
  sub esi, $2e0
  push esi
  call CWeaponMagazined__OnAnimationEnd_anm_open
  popad
end;

//-------------------------------------------------------������� �� ������� ��� �������� � ���������-----------------------------------------
function CWeaponShotgun_Needreload(wpn:pointer):boolean; stdcall;
begin
  result:= (IsWeaponJammed(wpn) or CWeaponShotgun__HaveCartridgeInInventory(wpn, 1));
end;

procedure CWeaponShotgun__TriStateReload_Needreload_Patch(); stdcall;
asm
  pushad
    push esi
    call CWeaponShotgun_Needreload
    test al, al
  popad
end;

procedure CWeaponShotgun__OnStateSwitch_Needreload_Patch(); stdcall;
asm
  pushad
    push edi
    call CWeaponShotgun_Needreload
    test al, al
  popad
end;

//------------------------------------------------------------------------------------------------------------------
function Init:boolean;
var
    debug_bytes:array of byte;
    addr:cardinal;
begin
  result:=false;
  setlength(debug_bytes, 6);
  ////////////////////////////////////////////////////
  //��������� ��� � ������������ ������ ���� �������� ��� �����������, ����� � ��� �� ������� �������� �������� ���� �� ������� ��������
  //��� �� �����������, ���� � ������, � �������� �������� ������� ������ ���� ��������, � ������ ���� � ��������� ������ ���, ����������� ������� ��� �, �� ��������� ��������� �����,  ���������
  //����� ������� ������ �� ����� ����������� �� ������� ����� ����
  // ������� � ���, ��� � CWeaponMagazined::TryReload �� ����������� �������� ����� m_ammoType ������ m_set_next_ammoType_on_reload
  debug_bytes[0]:=$C7;
  if not WriteBufAtAdr(xrGame_addr+$2D0185, @debug_bytes[0],1) then exit;
  if not WriteBufAtAdr(xrGame_addr+$2DE84B, @debug_bytes[0],1) then exit;  //CWeaponShotgun::HaveCarteidgeInInventory, ����� ��� ����� ��������������, �� ����� �����


  //������, ������� �������� ���� �������� � ������� � ������ ��� ������
  addr:=xrGame_addr+$2CCD94;
  if not WriteJump(addr, cardinal(@CWeaponMagazined__OnAnimationEnd_DoReload_Patch), 20, true) then exit;

  //������������ ���������� ������� ����� anm_open
  addr:=xrGame_addr+$2DE41C;
  if not WriteJump(addr, cardinal(@CWeaponMagazined__OnAnimationEnd_anm_open_Patch), 15, true) then exit;

  //��� ����� ���� �������� ������� ����������� - ���������� �������� ��������� ������ �������������
  nop_code(xrGame_addr+$2D10D8, 2); //������� ������� �� ����������� ������ ���������� ������� � �����������
  addr:=xrGame_addr+$2D1106;
  if not WriteJump(addr, cardinal(@CWeaponMagazined__ReloadMagazine_OnUnloadMag_Patch), 6, true) then exit;
  //������ ������ � ��������� ������, ���� � ��� ���� ����� ���� 
  addr:=xrGame_addr+$2D125F;
  if not WriteJump(addr, cardinal(@CWeaponMagazined__ReloadMagazine_OnFinish_Patch), 6, false) then exit;

{$ifdef NEW_BRIEF_MODE}
  //�������� CWeaponMagazined::GetBriefInfo ���, ����� �� ������ ����������� �� ������� ��� ����������� �������, � ���, ������� ����� ��������
  debug_bytes[0]:=$e9; debug_bytes[1]:=$BD; debug_bytes[2]:=$00; debug_bytes[3]:=$00; debug_bytes[4]:=$00; debug_bytes[5]:=$90;
  if not WriteBufAtAdr(xrGame_addr+$2CE5B2, @debug_bytes[0],6) then exit;
  //���������� ��� CWeaponMagazinedWGrenade
  debug_bytes[0]:=$e9; debug_bytes[1]:=$CC; debug_bytes[2]:=$00; debug_bytes[3]:=$00; debug_bytes[4]:=$00; debug_bytes[5]:=$90;
  if not WriteBufAtAdr(xrGame_addr+$2d2361, @debug_bytes[0],6) then exit;
{$endif}

  //��������� ���������� "�������" ������� ��� ���������� ������� ��������� +���������� �������� anm_close (� CWeaponShotgun::Action)
  addr:=xrGame_addr+$2DE374;
  if not WriteJump(addr, cardinal(@CWeaponShotgun__Action_OnStopReload_Patch), 30, true) then exit;

  //������ � ����������+�������� �������������+�������� �� ���������� ������� � �������
  addr:=xrGame_addr+$2DE3ED;
  if not WriteJump(addr, cardinal(@CWeaponShotgun__OnAnimationEnd_OnAddCartridge_Patch), 22, true) then exit;

  //������ �������, ������� �� ���� ������������ CWeaponMagazined, ���� �������� � ���� ��� �� � ���������, �� � ��������
  nop_code(xrGame_addr+$2D00B4,2);

  //����� ����������� ������������ ��������, ����� � ��������� ��� ��������
  addr:=xrGame_addr+$2DE94A;
  if not WriteJump(addr, cardinal(@CWeaponShotgun__TriStateReload_Needreload_Patch), 11, true) then exit;
  addr:=xrGame_addr+$2DE9D1;
  if not WriteJump(addr, cardinal(@CWeaponShotgun__OnStateSwitch_Needreload_Patch), 11, true) then exit;
  addr:=xrGame_addr+$2DEA19;
  if not WriteJump(addr, cardinal(@CWeaponShotgun__OnStateSwitch_Needreload_Patch), 11, true) then exit;
  //addr:=xrGame_addr+$2DEA00;
  //if not WriteJump(addr, cardinal(@CWeaponShotgun__OnStateSwitch_Needreload_Patch), 11, true) then exit;


{$ifdef DISABLE_AUTOAMMOCHANGE}
  addr:=xrGame_addr+$2D00FF;
  if not WriteJump(addr, cardinal(@CWeaponMagazined__TryReload_Patch), 5, true) then exit;

  addr:=xrGame_addr+$2DE849;
  if not WriteJump(addr, cardinal(@CWeaponShotgun__HaveCartridgeInInventory_Patch), 6, false) then exit;
{$endif}



  setlength(debug_bytes, 0);  
  result:=true;

end;

end.
