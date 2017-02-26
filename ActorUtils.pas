unit ActorUtils;

interface
const
  actMovingForward:cardinal = $1;
  actMovingBack:cardinal = $2;
  actMovingLeft:cardinal = $4;
  actMovingRight:cardinal = $8;
  actCrounch:cardinal = $10;
  actSlow:cardinal = $20;
  actSprint:cardinal = $1000;

  actAimStarted:cardinal = $4000000;
  actShowDetectorNow:cardinal = $8000000;
  actModSprintStarted:cardinal = $10000000;


  mState_WISHFUL:cardinal = $58c;
  mState_OLD:cardinal = $590;
  mState_REAL:cardinal = $594;



function GetActor():pointer; stdcall;
function GetActorActionState(stalker:pointer; mask:cardinal; state:cardinal=$594):boolean; stdcall;
procedure CreateObjectToActor(section:PChar); stdcall;
function IsHolderInSprintState(wpn:pointer):boolean; stdcall; //�������� ������ ��� ������, ��� ������ ������ ������ false!
function IsHolderHasActiveDetector(wpn:pointer):boolean; stdcall;
function IsHolderInAimState(wpn:pointer):boolean;stdcall;
procedure SetActorActionState(stalker:pointer; mask:cardinal; set_value:boolean; state:cardinal=$594); stdcall;
function GetActorActiveItem():pointer; stdcall;
function ItemInSlot(act:pointer; slot:integer):pointer; stdcall;
function Init():boolean; stdcall;
function CheckActorWeaponAvailabilityWithInform(wpn:pointer):boolean;



var NeedUnZoom_flag:boolean;


implementation
uses Messenger, BaseGameData, WpnUtils, GameWrappers, DetectorUtils,WeaponAdditionalBuffer, sysutils, KeyUtils, UIUtils;

function GetActor():pointer; stdcall;
begin
  asm
    mov eax, xrgame_addr
    add eax, $64e2c0;
    mov eax, [eax]
    mov @result, eax
  end;
end;

function GetActorActionState(stalker:pointer; mask:cardinal; state:cardinal=$594):boolean; stdcall;
asm
  push ecx
  push edx
  mov edx, state

  @body:
  mov ecx, mask
  mov @result, 0
  mov eax, stalker
  mov eax, [eax+edx]
  test eax, ecx
  je @finish
  mov @result, 1

  @finish:
  pop edx
  pop ecx
end;

procedure SetActorActionState(stalker:pointer; mask:cardinal; set_value:boolean; state:cardinal=$594); stdcall;
asm
  pushad
  mov edx, state

  @body:
  mov eax, stalker
  mov ecx, mask

  cmp set_value, 0
  je @clear_flag
    or [eax+edx], ecx
    jmp @finish
  @clear_flag:
    not ecx
    and [eax+edx], ecx
  @finish:
  popad
end;

function IsActorAim(stalker:pointer):boolean; stdcall;
begin
  asm
    mov eax, stalker
    mov al, [eax+$5D4]
    mov @result, al
  end;
end;

procedure CreateObjectToActor(section:PChar); stdcall;
var act:pointer;
begin
  act:=GetActor();
  if (act=nil) then exit;

  asm
    pushad
      call alife
      
      push 0
      push 0
      push 0
      mov ecx, act
      add ecx, $80
      push ecx      //position
      push section
      push eax      //alife simulator ptr

      mov ebx, xrgame_addr
      add ebx, $99490
      call ebx      //call create

      add esp, $18
    popad
  end;
end;

function IsHolderInSprintState(wpn:pointer):boolean;stdcall;
var actor:pointer;
    holder:pointer;
begin
  holder:=WpnUtils.GetOwner(wpn);
  actor:=GetActor();
  if (actor<>nil) and (actor=holder) and (GetActorActionState(holder, actSprint) or GetActorActionState(holder, actModSprintStarted)) then begin
    result:=true;
  end else
    result:=false;
end;

function IsHolderInAimState(wpn:pointer):boolean;stdcall;
var actor:pointer;
    holder:pointer;
begin
  holder:=WpnUtils.GetOwner(wpn);
  actor:=GetActor();
  if (actor<>nil) and (actor=holder) and (GetActorActionState(holder, actAimStarted)) then begin
    result:=true;
  end else
    result:=false;
end;

function IsHolderHasActiveDetector(wpn:pointer):boolean; stdcall;
var
  holder:pointer;
begin
  holder:=WpnUtils.GetOwner(wpn);
  if (holder<>nil) then begin
    result:=(DetectorUtils.GetActiveDetector(holder)<>nil);
  end else
    result:=false;
end;

function GetActorActiveItem():pointer; stdcall;
asm
  pushfd
  
  mov eax, xrGame_addr
  add eax, $64F0E4
  mov eax, [eax]
  mov eax, [eax+$94]
  cmp eax, 0
  je @finish
  mov eax, [eax+4]
  sub eax, $2e0

  @finish:
  popfd
  mov @result, eax
end;

procedure ProcessZoom(act:pointer);
var
  itm:pointer;
begin
  itm:=GetActorActiveItem();
  if (itm=nil) or not WpnCanShoot(PChar(GetClassName(itm))) then exit;

  if IsActionKeyPressed(kWPN_ZOOM) then begin
    if not IsAimToggle() and (CDialogHolder__TopInputReceiver()=nil) and CanAimNow(itm) and not IsAimNow(itm) then begin
      virtual_Action(itm, kWPN_ZOOM, kActPress);
      NeedUnZoom_flag := false;
    end;
  end;

  if NeedUnZoom_flag then begin
    if IsAimNow(itm) then begin
      if CanLeaveAimNow(itm) then begin
        virtual_Action(itm, kWPN_ZOOM, kActRelease);
      end;
    end else begin
      NeedUnZoom_flag:=false;
    end;
  end;
end;

procedure ActorUpdate(act:pointer); stdcall;
var
  itm, det:pointer;
  hud_sect:PChar;
begin
  det:=ItemInSlot(act, 9);

  if det <> nil then begin
    if GetActorActionState(act, actShowDetectorNow) and (GetActiveDetector(act)=nil) then begin
      SetDetectorForceUnhide(det, true);
    end else if GetCurrentState(det)=2 then begin //�� ��������� ������� ��������. �������� ����� �����, ���� ������ �� ��������� ������ �����-�� ��������.
      itm:=GetActorActiveItem();
      if (itm<>nil) and WpnCanShoot(PChar(GetClassName(itm))) then begin
        hud_sect:=GetHUDSection(itm);
        if (game_ini_line_exist(hud_sect, 'use_finish_detector_anim')) and (game_ini_r_bool(hud_sect, 'use_finish_detector_anim')) then begin
          if CanStartAction(itm) and (not IsHolderInSprintState(itm)) then
            PlayCustomAnimStatic(itm, 'anm_finish_detector', 'sndFinishDet');
        end;
      end;
    end;
  end else begin
    SetActorActionState(act, actShowDetectorNow, false);
  end;


  ProcessZoom(act);
end;

procedure ActorUpdate_Patch(); stdcall
asm
  pushad
    push ecx
    call ActorUpdate
  popad
  mov eax, [esi+$200]
end;

function ItemInSlot(act:pointer; slot:integer):pointer; stdcall;
asm
  pushad
    mov @result, 0
    cmp act, 0
    je @finish

    push act
    call game_object_GetScriptGameObject
    cmp eax, 0
    je @finish

    mov ecx, eax
    push slot
    mov ebx, xrGame_addr
    add ebx, $1C87f0
    call ebx
    cmp eax, 0
    je @finish

    mov eax, [eax+4]
    cmp eax, 0
    je @finish
    
    sub eax, $e8
    mov @result, eax

    @finish:
  popad
end;


function CheckActorWeaponAvailabilityWithInform(wpn:pointer):boolean;
begin
  result:=false;
  if (GetActorActiveItem()<>wpn) then begin
    Messenger.SendMessage('gunsl_msg_take_wpn_into_hands');
    exit;
  end;

  if not (CanStartAction(wpn)) then begin
    Messenger.SendMessage('gunsl_msg_stop_actions');
    exit;
  end;
  result:=true;
end;

function Init():boolean; stdcall;
var jmp_addr:cardinal;
begin
  NeedUnZoom_flag:=false;
  result:=false;
  jmp_addr:=xrGame_addr+$261DF6;
  if not WriteJump(jmp_addr, cardinal(@ActorUpdate_Patch), 6, true) then exit;
  result:=true;
end;

end.
