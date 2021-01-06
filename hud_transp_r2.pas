unit hud_transp_r2;
{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface
function Init():boolean; stdcall;


implementation
uses BaseGameData, Misc;

type FixedMapR2 = packed record
  nodes:pointer;
  pool:cardinal;
  limit:cardinal;
end;

var
  g_map_hud_sorted_r2:FixedMapR2;
  g_map_hud_distort_r2:FixedMapR2;
  hud_render_phase:cardinal;  //0 - ����������, 1 - sorted, 2 - distort

procedure hud_shader_fix_Patch_sorted(); stdcall;
asm
  lea eax, g_map_hud_sorted_r2
  ret
end;

procedure hud_shader_fix_Patch_distort(); stdcall;
asm
  //������� ���������, � ����� ����� ����������: � ������������ ��� � �������.

  mov eax, xrRender_R2_addr
  add eax, $CE380 //���� ����, ��� ���� ������ ����
  cmp [eax], 00
  je @not_hud

  lea eax, g_map_hud_distort_r2
  ret

  @not_hud:
  lea eax,[ebp+$1B8]
  ret
end;

procedure r_dsgraph_render_hud_Patch_select_pool(); stdcall;
asm
  //���� ������ �������� sorted ��� distort - �� �������� ���� ���������� ����
  //����� - ���������� ������������ ���.
  cmp hud_render_phase, 0
  je @original_nosorted
  cmp hud_render_phase, 2
  je @distorted

  cmp g_map_hud_sorted_r2.pool, 0
  lea ecx, g_map_hud_sorted_r2.nodes
  ret

  @distorted:
  cmp g_map_hud_distort_r2.pool, 0
  lea ecx, g_map_hud_distort_r2.nodes
  ret

  @original_nosorted:
  cmp [ebp+$1a4], 0
  lea ecx, [ebp+$1a0]
  ret
end;

procedure r_dsgraph_render_hud_Patch_cleanup(); stdcall;
asm
  cmp hud_render_phase, 0
  je @original_nosorted
  cmp hud_render_phase, 2
  je @distorted

  mov g_map_hud_sorted_r2.pool, 0
  ret

  @distorted:
  mov g_map_hud_distort_r2.pool, 0
  ret

  @original_nosorted:
  mov [ebp+$1a4], 0
  ret
end;

procedure render_distort_fix_Patch(); stdcall;
asm
  pushad
    mov hud_render_phase, 2

    mov ebx, xrRender_R2_addr
    lea eax, [ebx+$CE270]
    push eax
    add ebx, $20730
    call ebx //void r_dsgraph_structure::r_dsgraph_render_hud(), � ��� ������������ ���� ���� �������� ��������� sorted
    mov hud_render_phase, 0

  popad

  //������������
  mov ecx, xrRender_R2_addr
  mov ecx, [ecx+$B57B8]
  ret
end;


procedure render_forward_fix_Patch(); stdcall;
asm
  pushad
    mov hud_render_phase, 1

    mov ebx, xrRender_R2_addr

    lea eax, [ebx+$CE270]
    push eax
    add ebx, $20730
    call ebx //void r_dsgraph_structure::r_dsgraph_render_hud(), � ��� ������������ ���� ���� �������� ��������� sorted
    mov hud_render_phase, 0

    mov ebx, xrRender_R2_addr

  popad

  mov ecx, xrRender_R2_addr
  mov ecx, [ecx+$B57B8]
  ret
end;

function Init():boolean; stdcall;
var
  jmp_addr:cardinal;
  ptr:pointer;
begin

  result:=false;
  if xrRender_R2_addr=0 then exit;

  g_map_hud_sorted_r2.nodes:=nil;
  g_map_hud_sorted_r2.pool:=0;
  g_map_hud_sorted_r2.limit:=0;
  g_map_hud_distort_r2.nodes:=nil;
  g_map_hud_distort_r2.pool:=0;
  g_map_hud_distort_r2.limit:=0;
  hud_render_phase:=0;

  jmp_addr:=xrRender_R2_addr+$1D777;
  if not WriteJump(jmp_addr, cardinal(@hud_shader_fix_Patch_sorted), 6, true) then exit;

  jmp_addr:=xrRender_R2_addr+$1D6BC;
  if not WriteJump(jmp_addr, cardinal(@hud_shader_fix_Patch_distort), 6, true) then exit;

  jmp_addr:=xrRender_R2_addr+$F5C2;
  if not WriteJump(jmp_addr, cardinal(@render_forward_fix_Patch), 6, true) then exit;

  jmp_addr:=xrRender_R2_addr+$6E52E;
  if not WriteJump(jmp_addr, cardinal(@render_distort_fix_Patch), 6, true) then exit;

  jmp_addr:=xrRender_R2_addr+$20C09;
  if not WriteJump(jmp_addr, cardinal(@r_dsgraph_render_hud_Patch_select_pool), 13, true) then exit;

  jmp_addr:=xrRender_R2_addr+$20C30;
  if not WriteJump(jmp_addr, cardinal(@r_dsgraph_render_hud_Patch_cleanup), 10, true) then exit;


  // ���� "���������" ������ �������������� � ������ ����
  // https://github.com/OGSR/OGSR-Engine/commit/3b4f01f6486446ed920116ca739b1984b8e576d4

  // � CParticleEffect::Render ������ VIEWPORT_NEAR
  ptr:=GetHudNearClipPtr();
  if not WriteBufAtAdr(xrRender_R2_addr+$4e58c, @ptr, sizeof(single)) then exit;

  // R_dsgraph_structure::r_dsgraph_render_hud (VIEWPORT_NEAR)
  ptr:=GetNegHudNearClipPtr();
  if not WriteBufAtAdr(xrRender_R2_addr+$2082c, @ptr, sizeof(single)) then exit;
  ptr:=GetHudNearClipPtr();
  if not WriteBufAtAdr(xrRender_R2_addr+$207d1, @ptr, sizeof(single)) then exit;

  // R_dsgraph_structure::r_dsgraph_render_hud_ui
  ptr:=GetNegHudNearClipPtr();
  if not WriteBufAtAdr(xrRender_R2_addr+$20d80, @ptr, sizeof(single)) then exit;
  ptr:=GetHudNearClipPtr();
  if not WriteBufAtAdr(xrRender_R2_addr+$20d25, @ptr, sizeof(single)) then exit;

  // R_dsgraph_structure::r_dsgraph_render_emissive (?)
  ptr:=GetNegHudNearClipPtr();
  if not WriteBufAtAdr(xrRender_R2_addr+$21382, @ptr, sizeof(single)) then exit;
  ptr:=GetHudNearClipPtr();
  if not WriteBufAtAdr(xrRender_R2_addr+$21327, @ptr, sizeof(single)) then exit;

  // CRenderTarget::accum_point
  ptr:=GetNegHudNearClipPtr();
  if not WriteBufAtAdr(xrRender_R2_addr+$64413, @ptr, sizeof(single)) then exit;
  ptr:=GetHudNearClipPtr();
  if not WriteBufAtAdr(xrRender_R2_addr+$643b7, @ptr, sizeof(single)) then exit;

  result:=true;
end;

end.
