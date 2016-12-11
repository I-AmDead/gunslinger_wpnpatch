unit WeaponVisualSelector;

interface
function Init:boolean;

implementation
uses BaseGameData, GameWrappers, WpnUtils;
const
  hud:PChar='hud';
  visual:PChar='visual';
  collimator:PChar='collimator';

var
  cweaponmagazined_netspawn_patch_addr:cardinal;
  scope_attach_callback_addr:cardinal;
  upgrade_weapon_addr:cardinal;
  scope_detach_callback_addr:cardinal;


procedure WeaponVisualChanger();
//� ���������������� - ���� ��������, ����� ������, � ������� ����� ��������
begin
  asm
    pushad
    pushfd

    //jmp @finish
    //�������� ��������-������ � �� ������ �������� �� NULL
    mov edi, [esp+$28]
    test edi, edi
    je @finish

    //���������, ����� �� ������ ��������� �����-�� �����������
    //��������� scope_status � ��������, ��� ��� 2 - ������ �������
    mov ebx, [edi+$464]
    cmp ebx, 2
    jne @finish
    //��������, ��� �� ������ ����� ������� ����� ������ �������
    mov ebx, [edi+$6b0]
    cmp ebx, [edi+$6b4]
    je @finish
    //��������� ������ �������
    movzx eax, byte ptr [edi+$6bc]
    //������ ���������, ���������� �� ������ ������. ���� ��� - �� ������������� ������� ������� ������� ������� ������. ���� ��� ���������� ������ ������������� ��������
    test byte ptr [edi+$460], 1
    jnz @getscopesectname
    mov eax, 0
    @getscopesectname:
    //������� � ebx ������-������, ���������� ������� ������ �������
    lea ebx, [4*eax+ebx]
    //��������� �������� ������ ���� ������ ��� ������� �������
    push hud
    push ebx
    call game_ini_read_string_by_object_string
    //������ � � str_container'e
    push eax
    call str_container_dock
    test eax, eax
    je @finish

    //�������� ������� ������������� � ����� ������ ���� � �������� � ������
    add [eax], 1
    mov ecx, [edi+$314]
    test ecx, ecx
    je @writehud
    sub [ecx], 1

    //������� ����� ��� � ������
    @writehud:
    mov [edi+$314], eax

    //������ ��������� ������ ����� ������
    push visual
    push ebx
    call game_ini_read_string_by_object_string
    test eax, eax
    je @finish

    push eax
    push edi
    call SetVisual


    //�������� ������������� ������ � ���������, ������������� ������ ������������ ��� ���
    push scope_name
    push ebx
    call game_ini_read_string_by_object_string
    test eax, eax
    je @finish
    mov ebx, eax
    push collimator
    push ebx
    call game_ini_line_exist
    test al, al
    jz @no_collimator
    push collimator
    push ebx
    call game_ini_r_bool
    test al, al
    jz @no_collimator
    mov byte ptr [edi+$6bd], 1
    jmp @finish
    @no_collimator:
    mov byte ptr [edi+$6bd], 0
    jmp @finish

    @finish:
    popfd
    popad
    ret 4
  end;
end;

procedure CWeaponMagazined_NetSpawn_Patch();
begin
  asm
    pushad
    pushfd

    push esi
    call WeaponVisualChanger

    popfd
    popad

    test edi, edi
    mov [esp+$10], eax

    jmp cweaponmagazined_netspawn_patch_addr
    //ret 4
  end;
end;

procedure AttachScope_Callback_Patch();
begin
  asm
    or byte ptr [ebp+$460],01

    pushad
    pushfd

    push ebp
    call WeaponVisualChanger

    popfd
    popad
    jmp scope_attach_callback_addr
  end;
end;

procedure DetachScope_Callback_Patch();
begin
  asm
    mov [esi+$460], al
    pushad
    pushfd

    push esi
    call WeaponVisualChanger

    popfd
    popad
    jmp scope_detach_callback_addr
  end;
end;

procedure Upgrade_Weapon_Patch();
begin
  asm
    pushad
    pushfd
    push ebx
    call WeaponVisualChanger
    popfd
    popad
    
    push ecx
    lea edx, [esp+$1c]
    jmp upgrade_weapon_addr
  end;
end;


function Init:boolean;
begin
  result:=false;

  cweaponmagazined_netspawn_patch_addr:=xrGame_addr+$2C120B;
  if not WriteJump(cweaponmagazined_netspawn_patch_addr, cardinal(@CWeaponMagazined_NetSpawn_Patch),6) then exit;

  scope_attach_callback_addr:=xrGame_addr+$2CEE33;
  if not WriteJump(scope_attach_callback_addr, cardinal(@AttachScope_Callback_Patch), 7) then exit;

  scope_detach_callback_addr:=xrGame_addr+$2CDA8D;
  if not WriteJump(scope_detach_callback_addr, cardinal(@DetachScope_Callback_Patch), 6) then exit;

  upgrade_weapon_addr:=xrGame_addr+$2D09D6;
  if not WriteJump(upgrade_weapon_addr, cardinal(@Upgrade_Weapon_Patch), 5) then exit;

  result:=true;
end;

end.
