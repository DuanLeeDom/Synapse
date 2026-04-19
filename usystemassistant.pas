unit uSystemAssistant;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Controls, StdCtrls, Graphics, Forms, Types, Process;

type
  TGPUVendor = (gpuNone, gpuNVIDIA, gpuAMD, gpuIntel);

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
    Processo.Executable := 'cmd.exe';
    Processo.Parameters.Add('/c');
    Processo.Parameters.Add('wmic path win32_VideoController get name');
    {$ELSE}
    Processo.Executable := '/usr/bin/bash';
    Processo.Parameters.Add('-c');
    Processo.Parameters.Add('lspci | grep -i vga');
    {$ENDIF}

    Processo.Options := [poUsePipes, poNoConsole, poWaitOnExit];
    Processo.Execute;

    Saida.LoadFromStream(Processo.Output);

    for i := 0 to Saida.Count - 1 do
    begin
      Linha := LowerCase(Saida[i]);

      if Pos('nvidia', Linha) > 0 then
      begin
        Result := gpuNVIDIA;
        Break;
      end
      else if Pos('amd', Linha) > 0 then
      begin
        Result := gpuAMD;
        Break;
      end
      else if Pos('intel', Linha) > 0 then
      begin
        Result := gpuIntel;
        Break;
      end;
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
