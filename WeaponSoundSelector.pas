unit WeaponSoundSelector;

interface
function Init:boolean;

implementation
uses BaseGameData;

var
  magazined_reload_sound_select_patch_addr:cardinal;

procedure MagazinedWeaponReloadSoundSelector;
begin
  asm
    sub esi, $5B1

    push eax
    //���� � ��� ��� - ������������ �������������
    mov ax, word ptr [eax]
    cmp ax, W_RPG7
    pop eax
    je @rpg7

    //���� � ������ ��� �������� - �� ������ ������ ���� ����������� � ��
    cmp[esi+$690], 0
    je @empty
    //���� ��������� ���� ������ - ������������ ��������
    cmp byte ptr [esi+$45A], 1
    je @jamned
    cmp byte ptr [esi+$6C7], $FF
    jne @changecartridgetype

    push sndReload
    jmp @final

    @changecartridgetype:
    push sndChangeCartridgeType
    jmp @final

    @empty:
    push sndReloadEmpty
    jmp @final

    @jamned:
    cmp[esi+$690], 1
    jle @jamned_last
    push sndJamned
    jmp @final
    @jamned_last:
    push sndJamnedLast
    jmp @final

    @rpg7:
    cmp byte ptr [esi+$45A], 1
    je @rpg7_jamned
    push sndReload
    jmp @final
    @rpg7_jamned:
    push sndJamned
    jmp @final
    
    @final:
    add esi, $5B1
    jmp magazined_reload_sound_select_patch_addr
  end;
end;

function Init:boolean;
begin
  result:=false;
  magazined_reload_sound_select_patch_addr:=xrGame_addr+$2CCE6F;
  if not WriteJump(magazined_reload_sound_select_patch_addr, cardinal(@MagazinedWeaponReloadSoundSelector), 5) then exit;
  result:=true;
end;

end.
