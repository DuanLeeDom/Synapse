unit uImageProcQueue;

{ uImageProcQueue

  Modelo da fila de imagens.

  Reaproveita as decisoes que a fila de video ja tomou - item como objeto
  proprio, numeracao igual a posicao real de processamento, singleton para
  sobreviver a recriacao do frame, e aviso de alteracao para a view - e
  acrescenta o que a conversao de imagens exige: cada item tem formato de
  saida e pasta proprios, que sobrevivem a qualquer edicao posterior.

  A separacao entre "padrao da fila" e "configuracao do item" e feita por
  uma unica flag, UsarPastaPadrao. Enquanto ela estiver ligada o item
  segue a pasta global, mesmo que o valor tenha sido congelado no momento
  da inclusao; ao desligar, o item passa a usar o caminho proprio. Isso
  evita a confusao classica de um item que mostra uma pasta mas ignora
  outra, sem perder o controle de quem mandou. }

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Graphics, uDependencias, uProcessos, uImageFormats;

const
  { Mesmas medidas da fila de video, para as duas listas ficarem iguais
    visualmente quando o usuario alterna entre as abas. }
  ALTURA_THUMB_IMAGEM   = 64;
  LARGURA_THUMB_IMAGEM  = 96;

type
  TStatusItemImagem = (isiAguardando, isiProcessando, isiConcluido,
                       isiErro, isiCancelado);

  { TItemImagem
    Uma imagem da fila. Guarda origem, destino, configuracao propria,
    andamento e resultado. }
  TItemImagem = class
  private
    FIndice           : Integer;
    FArquivo          : string;
    FNome             : string;
    FPastaOrigem      : string;
    FFormatoOriginal  : string;
    FLarguraOrigem    : Integer;
    FAlturaOrigem     : Integer;
    FFormatoDestino   : string;
    FPastaDestino     : string;
    FUsarPastaPadrao  : Boolean;
    FOpcoes           : TOpcoesConversao;
    FOpcoesProprias   : Boolean;
    FStatus           : TStatusItemImagem;
    FProgresso        : Integer;
    FMensagem         : string;
    FDetalheErro      : string;
    FMiniatura        : TBitmap;
    FProcesso         : TObject;

    procedure SetProgresso(AValor: Integer);
  public
    constructor Create(AIndice: Integer; const AArquivo: string);
    destructor Destroy; override;

    procedure AtribuirMiniatura(AValor: TBitmap);
    procedure DefinirDimensoesOrigem(AWidth, AHeight: Integer);

    { Opcoes e um registro, e um property que devolve registro entrega uma
      copia: escrever em F.Opcoes.Qualidade alteraria a copia e se
      perderia. Por isso a leitura e a escrita sao metodos separados. }
    function Opcoes: TOpcoesConversao;
    procedure DefinirOpcoes(const AOpcoes: TOpcoesConversao);

    { Usado pela fila para manter um item preso ao padrao global. }
    procedure HerdarOpcoesPadrao(const AOpcoes: TOpcoesConversao);
    property OpcoesProprias: Boolean read FOpcoesProprias;

    { Nome do arquivo de saida, ja com a extensao de destino. }
    function NomeDestino: string;
    { Caminho completo do arquivo de saida. Vazio quando nao ha pasta. }
    function CaminhoDestino: string;

    function StatusTexto: string;
    function ExtensaoOriginal: string;
    function RotuloSaida: string;

    { Texto "origem -> formato -> destino -> status", que e o resumo
      mostrado na fila para o usuario conferir antes de processar. }
    function ResumoFluxo: string;
    function ResumoOpcoes: string;

    property Indice          : Integer read FIndice write FIndice;
    property Arquivo         : string  read FArquivo;
    property Nome            : string  read FNome;
    property PastaOrigem     : string  read FPastaOrigem;
    property FormatoOriginal : string  read FFormatoOriginal;
    property LarguraOrigem   : Integer read FLarguraOrigem;
    property AlturaOrigem    : Integer read FAlturaOrigem;
    property FormatoDestino  : string  read FFormatoDestino write FFormatoDestino;
    property PastaDestino    : string  read FPastaDestino write FPastaDestino;
    property UsarPastaPadrao : Boolean read FUsarPastaPadrao
                                        write FUsarPastaPadrao;
    property Status          : TStatusItemImagem read FStatus write FStatus;
    property Progresso       : Integer read FProgresso write SetProgresso;
    property Mensagem        : string  read FMensagem write FMensagem;
    property DetalheErro     : string  read FDetalheErro write FDetalheErro;
    property Miniatura       : TBitmap read FMiniatura;
    property Processo        : TObject read FProcesso write FProcesso;
  end;

  { TFilaImagens
    Lista de itens. Instancia unica para a fila nao se perder quando o
    frame que a exibe e recriado ao trocar de aba. }
  TFilaImagens = class
  private
    FItens    : TList;
    FAlterado : TNotifyEvent;
    FSelecionado: TItemImagem;
    FProcessando : Boolean;
    FCancelado  : Boolean;
    FFormatoPadrao: string;
    FPastaPadrao  : string;
    FOpcoesPadrao : TOpcoesConversao;

    class var FUnica: TFilaImagens;

    procedure AvisarAlteracao;
    procedure Renumerar;
    function IndiceInterno(AItem: TItemImagem): Integer;
    function ContidoEmPorArquivo(const AArquivo: string): Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    class function Unica: TFilaImagens;

    { Adiciona um arquivo. Devolve nil quando o caminho nao existe ou a
      extensao nao e reconhecida como imagem. }
    function AdicionarArquivo(const AArquivo: string): TItemImagem;
    procedure AdicionarLista(const AArquivos: TStrings);
    { Adiciona os arquivos de uma pasta, opcionalmente so os de uma
      extensao. Devolve quantos entraram. }
    function AdicionarPasta(const APasta: string;
      const AFiltro: string = '*.*'): Integer;

    procedure Remover(AItem: TItemImagem);
    procedure Mover(AItem: TItemImagem; AParaPosicao: Integer);
    procedure Limpar;

    function QtItens: Integer;
    function QtPendentes: Integer;
    function QtConcluidos: Integer;
    function QtComErro: Integer;
    function Item(AIndice: Integer): TItemImagem;
    function ContidoEm(AItem: TItemImagem): Boolean;
    function PrimeiroPendente: TItemImagem;

    { Pasta que sera realmente usada por este item. O item pode estar
      seguindo o padrao global, ter pasta propria ou nenhuma das duas, e
      sem pasta nenhuma o resultado sensato e gravar ao lado do
      original. Concentrar a regra aqui evita que a interface e o runner
      decidam de formas diferentes e mostrem destinos divergentes. }
    function PastaDeDestino(AItem: TItemImagem): string;

    { Pasta que entra em todos os itens novos quando o item usa padrao. }
    procedure AplicarPadraoATodos;

    property Selecionado  : TItemImagem read FSelecionado write FSelecionado;
    property Processando  : Boolean read FProcessando write FProcessando;
    property Cancelado    : Boolean read FCancelado write FCancelado;
    property OnAlterado   : TNotifyEvent read FAlterado write FAlterado;

    { Padroes globais: aplicados aos proximos itens e, quando o item usa
      pasta padrao, tambem aos ja existentes.

      Mesma razao do item: opcoes e registro, e pasta tambem, precisam de
      metodo em vez de atribuicao direta. DefinirPastaPadrao atualiza os
      itens que seguem o padrao, senao a lista mostraria um destino e o
      conversor gravaria em outro. }
    function OpcoesPadrao: TOpcoesConversao;
    procedure DefinirOpcoesPadrao(const AOpcoes: TOpcoesConversao);
    procedure DefinirPastaPadrao(const APasta: string);

    property FormatoPadrao : string read FFormatoPadrao write FFormatoPadrao;
    property PastaPadrao   : string read FPastaPadrao write DefinirPastaPadrao;
  end;

  { TThumbnailServiceImagem
    Miniaturas dos itens. Usa o proprio ImageMagick para gerar um BMP
    pequeno e temporario, o que faz funcionar ate com formatos que o LCL
    nao decodifica, como WebP, AVIF e HEIC. }
  TThumbnailServiceImagem = class
  public
    class function DoArquivo(const AArquivo: string;
      AWidth, AHeight: Integer): TBitmap;
  end;

  { TImageInfoService
    Le o tamanho da imagem. O proprio ImageMagick e quem responde, porque
    nenhum decodificador do LCL da para ler RAW, TIFF ou HEIC. }
  TImageInfoService = class
  public
    class function LerDimensoes(const AArquivo: string;
      out AWidth, AHeight: Integer): Boolean;
  end;

implementation

{ TItemImagem }

constructor TItemImagem.Create(AIndice: Integer; const AArquivo: string);
begin
  inherited Create;
  FIndice          := AIndice;
  FArquivo         := AArquivo;
  FNome            := ExtractFileName(AArquivo);
  FPastaOrigem     := ExtractFileDir(AArquivo);
  FFormatoOriginal := TGerenciadorFormatos.ChaveNormalizada(AArquivo);
  FFormatoDestino  := 'png';
  FStatus          := isiAguardando;
  FProgresso       := 0;
  FMensagem        := 'Aguardando';
  FOpcoes          := TGerenciadorFormatos.OpcoesPadrao;
  FUsarPastaPadrao := True;
end;

destructor TItemImagem.Destroy;
begin
  FMiniatura.Free;
  inherited Destroy;
end;

procedure TItemImagem.SetProgresso(AValor: Integer);
begin
  if AValor < 0 then
    FProgresso := 0
  else if AValor > 100 then
    FProgresso := 100
  else
    FProgresso := AValor;
end;

procedure TItemImagem.AtribuirMiniatura(AValor: TBitmap);
var
  Antigo: TBitmap;
begin
  { Trocar a miniatura eDestroy do anterior em vez de sobrescrever: o
    mesmo bitmap pode estar pintado na hora em que a lista e recriada. }
  Antigo := FMiniatura;
  FMiniatura := AValor;
  Antigo.Free;
end;

procedure TItemImagem.DefinirDimensoesOrigem(AWidth, AHeight: Integer);
begin
  FLarguraOrigem := AWidth;
  FAlturaOrigem  := AHeight;
end;

function TItemImagem.Opcoes: TOpcoesConversao;
begin
  Result := FOpcoes;
end;

procedure TItemImagem.DefinirOpcoes(const AOpcoes: TOpcoesConversao);
begin
  FOpcoes := AOpcoes;
  { Marcar aqui e o que separa "item ajustado pelo usuario" de "item
    herdando o padrao". Sem isso, trocar o padrao global sobrescreveria
    ajustes feitos item a item. }
  FOpcoesProprias := True;
end;

procedure TItemImagem.HerdarOpcoesPadrao(const AOpcoes: TOpcoesConversao);
begin
  FOpcoes := AOpcoes;
  FOpcoesProprias := False;
end;

function TItemImagem.ExtensaoOriginal: string;
begin
  Result := FFormatoOriginal;
end;

function TItemImagem.RotuloSaida: string;
begin
  Result := TGerenciadorFormatos.RotuloDe(FFormatoDestino);
end;

function TItemImagem.NomeDestino: string;
begin
  Result := ChangeFileExt(FNome,
    '.' + TGerenciadorFormatos.ExtensaoDe(FFormatoDestino));
end;

function TItemImagem.CaminhoDestino: string;
begin
  Result := '';
  if FPastaDestino = '' then
    Exit;
  Result := IncludeTrailingPathDelimiter(FPastaDestino) + NomeDestino;
end;

function TItemImagem.StatusTexto: string;
begin
  case FStatus of
    isiAguardando: Result := 'Aguardando';
    isiProcessando: Result := 'Processando';
    isiConcluido:  Result := 'Concluido';
    isiErro:       Result := 'Erro';
    isiCancelado:  Result := 'Cancelado';
  else
    Result := '';
  end;
end;

function TItemImagem.ResumoFluxo: string;
begin
  Result := FNome + '  ->  ' + RotuloSaida + '  ->  ';
  if FPastaDestino = '' then
    Result := Result + '(sem pasta definida)'
  else
    Result := Result + ExtractFileName(FPastaDestino) + LineEnding +
              FMensagem;
end;

function TItemImagem.ResumoOpcoes: string;
var
  Partes: TStringList;
  O: TOpcoesConversao;
begin
  O := Opcoes;
  Partes := TStringList.Create;
  try
    if O.Redimensionar then
      Partes.Add(Format('redimensionar %dx%d', [O.Largura, O.Altura]));
    if O.Qualidade >= 0 then
      Partes.Add('qualidade ' + IntToStr(O.Qualidade));
    if O.Compressao >= 0 then
      Partes.Add('compressao ' + IntToStr(O.Compressao));
    if O.ReduzirCores > 0 then
      Partes.Add(IntToStr(O.ReduzirCores) + ' cores');
    if not O.AplicarAlpha then
      Partes.Add('sem transparencia');
    if O.RemoverMetadados then
      Partes.Add('sem metadados');
    if O.SemPerda then
      Partes.Add('sem perda');
    if Partes.Count = 0 then
      Result := 'padrao do formato'
    else
    begin
      Result := StringReplace(Partes.Text, LineEnding, '; ', [rfReplaceAll]);
      { O Text do TStringList acrescenta a quebra no fim tambem no ultimo
        item, entao sem este corte o resumo terminava em "; ". TrimRight
        desta versao do compilador so aceita a string inteira. }
      while (Result <> '') and (Result[Length(Result)] in [';', ' ']) do
        Result := Copy(Result, 1, Length(Result) - 1);
    end;
  finally
    Partes.Free;
  end;
end;

{ TFilaImagens }

class function TFilaImagens.Unica: TFilaImagens;
begin
  if FUnica = nil then
    FUnica := TFilaImagens.Create;
  Result := FUnica;
end;

constructor TFilaImagens.Create;
begin
  inherited Create;
  FItens := TList.Create;
  FFormatoPadrao := 'png';
  FPastaPadrao   := '';
  FOpcoesPadrao  := TGerenciadorFormatos.OpcoesPadrao;
end;

destructor TFilaImagens.Destroy;
begin
  FItens.Free;
  inherited Destroy;
end;

procedure TFilaImagens.AvisarAlteracao;
begin
  if Assigned(FAlterado) then
    FAlterado(Self);
end;

procedure TFilaImagens.Renumerar;
var
  i: Integer;
begin
  for i := 0 to FItens.Count - 1 do
    TItemImagem(FItens[i]).Indice := i + 1;
end;

function TFilaImagens.IndiceInterno(AItem: TItemImagem): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to FItens.Count - 1 do
    if TItemImagem(FItens[i]) = AItem then
      Exit(i);
end;

function TFilaImagens.OpcoesPadrao: TOpcoesConversao;
begin
  Result := FOpcoesPadrao;
end;

procedure TFilaImagens.DefinirPastaPadrao(const APasta: string);
begin
  if APasta = FPastaPadrao then
    Exit;
  FPastaPadrao := APasta;

  { Os itens que seguem o padrao recebem a pasta nova na hora. Sem isso o
    item continuaria mostrando o destino antigo na lista, enquanto o
    conversor gravaria no novo: a tela mentiria sobre onde o arquivo
    vai parar. }
  AplicarPadraoATodos;
end;

procedure TFilaImagens.DefinirOpcoesPadrao(const AOpcoes: TOpcoesConversao);
var
  i: Integer;
  PorItem: TItemImagem;
begin
  FOpcoesPadrao := AOpcoes;
  { So os itens que NAO receberam ajuste proprio seguem o padrao global.
    Sem essa distincao, mexer no padrao apagaria a configuracao de quem o
    usuario ajustou item por item, que e justamente o recurso. }
  for i := 0 to FItens.Count - 1 do
  begin
    PorItem := TItemImagem(FItens[i]);
    if not PorItem.OpcoesProprias then
      { HerdarOpcoesPadrao e nao DefinirOpcoes: DefinirOpcoes marca o
        item como ajustado a mao, e o item pararia de seguir o padrao
        depois da proxima mudanca global. }
      PorItem.HerdarOpcoesPadrao(AOpcoes);
  end;
  AvisarAlteracao;
end;

function TFilaImagens.AdicionarArquivo(
  const AArquivo: string): TItemImagem;
var
  C: string;
  W, H: Integer;
begin
  Result := nil;
  C := Trim(AArquivo);
  if (C = '') or (not FileExists(C)) then
    Exit;
  if not TGerenciadorFormatos.EhEntradaDeImagem(C) then
    Exit;

  { Arquivo ja na fila nao entra de novo: arrastar a mesma pasta duas vezes
    e um gesto comum e nao deve duplicar o trabalho. }
  if ContidoEmPorArquivo(C) then
    Exit;

  Result := TItemImagem.Create(FItens.Count + 1, C);
  Result.FormatoDestino := FFormatoPadrao;
  Result.HerdarOpcoesPadrao(FOpcoesPadrao);
  Result.UsarPastaPadrao := True;
  Result.PastaDestino := FPastaPadrao;

  { Tamanho e miniatura sao lidos antes do item entrar na lista, para que o
    primeiro desenho ja mostre a imagem e as medidas certas. O item ainda
    nao esta na fila, entao um item invalido aqui simplesmente nao entra,
    sem restar numero ou deixar residuo. }
  if TImageInfoService.LerDimensoes(C, W, H) then
  begin
    Result.DefinirDimensoesOrigem(W, H);
    Result.AtribuirMiniatura(
      TThumbnailServiceImagem.DoArquivo(C, LARGURA_THUMB_IMAGEM,
        ALTURA_THUMB_IMAGEM));
  end;

  FItens.Add(Result);
  Renumerar;
  AvisarAlteracao;
end;

procedure TFilaImagens.AdicionarLista(const AArquivos: TStrings);
var
  i: Integer;
begin
  for i := 0 to AArquivos.Count - 1 do
    AdicionarArquivo(AArquivos[i]);
end;

function TFilaImagens.AdicionarPasta(const APasta: string;
  const AFiltro: string): Integer;
var
  SR: TSearchRec;
  Total: Integer;
begin
  Result := 0;
  if not DirectoryExists(APasta) then
    Exit;
  Total := FindFirst(IncludeTrailingPathDelimiter(APasta) + AFiltro,
    faAnyFile - faDirectory, SR);
  if Total = 0 then
    Exit;
  try
    repeat
      if AdicionarArquivo(IncludeTrailingPathDelimiter(APasta) + SR.Name) <> nil
      then
        Inc(Result);
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

procedure TFilaImagens.Remover(AItem: TItemImagem);
var
  Pos: Integer;
begin
  Pos := IndiceInterno(AItem);
  if Pos < 0 then
    Exit;
  { Um item em andamento nao pode sumir da lista enquanto o processo
    trabalha nele: o runner ainda precisa da referencia. }
  if AItem.Status = isiProcessando then
    Exit;
  FSelecionado := nil;
  FItens.Delete(Pos);
  AItem.Free;
  Renumerar;
  AvisarAlteracao;
end;

procedure TFilaImagens.Mover(AItem: TItemImagem; AParaPosicao: Integer);
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

procedure TFilaImagens.Limpar;
var
  i: Integer;
begin
  for i := FItens.Count - 1 downto 0 do
    TItemImagem(FItens[i]).Free;
  FItens.Clear;
  FSelecionado := nil;
  Renumerar;
  AvisarAlteracao;
end;

function TFilaImagens.QtItens: Integer;
begin
  Result := FItens.Count;
end;

function TFilaImagens.QtPendentes: Integer;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to FItens.Count - 1 do
    if TItemImagem(FItens[i]).Status = isiAguardando then
      Inc(Result);
end;

function TFilaImagens.QtConcluidos: Integer;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to FItens.Count - 1 do
    if TItemImagem(FItens[i]).Status = isiConcluido then
      Inc(Result);
end;

function TFilaImagens.QtComErro: Integer;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to FItens.Count - 1 do
    if TItemImagem(FItens[i]).Status = isiErro then
      Inc(Result);
end;

function TFilaImagens.Item(AIndice: Integer): TItemImagem;
begin
  if (AIndice < 0) or (AIndice >= FItens.Count) then
  begin
    Result := nil;
    Exit;
  end;
  Result := TItemImagem(FItens[AIndice]);
end;

function TFilaImagens.ContidoEm(AItem: TItemImagem): Boolean;
begin
  Result := IndiceInterno(AItem) >= 0;
end;

function TFilaImagens.PrimeiroPendente: TItemImagem;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to FItens.Count - 1 do
    if TItemImagem(FItens[i]).Status = isiAguardando then
      Exit(TItemImagem(FItens[i]));
end;

function TFilaImagens.PastaDeDestino(AItem: TItemImagem): string;
begin
  Result := '';
  if AItem = nil then
    Exit;
  if AItem.UsarPastaPadrao then
    Result := FPastaPadrao
  else
    Result := AItem.PastaDestino;
  { Sem pasta definida em nenhum lugar, gravar ao lado do original e o
    que evita perda de trabalho e mantem o item utilizavel sem exigir
    que o usuario escolha um destino antes de comecar. }
  if Result = '' then
    Result := AItem.PastaOrigem;
end;

procedure TFilaImagens.AplicarPadraoATodos;
var
  i: Integer;
  PorItem: TItemImagem;
begin
  { O nome Item colide com o metodo Item da classe quando o compilador
    resolve a variavel no mesmo escopo; PorItem evita a ambiguidade. }
  for i := 0 to FItens.Count - 1 do
  begin
    PorItem := TItemImagem(FItens[i]);
    if not PorItem.UsarPastaPadrao then
      Continue;
    PorItem.PastaDestino := FPastaPadrao;
  end;
  AvisarAlteracao;
end;

function TFilaImagens.ContidoEmPorArquivo(const AArquivo: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to FItens.Count - 1 do
    if TItemImagem(FItens[i]).Arquivo = AArquivo then
      Exit(True);
end;

{ TThumbnailServiceImagem }

class function TThumbnailServiceImagem.DoArquivo(const AArquivo: string;
  AWidth, AHeight: Integer): TBitmap;
var
  Destino: string;
  Exe: string;
  Args: TStringList;
  Proc: TProcessoGerenciado;
begin
  Result := nil;
  if (AArquivo = '') or (not FileExists(AArquivo)) then
    Exit;

  Exe := TGerenciadorDependencias.Caminho(depImageMagick);
  if Exe = '' then
    Exit;

  { Converter para um BMP pequeno e temporario em vez de tentar abrir o
    arquivo direto resolve dois problemas: o LCL desta instalacao so le
    BMP com seguranca e nao decodifica PNG, WebP, AVIF nem HEIC; e a
    miniatura sai sempre no tamanho exato pedido, sem depender das
    proporcoes do original. E o mesmo caminho ja usado pela fila de
    video, que converte a miniatura do yt-dlp antes de carregar. }
  Destino := IncludeTrailingPathDelimiter(GetTempDir) +
             'syn_img_' + IntToStr(GetProcessID) + '_' +
             FormatDateTime('hhnnsszzz', Now) + '.bmp';

  Args := TStringList.Create;
  Proc := TProcessoGerenciado.Create;
  try
    Args.Add(AArquivo);
    Args.Add('-thumbnail');
    Args.Add(Format('%dx%d', [AWidth, AHeight]));
    Args.Add('-background');
    Args.Add('none');
    Args.Add('-alpha');
    Args.Add('background');
    Args.Add(Destino);

    if not Proc.Iniciar(Exe, Args, nil, False) then
      Exit;
    { -thumbnail e rapido, mas nao instantaneo em arquivo grande. O limite
      generoso evita que uma imagem patologica trave a fila; ao estourar o
      processo e encerrado e o item fica sem miniatura, o que e melhor do
      que a interface parar de responder. }
    if not Proc.Aguardar(30000) then
    begin
      Proc.Encerrar(encForcar);
      Exit;
    end;
  finally
    Proc.Free;
    Args.Free;
  end;

  if not FileExists(Destino) then
    Exit;

  Result := TBitmap.Create;
  try
    Result.LoadFromFile(Destino);
  except
    Result.Free;
    Result := nil;
  end;
  DeleteFile(Destino);
end;

{ TImageInfoService }

class function TImageInfoService.LerDimensoes(const AArquivo: string;
  out AWidth, AHeight: Integer): Boolean;
var
  Exe: string;
  Args: TStringList;
  Proc: TProcessoGerenciado;
  Saida: string;
  Partes: TStringList;
begin
  AWidth  := 0;
  AHeight := 0;
  Result  := False;
  if (AArquivo = '') or (not FileExists(AArquivo)) then
    Exit;

  Exe := TGerenciadorDependencias.Caminho(depImageMagick);
  if Exe = '' then
    Exit;

  Args := TStringList.Create;
  Proc := TProcessoGerenciado.Create;
  try
    { -ping le o cabecalho sem decodificar os pixels: e o que torna este
      passo barato mesmo para um RAW de 50 MB. }
    Args.Add('identify');
    Args.Add('-ping');
    Args.Add('-format');
    Args.Add('%w %h');
    Args.Add(AArquivo);

    { Redirecionar e obrigatorio aqui: as dimensoes voltam pela saida do
    comando, e sem poUsePipes o processo escreveria direto no console e
    LerTudo nao teria o que ler. }
    if not Proc.Iniciar(Exe, Args, nil, True) then
      Exit;
    if not Proc.Aguardar(15000) then
    begin
      Proc.Encerrar(encForcar);
      Exit;
    end;
    if Proc.CodigoSaida <> 0 then
      Exit;

    Saida := Trim(Proc.LerTudo);
  finally
    Proc.Free;
    Args.Free;
  end;

  { A saida e "largura altura", sem nenhuma quebra, porque -format substitui
    o relatorio inteiro. Separar por espaco toleraria o traco que o
    ImageMagick emite quando o arquivo tem varios quadros. }
  Partes := TStringList.Create;
  try
    Partes.Delimiter := ' ';
    Partes.StrictDelimiter := True;
    Partes.DelimitedText := Saida;
    if Partes.Count < 2 then
      Exit;
    AWidth  := StrToIntDef(Partes[0], 0);
    AHeight := StrToIntDef(Partes[1], 0);
    Result := (AWidth > 0) and (AHeight > 0);
  finally
    Partes.Free;
  end;
end;

end.