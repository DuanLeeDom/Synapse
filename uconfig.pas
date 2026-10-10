unit uConfig;

{ uConfig

  Preferencias do usuario, carregadas no inicio e aplicadas ao Media Pipeline
  e ao Download Service.

  Persistencia: synapse.ini, secao [settings]. O caminho do arquivo vem de
  TGerenciadorDependencias.CaminhoIni (ao lado do exe quando gravavel, senao
  na pasta de configuracao do usuario - uma instalacao em C:\Program Files nao
  pode ser gravada por usuario comum). O mesmo arquivo ja guarda a
  secao [dependencies], e por isso a gravacao remove e reescreve APENAS a
  secao [settings], preservando o restante do arquivo. O formato e o mesmo
  parser simples de uDependencias, que evita depender de TIniFile.

  Seguranca: cookies de navegador sao dados sensiveis. Nada aqui le, copia
  ou registra o conteudo dos cookies; a preferencia guarda somente qual
  navegador usar (ou nenhum). O token e entregue ao yt-dlp via
  --cookies-from-browser por quem monta o comando. }

{$mode ObjFPC}{$H+}
{$CODEPAGE UTF8}

interface

uses
  Classes, SysUtils, uDependencias;

const
  SECAO_SETTINGS = 'settings';

  { Navegadores aceitos pelo --cookies-from-browser do yt-dlp. A entrada 0 e
    o "nao usar" e nunca vira argumento; as demais carregam o token exato que
    o yt-dlp espera. Manter nomes e tokens alinhados pelo mesmo indice. }
  NAVEGADORES_NOMES: array[0..5] of string = (
    'Não usar cookies',
    'Google Chrome',
    'Microsoft Edge',
    'Mozilla Firefox',
    'Brave',
    'Opera'
  );
  NAVEGADORES_TOKENS: array[0..5] of string = (
    '',
    'chrome',
    'edge',
    'firefox',
    'brave',
    'opera'
  );

  { Rotulos compartilhados com o Media Pipeline. Os indices destas listas
    sao o contrato de posicao com cbx_option_video_editor e
    ComboBox_Format_Videos; manter a ordem. }
  FORMATOS_VIDEO_NOMES: array[0..8] of string = (
    'Original (melhor disponível)',
    '4K Ultra HD (2160p)',
    '2K Quad HD (1440p)',
    'Full HD (1080p)',
    'HD (720p)',
    'SD (480p)',
    '360p',
    '240p',
    '144p'
  );
  EDITORES_NOMES: array[0..8] of string = (
    'DaVinci Resolve (Free)',
    'DaVinci Resolve Studio',
    'Kdenlive',
    'Shotcut',
    'OpenShot',
    'Lightworks (Free)',
    'Lightworks',
    'Flowblade',
    'Cinelerra'
  );
  { Indice de imagem (imgl_options_edit) de cada editor, na ordem acima. }
  EDITORES_IMAGENS: array[0..8] of Integer = (0, 0, 1, 2, 3, 4, 4, 5, 6);

  MODO_NOME_YTDLP  = 0;
  MODO_NOME_PADRAO = 1;
  MODO_NOME_DEFINIR= 2;

  PROCESSO_CPU = 0;
  PROCESSO_GPU = 1;

  { Fonte dos cookies entregues ao yt-dlp. Navegador usa --cookies-from-browser
    (o usuario precisa estar logado no site e ter resolvido o captcha naquele
    navegador); arquivo usa --cookies com um cookies.txt exportado. }
  COOKIES_NENHUM    = 0;
  COOKIES_NAVEGADOR = 1;
  COOKIES_ARQUIVO   = 2;

type
  TConfiguracoes = class
  private
    FPastaDestino    : string;
    FModoNome        : Integer;
    FNomeArquivo     : string;
    FFormatoVideo    : Integer;
    FEditorVideo     : Integer;
    FProcessamento   : Integer;
    FOversample      : Boolean;
    FModoCookies     : Integer;
    FNavegadorCookies: Integer;
    FArquivoCookies  : string;
    FVerificaAtual   : Boolean;
    FIniPath         : string;

    procedure DefinirPadroes;
    function  LerChave(const AChave: string): string;
    function  LerInteiro(const AChave: string; APadrao: Integer): Integer;
  public
    constructor Create;

    procedure Carregar;
    procedure Salvar;

    { Volta tudo ao padrao e grava. Usado pelo botao "Restaurar padrões". }
    procedure RestaurarPadroes;

    { Token pronto para --cookies-from-browser, ou '' quando desativado ou
      quando a fonte escolhida for um arquivo. }
    function TokenNavegador: string;

    { True quando ha uma fonte de cookies utilizavel configurada. }
    function UsandoCookies: Boolean;

    { Acrescenta os argumentos de cookies (--cookies-from-browser X ou
      --cookies "arquivo") a lista informada. Usado pelo TGerenciadorDownload. }
    procedure AcrescentarCookies(AArgs: TStrings);

    { Fragmento de linha de comando equivalente, pronto para concatenar:
      ' --cookies-from-browser chrome' / ' --cookies "C:\...\cookies.txt"' /
      '' quando desativado. Usado pelo Media Pipeline. }
    function ComandoCookies: string;

    { Pasta de destino valida: a escolhida, ou Downloads, ou o diretorio
      atual, nessa ordem. Nunca devolve vazio. }
    function PastaDestinoEfetiva: string;

    property PastaDestino    : string  read FPastaDestino     write FPastaDestino;
    property ModoNome        : Integer read FModoNome         write FModoNome;
    property NomeArquivo     : string  read FNomeArquivo      write FNomeArquivo;
    property FormatoVideo    : Integer read FFormatoVideo     write FFormatoVideo;
    property EditorVideo     : Integer read FEditorVideo      write FEditorVideo;
    property Processamento   : Integer read FProcessamento    write FProcessamento;
    property Oversample      : Boolean read FOversample       write FOversample;
    property ModoCookies     : Integer read FModoCookies      write FModoCookies;
    property NavegadorCookies: Integer read FNavegadorCookies write FNavegadorCookies;
    property ArquivoCookies  : string  read FArquivoCookies   write FArquivoCookies;
    property VerificaAtual   : Boolean read FVerificaAtual    write FVerificaAtual;
  end;

{ Instancia unica, criada na primeira chamada. }
function Configuracoes: TConfiguracoes;

implementation

var
  GConfig: TConfiguracoes = nil;

function Configuracoes: TConfiguracoes;
begin
  if GConfig = nil then
  begin
    GConfig := TConfiguracoes.Create;
    { Carrega o que ja foi salvo na primeira vez que o aplicativo pede as
      preferencias, para que o startup ja comece com os valores do usuario. }
    GConfig.Carregar;
  end;
  Result := GConfig;
end;

{ ------------------------------------------------------------------------ }
{ TConfiguracoes                                                           }
{ ------------------------------------------------------------------------ }

constructor TConfiguracoes.Create;
begin
  inherited Create;
  FIniPath := TGerenciadorDependencias.CaminhoIni;
  DefinirPadroes;
end;

procedure TConfiguracoes.DefinirPadroes;
var
  Downloads: string;
begin
  Downloads := GetUserDir + 'Downloads';
  if DirectoryExists(Downloads) then
    FPastaDestino := Downloads
  else
    FPastaDestino := '';

  FModoNome         := MODO_NOME_YTDLP;
  FNomeArquivo      := '';
  FFormatoVideo     := 0;
  FEditorVideo      := 0;
  FProcessamento    := PROCESSO_CPU;
  FOversample       := False;
  FModoCookies      := COOKIES_NENHUM;
  FNavegadorCookies := 0;
  FArquivoCookies   := '';
  FVerificaAtual    := True;
end;

function TConfiguracoes.LerChave(const AChave: string): string;
var
  Linhas: TStringList;
  i, P: Integer;
  Linha, Sec, Chave, Valor: string;
begin
  Result := '';
  if not FileExists(FIniPath) then
    Exit;

  Linhas := TStringList.Create;
  try
    try
      Linhas.LoadFromFile(FIniPath);
    except
      Exit;
    end;

    Sec := '';
    for i := 0 to Linhas.Count - 1 do
    begin
      Linha := Trim(Linhas[i]);
      if Linha = '' then
        Continue;
      if Linha[1] = ';' then
        Continue;
      if Linha[1] = '[' then
      begin
        Sec := LowerCase(Trim(Copy(Linha, 2, Length(Linha) - 2)));
        Continue;
      end;
      if Sec <> SECAO_SETTINGS then
        Continue;
      P := Pos('=', Linha);
      if P = 0 then
        Continue;
      Chave := LowerCase(Trim(Copy(Linha, 1, P - 1)));
      Valor := Trim(Copy(Linha, P + 1, Length(Linha) - P));
      if Chave = AChave then
        Exit(Valor);
    end;
  finally
    Linhas.Free;
  end;
end;

function TConfiguracoes.LerInteiro(const AChave: string; APadrao: Integer): Integer;
begin
  Result := StrToIntDef(LerChave(AChave), APadrao);
end;

procedure TConfiguracoes.Carregar;
begin
  DefinirPadroes;

  FPastaDestino     := LerChave('pasta_destino');
  FModoNome         := LerInteiro('modo_nome', MODO_NOME_YTDLP);
  FNomeArquivo      := LerChave('nome_arquivo');
  FFormatoVideo     := LerInteiro('formato_video', 0);
  FEditorVideo      := LerInteiro('editor_video', 0);
  FProcessamento    := LerInteiro('processamento', PROCESSO_CPU);
  FOversample       := LerInteiro('oversample', 0) <> 0;
  FNavegadorCookies := LerInteiro('navegador_cookies', 0);
  FArquivoCookies   := LerChave('arquivo_cookies');
  FVerificaAtual    := LerInteiro('verificar_atualizacoes', 1) <> 0;

  { Compatibilidade: a versao anterior gravava o booleano usar_cookies. Se o
    modo ainda nao existir no ini, ele e derivado dali. }
  if LerChave('modo_cookies') = '' then
  begin
    if LerInteiro('usar_cookies', 0) <> 0 then
      FModoCookies := COOKIES_NAVEGADOR
    else
      FModoCookies := COOKIES_NENHUM;
  end
  else
    FModoCookies := LerInteiro('modo_cookies', COOKIES_NENHUM);

  { Valores fora da faixa conhecida voltam ao padrao em vez de derrubar o
    carregamento. }
  if (FModoNome < MODO_NOME_YTDLP) or (FModoNome > MODO_NOME_DEFINIR) then
    FModoNome := MODO_NOME_YTDLP;
  if (FEditorVideo < 0) or (FEditorVideo > High(EDITORES_NOMES)) then
    FEditorVideo := 0;
  if (FFormatoVideo < 0) or (FFormatoVideo > High(FORMATOS_VIDEO_NOMES)) then
    FFormatoVideo := 0;
  if (FProcessamento < PROCESSO_CPU) or (FProcessamento > PROCESSO_GPU) then
    FProcessamento := PROCESSO_CPU;
  if (FNavegadorCookies < 0) or (FNavegadorCookies > High(NAVEGADORES_TOKENS)) then
    FNavegadorCookies := 0;
  if (FModoCookies < COOKIES_NENHUM) or (FModoCookies > COOKIES_ARQUIVO) then
    FModoCookies := COOKIES_NENHUM;
end;

procedure TConfiguracoes.RestaurarPadroes;
begin
  DefinirPadroes;
  Salvar;
end;

procedure TConfiguracoes.Salvar;
var
  Linhas, Saida: TStringList;
  i: Integer;
  Linha, Sec: string;

  function BoolIni(AValor: Boolean): string;
  begin
    if AValor then Result := '1' else Result := '0';
  end;

begin
  Linhas := TStringList.Create;
  Saida  := TStringList.Create;
  try
    if FileExists(FIniPath) then
      try
        Linhas.LoadFromFile(FIniPath);
      except
        { Se o existente nao puder ser lido, ele e recriado a partir do zero:
          perder a secao [dependencies] e preferivel a gravar um ini truncado. }
        Linhas.Clear;
      end;

    { Copia tudo o que nao pertence a [settings]. }
    Sec := '';
    for i := 0 to Linhas.Count - 1 do
    begin
      Linha := Trim(Linhas[i]);
      if (Linha <> '') and (Linha[1] = '[') then
        Sec := LowerCase(Trim(Copy(Linha, 2, Length(Linha) - 2)));
      if Sec <> SECAO_SETTINGS then
        Saida.Add(Linhas[i]);
    end;

    while (Saida.Count > 0) and (Trim(Saida[Saida.Count - 1]) = '') do
      Saida.Delete(Saida.Count - 1);
    if Saida.Count > 0 then
      Saida.Add('');

    Saida.Add('[' + SECAO_SETTINGS + ']');
    Saida.Add('pasta_destino=' + FPastaDestino);
    Saida.Add('modo_nome=' + IntToStr(FModoNome));
    Saida.Add('nome_arquivo=' + FNomeArquivo);
    Saida.Add('formato_video=' + IntToStr(FFormatoVideo));
    Saida.Add('editor_video=' + IntToStr(FEditorVideo));
    Saida.Add('processamento=' + IntToStr(FProcessamento));
    Saida.Add('oversample=' + BoolIni(FOversample));
    Saida.Add('modo_cookies=' + IntToStr(FModoCookies));
    Saida.Add('navegador_cookies=' + IntToStr(FNavegadorCookies));
    Saida.Add('arquivo_cookies=' + FArquivoCookies);
    Saida.Add('verificar_atualizacoes=' + BoolIni(FVerificaAtual));

    Saida.SaveToFile(FIniPath);
  finally
    Saida.Free;
    Linhas.Free;
  end;
end;

function TConfiguracoes.TokenNavegador: string;
begin
  Result := '';
  if FModoCookies <> COOKIES_NAVEGADOR then
    Exit;
  if (FNavegadorCookies < 0) or (FNavegadorCookies > High(NAVEGADORES_TOKENS)) then
    Exit;
  Result := NAVEGADORES_TOKENS[FNavegadorCookies];
end;

function TConfiguracoes.UsandoCookies: Boolean;
begin
  if FModoCookies = COOKIES_NAVEGADOR then
    Result := TokenNavegador <> ''
  else if FModoCookies = COOKIES_ARQUIVO then
    Result := (FArquivoCookies <> '') and FileExists(FArquivoCookies)
  else
    Result := False;
end;

procedure TConfiguracoes.AcrescentarCookies(AArgs: TStrings);
var
  Token: string;
begin
  if AArgs = nil then
    Exit;

  if FModoCookies = COOKIES_NAVEGADOR then
  begin
    Token := TokenNavegador;
    if Token <> '' then
    begin
      AArgs.Add('--cookies-from-browser');
      AArgs.Add(Token);
    end;
  end
  else if FModoCookies = COOKIES_ARQUIVO then
  begin
    if (FArquivoCookies <> '') and FileExists(FArquivoCookies) then
    begin
      AArgs.Add('--cookies');
      AArgs.Add(FArquivoCookies);
    end;
  end;
end;

function TConfiguracoes.ComandoCookies: string;
var
  Token: string;
begin
  Result := '';

  if FModoCookies = COOKIES_NAVEGADOR then
  begin
    Token := TokenNavegador;
    if Token <> '' then
      Result := ' --cookies-from-browser ' + Token;
  end
  else if FModoCookies = COOKIES_ARQUIVO then
  begin
    if (FArquivoCookies <> '') and FileExists(FArquivoCookies) then
      Result := ' --cookies "' + FArquivoCookies + '"';
  end;
end;

function TConfiguracoes.PastaDestinoEfetiva: string;
var
  Downloads: string;
begin
  { A pasta escolhida vale mesmo antes de existir: yt-dlp/ffmpeg a criam. O
    fallback so entra quando nenhuma foi definida. }
  if FPastaDestino <> '' then
    Exit(FPastaDestino);

  Downloads := GetUserDir + 'Downloads';
  if DirectoryExists(Downloads) then
    Exit(Downloads);

  Result := GetCurrentDir;
end;

finalization
  FreeAndNil(GConfig);

end.
