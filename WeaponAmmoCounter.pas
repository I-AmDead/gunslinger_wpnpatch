unit WeaponAmmoCounter;

interface
function Init:boolean;

implementation
uses BaseGameData, GameWrappers, windows;

var
  reload_process_selectcount_addr:cardinal;
  reload_process_reportcartridgescnt_addr:cardinal;

procedure SelectAmmoInMagCount;
//� ������� ��������� ������� �� 1 �������, ��� � ��������!
begin
  asm
    lea ecx, [esi-$2E0]
    pushad
    pushfd
    mov ebx, [ecx+$694]
    //������� � ebx ����� ��������, ������� ����� ��������
    //���� � ��� ���������� ��� ��� - �� ����� ����������� ��������
    mov word ptr [ecx], ax
    cmp ax, W_BM16
    je @finish
    cmp ax, W_RPG7
    je @finish
    //�������, ���� �� � �������� �������
    cmp [ecx+$690], 0
    jle @empty
    //���� �������� ������ ��������� - �� ���� �������� ���� ����� ���� ��������, ��������� ����������� �� 1 ������� ����� �������� � ��������� ���!
    cmp byte ptr [ecx+$45A], 1
    je @gun_jamned
    //���� �� ������ ��� �����������
    cmp byte ptr [ecx+$6C7], $FF
    jne @changingammotype
    jmp @finish

    @gun_jamned:
    //���� ������
    //�������� ����� ���� �������� � ����� ������
    mov byte ptr [ecx+$6C7], $FF
    //������� �� ������������ �������� ���� ������
    mov ebx, [ecx+$690]
    sub ebx, 1

    //������ ������� ��������� � �������� 1 ������
    mov [ecx+$690], 1
    mov edx, [ecx+$6c8]
    mov eax, [ecx+$6cc]
    sub eax, $3c
    mov [ecx+$6c8], eax
    //��������� ���� ������ � ���������
    push ecx
    call unload_magazine
    //���������� ��������� �������
    mov [ecx+$6c8], edx
    mov [ecx+$690], ebx
    jmp @finish

    @empty:
    @changingammotype:
    //���� ������ ��� �������� - ������� ��� ������� � ����������
    //TODO:��������� ���� ����� ��� �������������
    sub ebx, 1
    jmp @finish

    @finish:
    //�������� ����� �������� � �������� ����� ��������
    //��������� �� 2 �����, ����� 4 ����� ������ � 2 ������������ ����
    mov [ecx+$6A2], bx
    shr ebx,16
    mov [ecx+$6BE], bx

    popfd
    popad

    jmp reload_process_selectcount_addr
  end;
end;

procedure DoCompareMagCapacity(count:cardinal);stdcall;
//������ �� ����������, �� ���������� �����!
//� esi ������� ����� ������
begin
  asm
    push ecx

    //������ ����� �������� � ������, ������� (�����������) ���� ����������
    mov cx, [esi+$6BE]
    shl ecx, 16
    add cx, word ptr [esi+$6A2]
    cmp count, ecx

    pop ecx
  end;
end;

procedure OnCartridgeAdded;
begin
  asm
    //TODO:��� ����� ���� �������� �������� ������� ����� ������ � ������ � ����������
    
    //�������� ���������� ��������
    push eax //[esi+$690]
    call DoCompareMagCapacity
    jmp reload_process_reportcartridgescnt_addr
  end;
end;

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
  reload_process_reportcartridgescnt_addr:=xrGame_addr+$2D1150;
  writeprocessmemory(hndl, PChar(reload_process_reportcartridgescnt_addr), debug_bytes, 6, rb);
  if rb<>6 then exit;
  reload_process_reportcartridgescnt_addr:=reload_process_reportcartridgescnt_addr+6;
  if not WriteJump(reload_process_reportcartridgescnt_addr, cardinal(@DoCompareMagCapacity), 5, true) then exit;
  writeprocessmemory(hndl, PChar(reload_process_reportcartridgescnt_addr), @debug_bytes[6], 1, rb);
  if rb<>1 then exit;
  //----------------------------------------------------
  reload_process_reportcartridgescnt_addr:=xrGame_addr+$2D1214;
  writeprocessmemory(hndl, PChar(reload_process_reportcartridgescnt_addr), debug_bytes, 6, rb);
  if rb<>6 then exit;
  reload_process_reportcartridgescnt_addr:=reload_process_reportcartridgescnt_addr+6;
  if not WriteJump(reload_process_reportcartridgescnt_addr, cardinal(@DoCompareMagCapacity), 5, true) then exit;
  writeprocessmemory(hndl, PChar(reload_process_reportcartridgescnt_addr), @debug_bytes[6], 2, rb);
  if rb<>2 then exit;
  //----------------------------------------------------


  reload_process_selectcount_addr:=xrGame_addr+$2CCDA0;
  reload_process_reportcartridgescnt_addr:=xrGame_addr+$2D11DA;
  if not WriteJump(reload_process_selectcount_addr, cardinal(@SelectAmmoInMagCount), 6) then exit;
  if not WriteJump(reload_process_reportcartridgescnt_addr, cardinal(@OnCartridgeAdded), 6) then exit;
  result:=true;
end;


end.
