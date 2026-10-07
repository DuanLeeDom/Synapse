unit uVideoQueue;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Graphics, GraphType, uProcessos, uDependencias;

type
  { TVideoQueueStatus
    Situação de um item dentro da fila de processamento. }
  TVideoQueueStatus = (vqsAguardando, vqsProcessando, vqsConcluido,
                       vqsErro, vqsCancelado);

  { TVideoQueueFase
    Fase do processamento usada para converter a porcentagem parcial
    (download / conversão) na porcentagem global do item. }
  TVideoQueueFase = (vqfDownload, vqfConversao);

  { TVideoQueueItem
    Um vídeo da fila. Guarda a origem (URL ou arquivo local), a
    configuração de conversão congelada no momento em que foi
    adicionado, o andamento e o resultado. }
  TVideoQueueItem = class
  private
    FIndice          : Integer;
    FURL             : string;
    FArquivoLocal    : string;
    FTitulo          : string;
    FFormatoOriginal : string;
    FExtDestino      : string;
    FCodecDestino    : string;
    FVideoParams     : string;
    FParamsAudio     : string;
    FFormatoYtdlp    : string;
    FMergeFormat     : string;
    FNomePrefixo     : string;
    FPastaDestino    : string;
    FDestino         : string;
    FStatus          : TVideoQueueStatus;
    FFase            : TVideoQueueFase;
    FProgresso       : Integer;
    FMensagem        : string;
    FMiniatura       : TBitmap;

    procedure SetProgresso(AValor: Integer);
  public
    constructor Create(AIndice: Integer; const AURL, AArquivoLocal: string);
    destructor Destroy; override;

    procedure AtribuirMiniatura(AValor: TBitmap);

    function OrigemLocal: Boolean;
    function ExtensaoOrigem: string;
    function StatusTexto: string;
    function ResumoFormatos: string;
    function ResumoDownload: string;
    function ResumoDestino: string;

    property Indice          : Integer read FIndice write FIndice;
    property URL             : string  read FURL write FURL;
    property ArquivoLocal    : string  read FArquivoLocal write FArquivoLocal;
    property Titulo          : string  read FTitulo write FTitulo;
    property FormatoOriginal : string  read FFormatoOriginal write FFormatoOriginal;
    property ExtDestino      : string  read FExtDestino write FExtDestino;
    property CodecDestino    : string  read FCodecDestino write FCodecDestino;
    property VideoParams     : string  read FVideoParams write FVideoParams;
    property ParamsAudio     : string  read FParamsAudio write FParamsAudio;
    property FormatoYtdlp    : string  read FFormatoYtdlp write FFormatoYtdlp;
    property MergeFormat     : string  read FMergeFormat write FMergeFormat;
    property NomePrefixo     : string  read FNomePrefixo write FNomePrefixo;
    property PastaDestino    : string  read FPastaDestino write FPastaDestino;
    property Destino         : string  read FDestino write FDestino;
    property Status          : TVideoQueueStatus read FStatus write FStatus;
    property Fase            : TVideoQueueFase read FFase write FFase;
    property Progresso       : Integer read FProgresso write SetProgresso;
    property Mensagem        : string  read FMensagem write FMensagem;
    property Miniatura       : TBitmap read FMiniatura;
  end;

  { TVideoQueue
    Lista de itens do pipeline. É uma instância única para que a fila
    não se perca quando o frame que a exibe é recriado. }
  TVideoQueue = class
  private
    FItens     : TList;
    FAlterado  : TNotifyEvent;
    FInstancia : TVideoQueue;
    class var FUnica: TVideoQueue;

    procedure AvisarAlteracao;
    procedure Renumerar;
    function IndiceInterno(AItem: TVideoQueueItem): Integer;
    { Núcleo da adição em lote. AModo: 0=misto (arquivo existente vira
      arquivo, resto vira URL), 1=só URLs, 2=só arquivos. }
    function AddLote(const ALista: TStrings; AModo: Integer): Integer;
  public
    constructor Create;
    destructor Destroy; override;

    class function Unica: TVideoQueue;

    function  AdicionarURL(const AURL: string): TVideoQueueItem;
    function  AdicionarArquivo(const AArquivo: string): TVideoQueueItem;
    function  Adicionar(const AOrigem: string): TVideoQueueItem;

    { Adição em lote. Uma única notificação de alteração ao final: sem
      isso cada entrada dispararia uma reconstrução completa da visão e
      a colagem de centenas de URLs viraria O(N²). As três variantes
      deduplicam contra o que já existe na fila e dentro do próprio lote,
      preservando a ordem de chegada. }
    function  AdicionarURLs(const ALista: TStrings): Integer;
    function  AdicionarArquivos(const ALista: TStrings): Integer;
    function  AdicionarVarias(const ALista: TStrings): Integer;
    procedure Remover(AItem: TVideoQueueItem);
    procedure Mover(AItem: TVideoQueueItem; AParaPosicao: Integer);
    procedure Limpar;

    function QtItens: Integer;
    function QtPendentes: Integer;
    function Item(AIndice: Integer): TVideoQueueItem;
    function ContidoEm(AItem: TVideoQueueItem): Boolean;
    function PrimeiroPendente: TVideoQueueItem;
    function UltimoPendente: TVideoQueueItem;

    property OnAlterado: TNotifyEvent read FAlterado write FAlterado;
  end;

  { TThumbnailService
    Geração das miniaturas dos itens da fila: extrai um quadro real do
    vídeo com o FFmpeg, baixa a miniatura do próprio site com o yt-dlp
    quando a origem é uma URL e, quando não é possível, desenha um
    representante visual para que o item nunca fique sem imagem. }
  TThumbnailService = class
  public
    { Versões diretas para a interface, ainda usadas pelos testes. }
    class function DoArquivo(const AArquivo: string; AWidth, AHeight: Integer): TBitmap;
    class function DoURL(const AURL: string; AWidth, AHeight: Integer): TBitmap;
    class function Representacao(const ATexto: string; AWidth, AHeight: Integer): TBitmap;

    { Versões que escrevem o BMP num arquivo temporário e devolvem o
      caminho — são as usadas pelos trabalhadores em thread própria,
      que não podem criar TBitmap (o canvas pertence à thread da
      interface). CarregarBMP/ApagarBMP correm na interface. }
    class function DoArquivoParaArquivo(const AArquivo: string;
      AWidth, AHeight: Integer; const ASufixo: string): string;
    class function DoURLParaArquivo(const AURL: string;
      AWidth, AHeight: Integer; const ASufixo: string;
      out ATitulo: string): string;
    class function CarregarBMP(const ACaminho: string): TBitmap;
    class procedure ApagarBMP(const ACaminho: string);
  end;

{ ExtrairURLs
  Separa um texto colado em uma lista de origens válidas para a fila.
  Aceita um URL sozinho (comportamento antigo) ou vários separados por
  espaço, tabulação ou quebra de linha, que é como as listas de links
  chegam ao ser copiadas de navegadores, redes sociais e mensageiros.

  Cada pedaço só entra quando tem esquema de rede (://) ou quando aponta
  para um arquivo que existe de fato — a mesma regra que
  TVideoQueue.Adicionar já aplica, sem criar um fluxo paralelo. A
  pontuação de cola (vírgula, ponto, parênteses, aspas) é retirada das
  pontas, a ordem da colagem é preservada e repetições no mesmo lote são
  descartadas. A lista devolvida pertence a quem chama. }
function ExtrairURLs(const ATexto: string): TStringList;

implementation

{ TVideoQueueItem }

constructor TVideoQueueItem.Create(AIndice: Integer;
                                    const AURL, AArquivoLocal: string);
begin
  inherited Create;
  FIndice          := AIndice;
  FURL             := AURL;
  FArquivoLocal    := AArquivoLocal;
  FStatus          := vqsAguardando;
  FProgresso       := 0;
  FMensagem        := 'Aguardando processamento';
  FFormatoOriginal := 'Origem Web';

  if AArquivoLocal <> '' then
  begin
    FTitulo          := ChangeFileExt(ExtractFileName(AArquivoLocal), '');
    FFormatoOriginal := UpperCase(ExtractFileExt(AArquivoLocal));
  end
  else
    FTitulo := AURL;
end;

destructor TVideoQueueItem.Destroy;
begin
  FMiniatura.Free;
  inherited Destroy;
end;

procedure TVideoQueueItem.SetProgresso(AValor: Integer);
begin
  if AValor < 0 then
    FProgresso := 0
  else if AValor > 100 then
    FProgresso := 100
  else
    FProgresso := AValor;
end;

procedure TVideoQueueItem.AtribuirMiniatura(AValor: TBitmap);
begin
  if FMiniatura = AValor then
    Exit;
  FMiniatura.Free;
  FMiniatura := AValor;
end;

function TVideoQueueItem.OrigemLocal: Boolean;
begin
  Result := FArquivoLocal <> '';
end;

function TVideoQueueItem.ExtensaoOrigem: string;
begin
  if FArquivoLocal <> '' then
    Result := UpperCase(ExtractFileExt(FArquivoLocal))
  else
    Result := '';
end;

function TVideoQueueItem.StatusTexto: string;
begin
  case FStatus of
    vqsAguardando : Result := 'AGUARDANDO';
    vqsProcessando: Result := 'PROCESSANDO';
    vqsConcluido  : Result := 'CONCLUÍDO';
    vqsErro       : Result := 'ERRO';
    vqsCancelado  : Result := 'CANCELADO';
  else
    Result := '';
  end;
end;

function TVideoQueueItem.ResumoFormatos: string;
var
  sOrigem, sDestino: string;
begin
  sOrigem := FFormatoOriginal;
  if sOrigem = '' then
    sOrigem := 'Origem Web';

  if FExtDestino = '' then
    sDestino := 'a definir'
  else
    sDestino := UpperCase(FExtDestino);

  if FCodecDestino <> '' then
    Result := Format('Original: %s   >   Destino: %s   (%s)',
                     [sOrigem, sDestino, FCodecDestino])
  else
    Result := Format('Original: %s   >   Destino: %s', [sOrigem, sDestino]);
end;

function TVideoQueueItem.ResumoDownload: string;
begin
  if FFormatoYtdlp = '' then
    Exit('Download: arquivo local');

  if FArquivoLocal <> '' then
    Result := 'Download: ' + FFormatoYtdlp + '  >  local: ' + FFormatoOriginal
  else
    Result := 'Download: ' + FFormatoYtdlp + '  >  merge: ' + FMergeFormat;
end;

function TVideoQueueItem.ResumoDestino: string;
begin
  Result := FDestino;
end;

{ TVideoQueue }

class function TVideoQueue.Unica: TVideoQueue;
begin
  if FUnica = nil then
    FUnica := TVideoQueue.Create;
  Result := FUnica;
end;

constructor TVideoQueue.Create;
begin
  inherited Create;
  FItens := TList.Create;
end;

destructor TVideoQueue.Destroy;
begin
  FAlterado := nil;
  Limpar;
  FItens.Free;
  if FUnica = Self then
    FUnica := nil;
  inherited Destroy;
end;

procedure TVideoQueue.AvisarAlteracao;
begin
  if Assigned(FAlterado) then
    FAlterado(Self);
end;

{ A numeração exibida é sempre a posição real na lista de processamento. }
procedure TVideoQueue.Renumerar;
var
  i: Integer;
begin
  for i := 0 to FItens.Count - 1 do
    TVideoQueueItem(FItens[i]).Indice := i + 1;
end;

{ Reordena a fila de verdade: a posição escolhida é a ordem em que os
  itens serão processados. AParaPosicao é 1-based. }
procedure TVideoQueue.Mover(AItem: TVideoQueueItem; AParaPosicao: Integer);
var
  De, Para: Integer;
begin
  De := IndiceInterno(AItem);
  if De < 0 then
    Exit;

  Para := AParaPosicao - 1;
  if Para < 0 then
    Para := 0;
  if Para > FItens.Count - 1 then
    Para := FItens.Count - 1;
  if Para = De then
    Exit;

  FItens.Move(De, Para);
  Renumerar;
  AvisarAlteracao;
end;

function TVideoQueue.IndiceInterno(AItem: TVideoQueueItem): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to FItens.Count - 1 do
    if TVideoQueueItem(FItens[i]) = AItem then
      Exit(i);
end;

function TVideoQueue.AdicionarURL(const AURL: string): TVideoQueueItem;
var
  i: Integer;
begin
  Result := nil;
  if Trim(AURL) = '' then
    Exit;

  for i := 0 to FItens.Count - 1 do
    if TVideoQueueItem(FItens[i]).URL = AURL then
      Exit;

  Result := TVideoQueueItem.Create(FItens.Count + 1, Trim(AURL), '');
  FItens.Add(Result);
  Renumerar;
  AvisarAlteracao;
end;

function TVideoQueue.AdicionarArquivo(const AArquivo: string): TVideoQueueItem;
var
  i: Integer;
begin
  Result := nil;
  if (Trim(AArquivo) = '') or (not FileExists(AArquivo)) then
    Exit;

  for i := 0 to FItens.Count - 1 do
    if TVideoQueueItem(FItens[i]).ArquivoLocal = AArquivo then
      Exit;

  Result := TVideoQueueItem.Create(FItens.Count + 1, '', Trim(AArquivo));
  FItens.Add(Result);
  Renumerar;
  AvisarAlteracao;
end;

function TVideoQueue.Adicionar(const AOrigem: string): TVideoQueueItem;
begin
  if FileExists(AOrigem) then
    Result := AdicionarArquivo(AOrigem)
  else
    Result := AdicionarURL(AOrigem);
end;

function TVideoQueue.AddLote(const ALista: TStrings; AModo: Integer): Integer;
var
  U, Ar: TStringList;
  i, X: Integer;
  Origem: string;
begin
  Result := 0;
  if not Assigned(ALista) then
    Exit;
  if ALista.Count = 0 then
    Exit;

  { Duas listas ordenadas usadas como conjuntos: uma com as URL existentes
    e outra com os caminhos de arquivo. A dedução O((N+M) log M) acontece
    por Find/Add, e como as entradas do próprio lote entram no conjunto à
    medida que são aceitas, a repetição dentro da colagem some também. }
  U := TStringList.Create;
  Ar := TStringList.Create;
  try
    U.Sorted := True;
    U.Duplicates := dupIgnore;
    Ar.Sorted := True;
    Ar.Duplicates := dupIgnore;

    for i := 0 to FItens.Count - 1 do
    begin
      if TVideoQueueItem(FItens[i]).URL <> '' then
        U.Add(TVideoQueueItem(FItens[i]).URL);
      if TVideoQueueItem(FItens[i]).ArquivoLocal <> '' then
        Ar.Add(TVideoQueueItem(FItens[i]).ArquivoLocal);
    end;

    for i := 0 to ALista.Count - 1 do
    begin
      Origem := Trim(ALista[i]);
      if Origem = '' then
        Continue;

      { Arquivo que existe entra como arquivo, exceto quando a chamada
        pede explicitamente só URLs. }
      if (AModo <> 1) and FileExists(Origem) then
      begin
        if Ar.Find(Origem, X) then
          Continue;
        Ar.Add(Origem);
        FItens.Add(TVideoQueueItem.Create(FItens.Count + 1, '', Origem));
        Inc(Result);
        Continue;
      end;

      if AModo = 2 then
        Continue;

      if U.Find(Origem, X) then
        Continue;
      U.Add(Origem);
      FItens.Add(TVideoQueueItem.Create(FItens.Count + 1, Origem, ''));
      Inc(Result);
    end;
  finally
    U.Free;
    Ar.Free;
  end;

  if Result > 0 then
  begin
    Renumerar;
    AvisarAlteracao;
  end;
end;

function TVideoQueue.AdicionarURLs(const ALista: TStrings): Integer;
begin
  Result := AddLote(ALista, 1);
end;

function TVideoQueue.AdicionarArquivos(const ALista: TStrings): Integer;
begin
  Result := AddLote(ALista, 2);
end;

function TVideoQueue.AdicionarVarias(const ALista: TStrings): Integer;
begin
  Result := AddLote(ALista, 0);
end;

procedure TVideoQueue.Remover(AItem: TVideoQueueItem);
var
  i: Integer;
begin
  i := IndiceInterno(AItem);
  if i < 0 then
    Exit;

  TVideoQueueItem(FItens[i]).Free;
  FItens.Delete(i);

  Renumerar;

  AvisarAlteracao;
end;

procedure TVideoQueue.Limpar;
var
  i: Integer;
begin
  for i := 0 to FItens.Count - 1 do
    TVideoQueueItem(FItens[i]).Free;
  FItens.Clear;
  AvisarAlteracao;
end;

function TVideoQueue.QtItens: Integer;
begin
  Result := FItens.Count;
end;

function TVideoQueue.QtPendentes: Integer;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to FItens.Count - 1 do
    if TVideoQueueItem(FItens[i]).Status = vqsAguardando then
      Inc(Result);
end;

function TVideoQueue.Item(AIndice: Integer): TVideoQueueItem;
begin
  if (AIndice < 0) or (AIndice >= FItens.Count) then
    Result := nil
  else
    Result := TVideoQueueItem(FItens[AIndice]);
end;

function TVideoQueue.ContidoEm(AItem: TVideoQueueItem): Boolean;
begin
  Result := IndiceInterno(AItem) >= 0;
end;

function TVideoQueue.PrimeiroPendente: TVideoQueueItem;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to FItens.Count - 1 do
    if TVideoQueueItem(FItens[i]).Status = vqsAguardando then
      Exit(TVideoQueueItem(FItens[i]));
end;

function TVideoQueue.UltimoPendente: TVideoQueueItem;
var
  i: Integer;
begin
  Result := nil;
  for i := FItens.Count - 1 downto 0 do
    if TVideoQueueItem(FItens[i]).Status = vqsAguardando then
      Exit(TVideoQueueItem(FItens[i]));
end;

{ ExtrairURLs }

{ Corta das pontas do trecho a pontuação que costuma vir colada junto do
  link quando ele é copiado de uma página, de um chat ou de uma planilha:
  "(https://x)", "https://x,", "https://x." etc. Só as pontas são
  tratadas, porque os mesmos caracteres podem fazer parte legítima da URL
  e não devem ser apagados do meio dela. As aspas entram pelo código
  numérico para não confundir o compilador dentro do conjunto. }
const
  PONTUACAO_INICIAL = ['(', '[', '{', '<', #39, #34];
  PONTUACAO_FINAL   = [',', '.', ';', ':', '!', '?', ')', ']', '}', #39,
                       #34, '>', '|'];

function LimparPontuacaoColada(const AToken: string): string;
var
  Primeiro, Ultimo: Char;
begin
  Result := Trim(AToken);

  while Result <> '' do
  begin
    Primeiro := Result[1];
    if not (Primeiro in PONTUACAO_INICIAL) then
      Break;
    Result := Copy(Result, 2, Length(Result) - 1);
  end;

  while Result <> '' do
  begin
    Ultimo := Result[Length(Result)];
    if not (Ultimo in PONTUACAO_FINAL) then
      Break;
    Result := Copy(Result, 1, Length(Result) - 1);
  end;
end;

function Separador(const ACar: Char): Boolean;
begin
  Result := ACar in [#9, #10, #13, ' ', #11, #12];
end;

function ExtrairURLs(const ATexto: string): TStringList;
var
  i, j, Tamanho: Integer;
  Peca, Limpa: string;
  TemSeparador: Boolean;
begin
  Result := TStringList.Create;

  { Caminho de arquivo já existente tem prioridade: ele vale o texto todo,
    mesmo contendo espaços, como acontecia antes deste recurso. Vários
    arquivos locais continuam sendo tratados por "ADICIONAR ARQUIVOS...",
    que aceita seleção múltipla e não depende de separador. }
  Limpa := Trim(ATexto);
  if Limpa = '' then
    Exit;

  if FileExists(Limpa) then
  begin
    Result.Add(Limpa);
    Exit;
  end;

  { Sem nenhum separador o texto já é um endereço só: devolvido inteiro,
    sem passar pelo critério de validação, como era no comportamento
    antigo do campo. }
  TemSeparador := False;
  for i := 1 to Length(ATexto) do
    if Separador(ATexto[i]) then
    begin
      TemSeparador := True;
      Break;
    end;

  if not TemSeparador then
  begin
    Limpa := LimparPontuacaoColada(ATexto);
    if Limpa <> '' then
      Result.Add(Limpa);
    Exit;
  end;

  { Lista colada: espaço, tabulação ou quebra de linha separam um endereço
    do próximo. Cada pedaço passa pela mesma regra de
    TVideoQueue.Adicionar — link com esquema ou arquivo que existe — e
    qualquer outro ruído de texto é ignorado. A repetição é descartada na
    inserção para manter a ordem original, já que dupIgnore exigiria
    ordenar a lista. }
  Tamanho := Length(ATexto);
  i := 1;
  while i <= Tamanho do
  begin
    while (i <= Tamanho) and Separador(ATexto[i]) do
      Inc(i);
    j := i;
    while (j <= Tamanho) and not Separador(ATexto[j]) do
      Inc(j);
    if j > i then
    begin
      Peca := Copy(ATexto, i, j - i);
      i := j;
      Limpa := LimparPontuacaoColada(Peca);
      if (Limpa <> '') and
         ((Pos('://', Limpa) > 0) or FileExists(Limpa)) and
         (Result.IndexOf(Limpa) < 0) then
        Result.Add(Limpa);
      continue;
    end;
    Inc(i);
  end;
end;

{ TThumbnailService }

{ Caminho de um BMP temporário único dentro do pool de miniaturas. }
function CaminhoTemporarioBMP(const ABase, ASufixo: string): string;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir) + ABase + '_' + ASufixo + '.bmp';
end;

{ A primeira linha útil de uma saída de texto: não vazia e fora de
  colchetes, para não confundir o título com linhas de serviço do yt-dlp
  ("[youtube] Extracting URL", avisos...). }
function PrimeiraLinhaUtil(const ATexto: string): string;
var
  S, Linha: string;
  P: Integer;
begin
  Result := '';
  S := Trim(ATexto);
  if S = '' then
    Exit;

  repeat
    P := Pos(#10, S);
    if P > 0 then
    begin
      Linha := Copy(S, 1, P - 1);
      S := Copy(S, P + 1, Length(S));
    end
    else
    begin
      Linha := S;
      S := '';
    end;
    Linha := Trim(Linha);
    if (Linha <> '') and (Linha[1] <> '[') then
      Exit(Linha);
  until S = '';
end;

{ Roda o FFmpeg convertendo uma entrada (vídeo ou imagem) em BMP pequeno
  no diretório temporário. A espera usa ABombeia=False: ela acontece em
  thread própria e não pode repintar a interface. O processo entra no Job
  do aplicativo dentro de Iniciar, então não sobrevive ao fechamento da
  janela. ACapturarQuadro coloca o -ss 1 antes do -i para pular do começo
  do vídeo. }
function ConverterEmBMP(const AEntrada: string; ACapturarQuadro: Boolean;
  AWidth, AHeight: Integer; const ASufixo: string): string;
var
  Exe, Destino: string;
  Args: TStringList;
  Proc: TProcessoGerenciado;
begin
  Result := '';
  if (ASufixo = '') or (AEntrada = '') or (not FileExists(AEntrada)) then
    Exit;

  Exe := TGerenciadorDependencias.Caminho(depFFmpeg);
  if Exe = '' then
    Exe := 'ffmpeg';

  { BMP é usado porque TBitmap faz parte do LCL e dispensa fcl-image.
    Sem poUsePipes o ffmpeg não ganha console e jogar progresso fora é
    apenas ignorar a escrita sem redirecionar nada. }
  Destino := CaminhoTemporarioBMP('syn_thumb', ASufixo);

  Args := TStringList.Create;
  Proc := TProcessoGerenciado.Create;
  try
    Args.Add('-y');
    if ACapturarQuadro then
    begin
      Args.Add('-ss');
      Args.Add('1');
    end;
    Args.Add('-i');
    Args.Add(AEntrada);
    Args.Add('-frames:v');
    Args.Add('1');
    Args.Add('-vf');
    Args.Add(Format('scale=%d:%d:force_original_aspect_ratio=decrease',
      [AWidth, AHeight]));
    Args.Add('-c:v');
    Args.Add('bmp');
    Args.Add('-f');
    Args.Add('image2');
    Args.Add(Destino);

    if not Proc.Iniciar(Exe, Args, nil, False) then
      Exit;
    if not Proc.Aguardar(30000, False) then
    begin
      Proc.Encerrar(encForcar);
      Exit;
    end;
  finally
    Proc.Free;
    Args.Free;
  end;

  if FileExists(Destino) then
    Result := Destino;
end;

class function TThumbnailService.CarregarBMP(const ACaminho: string): TBitmap;
begin
  Result := nil;
  if (ACaminho = '') or (not FileExists(ACaminho)) then
    Exit;
  Result := TBitmap.Create;
  try
    Result.LoadFromFile(ACaminho);
  except
    Result.Free;
    Result := nil;
  end;
end;

class procedure TThumbnailService.ApagarBMP(const ACaminho: string);
begin
  if ACaminho <> '' then
    DeleteFile(ACaminho);
end;

class function TThumbnailService.DoArquivoParaArquivo(const AArquivo: string;
  AWidth, AHeight: Integer; const ASufixo: string): string;
begin
  Result := ConverterEmBMP(AArquivo, True, AWidth, AHeight, ASufixo);
end;

class function TThumbnailService.DoArquivo(const AArquivo: string;
                                          AWidth, AHeight: Integer): TBitmap;
var
  P: string;
begin
  Result := nil;
  P := DoArquivoParaArquivo(AArquivo, AWidth, AHeight,
    IntToStr(GetProcessID) + '_' + FormatDateTime('hhnnsszzz', Now));
  if P = '' then
    Exit;
  Result := CarregarBMP(P);
  ApagarBMP(P);
end;

{ Baixa a miniatura publicada pela própria fonte (yt-dlp) e a converte
  em BMP temporário. Também devolve o título na primeira linha útil da
  saída: a mesma chamada de rede que baixa a imagem informa o nome, e
  com isso o item deixa de mostrar a URL enquanto aguarda o download. }
class function TThumbnailService.DoURLParaArquivo(const AURL: string;
  AWidth, AHeight: Integer; const ASufixo: string; out ATitulo: string): string;
var
  Exe, Base, Imagem: string;
  Args: TStringList;
  Proc: TProcessoGerenciado;
  Info: TSearchRec;
  Inicio: QWord;
  Saida, Trecho: string;
  Estourou: Boolean;
begin
  Result := '';
  ATitulo := '';
  if (ASufixo = '') or (Trim(AURL) = '') then
    Exit;

  Exe := TGerenciadorDependencias.Caminho(depYtDlp);
  if Exe = '' then
    Exe := 'yt-dlp';

  { Base sem extensão: o %(ext)s do modelo de saída escolhe o formato. }
  Base := IncludeTrailingPathDelimiter(GetTempDir) + 'syn_thumburl_' + ASufixo;

  Args := TStringList.Create;
  Proc := TProcessoGerenciado.Create;
  try
    Args.Add('--no-playlist');
    Args.Add('--skip-download');
    Args.Add('--write-thumbnail');
    { --print põe o yt-dlp em modo simulate e aí ele NÃO grava nada em
      disco — nem a miniatura. --no-simulate devolve a gravação enquanto
      --skip-download continua impedindo o download do vídeo. }
    Args.Add('--no-simulate');
    Args.Add('--no-warnings');
    Args.Add('--print');
    Args.Add('%(title)s');
    Args.Add('--output');
    Args.Add(Base + '.%(ext)s');
    Args.Add('--');
    Args.Add(Trim(AURL));

    if Proc.Iniciar(Exe, Args, nil, True) then
    begin
      { A saída precisa ser drenada enquanto o yt-dlp roda. O buffer do
        pipe enche em poucos KB e o processo trava na escrita, sem
        nunca terminar — Aguardar apenas acompanha o fim, não lê nada,
        e o prazo de 45 s estourava sem que a imagem chegasse a ser
        gravada. O laço lê a cada passo e impõe o próprio prazo; roda
        em thread própria, então não há mensagem a bombear. }
      Estourou := False;
      Inicio   := GetTickCount64;
      Saida    := '';
      while Proc.Ativo do
      begin
        if Proc.LerDisponivel(Trecho) > 0 then
          Saida := Saida + Trecho;
        Sleep(10);
        if Integer(GetTickCount64 - Inicio) >= 45000 then
        begin
          Proc.Encerrar(encForcar);
          Estourou := True;
          Break;
        end;
      end;
      if Estourou then
        ATitulo := PrimeiraLinhaUtil(Saida)
      else
        ATitulo := PrimeiraLinhaUtil(Saida + Proc.LerTudo);
    end;
  finally
    Proc.Free;
    Args.Free;
  end;

  Imagem := '';
  if FindFirst(Base + '.*', faAnyFile, Info) = 0 then
  begin
    try
      repeat
        { Um download interrompido deixa um '*.part' para trás: ele não é
          imagem e não deve vencer a busca. }
        if LowerCase(ExtractFileExt(Info.Name)) <> '.part' then
        begin
          Imagem := IncludeTrailingPathDelimiter(GetTempDir) + Info.Name;
          Break;
        end;
      until FindNext(Info) <> 0;
    finally
      FindClose(Info);
    end;
  end;

  if Imagem <> '' then
  begin
    Result := ConverterEmBMP(Imagem, False, AWidth, AHeight, ASufixo);
    DeleteFile(Imagem);
  end;
end;

class function TThumbnailService.DoURL(const AURL: string;
                                       AWidth, AHeight: Integer): TBitmap;
var
  P, Titulo: string;
begin
  Result := nil;
  P := DoURLParaArquivo(AURL, AWidth, AHeight,
    IntToStr(GetProcessID) + '_' + FormatDateTime('hhnnsszzz', Now), Titulo);
  if P = '' then
    Exit;
  Result := CarregarBMP(P);
  ApagarBMP(P);
end;

class function TThumbnailService.Representacao(const ATexto: string;
                                              AWidth, AHeight: Integer): TBitmap;
var
  Tela: TCanvas;
  Area: TRect;
  Pontos: array[0..2] of TPoint;
  Rotulo: string;
  i, Tam: Integer;
  CentroX, CentroY: Integer;
begin
  Result := nil;
  try
    Result := TBitmap.Create;
    Result.SetSize(AWidth, AHeight);
    Tela := Result.Canvas;
    Tela.Brush.Style := bsSolid;
    Tela.Brush.Color := RGBToColor(58, 62, 70);
    Tela.FillRect(Rect(0, 0, AWidth, AHeight));

    Area := Rect(0, 0, AWidth, AHeight);
    Tela.Brush.Style := bsClear;
    Tela.Brush.Color := RGBToColor(96, 102, 112);
    Tela.Pen.Color := RGBToColor(140, 148, 160);
    Tela.Pen.Width := 1;
    Tela.RoundRect(Area, 4, 4);

    CentroX := AWidth div 2;
    CentroY := (AHeight div 2) - 6;
    Tam := (AHeight div 3);
    if Tam < 10 then Tam := 10;

    Pontos[0].X := CentroX - (Tam div 2);
    Pontos[0].Y := CentroY - (Tam div 2);
    Pontos[1].X := CentroX + Tam;
    Pontos[1].Y := CentroY;
    Pontos[2].X := CentroX - (Tam div 2);
    Pontos[2].Y := CentroY + (Tam div 2);

    Tela.Brush.Style := bsSolid;
    Tela.Brush.Color := RGBToColor(226, 232, 240);
    Tela.Pen.Style := psClear;
    Tela.Polygon(Pontos);

    Rotulo := '';
    for i := 1 to Length(ATexto) do
      if ATexto[i] <> ' ' then
      begin
        Rotulo := Rotulo + ATexto[i];
        if Length(Rotulo) >= 3 then
          Break;
      end;
    Rotulo := UpperCase(Rotulo);

    Tela.Brush.Style := bsClear;
    Tela.Font.Color := RGBToColor(210, 216, 226);
    Tela.Font.Size := 8;
    Tela.Font.Style := [fsBold];
    Tela.Font.Name := 'Sans Serif';
    Tela.TextRect(Rect(0, CentroY + Tam, AWidth, AHeight), 0, 0, Rotulo);
  except
    { Em ambientes sem canvas utilizavel devolve nil e o item fica sem imagem. }
    Result.Free;
    Result := nil;
  end;
end;

end.