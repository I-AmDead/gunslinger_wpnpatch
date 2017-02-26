unit WeaponUpdate;

interface
function Init:boolean;
//function WpnUpdate(wpn:pointer):boolean; stdcall;
procedure ReassignWorldAnims(wpn:pointer); stdcall;
procedure CWeapon__ModUpdate(wpn:pointer); stdcall;

implementation
uses Messenger, BaseGameData, GameWrappers, WpnUtils, LightUtils, sysutils, WeaponAdditionalBuffer, WeaponEvents, ActorUtils, strutils, math, gunsl_config, ConsoleUtils;



var patch_addr:cardinal;
  tst_light:pointer;

//���������� � ������ ������� ��� �� ������
procedure ProcessLaserDot(wpn: pointer; laser_bones:PChar; laser_particle:PChar);
var
  act:pointer;
  buf:WpnBuf;
  pos:FVector3;
  dir:FVector3;

  koef:single;
begin
  buf:=GetBuffer(wpn);
  if buf=nil then exit;
  buf.SetLaserInstalledStatus(true);

  act:=GetActor();
  if not buf.IsLaserEnabled() then begin
    SetWeaponMultipleBonesStatus(wpn, laser_bones, false);
  end else begin
    SetWeaponMultipleBonesStatus(wpn, laser_bones, true);
  end;
//TODO:�������� �������� �� ��, �������������� �� ������ ��� ��� ���
  if (act=nil) or (act<>GetOwner(wpn)) or (GetActorActiveItem()<>wpn) or (GetNextState(wpn)=EHudStates__eHidden) or  (not buf.IsLaserEnabled()) or IsDemoRecord() then begin
//  if (act=nil) or (act<>GetOwner(wpn)) then begin// or (GetCurrentState(wpn)=CHUDState__eHidden) or (not buf.IsLaserEnabled()) or IsDemoRecord() then begin
//    log(inttostr(cardinal(wpn)));
    if buf.IsLaserDotInited() then begin
      buf.SetLaserDotParticle(nil);
    end;
    exit;
  end;



  if not buf.IsLaserDotInited() then begin
    buf.SetLaserDotParticle(laser_particle);
//    log('playing at '+floattostr((psingle(GetPosition(wpn)))^));
  end;


  pos:=FVector3_copyfromengine(CRenderDevice__GetCamPos());
  dir:=FVector3_copyfromengine(CRenderDevice__GetCamDir());

  koef:=GetLaserPointDrawingDistance(GetTargetDist());
//  log (floattostr(koef));

  pos.x:=pos.x+koef*dir.x;
  pos.y:=pos.y+koef*dir.y;
  pos.z:=pos.z+koef*dir.z;

  buf.PlayLaserDotParticleAt(@pos);

end;

procedure ProcessAmmoAdv(wpn: pointer);
var
  hud_sect:PChar;
  bones_sect:PChar;
  bones:PChar;
  cnt:integer;
begin
  hud_sect:=GetHUDSection(wpn);
  bones_sect:= game_ini_read_string(hud_sect, 'ammo_params_section');
  cnt:=GetAmmoInMagCount(wpn);

  if IsWeaponJammed(wpn) and game_ini_line_exist(bones_sect, 'additional_ammo_bone_when_jammed') and game_ini_r_bool(bones_sect, 'additional_ammo_bone_when_jammed') then
    cnt:=cnt+1;

  //�������� ���
  bones:= game_ini_read_string(bones_sect, 'all_bones');
  SetWeaponMultipleBonesStatus(wpn, bones, false);

  //���������� ������
  bones:= game_ini_read_string(bones_sect, PChar('configuration_'+inttostr(cnt)));
  SetWeaponMultipleBonesStatus(wpn, bones, true);
end;


procedure ProcessAmmo(wpn: pointer);
var hud_sect:PChar;
    prefix, prefix_hide, prefix_var:string;
    i:integer;
    start_index, finish_index, limitator:integer;
begin
  hud_sect:=GetHUDSection(wpn);
  if game_ini_line_exist(hud_sect, 'use_advanced_ammo_bones') and game_ini_r_bool(hud_sect, 'use_advanced_ammo_bones') then begin
    ProcessAmmoAdv(wpn);
    exit;
  end;

  if not game_ini_line_exist(hud_sect, 'use_ammo_bones') or (game_ini_r_bool(hud_sect, 'use_ammo_bones')=false) then exit;
  prefix:= game_ini_read_string(hud_sect, 'ammo_bones_prefix');

  if game_ini_line_exist(hud_sect, 'ammo_hide_bones_prefix') then
    prefix_hide:= game_ini_read_string(hud_sect, 'ammo_hide_bones_prefix')
  else
    prefix_hide:='';

  if game_ini_line_exist(hud_sect, 'ammo_var_bones_prefix') then
    prefix_var:= game_ini_read_string(hud_sect, 'ammo_var_bones_prefix')
  else
    prefix_var:='';


  if game_ini_line_exist(hud_sect, 'start_ammo_bone_index') then
    start_index:= strtoint(game_ini_read_string(hud_sect, 'start_ammo_bone_index'))
  else
    start_index:=0;

  if game_ini_line_exist(hud_sect, 'end_ammo_bone_index') then
    limitator:= strtoint(game_ini_read_string(hud_sect, 'end_ammo_bone_index'))
  else
    limitator:=0;

  finish_index:=start_index+GetAmmoInMagCount(wpn)-1;

  if IsWeaponJammed(wpn) and game_ini_line_exist(hud_sect, 'additional_ammo_bone_when_jammed') and game_ini_r_bool(hud_sect, 'additional_ammo_bone_when_jammed') then
    finish_index:=finish_index+1;

  if game_ini_line_exist(hud_sect, 'ammo_divisor_up') then
    finish_index:=ceil(finish_index/strtoint(game_ini_read_string(hud_sect, 'ammo_divisor_up')))
  else if game_ini_line_exist(hud_sect, 'ammo_divisor_down') then
    finish_index:=floor(finish_index/strtoint(game_ini_read_string(hud_sect, 'ammo_divisor_down')));

  if finish_index>limitator then finish_index:=limitator;

//  if wpn=GetActorActiveItem() then SendMessage(PChar(inttostr(start_index)+' '+PChar(inttostr(finish_index))+' '+PChar(inttostr(limitator))));

  for i:=start_index to finish_index do begin
    SetWeaponMultipleBonesStatus(wpn, PChar(prefix+inttostr(i)), true);
    if prefix_hide<>'' then begin
      SetWeaponMultipleBonesStatus(wpn, PChar(prefix_hide+inttostr(i)), false);
    end;
  end;
  for i:= finish_index+1 to limitator do begin
    SetWeaponMultipleBonesStatus(wpn, PChar(prefix+inttostr(i)), false);
    if prefix_hide<>'' then begin
      SetWeaponMultipleBonesStatus(wpn, PChar(prefix_hide+inttostr(i)), true);
    end;
  end;

  if prefix_var<>'' then begin
    for i:= start_index-1 to limitator do begin
      SetWeaponMultipleBonesStatus(wpn, PChar(prefix_var+inttostr(i)), i=finish_index);
    end;
  end;
end;

procedure HideOneUpgradeLevel(wpn:pointer; up_gr_section:pchar); stdcall;
var
  up_sect:PChar;
  up_group:string;
  tmp:string;
  all_subelements, element:string;
begin
  all_subelements:=game_ini_read_string(up_gr_section, 'elements');
  
  while (GetNextSubStr(all_subelements, element, ',')) do begin
    //���������� �����, ������� ��������� ������ �������
    if game_ini_line_exist(PChar(element), 'effects') then begin
      up_group:=game_ini_read_string(PChar(element), 'effects');
      while (GetNextSubStr(up_group, tmp, ',')) do begin
        HideOneUpgradeLevel(wpn, PChar(tmp));
      end;
    end;

    //������ ���������, ����� ����� ���� ����������, ����� ������ ������� ����������
    up_sect:=game_ini_read_string(PChar(element), 'section');
    if game_ini_line_exist(up_sect, 'show_bones') then SetWeaponMultipleBonesStatus(wpn, game_ini_read_string(up_sect, 'show_bones'), false);
  end;
end;

procedure ProcessUpgrade(wpn:pointer); stdcall;
var all_upgrades:string;
    section:PChar;
    up_gr_sect:string;
    i:integer;
begin
  section:=GetSection(wpn);
  //������ ��� �����, ������� ���� ������, ������ �� ������ ������ ������
  if game_ini_line_exist(section, 'def_hide_bones') then SetWeaponMultipleBonesStatus(wpn, game_ini_read_string(section, 'def_hide_bones'), false);
  if game_ini_line_exist(section, 'def_show_bones') then SetWeaponMultipleBonesStatus(wpn, game_ini_read_string(section, 'def_show_bones'), true);  
  
  //��������� ������ ���� ��������� ���� �� �������
  if not game_ini_line_exist(section, 'upgrades') then exit;
  all_upgrades:=game_ini_read_string(section, 'upgrades');
  //��������� �� ���
  while (GetNextSubStr(all_upgrades, up_gr_sect, ',')) do begin
      HideOneUpgradeLevel(wpn, PChar(up_gr_sect));
  end;

  //���������, ����� �������� ��� �����������, � ��������� ��
  for i:=0 to GetInstalledUpgradesCount(wpn)-1 do begin
    section:=GetInstalledUpgradeSection(wpn, i);
    section:=game_ini_read_string(section, 'section');
    if game_ini_line_exist(section, 'show_bones') then SetWeaponMultipleBonesStatus(wpn, game_ini_read_string(section, 'show_bones'), true);
    if game_ini_line_exist(section, 'hide_bones') then SetWeaponMultipleBonesStatus(wpn, game_ini_read_string(section, 'hide_bones'), false);
    if game_ini_line_exist(section, 'hud') then begin
      SetHUDSection(wpn, game_ini_read_string(section, 'hud'));
    end;
    if game_ini_line_exist(section, 'visual') then begin
      SetWpnVisual(wpn, game_ini_read_string(section, 'visual'));
    end;

    if game_ini_line_exist(section, 'laser') and game_ini_r_bool(section, 'laser') then begin
      ProcessLaserDot(wpn, game_ini_read_string(section, 'laser_ray_bones'), game_ini_read_string(section, 'laser_particle'));
    end;
  end;
end;

procedure ProcessScope(wpn:pointer); stdcall;
var section:PChar;
    curscope:string;
    scopes:string;
    tmp:string;
    status:boolean;
begin
  section:=GetSection(wpn);
  if not game_ini_line_exist(section, 'scopes_sect') then exit;
  scopes:=game_ini_read_string(section, 'scopes_sect');
  if IsScopeAttached(wpn) and (GetScopeStatus(wpn)=2) then curscope:=GetCurrentScopeSection(wpn) else curscope:='';
  while (GetNextSubStr(scopes, tmp, ',')) do begin
    if tmp=curscope then status:=true else status:=false;
    if game_ini_line_exist(PChar(tmp), 'bones') then begin;
      SetWeaponMultipleBonesStatus(wpn,game_ini_read_string(PChar(tmp), 'bones'), status);
    end;
    if game_ini_line_exist(PChar(tmp), 'hide_bones') then begin
      SetWeaponMultipleBonesStatus(wpn,game_ini_read_string(PChar(tmp), 'hide_bones'), not status);
    end;
  end;
end;

procedure ReassignWorldAnims(wpn:pointer); stdcall;
var
  sect:PChar;
  anm:string;
  rest_anm:string;
  state:cardinal;
  firemode:integer;
  bmixin:boolean;
begin

  state:=cardinal(GetNextState(wpn));
  if (not GetAnimForceReassignStatus(wpn)) then exit;
  sect:=GetSection(wpn);
  if not game_ini_line_exist(sect, 'use_world_anims') or not game_ini_r_bool(sect, 'use_world_anims') then exit;

  bmixin:=true;
  if state=EHudStates__eIdle then begin
    anm:='wanm_idle';
  end else if state=EHudStates__eShowing then begin
    anm:='wanm_draw'
  end else if state=EHudStates__eHiding then begin
    anm:='wanm_holster';
  end else if state=EWeaponStates__eFire then begin
    anm:='wanm_shoot';
    if ((WpnUtils.GetGLStatus(wpn)=1) or (WpnUtils.IsGLAttached(wpn))) and WpnUtils.IsGLEnabled(wpn) then begin
      anm:=anm+'_gl';
    end else if GetAmmoInMagCount(wpn)<=0 then begin
      rest_anm:=anm;
      anm:=anm+'_last';
      if not(game_ini_line_exist(sect, PChar(anm))) or (trim(game_ini_read_string(sect,PChar(anm)))='') then begin
        anm:=rest_anm;
      end;
    end;
  end else if state=EWeaponStates__eReload then begin
    anm:='wanm_reload';
  end else begin
    anm:='wanm_idle';
  end;

  if not game_ini_line_exist(sect, PChar(anm)) or (trim(game_ini_read_string(sect,PChar(anm)))='') then begin
    anm:='wanm_idle';
  end;

  rest_anm:=anm;
  if IsWeaponJammed(wpn) then begin
    anm:=anm+'_jammed';
  end else if (GetAmmoInMagCount(wpn)<=0) and (state<>EWeaponStates__eFire) then begin
    anm:=anm+'_empty';
  end;
  if not(game_ini_line_exist(sect, PChar(anm))) or (trim(game_ini_read_string(sect,PChar(anm)))='') then begin
    anm:=rest_anm;
  end;

  rest_anm:=anm;
  firemode:=CurrentQueueSize(wpn);
  if firemode<0 then begin
    anm:=anm+'_a';
  end else begin
    anm:=anm+'_'+inttostr(firemode);
  end;

  if not(game_ini_line_exist(sect, PChar(anm))) or (trim(game_ini_read_string(sect,PChar(anm)))='') then begin
    anm:=rest_anm;
  end;  

  PlayCycle(wpn, game_ini_read_string(sect,PChar(anm)), bmixin);

  SetAnimForceReassignStatus(wpn, false);
end;

procedure CWeapon__ModUpdate(wpn:pointer); stdcall;
var
  buf:WpnBuf;
  sect:PChar;
begin
    if get_server_object_by_id(GetID(wpn))=nil then exit;

    //������ ������
    buf:=WeaponAdditionalBuffer.GetBuffer(wpn);
    if buf<>nil then begin
      if not buf.Update then Log('Failed to update wpn: '+inttohex(cardinal(wpn), 8));
    end;    

    if ((GetActor()=nil) or (GetOwner(wpn)<>GetActor())) then begin
      if IsExplosed(wpn) then OnWeaponExplode_AfterAnim(wpn, 0);
      if leftstr(GetCurAnim(wpn), length('anm_attach_scope_'))='anm_attach_scope_' then DetachAddon(wpn, 1);
      if leftstr(GetCurAnim(wpn), length('anm_attach_gl'))='anm_attach_gl' then DetachAddon(wpn, 2);
      if leftstr(GetCurAnim(wpn), length('anm_attach_sil'))='anm_attach_sil' then DetachAddon(wpn, 4);
    end;

    //���������� ������������� ��������
    ProcessUpgrade(wpn);
    //������ ��������� ������������� ������
    ProcessScope(wpn);
    //���������� � ������������� ��������
    ProcessAmmo(wpn);
    //����� �� 3-�� ����
    ReassignWorldAnims(wpn);

    sect:=GetSection(wpn);
    if game_ini_line_exist(sect, 'laser') and game_ini_r_bool(sect, 'laser') then begin
      ProcessLaserDot(wpn, game_ini_read_string(sect, 'laser_ray_bones'), game_ini_read_string(sect, 'laser_particle'));
    end;


  {if tst_light = nil then tst_light:=LightUtils.CreateLight;
  LightUtils.Enable(tst_light, true);
  asm
    pushad
    pushfd

    mov ebp, $492ed8

    mov ebx, tst_light
    push [ebp+$38]
    push [ebp+$34]
    push [ebp+$30]
    push ebx
    call LightUtils.SetPos

    push [ebp+$44]
    push [ebp+$40]
    push [ebp+$3C]
    push ebx
    call LightUtils.SetDir

    popfd
    popad
  end;     }
end;

procedure CWeapon__UpdateCL_Patch();stdcall;
asm
    pushad
      push esi
      call CWeapon__ModUpdate
    popad
    mov eax, [esi+$338]
end;


function AdditionalCrosshairHideConditions(wpn:pointer):boolean; stdcall;
var
  buf:WpnBuf;
begin
  //������� true, ���� ������ ��� �� ����������


  if GetCurrentDifficulty()>=gd_veteran then begin
    result:=false;
    exit;
  end;
  buf:=GetBuffer(wpn);
  if (buf<>nil) and buf.IsLaserInstalled() and buf.IsLaserEnabled() then begin
    result:=false;
    exit;  
  end;
  result:=true;
end;

procedure CWeapon__show_crosshair_Patch(); stdcall;
asm
  pushad
    push esi
    call AdditionalCrosshairHideConditions
    cmp al, 1
  popad
  je @show
  xor eax, eax
  ret
  @show:
  mov eax, 1
  ret
end;

function Init:boolean;
begin
  result:=false;
  tst_light:=nil;

  patch_addr:=xrGame_addr+$2C04A0;
  if not WriteJump(patch_addr, cardinal(@CWeapon__UpdateCL_Patch), 6, true) then exit;


  //���� CWeapon::show_crosshair, ����� ��� ������������� ��� ����������� ����������
  patch_addr:=xrGame_addr+$2bd1e5;
  if not WriteJump(patch_addr, cardinal(@CWeapon__show_crosshair_Patch), 5, true) then exit;

  result:=true;
end;
end.

