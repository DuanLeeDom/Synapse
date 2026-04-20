unit uSystemAssistant;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Controls, StdCtrls, Graphics, Forms, Types, Process,
  Buttons;

type
  TGPUVendor = (gpuNone, gpuNVIDIA, gpuAMD, gpuIntel);

  { TProcessoControlado }
  TProcessoControlado = class
  private
    FProcessoAtivo : TProcess;
    FCancelado     : Boolean;
    FBotao         : TButton;
    FLabelProcessar: string;
    FLabelCancelar : string;

    procedure MatarProcessoFilho;
  public
    constructor Create(ABotao: TButton;
                       const ALabelProcessar: string = 'PROCESSAR';
                       const ALabelCancelar: string  = 'Cancelar');

    procedure IniciarProcesso;
    procedure FinalizarProcesso;
    procedure RegistrarProcesso(AProcesso: TProcess);
    procedure Cancelar;
    function EstaCancelado: Boolean;
  end;

  { TSystemAssistant }

  TSystemAssistant = class
  private
    function WrapText(AText: string; AMaxChars: Integer = 50): string;
  public
    procedure AddHelp(AControl: TControl; const AHelpText: string;
                      OffsetX: Integer; OffsetY: Integer;
                      AMaxWidth: Integer = 50);
    procedure RecarregarDependentes(
                      const ADependentes: array of TComboBox);
    function DetectarGPU: TGPUVendor;
    function ObterParamsGPU(const AVideoParams: string;
                            AGPUVendor: TGPUVendor): string;
  end;

implementation

{ TProcessoControlado }

procedure TProcessoControlado.MatarProcessoFilho;
var
  Killer: TProcess;
begin
  Killer := TProcess.Create(nil);
  try
    {$IFDEF WINDOWS}
    Killer.Executable := 'cmd.exe';
    Killer.Parameters.Add('/c');
    Killer.Parameters.Add('taskkill /F /IM ffmpeg.exe /T & taskkill /F /IM yt-dlp.exe /T');
    {$ELSE}
    Killer.Executable := '/usr/bin/bash';
    Killer.Parameters.Add('-c');
    Killer.Parameters.Add('pkill -9 -f ffmpeg; pkill -9 -f yt-dlp');
    {$ENDIF}
    Killer.Options := [poNoConsole, poWaitOnExit];
  finally
    Killer.Free;
  end;
end;

constructor TProcessoControlado.Create(ABotao: TButton;
  const ALabelProcessar: string; const ALabelCancelar: string);
begin
  inherited Create;
  FBotao         := ABotao;
  FLabelProcessar:= ALabelProcessar;
  FLabelCancelar := ALabelCancelar;
  FProcessoAtivo := nil;
  FCancelado     := False;
end;

procedure TProcessoControlado.IniciarProcesso;
begin
  FCancelado := False;
  if Assigned(FBotao) then
  begin
    FBotao.Caption := FLabelCancelar;
    FBotao.Enabled := True;
  end;
end;

procedure TProcessoControlado.FinalizarProcesso;
begin
  FProcessoAtivo := nil;
  FCancelado     := False;
  if Assigned(FBotao) then
  begin
    FBotao.Caption := FLabelProcessar;
    FBotao.Enabled := True;
  end;
end;

procedure TProcessoControlado.RegistrarProcesso(AProcesso: TProcess);
begin
  FProcessoAtivo := AProcesso;
end;

procedure TProcessoControlado.Cancelar;
var
  Cmd: string;
begin
  FCancelado := True;

  if Assigned(FProcessoAtivo) and FProcessoAtivo.Running then
  begin
    try
      Cmd := 'q';
      FProcessoAtivo.Input.Write(Cmd[1], Length(Cmd));
    Except
    end;
  end;

  if Assigned(FProcessoAtivo) and FProcessoAtivo.Running then
  begin
    FProcessoAtivo.Terminate(1);
    FProcessoAtivo := nil;

    MatarProcessoFilho;
  end;
end;

function TProcessoControlado.EstaCancelado: Boolean;
begin
  Result := FCancelado;
end;

{ TSystemAssistant }

function TSystemAssistant.WrapText(AText: string; AMaxChars: Integer): string;
var
  i, LineLen: Integer;
begin
  Result  := '';
  LineLen := 0;
  for i := 1 to Length(AText) do
  begin
    Result := Result + AText[i];
    Inc(LineLen);
    if (LineLen >= AMaxChars) and (AText[i] = ' ') then
    begin
      Result  := Result + LineEnding;
      LineLen := 0;
    end;
  end;
end;

procedure TSystemAssistant.AddHelp(AControl: TControl;
  const AHelpText: string; OffsetX: Integer; OffsetY: Integer;
  AMaxWidth: Integer);
var
  HelpIcon: TLabel;
begin
  if not Assigned(AControl) then Exit;

  HelpIcon        := TLabel.Create(AControl.Owner);
  HelpIcon.Parent := AControl.Parent;

  HelpIcon.Caption    := 'ⓘ';
  HelpIcon.Font.Color := clGray;
  HelpIcon.Font.Style := [fsBold];
  HelpIcon.Cursor     := crHandPoint;
  HelpIcon.Hint       := WrapText(AHelpText, AMaxWidth);
  HelpIcon.ShowHint   := True;

  HelpIcon.Left := AControl.Left + AControl.Width + OffsetX;
  HelpIcon.Top  := AControl.Top + AControl.Height - (HelpIcon.Height div 2) + OffsetY;

  HelpIcon.BringToFront;
end;

procedure TSystemAssistant.RecarregarDependentes(
  const ADependentes: array of TComboBox);
var
  i: Integer;
begin
  for i := 0 to High(ADependentes) do
  begin
    ADependentes[i].Items.Clear;
    ADependentes[i].ItemIndex := -1;
  end;
end;

function TSystemAssistant.DetectarGPU: TGPUVendor;
var
  Processo: TProcess;
  Saida   : TStringList;
  Linha   : string;
  i       : Integer;
begin
  Result   := gpuNone;
  Processo := TProcess.Create(nil);
  Saida    := TStringList.Create;
  try
    {$IFDEF WINDOWS}
    Processo.Executable := 'powershell.exe';
    Processo.Parameters.Add('-NoProfile');
    Processo.Parameters.Add('-Command');
    Processo.Parameters.Add('Get-WmiObject Win32_VideoController | Select-Object -ExpandProperty Name');
    {$ELSE}
    Processo.Executable := '/usr/bin/bash';
    Processo.Parameters.Add('-c');
    Processo.Parameters.Add('lspci | grep -i vga');
    {$ENDIF}

    Processo.Options := [poUsePipes, poNoConsole, poWaitOnExit];
    Processo.Execute;

    Saida.LoadFromStream(Processo.Output);

    // percorre todas as linhas — prioridade: NVIDIA > AMD > Intel
    for i := 0 to Saida.Count - 1 do
    begin
      Linha := LowerCase(Saida[i]);

      if Pos('nvidia', Linha) > 0 then
        Result := gpuNVIDIA
      else if (Pos('amd', Linha) > 0) and (Result = gpuNone) then
        Result := gpuAMD
      else if (Pos('intel', Linha) > 0) and (Result = gpuNone) then
        Result := gpuIntel;
    end;

  finally
    Saida.Free;
    Processo.Free;
  end;
end;

function TSystemAssistant.ObterParamsGPU(const AVideoParams: string;
  AGPUVendor: TGPUVendor): string;
begin
  case AGPUVendor of
    gpuNVIDIA:
      Result := StringReplace(AVideoParams, '-c:v libx264',
                              '-c:v h264_nvenc -preset p4',
                              [rfIgnoreCase]);
    gpuAMD:
      Result := StringReplace(AVideoParams, '-c:v libx264',
                              '-c:v h264_amf',
                              [rfIgnoreCase]);
    gpuIntel:
      Result := StringReplace(AVideoParams, '-c:v libx264',
                              '-c:v h264_qsv',
                              [rfIgnoreCase]);
  else
    Result := AVideoParams;
  end;
end;

end.
