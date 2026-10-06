unit uVideoQueue;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Graphics, GraphType, Process, uProcessos, uDependencias;

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
  public
    constructor Create;
    destructor Destroy; override;

    class function Unica: TVideoQueue;

    function  AdicionarURL(const AURL: string): TVideoQueueItem;
    function  AdicionarArquivo(const AArquivo: string): TVideoQueueItem;
    function  Adicionar(const AOrigem: string): TVideoQueueItem;
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
    class function DoArquivo(const AArquivo: string; AWidth, AHeight: Integer): TBitmap;
    class function DoURL(const AURL: string; AWidth, AHeight: Integer): TBitmap;
    class function Representacao(const ATexto: string; AWidth, AHeight: Integer): TBitmap;
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

class function TThumbnailService.DoArquivo(const AArquivo: string;
                                          AWidth, AHeight: Integer): TBitmap;
var
  Destino, Cmd: string;
  Processo: TProcess;
  Bitmap: TBitmap;
begin
  Result := nil;
  if (AArquivo = '') or (not FileExists(AArquivo)) then
    Exit;

  { BMP é usado porque TBitmap faz parte do LCL e dispensa fcl-image. }
  Destino := IncludeTrailingPathDelimiter(GetTempDir) +
             'syn_thumb_' + IntToStr(GetProcessID) + '_' +
             FormatDateTime('hhnnsszzz', Now) + '.bmp';

  Processo := TProcess.Create(nil);
  try
    { '-vf scale=...' precisa chegar ao ffmpeg como um argumento so. Via
      'cmd.exe /c' o quoting era resolvido pelo interpretador de comandos;
      chamado direto, o argumento e repassado como escrito. O descarte de
      stderr deixa de existir: sem shell nao ha para onde redirecionar, e
      poStderrToOutPut com a saida descartada resolve o mesmo problema. }
    Processo.Executable := TGerenciadorDependencias.Caminho(depFFmpeg);
    if Processo.Executable = '' then
      Processo.Executable := 'ffmpeg';
    Processo.Parameters.Add('-y');
    Processo.Parameters.Add('-ss');
    Processo.Parameters.Add('1');
    Processo.Parameters.Add('-i');
    Processo.Parameters.Add(AArquivo);
    Processo.Parameters.Add('-frames:v');
    Processo.Parameters.Add('1');
    Processo.Parameters.Add('-vf');
    Processo.Parameters.Add(Format('scale=%d:%d:force_original_aspect_ratio=decrease',
      [AWidth, AHeight]));
    Processo.Parameters.Add('-c:v');
    Processo.Parameters.Add('bmp');
    Processo.Parameters.Add('-f');
    Processo.Parameters.Add('image2');
    Processo.Parameters.Add(Destino);
    Processo.Options := [poNoConsole, poWaitOnExit, poStderrToOutPut];
    Processo.Execute;

    {$IFDEF WINDOWS}
    { Vincular ao Job evita que um ffmpeg esquecido fique rodando sem
      ninguem esperando pelo arquivo. }
    TGerenciadorProcessos.Vincular(THandle(Processo.ProcessHandle));
    {$ENDIF}
  finally
    Processo.Free;
  end;

  if not FileExists(Destino) then
    Exit;

  Bitmap := TBitmap.Create;
  try
    Bitmap.LoadFromFile(Destino);
    Result := Bitmap;
    Bitmap := nil;
  except
    Result := nil;
  end;
  Bitmap.Free;
  DeleteFile(Destino);
end;

{ Executa um comando externo ignorando o console e sem lancar excecao. }
function ExecutarSilencioso(const ACmd: string): Boolean;
var
  Processo: TProcess;
  Partes: TStringList;
  i: Integer;
begin
  Result := False;
  Partes := TGerenciadorDependencias.DividirArgumentos(ACmd);
  if Partes.Count = 0 then
    Exit;
  try
    { A linha vira executavel mais argumentos, e o binario e chamado
      direto: sem 'cmd.exe /c' no meio nao existe interpretador de
      comandos para reinterpretar as aspas. }
    Processo := TProcess.Create(nil);
    try
      Processo.Executable := Partes[0];
      for i := 1 to Partes.Count - 1 do
        Processo.Parameters.Add(Partes[i]);
      Processo.Options := [poNoConsole, poWaitOnExit, poStderrToOutPut];
      Processo.Execute;   { TProcess.Execute e' procedure: nao devolve valor }
      Result := True;
    except
      Result := False;
    end;
    Processo.Free;
  finally
    Partes.Free;
  end;
end;

{ Converte qualquer imagem suportada pelo FFmpeg em BMP e a devolve. }
function ImportarComoBitmap(const AImagem: string;
  AWidth, AHeight: Integer): TBitmap;
var
  Base, Destino: string;
  Bitmap: TBitmap;
begin
  Result := nil;
  if (AImagem = '') or (not FileExists(AImagem)) then
    Exit;

  Base := IncludeTrailingPathDelimiter(GetTempDir) +
          'syn_thumb_' + IntToStr(GetProcessID) + '_' +
          FormatDateTime('hhnnsszzz', Now);
  Destino := Base + '.bmp';

  ExecutarSilencioso(Format('ffmpeg -y -i "%s" -frames:v 1 ' +
                            '-vf "scale=%d:%d:force_original_aspect_ratio=decrease" ' +
                            '-c:v bmp -f image2 "%s" %s',
                            [AImagem, AWidth, AHeight, Destino,
                             {$IFDEF WINDOWS}'2>nul'{$ELSE}'2>/dev/null'{$ENDIF}]));

  if FileExists(Destino) then
  begin
    Bitmap := TBitmap.Create;
    try
      Bitmap.LoadFromFile(Destino);
      Result := Bitmap;
      Bitmap := nil;
    except
      Result := nil;
    end;
    Bitmap.Free;
  end;

  DeleteFile(Destino);
end;

{ Baixa a miniatura publicada pela propria fonte (yt-dlp) e a converte
  para Bitmap. Devolve nil quando a origem nao possui miniatura. }
class function TThumbnailService.DoURL(const AURL: string;
                                       AWidth, AHeight: Integer): TBitmap;
var
  Base, Imagem: string;
  Info: TSearchRec;
begin
  Result := nil;
  if Trim(AURL) = '' then
    Exit;

  Base := IncludeTrailingPathDelimiter(GetTempDir) +
          'syn_thumburl_' + IntToStr(GetProcessID) + '_' +
          FormatDateTime('hhnnsszzz', Now);

  { --write-thumbnail + --skip-download nao baixa o video, apenas a imagem. }
  ExecutarSilencioso(Format('yt-dlp --no-playlist --skip-download --write-thumbnail ' +
                            '--no-warnings --output "%s.%%(ext)s" "%s" %s',
                            [Base, AURL,
                             {$IFDEF WINDOWS}'2>nul'{$ELSE}'2>/dev/null'{$ENDIF}]));

  Imagem := '';
  if FindFirst(Base + '.*', faAnyFile, Info) = 0 then
  begin
    try
      Imagem := IncludeTrailingPathDelimiter(GetTempDir) + Info.Name;
    finally
      FindClose(Info);
    end;
  end;

  if Imagem <> '' then
    Result := ImportarComoBitmap(Imagem, AWidth, AHeight);

  if FindFirst(Base + '.*', faAnyFile, Info) = 0 then
  begin
    try
      DeleteFile(IncludeTrailingPathDelimiter(GetTempDir) + Info.Name);
    finally
      FindClose(Info);
    end;
  end;
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