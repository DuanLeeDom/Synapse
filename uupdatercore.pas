unit uUpdaterCore;

{ uUpdaterCore

  Nucleo do verificador de atualizacoes, sem dependencia da LCL para poder ser
  testado em console. Consulta a API do GitHub e compara com a versao atual.

  A consulta e feita por processo externo (curl.exe; PowerShell como reserva no
  Windows) para nao depender de DLLs de OpenSSL. O parsing usa fpjson. }

{$mode ObjFPC}{$H+}
{$CODEPAGE UTF8}

interface

uses
  Classes, SysUtils;

type
  TInfoAtualizacao = record
    Disponivel : Boolean;
    VersaoAtual: string;
    VersaoNova : string;
    UrlPagina  : string;
  end;

{ Consulta a ultima release. Bloqueante. Devolve True quando o GitHub respondeu
  (AErro fica vazio nesse caso); caso contrario AErro traz o motivo. }
function ConsultarUltimaRelease(out AInfo: TInfoAtualizacao;
  out AErro: string): Boolean;

implementation

uses
  fpjson, jsonparser, uVersao, uProcessos;

function CaminhoCurl: string;
var
  Raiz: string;
begin
  {$IFDEF WINDOWS}
  Raiz := GetEnvironmentVariable('SystemRoot');
  if Raiz = '' then
    Raiz := 'C:\Windows';
  Result := IncludeTrailingPathDelimiter(Raiz) + 'System32' + PathDelim + 'curl.exe';
  if not FileExists(Result) then
    Result := 'curl';
  {$ELSE}
  Result := 'curl';
  {$ENDIF}
end;

{$IFDEF WINDOWS}
{ Reserva: baixa a URL via PowerShell para um script temporario e captura a
  saida padrao. }
function BaixarViaPowerShell(const AUrl: string; out ASaida: string): Boolean;
var
  Script, Tmp, Saida: string;
  Linhas, Args: TStringList;
  Cod: Integer;
begin
  Result := False;
  ASaida := '';
  Tmp := IncludeTrailingPathDelimiter(GetTempDir(False)) + 'synapse_update.ps1';

  Script :=
    '$ErrorActionPreference = "Stop"' + #13#10 +
    '$ProgressPreference = "SilentlyContinue"' + #13#10 +
    '[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12' + #13#10 +
    '$wc = New-Object System.Net.WebClient' + #13#10 +
    '$wc.Headers.Add("User-Agent", "Synapse")' + #13#10 +
    '[Console]::Out.Write($wc.DownloadString("' + AUrl + '"))';

  Linhas := TStringList.Create;
  Args := TStringList.Create;
  try
    Linhas.Text := Script;
    try
      Linhas.SaveToFile(Tmp);
    except
      Exit;
    end;

    Args.Add('-NoProfile');
    Args.Add('-NonInteractive');
    Args.Add('-ExecutionPolicy');
    Args.Add('Bypass');
    Args.Add('-File');
    Args.Add(Tmp);

    if TGerenciadorProcessos.CapturarSaida('powershell.exe', Args, 25000,
       Saida, Cod) then
    begin
      ASaida := Saida;
      Result := (Cod = 0) and (Pos('{', ASaida) > 0);
    end;
  finally
    Args.Free;
    Linhas.Free;
    SysUtils.DeleteFile(Tmp);
  end;
end;
{$ENDIF}

function BaixarCorpo(const AUrl: string; out ACorpo: string): Boolean;
var
  Args: TStringList;
  Saida: string;
  Cod: Integer;
begin
  Result := False;
  ACorpo := '';

  Args := TStringList.Create;
  try
    Args.Add('-s');
    Args.Add('-L');
    Args.Add('--max-time');
    Args.Add('15');
    Args.Add('--connect-timeout');
    Args.Add('8');
    Args.Add('-A');
    Args.Add('Synapse');
    Args.Add(AUrl);

    if TGerenciadorProcessos.CapturarSaida(CaminhoCurl, Args, 20000, Saida, Cod)
       and (Cod = 0) and (Pos('{', Saida) > 0) then
    begin
      ACorpo := Saida;
      Exit(True);
    end;
  finally
    Args.Free;
  end;

  {$IFDEF WINDOWS}
  if BaixarViaPowerShell(AUrl, ACorpo) then
    Exit(True);
  {$ENDIF}
end;

function CampoTexto(AObj: TJSONObject; const ANome, APadrao: string): string;
var
  D: TJSONData;
begin
  D := AObj.Find(ANome);
  if Assigned(D) then
    Result := D.AsString
  else
    Result := APadrao;
end;

function ConsultarUltimaRelease(out AInfo: TInfoAtualizacao;
  out AErro: string): Boolean;
var
  Corpo: string;
  Dados: TJSONData;
  Obj: TJSONObject;
begin
  Result := False;
  AErro := '';
  AInfo.Disponivel  := False;
  AInfo.VersaoAtual := VERSAO_APP;
  AInfo.VersaoNova  := '';
  AInfo.UrlPagina   := URL_RELEASES;

  if not BaixarCorpo(URL_API_ULTIMA_RELEASE, Corpo) then
  begin
    AErro := 'Nao foi possivel consultar o GitHub. Verifique a conexao com a internet.';
    Exit;
  end;

  Dados := nil;
  try
    try
      Dados := GetJSON(Corpo);
    except
      on E: Exception do
      begin
        AErro := 'Resposta inesperada do GitHub: ' + E.Message;
        Exit;
      end;
    end;

    if not (Dados is TJSONObject) then
    begin
      AErro := 'Resposta inesperada do GitHub.';
      Exit;
    end;

    AInfo.VersaoNova := CampoTexto(TJSONObject(Dados), 'tag_name', '');
    AInfo.UrlPagina  := CampoTexto(TJSONObject(Dados), 'html_url', URL_RELEASES);

    if AInfo.VersaoNova = '' then
    begin
      AErro := 'O repositorio ainda nao tem nenhuma release publicada.';
      Exit;
    end;

    AInfo.Disponivel := CompararVersoes(VERSAO_APP, AInfo.VersaoNova) < 0;
    Result := True;
  finally
    Dados.Free;
  end;
end;

end.
