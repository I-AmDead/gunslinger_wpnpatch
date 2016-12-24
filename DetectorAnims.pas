unit DetectorAnims;

interface

//�������� �������������� - �������� � ����� ��������� �� �������� � �������� ��� ������� ���������� "������" �������� �������

function Init:boolean;

implementation
uses BaseGameData, WeaponAdditionalBuffer, WpnUtils, ActorUtils;

function CanShowDetector():boolean; stdcall;
var
  itm:pointer;
begin
  result:=true;
  itm:=GetActorActiveItem();
  if itm<>nil then result:= not (IsActionProcessing(itm) or GetActorActionState(GetActor, actModSprintStarted));
end;

procedure OnDetectorPrepared(wpn:pointer; p:integer); stdcall
var act:pointer;
begin
  act:=GetActor;
  if (act <> nil) then SetActorActionState(act, actPreparingDetectorShowingStarted, true)
end;

{function CanShowDetectorWithPrepareIfNeeded():boolean; stdcall;
var
  itm:pointer;
  var act:pointer;
  cls:string;
begin
  result:=true;
  act:=GetActor;
  if (act = nil) then exit;
  if GetActorActionState(act, actPreparingDetectorShowingStarted) then begin
    SetActorActionState(act, actPreparingDetectorShowingStarted, false);
    exit;
  end;

  itm:=GetActorActiveItem();
  if itm<>nil then begin
    cls:=GetClassName(itm);
    if WpnCanShoot(PChar(cls)) or (cls = 'WP_KNIFE') then begin
      result:=false;
      if not (IsActionProcessing(itm) or GetActorActionState(GetActor, actModSprintStarted)) then begin
        PlayCustomAnimStatic(itm, 'anm_prepare_detector', 'sndPrepareDetector',OnDetectorPrepared, 0);
      end;
    end else begin
      if GetActorActionState(GetActor, actModSprintStarted) then result:=false; 
    end;
  end;
end;      }

procedure HideDetectorOnActionPatch; stdcall;
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

procedure UnHideDetectorOnActionPatch; stdcall;
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
    call CanShowDetector //�������� ����� � esi+$33d 1, �������� ����������� ������
    cmp al, 0
  popad

  @finish:
end;


function Init:boolean;
var jmp_addr:cardinal;
begin
  jmp_addr:=xrGame_addr+$2ECDF0;
  if not WriteJump(jmp_addr, cardinal(@ShowDetectorPatch), 19, true) then exit;
  jmp_addr:=xrGame_addr+$2ECF0A;
  if not WriteJump(jmp_addr, cardinal(@HideDetectorOnActionPatch), 6, true) then exit;
  jmp_addr:=xrGame_addr+$2ECF78;
  if not WriteJump(jmp_addr, cardinal(@UnHideDetectorOnActionPatch), 7, true) then exit;
end;

end.
