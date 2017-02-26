unit AN94Patch;
//���������� ������������ ����� �������� ��� ������ ���������

interface
function Init:boolean;

implementation
uses BaseGameData, gunsl_config, HudItemUtils;
var rpm_loading_patch_addr:cardinal;

const
  base_dispersioned_bullets_time_delta:PChar='base_dispersioned_bullets_time_delta';
  singleshoots_time_delta:PChar='singleshoots_time_delta';

procedure AN94_RPM_Patch; stdcall;
begin
  asm
    //������ ����������
    movss xmm0, [esi+$35c]
    //�������� ���������
    pushad
    pushfd
    //������� ���������, �� �������� �� �� ����������
    cmp [esi+$770], 01
    ja @queue
    push esi
    call GetSection
    mov ebx, eax
    //���������, ���� �� � ��� �������� singleshoots_time_delta
    push singleshoots_time_delta
    push ebx
    call game_ini_line_exist
    cmp al, 0
    je @finish
    //��������� ��� � �������� ����������������
    push singleshoots_time_delta
    push ebx
    call game_ini_r_single
    jmp @write


    @queue:
    mov eax, [esi+$774] //������� ��� ���������� � �������
    mov ebx, [esi+$778] //������� ���� � �������� ����������� ���������
    cmp ebx, 0
    je @finish
    sub ebx, 1
    cmp eax, ebx
    jae @finish
    //��������� ������� ������ ������
    push esi
    call GetSection
    mov ebx, eax
    //���������, ���� �� � ��� �������� base_dispersioned_bullets_rpm
    push base_dispersioned_bullets_time_delta
    push ebx
    call game_ini_line_exist
    cmp al, 0
    je @finish
    //��������� ��� � �������� ����������������
    push base_dispersioned_bullets_time_delta
    push ebx
    call game_ini_r_single
    jmp @write;

    @write:
    //������� ������, ��������� � �������� ������ ���� 
    sub esp, 4
    fstp dword ptr [esp]
    movss xmm0, [esp]
    add esp, 4
    @finish:
    popfd
    popad
    jmp rpm_loading_patch_addr
  end;
end;

function Init:boolean;
begin
  result:=false;
  rpm_loading_patch_addr:=xrGame_addr+$2D062F;
  if not WriteJump(rpm_loading_patch_addr, cardinal(@AN94_RPM_Patch), 8) then exit;
  result:=true;
end;

end.
