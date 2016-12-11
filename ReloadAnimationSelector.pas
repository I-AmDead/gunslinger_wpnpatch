unit ReloadAnimationSelector;

interface
function Init:boolean;

implementation
uses BaseGameData;
const
  anm_reload:PChar='anm_reload';
  anm_reload_w_gl:PChar='anm_reload_w_gl';
  anm_reload_empty:PChar='anm_reload_empty';
  anm_reload_empty_w_gl:PChar='anm_reload_empty_w_gl';
  anm_changecartridgetype:PChar='anm_changecartridgetype';
  anm_changecartridgetype_w_gl:PChar='anm_changecartridgetype_w_gl';
  anm_jamned:PChar = 'anm_jamned';
  anm_jamned_last:PChar = 'anm_jamned_last';
  anm_jamned_w_gl:PChar = 'anm_jamned_w_gl';
  anm_jamned_last_w_gl:PChar = 'anm_jamned_last_w_gl';
  
var
  reload_pistols_patch_addr:cardinal;
  reload_nogl_patch_addr:cardinal;
  reload_withgl_patch_addr:cardinal;

function PistolAssaultAnimationSelector(weapon_addr:cardinal):PChar; stdcall;
begin
  asm
    pushad
    pushf

    mov ecx, weapon_addr
    //���� � ��� ��� - ������������ �������������
    mov ax, word ptr [eax]
    cmp ax, W_RPG7
    je @rpg7
    //������ ��������� ������ �� ����
    cmp byte ptr [ecx+$45A], 1
    je @gun_jamned
    @reload:
    //�������, ����� �� ��������
    test byte ptr [ecx+460], 2
    jz @nogl
    jmp @w_gl

    @w_gl:
    //�������, ���� �� ������� � ������
    cmp [ecx+$690], 0
    je @reload_empty_w_gl
    //���������, ���� �� ����� ���� ��������
    cmp byte ptr [ecx+$6C7], $FF
    jne @changetype_w_gl
    mov ebx, anm_reload_w_gl
    jmp @finish
    @changetype_w_gl:
    mov ebx, anm_changecartridgetype_w_gl
    jmp @finish
    @reload_empty_w_gl:
    mov ebx, anm_reload_empty_w_gl
    jmp @finish

    @nogl:
    //�������, ���� �� ������� � ������
    cmp [ecx+$690], 0
    je @reload_empty_nogl
    //���������, ���� �� ����� ���� ��������
    cmp byte ptr [ecx+$6C7], $FF
    jne @changetype_nogl
    mov ebx, anm_reload
    jmp @finish
    @changetype_nogl:
    mov ebx, anm_changecartridgetype
    jmp @finish
    @reload_empty_nogl:
    mov ebx, anm_reload_empty
    jmp @finish
//-------------------------------------------------------------

    @gun_jamned:
    //���� ������. ����� ������� ���� ����� ���� ��������, ���� � ����������� � ������ ��������
    mov byte ptr [ecx+$6C7], $FF
    //���� ������ ������ - ������ ������������
    //TODO: ���� � ������� ��������� ���������� ����� ����� - �� ��������� ��� ��
    cmp [ecx+$690], 0
    jle @reload
    //���� � ������ ���� ������ - ������ ��������������� �����
    cmp [ecx+$690], 1
    jg @jamned_not_last

    //��������� ������ �������. ��������� ��������
    test byte ptr [ecx+460], 2
    jz @jamned_nogl_last
    mov ebx, anm_jamned_last_w_gl
    jmp @finish
    @jamned_nogl_last:
    mov ebx, anm_jamned_last
    jmp @finish


    @jamned_not_last:
    //� �������� ��������� ��������. ��������� ��������
    test byte ptr [ecx+460], 2
    jz @jamned_nogl_not_last
    mov ebx, anm_jamned_w_gl
    jmp @finish
    @jamned_nogl_not_last:
    mov ebx, anm_jamned
    jmp @finish
//-------------------------------------------------------------

    @rpg7:
    //�������� �� ����
    cmp byte ptr [ecx+$45A], 1
    je @rpg7_jamned
    mov ebx, anm_reload
    jmp @finish
    @rpg7_jamned:
    mov ebx, anm_jamned
    jmp @finish

    @finish:
    mov @result, ebx
//-------------------------------------------------------------

    popf
    popad
  end;
end;

procedure AK74ReloadNoGLAnimationSelector;
begin
  asm
    push ecx
    push esi
    call PistolAssaultAnimationSelector
    pop ecx
    push eax

    jmp reload_nogl_patch_addr
  end;
end;

procedure AK74ReloadWithGLAnimationSelector;
begin
  asm
    push ecx
    push esi
    call PistolAssaultAnimationSelector
    pop ecx
    push eax

    jmp reload_withgl_patch_addr
  end;
end;

procedure PistolReloadAnimationSelector;
begin
  asm
    push ecx
    push esi
    call PistolAssaultAnimationSelector
    pop ecx
    push eax
    
    jmp reload_pistols_patch_addr
  end;
end;

function Init:boolean;
begin
  result:=false;
  reload_nogl_patch_addr:=xrGame_addr+$2CCFB2;
  reload_withgl_patch_addr:=xrGame_addr+$2D18AB;
  reload_pistols_patch_addr:=xrGame_addr+$2C5451;
  if not WriteJump(reload_nogl_patch_addr, cardinal(@AK74ReloadNoGLAnimationSelector), 5) then exit;
  if not WriteJump(reload_withgl_patch_addr, cardinal(@AK74ReloadWithGLAnimationSelector), 5) then exit;
  if not WriteJump(reload_pistols_patch_addr, cardinal(@PistolReloadAnimationSelector), 14) then exit;
  result:=true;
end;

end.
