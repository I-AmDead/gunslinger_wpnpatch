unit DetectorAnims;

interface

//�������� �������������� - �������� � ����� ��������� �� �������� � �������� ��� ������� ���������� "������" �������� �������

function Init:boolean;

implementation
uses BaseGameData, WeaponAdditionalBuffer, WpnUtils, ActorUtils, GameWrappers, sysutils;

function CanShowDetector():boolean; stdcall;
var
  itm:pointer;
begin
  result:=true;
  itm:=GetActorActiveItem();
  if itm<>nil then result:= not (IsActionProcessing(itm) or GetActorActionState(GetActor, actModSprintStarted));
end;

procedure HideDetectorInUpdateOnActionPatch; stdcall;
var
  itm:pointer;
asm
  //������ ����������
  mov ecx, [eax+$2e4]
  //���� ���� ��� ������ ������ �������� - �� �� �����������
  jne @finish
  //��������, �� ����������� �� �����-���� ��������
  pushad
    call CanShowDetector
    cmp al, 1
  popad
  @finish:
end;

procedure UnHideDetectorInUpdateOnActionPatch; stdcall;
asm
  //������ ����������
  cmp[esi+$2e4], 3
  //���� ���� �� �������� �������� �������� - �� �� ����� ������
  jne @finish
  //��������, �� ����������� �� �����-���� ��������
  pushad
    call CanShowDetector
    cmp al, 1
  popad
  @finish:
end;

procedure OnDetectorPrepared(wpn:pointer; p:integer); stdcall
var
  act:pointer;
  itm:pointer;
begin
  itm:=GetActorActiveItem();
  act:=GetActor;

  if (itm <> nil) and (itm=wpn) then SetActorActionState(act, actPreparingDetectorFinished, true);
end;

procedure SetDetectorForceUnhide(det:pointer; status:boolean); stdcall
asm
  pushad
  mov eax, det
  movzx bx, status
  mov [eax+$33D], ebx
  popad
end;

function CanShowDetectorWithPrepareIfNeeded(det:pointer):boolean; stdcall;
var
  itm, act:pointer;
  hud_sect:PChar;
begin
  result:=false;
  act:=GetActor;
  if (act = nil) then exit;
  //��������� �������������� ����������� ���������� � ������ ������
  if not CanShowDetector then exit;

  //������ �������, �������� �� ��� ������� �������� ���������� ���������
  if GetActorActionState(act, actPreparingDetectorFinished) then begin
    result:=true;
    SetActorActionState(act, actPreparingDetectorFinished, false);
  end else begin
    //����� �� ��������. ��� ������������� �! ���� ������...
    itm:=GetActorActiveItem();
    if (itm<>nil) and WpnCanShoot(PChar(GetClassName(itm))) then begin
      hud_sect:=GetHUDSection(itm);
      if (game_ini_line_exist(hud_sect, 'use_prepare_detector_anim')) and (game_ini_r_bool(hud_sect, 'use_prepare_detector_anim')) then begin
        PlayCustomAnimStatic(itm, 'anm_prepare_detector', 'sndPrepareDet', OnDetectorPrepared, 0);
        SetDetectorForceUnhide(det, true);
      end else result:=true;
    end else begin
      result:=true;
    end;
  end;
end;

procedure ShowDetectorPatch; stdcall;
asm
  //������ ����������
  push ecx
  push eax
  mov ecx, esi
  mov [esp+$14], 0

  mov eax, xrgame_addr
  add eax, $2ECC40
  call eax
  test al, al

  je @finish
  //��������� ��������
  pushad
    push esi
    call CanShowDetectorWithPrepareIfNeeded //�������� ����� � esi+$33d 1, �������� ����������� ������
    cmp al, 0
  popad

  @finish:
end;

procedure DetectorUpdate(det: pointer);stdcall;
var
  itm, act:pointer;
  hud_sect:PChar;
begin
    itm:=GetActorActiveItem();
    if (itm<>nil) and WpnCanShoot(PChar(GetClassName(itm))) then begin
      hud_sect:=GetHUDSection(itm);
      if not(game_ini_line_exist(hud_sect, 'use_prepare_detector_anim')) or not (game_ini_r_bool(hud_sect, 'use_prepare_detector_anim')) then exit;
      if GetCurrentState(itm) = 2 then begin
        SetActorActionState(act, actPreparingDetectorFinished, false);
        SetDetectorForceUnhide(det, false);
      end;
    end;
end;

procedure DetectorUpdatePatch();stdcall;
asm
  mov edi, [eax+$94]
  pushad
    push ecx
    call DetectorUpdate
  popad
end;

function Init:boolean;
var jmp_addr:cardinal;
begin
  result:=false;
  jmp_addr:=xrGame_addr+$2ECEA7;
  if not WriteJump(jmp_addr, cardinal(@DetectorUpdatePatch), 6, true) then exit;
  jmp_addr:=xrGame_addr+$2ECDF0;
  if not WriteJump(jmp_addr, cardinal(@ShowDetectorPatch), 19, true) then exit;
  jmp_addr:=xrGame_addr+$2ECF0A;
  if not WriteJump(jmp_addr, cardinal(@HideDetectorInUpdateOnActionPatch), 6, true) then exit;
  jmp_addr:=xrGame_addr+$2ECF78;
  if not WriteJump(jmp_addr, cardinal(@UnHideDetectorInUpdateOnActionPatch), 7, true) then exit;
  result:=true;
end;

end.
