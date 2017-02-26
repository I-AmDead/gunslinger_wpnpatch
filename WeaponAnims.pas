unit WeaponAnims;

//�� ������ - �� ����. Sin!

interface
function Init:boolean;
function ModifierStd(wpn:pointer; base_anim:string; disable_noanim_hint:boolean=false):string;stdcall;

implementation
uses BaseGameData, WpnUtils, GameWrappers, ActorUtils, WeaponAdditionalBuffer, math, WeaponEvents, sysutils, strutils, DetectorUtils, WeaponAmmoCounter, Throwable, gunsl_config, messenger;

var
  anim_name:string;   //��-�� ����, ��� ��� ������ � ����� ������ - ���� ����� ����������� ����������, ���� ����� ������ ���������� �������� �����
  jump_addr:cardinal;

  movreass_last_update:cardinal;
  movreass_remain_time:cardinal;



procedure ModifierGL(wpn:pointer; var anm:string);
begin
  if (GetGLStatus(wpn)=1) or IsGLAttached(wpn) then begin
    if IsGLEnabled(wpn) then
      anm:=anm+'_g'
    else
      anm:=anm+'_w_gl';
  end;
end;

function GetFireModeStateMark(wpn:pointer):string;
var
  hud_sect:PChar;
  firemode:integer;
  tmpstr:string;
begin
  result:='';
  hud_sect:=GetHUDSection(wpn);
  if hud_sect=nil then exit;
  firemode:=CurrentQueueSize(wpn);
  if firemode<0 then tmpstr:='a' else tmpstr:=inttostr(firemode);
  tmpstr:='mask_firemode_'+tmpstr;
  if game_ini_line_exist(hud_sect, PChar(tmpstr)) then begin
    result:=game_ini_read_string(hud_sect,PChar(tmpstr));
  end;
end;

procedure ModifierMoving(wpn:pointer; actor:pointer; var anm:string; config_enabler_directions:string; config_enabler_main:string='');
var hud_sect:PChar;
begin
  hud_sect:=GetHUDSection(wpn);
    if (config_enabler_main<>'') then begin
       if not game_ini_line_exist(hud_sect, PChar(config_enabler_main)) or not game_ini_r_bool(hud_sect, PChar(config_enabler_main)) then exit;
    end;
  if GetActorActionState(actor, actMovingForward or actMovingBack or actMovingLeft or actMovingRight) then begin
    anm:=anm+'_moving';
    
    if not game_ini_line_exist(hud_sect, PChar(config_enabler_directions)) or not game_ini_r_bool(hud_sect, PChar(config_enabler_directions)) then exit;
    if GetActorActionState(actor, actMovingForward) then begin
      anm:=anm+'_forward';
    end;
    if GetActorActionState(actor, actMovingBack) then begin
      anm:=anm+'_back';
    end;
    if GetActorActionState(actor, actMovingLeft) then begin
      anm:=anm+'_left';
    end;
    if GetActorActionState(actor, actMovingRight) then begin
      anm:=anm+'_right';
    end;
  end;
end;

procedure ModifierBM16(wpn:pointer; var anm:string);
var cnt:integer;
begin
  if GetClassName(wpn) = 'WP_BM16' then begin
    cnt:=GetAmmoInMagCount(wpn);
    if cnt<=0 then
      anim_name:=anim_name+'_0'
    else if cnt=1 then
      anim_name:=anim_name+'_1'
    else
      anim_name:=anim_name+'_2';
  end;
end;

//------------------------------------------------------------------------------anm_idle(_sprint, _moving, _aim)---------------------------------------
function anm_idle_selector(wpn:pointer):pchar;stdcall;
var
  hud_sect:PChar;
  actor:pointer;
  canshoot, isdetector, isgrenorbolt, is_knife, is_bino:boolean;
  companion:pointer;
  assign_detector_anim:boolean;
  cls:string;
begin
  hud_sect:=GetHUDSection(wpn);
  anim_name:='anm_idle';
  actor:=GetActor();
  cls:=GetClassName(wpn);
  canshoot:=WpnCanShoot(PChar(cls));
  isgrenorbolt:=IsThrowable(PChar(cls));
  isdetector :=WpnIsDetector(PChar(cls));
  is_knife:=IsKnife(PChar(cls));
  is_bino:=IsBino(PChar(cls));
  assign_detector_anim:=false;
  //���� � ��� �������� - �� �����, �� � ������ �������� ������ ���
  if (actor<>nil) and (actor=GetOwner(wpn)) then begin
    if isdetector then companion:=GetActorActiveItem() else companion:=GetActiveDetector(actor);
    //--------------------------������������ ��������/��������� ������---------------------------------------

    //���� ����� � ������ ������������
    if (canshoot or is_bino) and IsAimNow(wpn) then begin
      anim_name:=anim_name+'_aim';
      if GetActorActionState(actor, actAimStarted) then begin
        ModifierMoving(wpn, actor, anim_name, 'enable_directions_'+anim_name);
      end else begin
        anim_name:=anim_name+'_start';
        if canshoot then CHudItem_Play_Snd(wpn, 'sndAimStart');
        SetActorActionState(actor, actAimStarted, true);
      end;
      if companion<>nil then assign_detector_anim:=true;
    end else if (canshoot or is_bino) and GetActorActionState(actor, actAimStarted) then begin
      anim_name:=anim_name+'_aim_end';
      if canshoot then CHudItem_Play_Snd(wpn, 'sndAimEnd');
      SetActorActionState(actor, actAimStarted, false);
      if companion<>nil then assign_detector_anim:=true;

    //��������� �� ������������ ������:
    end else if GetActorActionState(actor, actSprint) then begin
      anim_name:=anim_name+'_sprint';
      if (isdetector and not GetActorActionState(actor, actModDetectorSprintStarted)) or (not isdetector and not GetActorActionState(actor, actModSprintStarted)) then begin
        anim_name:=anim_name+'_start';
        if canshoot or isgrenorbolt or is_knife then CHudItem_Play_Snd(wpn, 'sndSprintStart');
        if isdetector then
          SetActorActionState(actor, actModDetectorSprintStarted, true)
        else
          SetActorActionState(actor, actModSprintStarted, true);
      end;

    end else if (isdetector and GetActorActionState(actor, actModDetectorSprintStarted)) or (not isdetector and GetActorActionState(actor, actModSprintStarted)) then begin;
      anim_name:=anim_name+'_sprint_end';
      if canshoot or isgrenorbolt or is_knife then
        CHudItem_Play_Snd(wpn, 'sndSprintEnd');

      if isdetector then
        SetActorActionState(actor, actModDetectorSprintStarted, false)
      else
        SetActorActionState(actor, actModSprintStarted, false);

    end else begin
      ModifierMoving(wpn, actor, anim_name, 'enable_directions_'+anim_name);
      if GetActorActionState(actor, actCrouch) then begin
        anim_name:=anim_name+'_crouch';
      end;
      if GetActorActionState(actor, actSlow) then begin
        anim_name:=anim_name+'_slow';
      end;
    end;
  //----------------------------------������������ ��������� ������----------------------------------------------------

    if canshoot then begin
        anim_name:=anim_name + GetFireModeStateMark(wpn);
        //���� ������ ��������� - ������ �������� �������� ��� ���������
        if IsWeaponJammed(wpn) then begin
          anim_name:=anim_name+'_jammed';
        end else if (GetAmmoInMagCount(wpn)<=0) and (cls<>'WP_BM16') then begin
          anim_name:=anim_name+'_empty';
        end;

        ModifierGL(wpn, anim_name);
    end;
  end;
  //���������� ����� ����������� �������
  ModifierBM16(wpn, anim_name);

  //���� �� �������� � ����������
  if (isdetector and Is16x9 and not game_ini_line_exist(hud_sect, PChar(anim_name+'_16x9'))) then begin
    log('Section ['+hud_sect+'] has no motion alias defined ['+anim_name+'_16x9]');
    if IsDebug then Messenger.SendMessage('Animation not found, see log!');
    anim_name:='anm_idle';
  end;

  if (not game_ini_line_exist(hud_sect, PChar(anim_name))) then begin
    log('Section ['+hud_sect+'] has no motion alias defined ['+anim_name+']');
    if IsDebug then Messenger.SendMessage('Animation not found, see log!');
    anim_name:='anm_idle';
    ModifierBM16(wpn, anim_name);
  end;

  if assign_detector_anim then begin
//    log('assigning ');
    StartCompanionAnimIfNeeded(rightstr(anim_name, length(anim_name)-4), wpn, true);
  end;
    
  result:=PChar(anim_name);
  MakeLockByConfigParam(wpn, hud_sect, PChar('lock_time_'+anim_name));
end;


procedure anm_idle_std_patch();stdcall;
begin
  asm
    push 0                  //�������� ����� ��� �������� �����
    pushad
    pushfd
    push esi
    call anm_idle_selector  //�������� ������ � ������ �����
    mov ecx, [esp+$28]      //���������� ����� ��������
    mov [esp+$28], eax      //������ �� ��� ����� �������������� ������
    mov [esp+$24], ecx      //���������� ����� �������� �� 4 ����� ���� � �����
    popfd
    popad
    ret
  end;
end;

procedure anm_idle_sub_patch();stdcall;
begin
  asm

    sub esi, $2E0
    call anm_idle_std_patch
    add esi, $2E0

    push eax
    push ebx
    mov eax, [esp+8]
    mov ebx, [esp+$c]
    mov [esp+8], ebx
    mov [esp+$c], eax
    pop ebx
    pop eax

  end;
end;
//------------------------------------------------------------------------------anm_show/hide/bore/switch_*-----------------------
function ModifierStd(wpn:pointer; base_anim:string; disable_noanim_hint:boolean=false):string;stdcall;
var
  hud_sect:PChar;
  actor:pointer;
  cls:string;
begin
  hud_sect:=GetHUDSection(wpn);
  actor:=GetActor();
  //���� � ��� �������� - �� �����, �� � ������ �������� ������ ���
  if (actor<>nil) and (actor=GetOwner(wpn)) then begin
  //----------------------------------������������ ��������� ������----------------------------------------------------
    //���� ������� ���� - ������ ������ empty, ���� �����
    cls:=GetClassName(wpn);
    if WpnCanShoot(PChar(cls)) then begin
      if leftstr(base_anim, 18)<>'anm_changefiremode' then base_anim:=base_anim + GetFireModeStateMark(wpn);
      if IsWeaponJammed(wpn) then begin
        base_anim:=base_anim+'_jammed';
      end else if (GetAmmoInMagCount(wpn)<=0) and (cls<>'WP_BM16') then begin
        base_anim:=base_anim+'_empty';
      end;

      if IsHolderHasActiveDetector(wpn) and game_ini_line_exist(hud_sect, PChar(base_anim+'_detector')) then begin
        //log ('det+rel');
        base_anim:=base_anim+'_detector';
      end;

      if game_ini_line_exist(hud_sect, PChar('disable_detector_'+base_anim)) and game_ini_r_bool(hud_sect, PChar('disable_detector_'+base_anim)) and game_ini_line_exist(hud_sect, PChar('immediate_unhide_'+base_anim)) and game_ini_r_bool(hud_sect, PChar('immediate_unhide_'+base_anim)) then begin
        SetActorActionState(actor, actShowDetectorNow, true);
      end;

      ModifierMoving(wpn, actor, base_anim, 'enable_directions_'+base_anim, 'enable_moving_'+base_anim);
      ModifierGL(wpn, base_anim);
    end;
  end;

  ModifierBM16(wpn, base_anim);
  if not disable_noanim_hint then begin
    if not game_ini_line_exist(hud_sect, PChar(base_anim)) then begin
      log('Section ['+hud_sect+'] has no motion alias defined ['+base_anim+']');
      if IsDebug then Messenger.SendMessage('Animation not found, see log!');
      base_anim:='anm_reload';
      ModifierBM16(wpn, base_anim);
    end;
  end;
  result:=base_anim;
end;

function anm_std_selector(wpn:pointer; base_anim:PChar):pchar;stdcall;
begin
  anim_name := ModifierStd(wpn, base_anim);
  result:=PChar(anim_name);
  MakeLockByConfigParam(wpn, GetHUDSection(wpn), PChar('lock_time_'+anim_name));
end;

function anm_show_selector(wpn:pointer):pchar;stdcall;
const
  anm_show:PChar = 'anm_show';
begin
  {if IsKnife(PChar(GetClassName(wpn))) then begin
    //TODO:������� ������������� ���� - �� ������ ������� ForgetDetectorAutoHide, ���� ������� ������������� ������ �� �����
    result:=anm_std_selector(wpn, anm_show);
    exit;
  end;}

  if (GetActor()<>nil) and (GetActor()=GetOwner(wpn)) then begin
    if not game_ini_line_exist(GetSection(wpn), 'gwr_changed_object') and not game_ini_line_exist(GetSection(wpn), 'gwr_eatable_object') then begin
      ForgetDetectorAutoHide();
    end;
  end;
  result:=anm_std_selector(wpn, anm_show);
end;

procedure anm_show_std_patch();stdcall;
begin
  asm
    push 0                  //�������� ����� ��� �������� �����

    pushad
    pushfd
      push esi
      call WeaponEvents.OnWeaponShow
    popfd
    popad


    pushad
    pushfd
    push esi
    call anm_show_selector  //�������� ������ � ������ �����
    mov ecx, [esp+$28]      //���������� ����� ��������
    mov [esp+$28], eax      //������ �� ��� ����� �������������� ������
    mov [esp+$24], ecx      //���������� ����� �������� �� 4 ����� ���� � �����
    popfd
    popad
    ret
  end;
end;

procedure anm_show_sub_patch();stdcall;
begin
  asm

    sub esi, $2E0
    call anm_show_std_patch
    add esi, $2E0

    push eax
    push ebx
    mov eax, [esp+8]
    mov ebx, [esp+$c]
    mov [esp+8], ebx
    mov [esp+$c], eax
    pop ebx
    pop eax

  end;
end;

procedure anm_hide_std_patch();stdcall;
const anm_hide:PChar = 'anm_hide';
begin
  asm
    push 0                  //�������� ����� ��� �������� �����

    pushad
      push esi
      call OnWeaponHideAnmStart
    popad

    pushad
    pushfd
      push anm_hide
      push esi
      call anm_std_selector   //�������� ������ � ������ �����
      mov ecx, [esp+$28]      //���������� ����� ��������
      mov [esp+$28], eax      //������ �� ��� ����� �������������� ������
      mov [esp+$24], ecx      //���������� ����� �������� �� 4 ����� ���� � �����
    popfd
    popad
    ret
  end;
end;

procedure anm_hide_sub_patch();stdcall;
begin
  asm

    sub esi, $2E0
    call anm_hide_std_patch
    add esi, $2E0

    push eax
    push ebx
    mov eax, [esp+8]
    mov ebx, [esp+$c]
    mov [esp+8], ebx
    mov [esp+$c], eax
    pop ebx
    pop eax

  end;
end;

procedure anm_bore_edi_patch();stdcall;
const anm_bore:PChar = 'anm_bore';
begin
  asm
    push 0                  //�������� ����� ��� �������� �����
    pushad
    pushfd
    push anm_bore
    sub edi, $2E0
    push edi
    call anm_std_selector  //�������� ������ � ������ �����
    mov ecx, [esp+$28]      //���������� ����� ��������
    mov [esp+$28], eax      //������ �� ��� ����� �������������� ������
    mov [esp+$24], ecx      //���������� ����� �������� �� 4 ����� ���� � �����
    popfd
    popad
    ret
  end;
end;

procedure anm_bore_std_patch();stdcall;
const anm_bore:PChar = 'anm_bore';
begin
  asm
    push 0                  //�������� ����� ��� �������� �����
    pushad
    pushfd
    push anm_bore
    push esi
    call anm_std_selector  //�������� ������ � ������ �����
    mov ecx, [esp+$28]      //���������� ����� ��������
    mov [esp+$28], eax      //������ �� ��� ����� �������������� ������
    mov [esp+$24], ecx      //���������� ����� �������� �� 4 ����� ���� � �����
    popfd
    popad
    ret
  end;
end;

procedure anm_bore_sub_patch();stdcall;
begin
  asm

    sub esi, $2E0
    call anm_bore_std_patch
    add esi, $2E0

    push eax
    push ebx
    mov eax, [esp+8]
    mov ebx, [esp+$c]
    mov [esp+8], ebx
    mov [esp+$c], eax
    pop ebx
    pop eax

  end;
end;

procedure anm_switch_sub_patch();stdcall;
const anm_switch:PChar = 'anm_switch';
begin
  asm
    push 0                  //�������� ����� ��� �������� �����
    pushad
    pushfd
    sub esi, $2E0
    push anm_switch
    push esi
    call anm_std_selector  //�������� ������ � ������ �����
    mov ecx, [esp+$28]      //���������� ����� ��������
    mov [esp+$28], eax      //������ �� ��� ����� �������������� ������
    mov [esp+$24], ecx      //���������� ����� �������� �� 4 ����� ���� � �����
    popfd
    popad
    ret
  end;
end;

function anm_shoot_g_selector(wpn:pointer; base_anim:PChar):pchar;stdcall;
var
  tmpstr:string;
  actor:pointer;
begin
  tmpstr:=base_anim;
  actor:=GetActor();
  //���� � ��� �������� - �� �����, �� � ������ �������� ������ ���
  if (actor<>nil) and (actor=GetOwner(wpn)) and (IsAimNow(wpn) or IsHolderInAimState(wpn)) then begin
    tmpstr:=tmpstr+'_aim';
  end;
  result:=anm_std_selector(wpn, PChar(tmpstr));
end;

procedure anm_shoot_g_std_patch();stdcall;
const anm_shoot_g:PChar = 'anm_shoot';
begin
  asm
    push 0                  //�������� ����� ��� �������� �����
    pushad
    pushfd
    push anm_shoot_g
    push esi
    call anm_shoot_g_selector  //�������� ������ � ������ �����
    mov ecx, [esp+$28]      //���������� ����� ��������
    mov [esp+$28], eax      //������ �� ��� ����� �������������� ������
    mov [esp+$24], ecx      //���������� ����� �������� �� 4 ����� ���� � �����
    popfd
    popad
    ret
  end;
end;



procedure anm_close_std_patch();stdcall;
const anm_close:PChar = 'anm_close';
begin
  asm
    push 0                  //�������� ����� ��� �������� �����
    pushad
    pushfd
    push anm_close
    push esi
    call anm_std_selector  //�������� ������ � ������ �����
    mov ecx, [esp+$28]      //���������� ����� ��������
    mov [esp+$28], eax      //������ �� ��� ����� �������������� ������
    mov [esp+$24], ecx      //���������� ����� �������� �� 4 ����� ���� � �����
    popfd
    popad
    ret
  end;
end;
//------------------------------------------------------------add_cartridge-----------------------------------------
procedure OnAddCartridge(wpn:pointer; param:integer);stdcall;
var
  hud_sect:PChar;
begin
  if (GetActor()<>nil) and (GetOwner(wpn)=GetActor()) and (leftstr(GetCurAnim(wpn), length('anm_add_cartridge'))='anm_add_cartridge') then begin
    hud_sect:=GetHUDSection(wpn);
    GetBuffer(wpn).SetReloaded(false);
    CWeaponShotgun__OnAnimationEnd_OnAddCartridge(wpn);
    GetBuffer(wpn).SetReloaded(true);
    MakeLockByConfigParam(wpn, hud_sect, PChar('lock_time_end_'+GetCurAnim(wpn)));
  end;
end;


function anm_add_cartridge_selector(wpn:pointer):pchar;stdcall;
var
  buf:WpnBuf;
  hud_sect:PChar;
begin
  anim_name := ModifierStd(wpn, 'anm_add_cartridge');
  result:=PChar(anim_name);
  buf:=GetBuffer(wpn);

  if buf <> nil then begin
    buf.SetReloaded(false);
    hud_sect:=GetHUDSection(wpn);
    if game_ini_line_exist(hud_sect, PChar('lock_time_start_'+anim_name)) then begin
      MakeLockByConfigParam(wpn, hud_sect, PChar('lock_time_start_'+anim_name), false, OnAddCartridge);
    end else begin
      MakeLockByConfigParam(wpn, hud_sect, PChar('lock_time_'+anim_name));
    end;
  end;
end;


procedure anm_add_cartridge_std_patch();stdcall;
asm
    push 0                  //�������� ����� ��� �������� �����
    pushad
    pushfd
    push esi
    call anm_add_cartridge_selector  //�������� ������ � ������ �����
    mov ecx, [esp+$28]      //���������� ����� ��������
    mov [esp+$28], eax      //������ �� ��� ����� �������������� ������
    mov [esp+$24], ecx      //���������� ����� �������� �� 4 ����� ���� � �����
    popfd
    popad
    ret
end;

//------------------------------------------------------------anm_open-----------------------------------------------

procedure OnAddCartridgeInOpen(wpn:pointer; param:integer);stdcall;
var
  hud_sect:PChar;
begin
  if (GetActor()<>nil) and (GetOwner(wpn)=GetActor()) and (leftstr(GetCurAnim(wpn), length('anm_open'))='anm_open') then begin
    hud_sect:=GetHUDSection(wpn);
    GetBuffer(wpn).SetReloaded(false);
    CWeaponShotgun__OnAnimationEnd_OnAddCartridge(wpn);
    GetBuffer(wpn).SetReloaded(true);
    MakeLockByConfigParam(wpn, hud_sect, PChar('lock_time_end_'+GetCurAnim(wpn)));
  end;
end;

function anm_open_selector(wpn:pointer):pchar;stdcall;
var
  buf:WpnBuf;
  hud_sect:PChar;
begin
  if IsWeaponJammed(wpn) then begin
    anim_name := ModifierStd(wpn, 'anm_reload');
    if GetAmmoInMagCount(wpn)=0 then anim_name:=anim_name+'_last';

    if GetAmmoInMagCount(wpn)>0 then begin
      CHudItem_Play_Snd(wpn, 'sndReloadJammed');
    end else begin
      CHudItem_Play_Snd(wpn, 'sndReloadJammedLast');
    end;

    result:=PChar(anim_name);
    exit;
  end;

  anim_name := ModifierStd(wpn, 'anm_open');
  result:=PChar(anim_name);

  if GetCurrentAmmoCount(wpn)>0 then begin
    CHudItem_Play_Snd(wpn, 'sndOpen');
  end else begin
    CHudItem_Play_Snd(wpn, 'sndOpenEmpty');
  end;

  buf:=GetBuffer(wpn);
  if buf <> nil then begin
    buf.SetReloaded(false);
    hud_sect:=GetHUDSection(wpn);
    if buf.AddCartridgeAfterOpen() then begin
      MakeLockByConfigParam(wpn, hud_sect, PChar('lock_time_start_'+anim_name), false, OnAddCartridgeInOpen);
    end else begin
      MakeLockByConfigParam(wpn, hud_sect, PChar('lock_time_'+anim_name));
    end;
  end;
end;

procedure anm_open_std_patch();stdcall;
begin
  asm
    push 0                  //�������� ����� ��� �������� �����
    pushad
    pushfd
    push esi
    call anm_open_selector  //�������� ������ � ������ �����
    mov ecx, [esp+$28]      //���������� ����� ��������
    mov [esp+$28], eax      //������ �� ��� ����� �������������� ������
    mov [esp+$24], ecx      //���������� ����� �������� �� 4 ����� ���� � �����
    popfd
    popad
    ret
  end;
end;

//----------------------------------------------------------anm_shots------------------------------------------------
function anm_shots_selector(wpn:pointer; play_breech_snd:boolean):pchar;stdcall;
var
  hud_sect:PChar;
  actor:pointer;
  fun:TAnimationEffector;
  modifier:string;
begin
  fun:=nil;

  if play_breech_snd then begin
    if IsExplosed(wpn) then begin
      CHudItem_Play_Snd(wpn, 'sndExplose');
    end else if IsWeaponJammed(wpn) then begin
      CHudItem_Play_Snd(wpn, 'sndJam');
    end else begin
      CHudItem_Play_Snd(wpn, 'sndBreechblock');
    end
  end;

  hud_sect:=GetHUDSection(wpn);
  anim_name:='anm_shoot';
  modifier:='';
  actor:=GetActor();
  //���� � ��� �������� - �� �����, �� � ������ �������� ������ ���
  if (actor<>nil) and (actor=GetOwner(wpn)) then begin
    //----------------------------------������������ ��������� ������----------------------------------------------------
    if IsAimNow(wpn) or IsHolderInAimState(wpn) then modifier:=modifier+'_aim';
    //----------------------------------������������ ��������� ������----------------------------------------------------
    modifier:=modifier + GetFireModeStateMark(wpn);
    if IsExplosed(wpn) then begin
      modifier:=modifier+'_explose';
      fun:=OnWeaponExplode_AfterAnim;
    end else if IsWeaponJammed(wpn) then begin
      modifier:=modifier+'_jammed';
    end else if GetAmmoInMagCount(wpn)=1 then begin
      modifier:=modifier+'_last';
    end;
    if (GetSilencerStatus(wpn)=1) or ((GetSilencerStatus(wpn)=2) and IsSilencerAttached(wpn)) then modifier:=modifier+'_sil';
    ModifierMoving(wpn, actor, modifier, 'enable_directions_anm_shoot_directions', 'enable_moving_anm_shoot');
    ModifierGL(wpn, modifier);
  end;

  ModifierBM16(wpn, modifier);


  //������ ������������� ���

  StartCompanionAnimIfNeeded('shoot'+modifier, wpn, true);


  anim_name:=anim_name+modifier;
  if not game_ini_line_exist(hud_sect, PChar(anim_name)) then begin
    log('Section ['+hud_sect+'] has no motion alias defined ['+anim_name+']');
    if IsDebug then Messenger.SendMessage('Animation not found, see log!');
    anim_name:='anm_reload';
    ModifierBM16(wpn, anim_name);
  end;
  result:=PChar(anim_name);
  MakeLockByConfigParam(wpn, hud_sect, PChar('lock_time_'+anim_name), true, fun, 0);


  SetAnimForceReassignStatus(wpn, true);
end;

procedure anm_shots_std_patch();stdcall;
begin
  asm
    push 0                  //�������� ����� ��� �������� �����
    pushad
    pushfd
    push 1
    push esi
    call anm_shots_selector  //�������� ������ � ������ �����
    mov ecx, [esp+$28]      //���������� ����� ��������
    mov [esp+$28], eax      //������ �� ��� ����� �������������� ������
    mov [esp+$24], ecx      //���������� ����� �������� �� 4 ����� ���� � �����
    popfd
    popad
    ret
  end;
end;

//---------------------------------------------------------anm_reload------------------------------------------------
procedure OnAmmoTimer(wpn:pointer; param:integer);stdcall;
var
  hud_sect:PChar;
begin
  //TODO: ������������� �������� ���������� ������ ��� ������������ �����
  if (GetCurrentState(wpn)=7) and (GetActor()<>nil) and (GetOwner(wpn)=GetActor()) and (leftstr(GetCurAnim(wpn), length('anm_reload'))='anm_reload') then begin
    hud_sect:=GetHUDSection(wpn);
    GetBuffer(wpn).SetReloaded(false);
    CWeaponMagazined__OnAnimationEnd_DoReload(wpn);
    GetBuffer(wpn).SetReloaded(true);
    MakeLockByConfigParam(wpn, hud_sect, PChar('lock_time_end_'+GetCurAnim(wpn)));
  end;
end;

function anm_reload_selector(wpn:pointer):pchar;stdcall;
var
  hud_sect:PChar;
  actor:pointer;
  buf:WpnBuf;
begin
  hud_sect:=GetHUDSection(wpn);
  anim_name:='anm_reload';
  actor:=GetActor();
  buf:=GetBuffer(wpn);
  //���� � ��� �������� - �� �����, �� � ������ �������� ������ ���
  if (actor<>nil) and (actor=GetOwner(wpn)) then begin
    //----------------------------------������������ ��������� ������----------------------------------------------------
    anim_name:=anim_name + GetFireModeStateMark(wpn);
    if IsWeaponJammed(wpn) then begin
      anim_name:=anim_name+'_jammed';
      if GetAmmoInMagCount(wpn)=0 then anim_name:=anim_name+'_last';
      SetAmmoTypeChangingStatus(wpn, $FF);
    end else if GetAmmoInMagCount(wpn)<=0 then begin
      if GetClassName(wpn)<>'WP_BM16' then anim_name:=anim_name+'_empty'; //� ���������� � ��� _0 ����� ����������� ��������
    end else if GetAmmoTypeChangingStatus(wpn)<>$FF then begin
      anim_name:=anim_name+'_ammochange';
    end;

    if IsHolderHasActiveDetector(wpn) and game_ini_line_exist(hud_sect, PChar(anim_name+'_detector')) then begin
       //log ('det+rel');
      anim_name:=anim_name+'_detector';
    end;

    if game_ini_r_bool_def(hud_sect, PChar('immediate_unhide_'+anim_name), false) then begin
      //���� ��������� ����� �������� - �� ���� ����������� ����� �������������� ���������, ���� ������� ��� ����� ��������� ����� (?)
      SetActorActionState(actor, actShowDetectorNow, true);
    end;

    ModifierGL(wpn, anim_name);
  end;

  ModifierBM16(wpn, anim_name);


  StartCompanionAnimIfNeeded(rightstr(anim_name, length(anim_name)-4), wpn, false);

  if not game_ini_line_exist(hud_sect, PChar(anim_name)) then begin
    log('Section ['+hud_sect+'] has no motion alias defined ['+anim_name+']');
    if IsDebug then Messenger.SendMessage('Animation not found, see log!');
    anim_name:='anm_reload';
    ModifierBM16(wpn, anim_name);
  end;
  result:=PChar(anim_name);

  if buf <> nil then buf.SetReloaded(false);
  if game_ini_line_exist(hud_sect, PChar('lock_time_start_'+anim_name)) then begin
    MakeLockByConfigParam(wpn, hud_sect, PChar('lock_time_start_'+anim_name), false, OnAmmoTimer);
    //log('lock-start, anm = '+anim_name);
  end else begin
    MakeLockByConfigParam(wpn, hud_sect, PChar('lock_time_'+anim_name));
  end;
end;


function anm_reload_g_selector(wpn:pointer):pchar;stdcall;
var
  hud_sect:PChar;
  actor:pointer;
  snd:string;
  buf:WpnBuf;
begin
  hud_sect:=GetHUDSection(wpn);
  anim_name:='anm_reload';
  actor:=GetActor();
  buf:=GetBuffer(wpn);
  //���� � ��� �������� - �� �����, �� � ������ �������� ������ ���
  if (actor<>nil) and (actor=GetOwner(wpn)) then begin
    //----------------------------------������������ ��������� ������----------------------------------------------------
    if (GetCurrentAmmoCount(wpn)>0) and  (GetAmmoTypeChangingStatus(wpn)<>$FF) then begin
      anim_name:=anim_name+'_ammochange';
      snd:='sndChangeGrenade';
    end else snd := 'sndLoadGrenade';

    if IsHolderHasActiveDetector(wpn) and game_ini_line_exist(hud_sect, PChar(anim_name+'_detector')) then begin
      //log ('det+rel');
      anim_name:=anim_name+'_detector';
      snd:=snd+'Detector';
    end;

    if game_ini_line_exist(hud_sect, PChar('immediate_unhide_'+anim_name)) and game_ini_r_bool(hud_sect, PChar('immediate_unhide_'+anim_name)) then begin
      //���� ��������� ����� �������� - �� ���� ����������� ����� �������������� ���������, ���� ������� ��� ����� ��������� ����� (?)
      SetActorActionState(actor, actShowDetectorNow, true);
    end;

    ModifierGL(wpn, anim_name);
    //�������� ����� ��������� ��� �������������
    StartCompanionAnimIfNeeded(rightstr(anim_name, length(anim_name)-4), wpn, false);
  end;

  if not game_ini_line_exist(hud_sect, PChar(anim_name)) then begin
    log('Section ['+hud_sect+'] has no motion alias defined ['+anim_name+']');
    if IsDebug then Messenger.SendMessage('Animation not found, see log!');
    anim_name:='anm_reload';
    ModifierBM16(wpn, anim_name);
  end;
  result:=PChar(anim_name);

  CHudItem_Play_Snd(wpn, PChar(snd));

  if buf <> nil then buf.SetReloaded(false);
  if game_ini_line_exist(hud_sect, PChar('lock_time_start_'+anim_name)) then begin
    MakeLockByConfigParam(wpn, hud_sect, PChar('lock_time_start_'+anim_name), false, OnAmmoTimer);
    //log('lock-start, anm = '+anim_name);
  end else begin
    MakeLockByConfigParam(wpn, hud_sect, PChar('lock_time_'+anim_name));
  end;
end;


procedure anm_reload_std_patch();stdcall;
begin
  asm
    push 0                  //�������� ����� ��� �������� �����
    pushad
    pushfd
    push esi
    call anm_reload_selector  //�������� ������ � ������ �����
    mov ecx, [esp+$28]      //���������� ����� ��������
    mov [esp+$28], eax      //������ �� ��� ����� �������������� ������
    mov [esp+$24], ecx      //���������� ����� �������� �� 4 ����� ���� � �����
    popfd
    popad
    ret
  end;
end;


procedure anm_reload_g_std_patch();stdcall;
const anm_reload_g:PChar = 'anm_reload';
begin
  asm
    push 0                  //�������� ����� ��� �������� �����
    pushad
    pushfd
//    push anm_reload_g
    push esi
//    call anm_std_selector  //�������� ������ � ������ �����
    call anm_reload_g_selector
    mov ecx, [esp+$28]      //���������� ����� ��������
    mov [esp+$28], eax      //������ �� ��� ����� �������������� ������
    mov [esp+$24], ecx      //���������� ����� �������� �� 4 ����� ���� � �����
    popfd
    popad
    ret
  end;
end;
//--------------------------------------------���� ��� �������� �������� ���������------------------------------
procedure GrenadeLauncherBugFix(); stdcall;
begin
  asm
    //�������� ���� �������� � �����
    mov [esp+4], 1
    // ������ ����������
    mov ecx, [esp]
    push ecx
    lea ecx, [esp+$1C];
    mov [esp+4], ecx
  end;
end;

procedure GrenadeAimBugFix(); stdcall;
begin
  asm
    //�������� ���� �������� � �����
    mov [esp+4], 1
    // ������ ����������
    mov ecx, [esp]
    push ecx
    lea ecx, [esp+$18];
    mov [esp+4], ecx
  end;
end;
//---------------------------------���� ��� ����������� ������������� ��� ����������� ���������-----------------------
procedure JammedBugFix(); stdcall;
begin
  asm
    cmp byte ptr [esi+$7f8], 1
    je @finish
    mov [esi+$45a], 0
    @finish:
  end;
end;
//------------���� ��� ����������� - ����� �� ���� �� ������� �������������� ����� �� ����------
procedure ReloadAnimPlayingPatch; stdcall;
begin
  asm
    pushad
      //push 0
      //call WeaponAdditionalBuffer.CanStartAction

      push kfRELOAD
      push esi
      call WeaponEvents.Weapon_SetKeyRepeatFlagIfNeeded
      cmp al, 1
    popad
    jne @finish

    mov edx, [esi]
    mov eax, [edx+$188]
    mov ecx, esi
    call eax
    @finish:
    ret
  end;
end;

procedure AmmoChangePlayingPatch; stdcall;
begin
  asm
    pushad
      push 0
      push esi
      call WeaponAdditionalBuffer.CanStartAction
      cmp al, 1
    popad
    mov eax, 1
    jne @finish

    mov eax, xrgame_addr
    add eax, $2bdcd0
    push [esp+4]
    call eax

    @finish:
    ret 4
  end;
end;
//--------------------------����������� ���� ��� ���� ������������ ������� ���������----------------------------------
//���������� ��������� ���� ������� � �����  
procedure SwitchAnimPlayingPatch; stdcall;
begin
  asm
    lea esi, [esi-$2e0];
    mov [esi+$2e8], 0
    mov [esi+$2e4], 0
    ret
  end;
end;

//� ���� -  �� ���� �������������, ����� �� ����
procedure SwitchAnimPlayingPatch2; stdcall;
begin
  asm
    //��������� ����������� ������������
    pushad
//      push 0
//      push esi
//      call WeaponAdditionalBuffer.CanStartAction
      push kfGLAUNCHSWITCH
      push esi
      call WeaponEvents.Weapon_SetKeyRepeatFlagIfNeeded
      cmp al, 1
    popad

    je @switch_ok
    //������������� ������ ������. ������� �� ������� � _����������_ �������� �����
    xor al, al
    mov [esi+$2e8], 0
    mov [esi+$2e4], 0
    pop esi     //���������� ������� ����� ��������
    pop esi
    ret
    
    @switch_ok:
    //������ ����������
    mov edx,[eax+$168]
    //������� � ���������� ���������
    ret
  end;
end;
//-----------------------------------------�������� �� ������������� ���������� ����----------------------------------
function CanReAssignIdleNow(CHudItem:pointer):boolean; stdcall;
var
  act, wpn:pointer;
  state:cardinal;
  iswpnthrowable, is_bino, canshoot:boolean;
begin
  result:=true;
  if WpnIsDetector(PChar(GetClassName(CHudItem))) then begin
    act:=GetActor();
    if (act<>nil) and (GetOwner(CHudItem)=act) then begin
      wpn:=GetActorActiveItem();
      if wpn<>nil then begin
        iswpnthrowable:=IsThrowable(PChar(GetClassName(wpn)));
        canshoot:=WpnCanShoot(PChar(GetClassName(wpn)));
        is_bino:=IsBino(PChar(GetClassName(wpn)));
        state:=GetCurrentState(wpn);

        if (iswpnthrowable and ((state=EMissileStates__eReady) or (state=EMissileStates__eThrowStart) or (state=EMissileStates__eThrow) or (state=EMissileStates__eThrowEnd))) then begin
          result:=false;
        end else if canshoot or is_bino then begin
          if IsAimNow(wpn) or IsHolderinAimState(wpn) then result:=false;
        end;
      end;
    end;
  end;
end;


procedure CHudItem__OnMovementChanged_Patch(); stdcall;
asm
  pushad
    sub esi, $2e0
    push esi
    call CanReAssignIdleNow
    cmp al, 0
  popad
  je @finish
    mov eax, [esi]
    mov edx, [eax+$60]
    call edx  // --> this->PlayAnimIdle()
    mov eax, xrgame_addr
    mov eax, [eax+$512bcc]    //CRenderDevice* Device
    mov ecx, [eax+$28]
    mov [esi+$10], ecx
  @finish:
  ret
end;


//-----------���� ��� idle_slow - ����� ���� �������� �������� ����� �������� �� �������� ���� � ��������� � �.�.-----
function NeedAssignAnim(act:pointer):boolean; stdcall;
begin
  result:=false;
  if GetActorActionState(act, actMovingForward)<>GetActorActionState(act, actMovingForward, mState_OLD)
    or GetActorActionState(act, actMovingBack)<>GetActorActionState(act, actMovingBack, mState_OLD)
    or GetActorActionState(act, actMovingLeft)<>GetActorActionState(act, actMovingLeft, mState_OLD)
    or GetActorActionState(act, actMovingRight)<>GetActorActionState(act, actMovingRight, mState_OLD)
    or GetActorActionState(act, actCrouch)<>GetActorActionState(act, actCrouch, mState_OLD)
    or GetActorActionState(act, actSlow)<>GetActorActionState(act, actSlow, mState_OLD)
  then begin
    result:=true;
  end;
end;

function CheckForceMoveReassign():boolean; stdcall;
var
  act:pointer;
begin
  result:=false;
  act:=GetActor;
  if act=nil then exit;
  result:=GetActorActionState(act, actModNeedMoveReassign);
  if result then SetActorActionState(act, actModNeedMoveReassign, false);
end;

procedure IdleSlowFixPatch(); stdcall;
begin
  asm
    //������ ���������� ���������
    and eax, $0F
    cmp [esp+$2C], eax
    //���� � ��� ���� ��������� ����� ����� - ������ ���� �� ������ 
    jne @finish
    //���� ��� �� ���������� ��������� ����� ����� ��������... ���������, �� ��������� �� ��� �.
    push eax
    push ebx

    mov eax, [ebx+$590]
    mov ebx, [ebx+$594]
    and eax, $0000003F
    and ebx, $0000003F
    cmp eax, ebx

    pop ebx
    pop eax

    jne @already_need_updating

    pushad
      call CheckForceMoveReassign
      cmp al, 0
    popad

    @already_need_updating:

{    pushad
      push ebx
      call NeedAssignAnim //BUG IN THIS FUNCTION!!!
      cmp al, 0
    popad  }
    
    @finish:
    ret
  end;
end;
//-------------------------------�� ���� ��������� bore-------------------------------------
procedure BoreAnimLockFix; stdcall;
begin
  asm
    pushad
      sub esi, $2e0
      push esi
      call WeaponAdditionalBuffer.CanBoreNow
      cmp al, 1
    popad
    je @finish
    mov eax, 0
    cmp [esi-$2e0+$2e4], 4
    jne @finish
    cmp [esi-$2e0+$2e8], 4
    jne @finish
    mov [esi-$2e0+$2e4], 0
    mov [esi-$2e0+$2e8], 0
    @finish:
    not edx
    test dl, 01
    ret;
  end;
end;
//---------------------------------�� ���� ������� ������ ��� �������� ���� � ����------------------------------------
procedure HideAnimLockFix; stdcall;
begin
  asm
    lea ecx, [esi-$2e0]
    pushad
      push ecx
      call WeaponEvents.OnWeaponHide
      cmp al, 1
    popad
    je @no_lock
    mov [esi-$2e0+$2e4], 0
    mov [esi-$2e0+$2e8], 0
    ret
    @no_lock:
    call eax
    ret;
  end;
end;
//------------------------------------------��������� �������� � ��������� ��� ����-----------------------------------
procedure ShootGLAnimLockFix; stdcall;
begin
  asm
    pushad
      push esi
      call WeaponAdditionalBuffer.OnShoot_CanShootNow
      cmp al, 1
    popad
    je @nolock
    //� ��� ��� - ������ ������ � �� ��������� ��� ���������
    xor al, al
    pop edi     //�������� ������� ����� ��������
    pop edi
    pop esi
    ret 8

    @nolock:
    cmp [esi+$690], 0
    ret
  end;
end;
//---------------------------------------�� ���� ����������� ��� ����-------------------------------------------------
procedure AimAnimLockFix; stdcall;
asm
    push eax
    //���������� ZF=0, ���� �������� �� �����
    cmp byte ptr [esi+$494], 0
    je @finish
    cmp byte ptr [esi+$496], 0
    jne @finish
    xor al, al
    pushad
      push esi
      call WeaponEvents.OnWeaponAimIn
      cmp al, 1
    popad
    jne @compare
    mov al, 1
    @compare:
    cmp al, 0
    @finish:
    pop eax
    ret
end;

//-------------------------------�� ���� ����� �� ������������ ������ �������--------------------------------------
procedure AimOutLockFix; stdcall;
asm
  pushad
    push esi
    call WeaponEvents.OnWeaponAimOut
    cmp al, 0
  popad
  je @finish

    mov eax, [esi]
    mov edx, [eax+$168]
    mov ecx, esi
    call edx //wpn->OnZoomOut()
  @finish:
  ret
end;
//---------------------------------------�� ���� �������� ��� ����-------------------------------------------------
procedure ShootAnimLockFix; stdcall;
begin
  //��������� ZF = 1, ���� ������ ��������
  asm
    pushad
      sub esi, $338
      push esi
      call WeaponAdditionalBuffer.OnShoot_CanShootNow
      cmp al, 0
    popad
    je @finish
    cmp [esi+$358], eax
    @finish:
    ret
  end;
end;
//---------------------------------------������ �������������� (� �� ������) �� ����-------------------------------------------------
function ProcessAllowSprintRequest(wpn:pointer):boolean;
var
  act:pointer;
begin
  result:=WeaponAdditionalBuffer.CanSprintNow(wpn);
  act:=GetActor();
  if not result and (act<>nil) and (act=GetOwner(wpn)) then begin
    SetActorActionState(act, actSprint, false, mState_WISHFUL);
    SetActorActionState(act, actSprint, false, mState_REAL);
    SetActorActionState(act, actSprint, false, mState_OLD);
  end;
end;

procedure SprintAnimLockFix; stdcall;
asm
    pushad
      push ecx
      call WeaponAdditionalBuffer.CanSprintNow
      cmp al, 0
    popad
    je @finish
      mov eax, [edx+$dc]
      call eax
      test al, al
    @finish:
    ret
end;
//---------------------------------------���������� �������������� �����������, ����� ��� �� �����-------------------------------------------------

procedure CWeaponMagazined__switch2_Empty_Patch(); stdcall;
asm
  pushad
    push 00
    push esi
    call virtual_CHudItem_SwitchState
  popad
  mov eax, 0
end;


procedure CWeaponMagazined__FireEnd_Patch(); stdcall;
asm
  //������ ��������� ������ ��������
  xor esi, esi
  test esi, esi
end;

//--------------------------------------------------------------------------------------------------------------------
//������������ ���� ��������
function NeedShootMix(wpn:pointer):boolean; stdcall;
var
  act: pointer;
  hud_sect:pchar;
  cur_anim:pchar;
begin
  result:=false;

  act:=GetActor();
  if (act=nil) or (GetOwner(wpn)<>act) then exit;
  hud_sect:=GetHUDSection(wpn);

  if not (game_ini_line_exist(hud_sect, 'mix_shoot_after_idle') and game_ini_r_bool(hud_sect, 'mix_shoot_after_idle')) then exit;

  cur_anim:=GetActualCurrentAnim(wpn);

  if leftstr(cur_anim, length('anm_idle')) = 'anm_idle' then result:=true;

end;



procedure ShootAnimMixPatch(); stdcall;
asm
  pop edx //���������� ����� ��������, ��� ������� �� �����������

  mov ecx, [esi+$2e4] //������������ ���������� ���
  push ecx
  push edi

  pushad
    push esi
    call NeedShootMix
    cmp al, 0
  popad
  je @nomix

  push 1
  jmp @finish

  @nomix:
  push 0

  @finish:
  push edx
  ret
end;

//----------------------------����� ���� ������������� �������� ��� ������������� ����� ������-------------------------
function MultiHideFix_IsHidingNow(wpn:pointer): boolean; stdcall;
begin
  if (GetCurrentState(wpn)=CHUDState__eHiding) and (leftstr(GetActualCurrentAnim(wpn), length('anm_hide')) = 'anm_hide') then
    result:=true
  else
    result:=false;
end;

procedure MultiHideFix(); stdcall;
asm
  //���������, ����� ����� ������ ��������
  //���� ��� �������� - �� �������� ��� ��������� ���������, ���� ��� ��� - �� ������� ��������.

  //�������� ����� �������� ��� ����������� CHudItem::PlayHUDMotion
  push [esp]
  push eax
  push ebx
  mov eax, [esp+$c] //ret addr
  mov ebx, [esp+$1c] // arg4
  mov [esp+$1c], eax   // ret --> arg4
  mov eax, [esp+$18] //arg3
  mov [esp+$18], ebx // arg4-->arg3
  mov ebx, [esp+$14] //arg2
  mov [esp+$14], eax // arg3 -->arg2
  mov eax, [esp+$10] //arg1
  mov [esp+$10], ebx //arg2 --> arg1
  mov [esp+$c], eax  //arg1 --> ret
  pop ebx
  pop eax
  add esp, 4

  //�������, �������� �� ��� �����
  pushad
    sub ecx, $2e0
    push ecx
    call MultiHideFix_IsHidingNow
    test eax, eax
  popad
  jne @already_playing_anim

  mov eax, xrgame_addr
  add eax, $2F9A60// CHudItem::PlayHUDMotion
  call eax

  jmp @finish
  @already_playing_anim:
  //������ �� ����, ������� ���������
  add esp, $10
  @finish:
end;

//---------------------------------------���� ���������������� ����������� �������� ��������---------------------------
//������������� ���������� �������� ���� � CWeaponMagazined::OnStateSwitch, ���� ���������� �������� �� ������� "�����������" � � MotionDef �� null

function CanAssignIdleAnimNow(wpn:pointer):boolean; stdcall;
const
  anm:string = 'anm_shoot';
begin
  result := ((GetAimFactor(wpn)>0.001) and (GetAimFactor(wpn)<0.999)) or (GetCurrentMotionDef(wpn)=nil) or (leftstr(GetActualCurrentAnim(wpn), length(anm))<>anm);
end;

procedure CWeaponMagazined__OnStateSwitch_IdlePatch(); stdcall;
asm
  pushad
    push ecx
    call CanAssignIdleAnimNow
    cmp al, 0
  popad
  
  je @finish
    call edx
  @finish:
  pop edi
  pop esi
  pop ebx
  ret 4
end;

//---------------------------------------------------------------------------------------------------------------------

procedure CWeapon__OnAnimationEnd(wpn:pointer); stdcall;
var
  act:pointer;
begin
  act:=GetActor();
  //�������� ���������� ���� ������ � ��������� � ����
  //������ ��� �������������� ��������������� ���� ����
  if (act<>nil) and (act=GetOwner(wpn)) and (leftstr(GetActualCurrentAnim(wpn), length('anm_idle'))='anm_idle')
    //���� ��� ��� �������� - �� ��������
    and GetActorActionState(act, actModSprintStarted, mstate_REAL) and GetActorActionState(act, actSprint, mstate_REAL)
  then begin
    SetActorActionState(act, actModNeedMoveReassign, true);
  end;
end;

procedure CWeapon__OnAnimationEnd_Patch(); stdcall;
asm
  pushad
    sub ecx, $2e0
    push ecx
    call CWeapon__OnAnimationEnd
  popad

  mov eax, xrgame_addr //������� �� ������ - ��������.
  add eax, $2F9640
  jmp eax
end;

//---------------------------------------------------------------------------------------------------------------------
procedure CWeaponKnife__OnAnimationEnd(wpn:pointer); stdcall;
begin
  //��������! �������� CWeapon__OnAnimationEnd � ��� ��������� ��-�� �������� ���������� ������ ��������, ��. ��� ����
  //
  CWeapon__OnAnimationEnd(wpn);
end;

procedure CWeaponKnife__OnAnimationEnd_Patch(); stdcall;
asm
  pushad
    sub ecx, $2e0
    push ecx
    call CWeaponKnife__OnAnimationEnd
  popad

  mov eax, [esp+8]
  cmp eax, 6
  ret
end;


//---------------------------------------------------------------------------------------------------------------------


procedure CHudItem__OnAnimationEnd_Patch(); stdcall;
asm
  pushad
    sub ecx, $2e0
    push ecx
    call WeaponEvents.OnWeaponHide
    cmp al, 1
  popad
  je @finish
    //������� �� ������� � ���������� �����
    pop eax
    ret
  @finish:
  mov eax, $4014
  ret
end;
//---------------------------------------------------------------------------------------------------------------------
function Init:boolean;
var
  buf:byte;
begin
  result:=false;

  movreass_remain_time:=0;
  movreass_last_update:=0;

  //�������� ���� ���������� ����� �����, �.�. ������ ��������� ������������ ��� � WeaponEvents.OnKnifeKick
  nop_code(xrGame_addr+$2d7503, 8);

  //���������� ���������� � ����������
  jump_addr:=xrGame_addr+$2bc7e0;
  if not WriteJump(jump_addr, cardinal(@CWeapon__OnAnimationEnd_Patch), 5, false) then exit;
  jump_addr:=xrGame_addr+$2d4f30;
  if not WriteJump(jump_addr, cardinal(@CWeaponKnife__OnAnimationEnd_Patch), 7, true) then exit;

  //������ ��� (���������� �����) � ������ ���������
  jump_addr:=xrGame_addr+$2D33B9;
  if not WriteJump(jump_addr, cardinal(@GrenadeLauncherBugFix), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D332D;
  if not WriteJump(jump_addr, cardinal(@GrenadeLauncherBugFix), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D3271;
  if not WriteJump(jump_addr, cardinal(@GrenadeAimBugFix), 5, true) then exit;
  //������ ������� ���� � ��������������
  jump_addr:=xrGame_addr+$2D0F2C;
  if not WriteJump(jump_addr, cardinal(@JammedBugFix), 7, true) then exit;

  //��� � ����������� �������� ��������
  jump_addr:=xrGame_addr+$2D1860; //CWeaponMagazinedWGrenade
  if not WriteJump(jump_addr, cardinal(@MultiHideFix), 5, true) then exit;
  jump_addr:=xrGame_addr+$2CCF78; //CWeaponMagazined
  if not WriteJump(jump_addr, cardinal(@MultiHideFix), 5, true) then exit;
  jump_addr:=xrGame_addr+$2C552F; //CWeaponPistol
  if not WriteJump(jump_addr, cardinal(@MultiHideFix), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D4FED; //CWeaponKnife
  if not WriteJump(jump_addr, cardinal(@MultiHideFix), 5, true) then exit;
  jump_addr:=xrGame_addr+$2E3A89; //���������
  if not WriteJump(jump_addr, cardinal(@MultiHideFix), 5, true) then exit;
  jump_addr:=xrGame_addr+$2C7649; //CMissile
  if not WriteJump(jump_addr, cardinal(@MultiHideFix), 5, true) then exit;
  jump_addr:=xrGame_addr+$2F38F3; //Flare
  if not WriteJump(jump_addr, cardinal(@MultiHideFix), 5, true) then exit;

  //�� ����� ��������� �������� �������� ��� ���������� ����
  jump_addr:=xrGame_addr+$2D0209;
  if not WriteJump(jump_addr, cardinal(@CWeaponMagazined__OnStateSwitch_IdlePatch), 8, false) then exit;
  //���������� ������� ������ � CWeaponMagazined::OnAnimationEnd, ����� ��� ��������� ����� �������� ��� ��������������� �� � else, � �� ������������ ���� � ����� ������� �� ����������� ���������� ������ �� �����
  buf:=$E9;
  if not WriteBufAtAdr(xrGame_addr+$2CCE20, @buf,1) then exit;


  //�� ����� �������������� 
  jump_addr:=xrGame_addr+$2CE821;
  if not WriteJump(jump_addr, cardinal(@ReloadAnimPlayingPatch), 12, true) then exit;

//----------------------------------------------------------
  //�������� �������������� �����������, ����� ��� �� �����
  jump_addr:=xrGame_addr+$2D07BF;
  if not WriteJump(jump_addr, cardinal(@CWeaponMagazined__switch2_Empty_Patch), 5, true) then exit;

  jump_addr:=xrGame_addr+$2CFFBE;
  if not WriteJump(jump_addr, cardinal(@CWeaponMagazined__FireEnd_Patch), 7, true) then exit;

  if not nop_code(xrGame_addr+$2D3ACE, 10) then exit;
//----------------------------------------------------------




  jump_addr:=xrGame_addr+$2becd9;
  if not WriteJump(jump_addr, cardinal(@AmmoChangePlayingPatch), 5, true) then exit;


  //���������� � �������������� �� �������� � �������
  jump_addr:=xrGame_addr+$2D1545;
  if not WriteJump(jump_addr, cardinal(@SwitchAnimPlayingPatch), 10, true) then exit;
  jump_addr:=xrGame_addr+$2D3DC4;
  if not WriteJump(jump_addr, cardinal(@SwitchAnimPlayingPatch2), 6, true) then exit;

  //��� �����
  jump_addr:=xrGame_addr+$2F9ED1;
  if not WriteJump(jump_addr, cardinal(@BoreAnimLockFix), 5, true) then exit;

  //��� ��������
  jump_addr:=xrGame_addr+$2D02FF;
  if not WriteJump(jump_addr, cardinal(@HideAnimLockFix), 8, true) then exit;
  jump_addr:=xrGame_addr+$2F96A0;
  if not WriteJump(jump_addr, cardinal(@CHudItem__OnAnimationEnd_Patch), 5, true) then exit;

  //��� �������� � ���������
  jump_addr:=xrGame_addr+$2D3ABE;
  if not WriteJump(jump_addr, cardinal(@ShootGLAnimLockFix), 7, true) then exit;

  //��� ������������
  jump_addr:=xrGame_addr+$2BECE4;
  if not WriteJump(jump_addr, cardinal(@AimAnimLockFix), 7, true) then exit;
  jump_addr:=xrGame_addr+$2BED9B;
  if not WriteJump(jump_addr, cardinal(@AimOutLockFix), 12, true) then exit;

  //��� ���������
  jump_addr:=xrGame_addr+$2CFE69;
  if not WriteJump(jump_addr, cardinal(@ShootAnimLockFix), 6, true) then exit;

  //��� �������
  jump_addr:=xrGame_addr+$26AF60;
  if not WriteJump(jump_addr, cardinal(@SprintAnimLockFix), 10, true) then exit;

  //������ ���������� ����� ���������� ����
  jump_addr:=xrGame_addr+$2727B3;
  if not WriteJump(jump_addr, cardinal(@IdleSlowFixPatch), 7, true) then exit;

  //��� ������������� ���������� ����� ������� ����� ���������, ����� �� � �������� ���� ����������� ���������
  jump_addr:=xrGame_addr+$2F977F;
  if not WriteJump(jump_addr, cardinal(@CHudItem__OnMovementChanged_Patch), 18, true) then exit;

  //������ ���� sndOpen � ����������, �.�. ������ �� ��������� ��� ����� ���������
  nop_code(xrGame_addr+$2DE6D5, 8);

  //������ ����������� ����������� ��������
  jump_addr:=xrGame_addr+$2F9FBC; //anm_idle
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D33A5; //anm_idle_w_gl
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D3319;//anm_idle_g
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2c5376;//anm_idle_empty
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;

  jump_addr:=xrGame_addr+$2F9B44;//anm_idle_sprint
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D33DB; //anm_idle_sprint_w_gl
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D334F;//anm_idle_sprint_g
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2c529c;//anm_idle_sprint_empty
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;


  jump_addr:=xrGame_addr+$2F9AC4;//anm_idle_moving
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D3370;//anm_idle_moving_g
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D33FC;//anm_idle_moving_w_gl
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2C530C;//anm_idle_moving_empty
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;

  jump_addr:=xrGame_addr+$2CD013;//anm_idle_aim
  if not WriteJump(jump_addr, cardinal(@anm_idle_std_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D3278;//anm_idle_w_gl_aim
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D325F;//anm_idle_g_aim
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2C53DC;//anm_idle_aim_empty
  if not WriteJump(jump_addr, cardinal(@anm_idle_std_patch), 5, true) then exit;

  //idles for WP_BM16
  ///////////////////////////////////////////////////////////////////////////////////
  jump_addr:=xrGame_addr+$2E08B7;//anm_idle_0
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2E088F;//anm_idle_1
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2E0867;//anm_idle_2
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2E0679;//anm_idle_moving_0
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2E0646;//anm_idle_moving_1
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2E0613;//anm_idle_moving_2
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2E082D;//anm_idle_aim_0
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2E0802;//anm_idle_aim_1
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2E07E2;//anm_idle_aim_2
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2E0759;//anm_idle_sprint_0
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2E0726;//anm_idle_sprint_1
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2E06F3;//anm_idle_sprint_2
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  ///////////////////////////////////////////////////////////////////////////////////

  jump_addr:=xrGame_addr+$2C519D;//anm_show_empty
  if not WriteJump(jump_addr, cardinal(@anm_show_sub_patch), 5, true) then exit;
{  jump_addr:=xrGame_addr+$2C75A5;//anm_show - grenades  ; moved to throwable
  if not WriteJump(jump_addr, cardinal(@anm_show_std_patch), 5, true) then exit;}
  jump_addr:=xrGame_addr+$2CCED2;//anm_show - spas12, rg6, knife
  if not WriteJump(jump_addr, cardinal(@anm_show_std_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D176A;//anm_show - assault
  if not WriteJump(jump_addr, cardinal(@anm_show_std_patch), 5, true) then exit;
{  jump_addr:=xrGame_addr+$2E3A2B;//anm_show - artefacts
  if not WriteJump(jump_addr, cardinal(@anm_show_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2EC9F3;//anm_show - detectors - DON'T USE IT!
  if not WriteJump(jump_addr, cardinal(@anm_show_sub_patch), 5, true) then exit;}
  jump_addr:=xrGame_addr+$2D173E;//anm_show_g
  if not WriteJump(jump_addr, cardinal(@anm_show_std_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D1721;//anm_show_w_gl
  if not WriteJump(jump_addr, cardinal(@anm_show_std_patch), 5, true) then exit;
  ///////////////////////////////////////////////////////////////////////////////////
  jump_addr:=xrGame_addr+$2C54FD;//anm_hide_empty
  if not WriteJump(jump_addr, cardinal(@anm_hide_sub_patch), 5, true) then exit;
{  jump_addr:=xrGame_addr+$2C7624;//anm_hide - grenades
  if not WriteJump(jump_addr, cardinal(@anm_hide_std_patch), 5, true) then exit;}
  jump_addr:=xrGame_addr+$2CCF42;//anm_hide - spas12, rg6
  if not WriteJump(jump_addr, cardinal(@anm_hide_std_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D182A;//anm_hide - assault
  if not WriteJump(jump_addr, cardinal(@anm_hide_std_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D4FB5;//anm_hide - knife
  if not WriteJump(jump_addr, cardinal(@anm_hide_std_patch), 5, true) then exit;
{  jump_addr:=xrGame_addr+$2E3A6D;//anm_hide - artefacts
  if not WriteJump(jump_addr, cardinal(@anm_hide_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2EC951;//anm_hide - detectors - DON'T USE IT!
  if not WriteJump(jump_addr, cardinal(@anm_hide_sub_patch), 5, true) then exit;}
  jump_addr:=xrGame_addr+$2D17FE;//anm_hide_g
  if not WriteJump(jump_addr, cardinal(@anm_hide_std_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D17E1;//anm_show_w_gl
  if not WriteJump(jump_addr, cardinal(@anm_hide_std_patch), 5, true) then exit;
  //////////////////////////////////////////////////////////////////////////////////
  jump_addr:=xrGame_addr+$2F9BC4;//anm_bore
  if not WriteJump(jump_addr, cardinal(@anm_bore_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D1A7B;//anm_bore_g
  if not WriteJump(jump_addr, cardinal(@anm_bore_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D1A99;//anm_bore_w_gl
  if not WriteJump(jump_addr, cardinal(@anm_bore_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2C5227;//anm_bore_empty
  if not WriteJump(jump_addr, cardinal(@anm_bore_edi_patch), 5, true) then exit;
  ////////////////////////////////////////////////////////////////////////////////
  jump_addr:=xrGame_addr+$2D1A05;//anm_switch
  if not WriteJump(jump_addr, cardinal(@anm_switch_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D19D0;//anm_switch_g
  if not WriteJump(jump_addr, cardinal(@anm_switch_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D191C;//anm_shoot_g
  if not WriteJump(jump_addr, cardinal(@anm_shoot_g_std_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D1E3D;//anm_shoot_g
  if not WriteJump(jump_addr, cardinal(@anm_reload_g_std_patch), 5, true) then exit;
  ////////////////////////////////////////////////////////////////////////////////
  jump_addr:=xrGame_addr+$2C5571;//anm_shots, anm_shots_l - pistols
  if not WriteJump(jump_addr, cardinal(@anm_shots_std_patch), 14, true) then exit;
  jump_addr:=xrGame_addr+$2CD0B2;//anm_shots - other
  if not WriteJump(jump_addr, cardinal(@anm_shots_std_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D196C;//anm_shots_w_gl
  if not WriteJump(jump_addr, cardinal(@anm_shots_std_patch), 5, true) then exit;
  ////////////////////////////////////////////////////////////////////////////////
  jump_addr:=xrGame_addr+$2DE462;//anm_open
  if not WriteJump(jump_addr, cardinal(@anm_open_std_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2DE542;//anm_close
  if not WriteJump(jump_addr, cardinal(@anm_close_std_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2DE4D2;//anm_add_cartridge
  if not WriteJump(jump_addr, cardinal(@anm_add_cartridge_std_patch), 5, true) then exit;

  jump_addr:=xrGame_addr+$2CCFB2;//anm_reload
  if not WriteJump(jump_addr, cardinal(@anm_reload_std_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D18AB;//anm_reload_w_gl
  if not WriteJump(jump_addr, cardinal(@anm_reload_std_patch), 5, true) then exit;

  jump_addr:=xrGame_addr+$2E057C;//anm_reload_1 - BM16
  if not WriteJump(jump_addr, cardinal(@anm_reload_std_patch), 5, true) then exit;

  jump_addr:=xrGame_addr+$2E0547;//anm_reload_2 - BM16
  if not WriteJump(jump_addr, cardinal(@anm_reload_std_patch), 5, true) then exit;

  jump_addr:=xrGame_addr+$2C5451;//reload - pistols
  if not WriteJump(jump_addr, cardinal(@anm_reload_std_patch), 14, true) then exit;


  //����������� ���������:
  //CWeaponMagazined:PlayAnimShoot
  jump_addr:=xrGame_addr+$2CD0CF;
  if not WriteJump(jump_addr, cardinal(@ShootAnimMixPatch), 10, true) then exit;  
  //CWeaponPistol::PlayAnimShoot
  jump_addr:=xrGame_addr+$2C5597;
  if not WriteJump(jump_addr, cardinal(@ShootAnimMixPatch), 10, true) then exit;

  result:=true;
end;


end.
