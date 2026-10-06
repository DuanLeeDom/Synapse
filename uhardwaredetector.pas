unit uHardwareDetector;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Process;

type
  TGPUVendor = (gpuNone, gpuNVIDIA, gpuAMD, gpuIntel);

  { THardwareDetector
    Lógica de pesquisa de hardware (detecção de GPU) e ajuste automático
    dos parâmetros de codificação do FFmpeg para acelerar via
    NVENC (NVIDIA), AMF (AMD) ou QSV (Intel). }
  THardwareDetector = class
  public
    function DetectarGPU: TGPUVendor;
    function ObterParamsGPU(const AVideoParams: string;
                            AGPUVendor: TGPUVendor): string;
  end;

implementation

function THardwareDetector.DetectarGPU: TGPUVendor;
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
    Processo.Parameters.Add('(Get-CimInstance Win32_VideoController).Name');
    {$ELSE}
    Processo.Executable := '/usr/bin/bash';
    Processo.Parameters.Add('-c');
    Processo.Parameters.Add('lspci | grep -i -E "vga|3d|display"');
    {$ENDIF}

    Processo.Options := [poUsePipes, poNoConsole, poWaitOnExit];
    Processo.Execute;

    Saida.LoadFromStream(Processo.Output);

    // ignora adaptadores genéricos/virtuais e prioriza NVIDIA > AMD > Intel
    for i := 0 to Saida.Count - 1 do
    begin
      Linha := LowerCase(Saida[i]);

      if (Pos('microsoft', Linha) > 0) or (Pos('basic display', Linha) > 0) or
         (Pos('virtual', Linha) > 0) or (Pos('remote', Linha) > 0) then
        Continue;

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

function THardwareDetector.ObterParamsGPU(const AVideoParams: string;
  AGPUVendor: TGPUVendor): string;
begin
  Result := AVideoParams;
  case AGPUVendor of
    gpuNVIDIA:
    begin
      Result := StringReplace(Result, '-c:v libx264',   '-c:v h264_nvenc -preset p4', [rfIgnoreCase]);
      Result := StringReplace(Result, '-c:v libx265',   '-c:v hevc_nvenc -preset p4', [rfIgnoreCase]);
      Result := StringReplace(Result, '-c:v libaom-av1','-c:v av1_nvenc -preset p4',  [rfIgnoreCase]);
      Result := StringReplace(Result, '-c:v libvpx-vp9','-c:v av1_nvenc -preset p4',  [rfIgnoreCase]);
    end;
    gpuAMD:
    begin
      Result := StringReplace(Result, '-c:v libx264',   '-c:v h264_amf', [rfIgnoreCase]);
      Result := StringReplace(Result, '-c:v libx265',   '-c:v hevc_amf', [rfIgnoreCase]);
      Result := StringReplace(Result, '-c:v libaom-av1','-c:v av1_amf',  [rfIgnoreCase]);
      Result := StringReplace(Result, '-c:v libvpx-vp9','-c:v av1_amf',  [rfIgnoreCase]);
    end;
    gpuIntel:
    begin
      Result := StringReplace(Result, '-c:v libx264',   '-c:v h264_qsv', [rfIgnoreCase]);
      Result := StringReplace(Result, '-c:v libx265',   '-c:v hevc_qsv', [rfIgnoreCase]);
      Result := StringReplace(Result, '-c:v libaom-av1','-c:v av1_qsv',  [rfIgnoreCase]);
      Result := StringReplace(Result, '-c:v libvpx-vp9','-c:v av1_qsv',  [rfIgnoreCase]);
    end;
  end;
end;

end.
