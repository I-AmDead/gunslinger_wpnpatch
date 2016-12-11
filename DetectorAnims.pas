unit DetectorAnims;

interface

//�������� �������������� - �������� � ����� ��������� �� �������� � �������� ��� ������� ���������� "������" �������� �������

function Init:boolean;

implementation
uses BaseGameData, WeaponAdditionalBuffer;

function IsDetectorNeedHideNow(detector: pointer; curwpn:pointer):boolean; stdcall;
begin
  result:=IsActionProcessing(curwpn);
end;

procedure HideDetectorOnActionPatch; stdcall;
asm
  //������ ����������
  mov ecx, [eax+$2e4]
  //���� ���� ��� ������ ������ �������� - �� �� �����������
  jne @finish
  //��������, �� ����������� �� �����-���� ��������
  pushad
    push eax
    push esi
    call IsDetectorNeedHideNow
    cmp al, 0
  popad
  @finish:
end;


function IsDetectorNeedUnHideNow(detector: pointer; curwpn:pointer):boolean; stdcall;
begin
  result:=true;
  if curwpn<>nil then result:=IsActionProcessing(curwpn);
end;

procedure UnHideDetectorOnActionPatch; stdcall;
asm
  //������ ����������
  cmp[esi+$2e4], 3
  //���� ���� �� �������� �������� �������� - �� �� ����� ������
  jne @finish
  //��������, �� ����������� �� �����-���� ��������
  pushad
    mov eax, [edi+4]
    sub eax, $2e0
    push eax
    push esi
    call IsDetectorNeedUnHideNow
    cmp al, 0
  popad
  @finish:
end;


function Init:boolean;
var jmp_addr:cardinal;
begin
  jmp_addr:=xrGame_addr+$2ECF0A;
  if not WriteJump(jmp_addr, cardinal(@HideDetectorOnActionPatch), 6, true) then exit;
  jmp_addr:=xrGame_addr+$2ECF78;
  if not WriteJump(jmp_addr, cardinal(@UnHideDetectorOnActionPatch), 7, true) then exit;
end;

end.
