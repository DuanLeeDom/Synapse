unit uCookies;

{ uCookies

  Utilidades para lidar com os cookies de navegador lidos pelo yt-dlp no
  Windows. O ponto central aqui e um detalhe pratico que confunde muito: o
  yt-dlp precisa COPIAR o banco de cookies do navegador para um arquivo
  temporario antes de le-lo, e o navegador trava esse arquivo enquanto esta
  aberto. Resultado: com o Chrome aberto o yt-dlp falha com "Could not copy
  Chrome cookie database" mesmo que o usuario esteja logado.

  Por isso o aplicativo precisa saber (1) se o navegador escolhido esta em
  execucao e (2) como fecha-lo de forma assistida antes de tentar o download.

  Nada aqui lê, copia ou transmite o conteudo dos cookies: apenas consulta e
  encerra processos pelo nome do executavel. }

{$mode ObjFPC}{$H+}
{$CODEPAGE UTF8}

interface

uses
  Classes, SysUtils;

{ Nome do executavel (Windows) do navegador indicado pelo token de
  --cookies-from-browser. Devolve '' quando o token nao e conhecido. }
function ExecutavelDoNavegador(const AToken: string): string;

{ Verdadeiro quando existe algum processo do navegador em execucao. E o que
  impede o yt-dlp de copiar o banco de cookies. }
function NavegadorEmExecucao(const AToken: string): Boolean;

{ Encerra todos os processos do navegador. Devolve True quando, ao final,
  nenhum processo do navegador permanece. }
function FecharNavegador(const AToken: string): Boolean;

implementation

uses
  uProcessos;

function PastaSistema: string;
begin
  Result := GetEnvironmentVariable('SystemRoot');
  if Result = '' then
    Result := 'C:\Windows';
  Result := IncludeTrailingPathDelimiter(Result) + 'System32' + PathDelim;
end;

function ExecutavelDoNavegador(const AToken: string): string;
begin
  case LowerCase(AToken) of
    'chrome' : Result := 'chrome.exe';
    'edge'   : Result := 'msedge.exe';
    'firefox': Result := 'firefox.exe';
    'brave'  : Result := 'brave.exe';
    'opera'  : Result := 'opera.exe';
  else
    Result := '';
  end;
end;

function NavegadorEmExecucao(const AToken: string): Boolean;
var
  Exe, Saida: string;
  Args: TStringList;
  Cod: Integer;
begin
  Result := False;
  Exe := ExecutavelDoNavegador(AToken);
  if Exe = '' then
    Exit;

  { tasklist sem filtro evita depender de quoting de argumentos com espaco
    ("IMAGENAME eq chrome.exe"); basta procurar o nome na listagem. }
  Args := TStringList.Create;
  try
    Args.Add('/NH');
    if TGerenciadorProcessos.CapturarSaida(PastaSistema + 'tasklist.exe',
       Args, 8000, Saida, Cod) then
      Result := Pos(LowerCase(Exe), LowerCase(Saida)) > 0;
  finally
    Args.Free;
  end;
end;

function FecharNavegador(const AToken: string): Boolean;
var
  Exe, Saida: string;
  Args: TStringList;
  Cod: Integer;
begin
  Exe := ExecutavelDoNavegador(AToken);
  if Exe = '' then
    Exit(False);

  Args := TStringList.Create;
  try
    Args.Add('/IM');
    Args.Add(Exe);
    Args.Add('/F');
    TGerenciadorProcessos.CapturarSaida(PastaSistema + 'taskkill.exe',
      Args, 12000, Saida, Cod);
  finally
    Args.Free;
  end;

  { O Windows leva um instante para liberar o arquivo de cookies depois do
    taskkill; a releitura confirmando o encerramento tambem serve de espera. }
  Sleep(600);
  Result := not NavegadorEmExecucao(AToken);
end;

end.
