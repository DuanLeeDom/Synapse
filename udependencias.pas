unit uDependencias;

{ uDependencias

  Catalogo e resolvedor das ferramentas externas usadas pelo aplicativo.

  Cada ferramenta e uma entrada de registro. Para adicionar uma nova basta
  declarar mais um item em INFO_DEP: o resolvedor, a validacao e o
  diagnostico passam a funcionar sem nenhuma outra alteracao.

  Ordem de resolucao, da mais especifica para a mais permissiva:

    1. synapse.ini, secao [dependencies]        -> override manual do usuario
    2. <pasta do exe>\tools\<chave>\bin\        -> distribuicao portatil
    3. <pasta do exe>\tools\<chave>\
    4. <pasta do exe>\tools\                    -> binarios soltos
    5. <pasta do exe>\                          -> binario ao lado do .exe
    6. PATH do sistema                          -> desenvolvimento / legado

  A base de tudo vem de Application.ExeName, portanto nao existe caminho
  absoluto da maquina de desenvolvimento gravado no codigo: o mesmo build
  funciona em qualquer outro computador.

  Este catalogo tambem e o unico lugar do projeto que precisa saber o nome
  do executavel de uma ferramenta. As demais units pedem o caminho por
  TDependencia e nunca montam string de comando na mao. }

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Process;

type
  { Ferramentas externas conhecidas pelo aplicativo. }
  TDependencia = (depFFmpeg, depYtDlp, depImageMagick, depQT);

  { Descricao estatica de uma ferramenta. Nomes e ArgumentoVersao sao
    separados por ';' porque uma typed const nao aceita array de string. }
  TInfoDependencia = record
    Chave          : string;  { 'ffmpeg' - chave do ini e nome da pasta }
    Rotulo         : string;  { 'FFmpeg' - como aparece na interface }
    Nomes          : string;  { 'ffmpeg;ffmpeg.exe' - candidatos no bundle }
    NomesPath      : string;  { 'ffmpeg;ffmpeg.exe' - candidatos no PATH }
    ArgumentoVersao: string;  { argumento usado para sondar a versao }
  end;

  { TGerenciadorDependencias

    Resolucao com cache: cada ferramenta e procurada uma unica vez e o
    resultado fica memorizado, porque sondar o disco a cada miniatura seria
    desperdicio. LimparCache existe para quando o usuario editar o ini
    com o programa aberto. }
  TGerenciadorDependencias = class
  public
    class function BaseDir: string;
    class function PastaTools: string;
    class function Caminho(ADep: TDependencia): string;
    class function Localizado(ADep: TDependencia): Boolean;
    class function Rotulo(ADep: TDependencia): string;
    class function Chave(ADep: TDependencia): string;
    class function Versao(ADep: TDependencia): string;
    class function ArgumentoVersao(ADep: TDependencia): string;
    class function QuantidadeLocalizadas: Integer;
    class function Diagnostico: string;
    class procedure LimparCache;

    { Quebra uma string de argumentos respeitando aspas duplas e simples.
      Necessario porque os perfis de codec sao montados como texto, por
      exemplo: -vf "scale=-2:2160". }
    class function DividirArgumentos(const ATexto: string): TStringList;

    { Reconstroi os argumentos como linha, so para exibir no log. }
    class function JuntarArgumentos(const AArgs: TStrings): string;
  end;

implementation

uses
  uProcessos;

const
  NOME_INI = 'synapse.ini';
  SECAO_INI = 'dependencies';

  { Separador da variavel PATH. Este NAO e o PathDelim do LCL, que vale
    barra invertida nesta instalacao: PATH e definido pelo sistema
    operacional e usa ponto e virgula no Windows e dois pontos no Unix.
    Usar PathDelim aqui quebrava o PATH em cada barra e nenhuma pasta era
    encontrada. }
  {$IFDEF WINDOWS}
  SEP_PATH = ';';
  {$ELSE}
  SEP_PATH = ':';
  {$ENDIF}

  {$IFDEF WINDOWS}
  SUFIXO = '.exe';
  { No Windows o ImageMagick 7 usa magick.exe; a versao 6 usa
    convert.exe. Ambos sao aceitos porque os dois ainda circulam. }
  NOMES_MAGICK = 'magick;magick.exe;convert;convert.exe';
  {$ELSE}
  SUFIXO = '';
  NOMES_MAGICK = 'magick;magick6;convert';
  {$ENDIF}

  INFO_DEP: array[TDependencia] of TInfoDependencia = (
    (Chave: 'ffmpeg';      Rotulo: 'FFmpeg';      Nomes: 'ffmpeg;ffmpeg.exe';
     NomesPath: 'ffmpeg;ffmpeg.exe'; ArgumentoVersao: '-version'),
    (Chave: 'ytdlp';       Rotulo: 'yt-dlp';      Nomes: 'yt-dlp;yt-dlp.exe';
     NomesPath: 'yt-dlp;yt-dlp.exe'; ArgumentoVersao: '--version'),
    (Chave: 'imagemagick'; Rotulo: 'ImageMagick'; Nomes: NOMES_MAGICK;
     NomesPath: NOMES_MAGICK; ArgumentoVersao: '-version'),
    (Chave: 'qt';          Rotulo: 'ffmpeg/ffprobe'; Nomes: 'ffprobe;ffprobe.exe';
     NomesPath: 'ffprobe;ffprobe.exe'; ArgumentoVersao: '-version')
  );

var
  { Cache de resolucao. Array estatico em vez de class var para nao depender
    do modo de compilacao do compilador. }
  GCaminhos : array[TDependencia] of string;
  GVersoes  : array[TDependencia] of string;
  GResolvido: array[TDependencia] of Boolean;
  GBases   : string = '';

{ ------------------------------------------------------------------------ }
{ Utilidades internas                                                       }
{ ------------------------------------------------------------------------ }

function Separar(const ALista: string; ADelim: Char = ';'): TStringList;
var
  i: Integer;
  Ini: Integer;
begin
  Result := TStringList.Create;
  Ini := 1;
  for i := 1 to Length(ALista) + 1 do
  begin
    if (i = Length(ALista) + 1) or (ALista[i] = ADelim) then
    begin
      if i > Ini then
        Result.Add(Copy(ALista, Ini, i - Ini));
      Ini := i + 1;
    end;
  end;
end;

function ExisteExecutavel(const ACaminho: string): Boolean;
begin
  Result := False;
  if ACaminho = '' then
    Exit;
  {$IFDEF WINDOWS}
  Result := FileExists(ACaminho) and
            (Pos('.exe', LowerCase(ACaminho)) > 0);
  {$ELSE}
  Result := FileExists(ACaminho) and (Pos('.app', LowerCase(ACaminho)) = 0);
  {$ENDIF}
end;

{ Le um TStream inteiro para string. TStream nao tem ReadAll no FPC, e a
  leitura por laco e mantida porque outros pontos do projeto tambem
  precisam dela. }
function LerStream(AStream: TStream): string;
var
  Buf: array[0..4095] of Char;
  N: Integer;
begin
  Result := '';
  repeat
    N := AStream.Read(Buf, SizeOf(Buf));
    if N > 0 then
      SetString(Result, PChar(@Buf[0]), Length(Result) + N);
  until N <= 0;
end;

{ Le a secao [dependencies] do synapse.ini sem depender de TIniFile, que
  nao esta disponivel nesta versao do compilador. O arquivo e minúsculo e
  tem formato fixo, entao um parser de trinta linhas e mais simples e
  portavel do que arrastar uma unit inteira para isto. }
function LerOverride(const AChave: string): string;
var
  Linhas: TStringList;
  Arquivo: string;
  i: Integer;
  Linha, Secao: string;
  P: Integer;
  Chave, Valor: string;
begin
  Result := '';
  Linhas := TStringList.Create;
  try
    Arquivo := TGerenciadorDependencias.BaseDir + NOME_INI;
    { Neste FPC LoadFromFile e procedure e lanca excecao se falhar, ao
      contrario do Delphi, onde devolve booleano. }
    if not FileExists(Arquivo) then
      Exit;
    try
      Linhas.LoadFromFile(Arquivo);
    except
      Exit;
    end;
    Secao := '';
    for i := 0 to Linhas.Count - 1 do
    begin
      Linha := Trim(Linhas[i]);
      if Linha = '' then
        Continue;
      if Linha[1] = ';' then     { comentario de linha inteira }
        Continue;
      if Linha[1] = '[' then
      begin
        Secao := LowerCase(Trim(Copy(Linha, 2, Length(Linha) - 2)));
        Continue;
      end;
      if Secao <> SECAO_INI then
        Continue;
      P := Pos('=', Linha);
      if P = 0 then
        Continue;
      Chave := LowerCase(Trim(Copy(Linha, 1, P - 1)));
      Valor := Trim(Copy(Linha, P + 1, Length(Linha) - P));
      if (Chave = AChave) and (Valor <> '') then
      begin
        Result := Valor;
        Exit;
      end;
    end;
  finally
    Linhas.Free;
  end;
end;

function ProcurarNoPath(const ANomes: string): string;
var
  Pastas: TStringList;
  i, j: Integer;
  Nomes: TStringList;
  Cand: string;
begin
  Result := '';
  Pastas := TStringList.Create;
  Nomes := Separar(ANomes);
  try
    { A lista do PATH e quebrada por SEP_PATH e nao por TStringList.DelimitedText:
    aquele metodo depende do Delimiter e do QuoteChar da lista, e o
    ganho de usa-lo aqui e nenhum. Um splitter explicito deixa o
    comportamento a vista. }
    Pastas := Separar(GetEnvironmentVariable('PATH'), SEP_PATH);
    for i := 0 to Pastas.Count - 1 do
      for j := 0 to Nomes.Count - 1 do
      begin
        {$IFDEF UNIX}
        if Pos('.app', Pastas[i]) > 0 then
          Continue;
        {$ENDIF}
        Cand := IncludeTrailingPathDelimiter(Pastas[i]) + Nomes[j];
        if ExisteExecutavel(Cand) then
          Exit(Cand);
      end;
  finally
    Nomes.Free;
    Pastas.Free;
  end;
end;

{ ------------------------------------------------------------------------ }
{ TGerenciadorDependencias                                                  }
{ ------------------------------------------------------------------------ }

class function TGerenciadorDependencias.BaseDir: string;
begin
  { ParamStr(0) devolve o caminho completo do executavel. ExtrairFilePath
    transforma em pasta terminada em barra, o que evita concatenar caminho
    com barra errada em cada chamada. }
  Result := GBases;
  if Result = '' then
  begin
    {$IFDEF UNIX}
    Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
    if Result = '' then
      Result := IncludeTrailingPathDelimiter(GetCurrentDir);
    {$ELSE}
    Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
    {$ENDIF}
    GBases := Result;
  end;
end;

class function TGerenciadorDependencias.PastaTools: string;
begin
  Result := IncludeTrailingPathDelimiter(BaseDir) + 'tools' + PathDelim;
end;

class procedure TGerenciadorDependencias.LimparCache;
var
  i: TDependencia;
begin
  for i := Low(TDependencia) to High(TDependencia) do
  begin
    GCaminhos[i]  := '';
    GVersoes[i]   := '';
    GResolvido[i] := False;
  end;
end;

class function TGerenciadorDependencias.Chave(ADep: TDependencia): string;
begin
  Result := INFO_DEP[ADep].Chave;
end;

class function TGerenciadorDependencias.Rotulo(ADep: TDependencia): string;
begin
  Result := INFO_DEP[ADep].Rotulo;
end;

class function TGerenciadorDependencias.ArgumentoVersao(ADep: TDependencia): string;
begin
  Result := INFO_DEP[ADep].ArgumentoVersao;
end;

class function TGerenciadorDependencias.Caminho(ADep: TDependencia): string;
var
  Override: string;
  Sub: string;
  Nomes: TStringList;
  i: Integer;
  Cand: string;
begin
  if GResolvido[ADep] then
    Exit(GCaminhos[ADep]);

  { Marca como resolvido mesmo em caso de falha, para nao revarre o disco a
    cada chamada quando a ferramenta realmente nao existe. }
  GResolvido[ADep] := True;
  GCaminhos[ADep]  := '';

  { 1) Override manual no ini }
  Override := LerOverride(INFO_DEP[ADep].Chave);
  if (Override <> '') and ExisteExecutavel(Override) then
  begin
    GCaminhos[ADep] := Override;
    Exit(GCaminhos[ADep]);
  end;

  Nomes := Separar(INFO_DEP[ADep].Nomes);
  try
    { 2) tools\<chave>\bin\ e tools\<chave>\ }
    Sub := IncludeTrailingPathDelimiter(PastaTools) + INFO_DEP[ADep].Chave;
    for i := 0 to Nomes.Count - 1 do
    begin
      Cand := IncludeTrailingPathDelimiter(Sub + PathDelim + 'bin') + Nomes[i];
      if ExisteExecutavel(Cand) then
      begin
        GCaminhos[ADep] := Cand;
        Exit(GCaminhos[ADep]);
      end;
      Cand := IncludeTrailingPathDelimiter(Sub) + Nomes[i];
      if ExisteExecutavel(Cand) then
      begin
        GCaminhos[ADep] := Cand;
        Exit(GCaminhos[ADep]);
      end;
    end;

    { 3) tools\ solto }
    for i := 0 to Nomes.Count - 1 do
    begin
      Cand := IncludeTrailingPathDelimiter(PastaTools) + Nomes[i];
      if ExisteExecutavel(Cand) then
      begin
        GCaminhos[ADep] := Cand;
        Exit(GCaminhos[ADep]);
      end;
    end;

    { 4) ao lado do executavel }
    for i := 0 to Nomes.Count - 1 do
    begin
      Cand := IncludeTrailingPathDelimiter(BaseDir) + Nomes[i];
      if ExisteExecutavel(Cand) then
      begin
        GCaminhos[ADep] := Cand;
        Exit(GCaminhos[ADep]);
      end;
    end;
  finally
    Nomes.Free;
  end;

  { 5) PATH }
  GCaminhos[ADep] := ProcurarNoPath(INFO_DEP[ADep].NomesPath);
  Result := GCaminhos[ADep];
end;

class function TGerenciadorDependencias.Localizado(ADep: TDependencia): Boolean;
begin
  Result := Caminho(ADep) <> '';
end;

class function TGerenciadorDependencias.Versao(ADep: TDependencia): string;
var
  Args: TStringList;
  Saida: string;
  Codigo: Integer;
begin
  if GVersoes[ADep] <> '' then
    Exit(GVersoes[ADep]);

  GVersoes[ADep] := '(nao encontrada)';
  if not Localizado(ADep) then
    Exit(GVersoes[ADep]);

  Args := TStringList.Create;
  try
    Args.Add(INFO_DEP[ADep].ArgumentoVersao);
    if not TGerenciadorProcessos.CapturarSaida(Caminho(ADep), Args, 15000,
        Saida, Codigo) then
      Exit(GVersoes[ADep]);
  finally
    Args.Free;
  end;

  Saida := Trim(Saida);
  if Saida <> '' then
  begin
    { Guarda so a primeira linha: -version do FFmpeg e do ImageMagick imprime
      varias, e so interessa a primeira. }
    Saida := Copy(Saida, 1, Pos(LineEnding, Saida + LineEnding) - 1);
    GVersoes[ADep] := Saida;
  end;
  Result := GVersoes[ADep];
end;

class function TGerenciadorDependencias.QuantidadeLocalizadas: Integer;
var
  i: TDependencia;
begin
  { Uma dependencia ausente nao impede o uso do aplicativo: ffmpeg e
    obrigatorio, mas o ImageMagick so e necessario na aba de imagens. Por
    isso isto conta quantas foram achadas, em vez de devolver um booleano
    rigido que obrigaria a tratar todo mundo igual. }
  Result := 0;
  for i := Low(TDependencia) to High(TDependencia) do
    if Localizado(i) then
      Inc(Result);
end;

class function TGerenciadorDependencias.Diagnostico: string;
var
  i: TDependencia;
begin
  Result := 'Pasta do aplicativo : ' + BaseDir + LineEnding +
            'Pasta de ferramentas: ' + PastaTools + LineEnding +
            'Ambiente PATH       : ' + GetEnvironmentVariable('PATH') +
            LineEnding + LineEnding;
  for i := Low(TDependencia) to High(TDependencia) do
  begin
    Result := Result + Format('%-12s ', [INFO_DEP[i].Rotulo]);
    if Localizado(i) then
      Result := Result + '[OK] ' + Caminho(i) + LineEnding +
                '             ' + Versao(i) + LineEnding
    else
      Result := Result + '[AUSENTE] nao encontrado nem em tools/ nem no PATH' +
                LineEnding;
  end;
end;

class function TGerenciadorDependencias.DividirArgumentos(
  const ATexto: string): TStringList;
var
  i: Integer;
  Atual: string;
 Dentro: AnsiChar;
begin
  Result := TStringList.Create;
  Atual  := '';
  Dentro := #0;

  for i := 1 to Length(ATexto) do
  begin
    if (Dentro = #0) and (ATexto[i] = ' ') then
    begin
      if Atual <> '' then
      begin
        Result.Add(Atual);
        Atual := '';
      end;
      Continue;
    end;

    if Dentro = #0 then
    begin
      if (ATexto[i] = '"') or (ATexto[i] = '''') then
      begin
        Dentro := ATexto[i];
        Continue;
      end;
      Atual := Atual + ATexto[i];
    end
    else
    begin
      if ATexto[i] = Dentro then
        Dentro := #0
      else
        Atual := Atual + ATexto[i];
    end;
  end;

  if Atual <> '' then
    Result.Add(Atual);
end;

class function TGerenciadorDependencias.JuntarArgumentos(
  const AArgs: TStrings): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to AArgs.Count - 1 do
  begin
    if i > 0 then
      Result := Result + ' ';
    if Pos(' ', AArgs[i]) > 0 then
      Result := Result + '"' + AArgs[i] + '"'
    else
      Result := Result + AArgs[i];
  end;
end;

end.