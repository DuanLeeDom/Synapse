unit uVideoQueueView;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, StdCtrls, ExtCtrls,
  Buttons, ComCtrls, Dialogs, LCLIntf, uVideoQueue, uQueuePool;

type
  TfrVideoQueue = class;

  { TThumbPoolTask
    Miniatura de um item da fila entregue ao TQueuePool. O worker roda
    Executar dentro da própria thread, gerando um BMP temporário e, no
    caso de URL, descobrindo também o título; a interface lê os campos
    SaidaBMP/Titulo quando a tarefa volta pela lista de concluídos.
    Item nunca é tocado pelo worker; SaidaBMP/Titulo são escritos por ele
    e lidos na main thread, nunca ao mesmo tempo. }
  TThumbPoolTask = class(TPoolTask)
  public
    Item    : TVideoQueueItem;
    EhURL   : Boolean;
    Origem  : string;
    Sufixo  : string;
    Largura : Integer;
    Altura  : Integer;
    SaidaBMP: string;
    Titulo  : string;
    procedure Executar; override;
  end;

  { TThumbPanel
    Moldura da miniatura: fundo fixo e borda discreta com cantos
    arredondados, desenhada no Paint para não depender de estilos
    nativos de bevel. }
  TThumbPanel = class(TPanel)
  protected
    procedure Paint; override;
  public
    Raio     : Integer;
    CorBorda : TColor;
    constructor Create(AOwner: TComponent); override;
  end;

  { TVideoQueueItemView
    Painel visual de um item da fila. Layout da esquerda para a direita:
    coluna de status (selo + mensagem), botão X de remoção, miniatura,
    informações (título, origem, destino, formatos, download) e a alça
    de expandir na borda direita; a barra de progresso ocupa a base. Cada
    instância recebe um Name próprio — todos os painéis pertencem ao
    mesmo owner (o frame da fila), portanto nomes fixos como 'ItemFila'
    provocariam EComponentError ao adicionar o segundo vídeo. Nenhum
    painel pode exibir a própria Caption: por padrão o TPanel mostra o
    Name como texto, e era isso que vazava identificadores internos como
    "ItemFila5_Texto" na interface. }
  TVideoQueueItemView = class(TPanel)
  private
    FItem        : TVideoQueueItem;
    FSelecionado : Boolean;
    FQuadro      : TObject;
    FPosicaoMouse: TPoint;
    FPressionado : Boolean;
    FBloqueado   : Boolean;
    FExpandido   : Boolean;

pnl_thumb    : TThumbPanel;
  img_thumb    : TImage;
  pnl_info     : TPanel;
    lbl_titulo   : TLabel;
    lbl_origem   : TLabel;
    lbl_destino  : TLabel;
    lbl_formatos : TLabel;
    lbl_download : TLabel;
    pbar_item    : TProgressBar;
    pnl_status   : TPanel;
    pnl_badge    : TPanel;
    lbl_status   : TLabel;
    lbl_mensagem : TLabel;
    btn_remover  : TSpeedButton;
    btn_expandir : TSpeedButton;

    procedure Montar;
    function  NovoPainel(APai: TWinControl; const ANome: string;
                         AAlinhar: TAlign): TPanel;
    { Os eventos de mouse ficam protegidos em TControl e só aparecem
      republicados nas classes concretas, por isso os três overloads. }
    procedure RepassarMouse(AControle: TPanel); overload;
    procedure RepassarMouse(AControle: TLabel); overload;
    procedure RepassarMouse(AControle: TImage); overload;
    procedure ItemMouseDown(Sender: TObject; Button: TMouseButton;
                            Shift: TShiftState; X, Y: Integer);
    procedure ItemMouseMove(Sender: TObject; Shift: TShiftState;
                            X, Y: Integer);
    procedure ItemMouseUp(Sender: TObject; Button: TMouseButton;
                          Shift: TShiftState; X, Y: Integer);
    procedure BtnRemoverClick(Sender: TObject);
    procedure BtnExpandirClick(Sender: TObject);
    procedure ItemDblClick(Sender: TObject);
    procedure AtualizarVisual;
    procedure AplicarAlturaExpandida;
    function  Quadro: TfrVideoQueue;
    function  Truncar(const ATexto: string; AMaxChars: Integer): string;
    function  MensagemCompacta(const ATexto: string): string;
  public
    constructor Create(AOwner: TComponent; AQuadro: TObject); reintroduce;
    destructor Destroy; override;

    procedure Atualizar;
    procedure SetSelecionado(AValor: Boolean);
    procedure SetBloqueado(AValor: Boolean);

property Item        : TVideoQueueItem read FItem write FItem;
    property Selecionado : Boolean read FSelecionado;
    property Bloqueado   : Boolean read FBloqueado write SetBloqueado;

    { Exposta só para os testes automatizados confirmarem a cor aplicada. }
    function CorDoPainelDeTextos: TColor;
  end;

  { TfrVideoQueue
    Área de interface da fila: hospeda um painel por vídeo adicionado,
    mantém cada um atualizado conforme o pipeline avança e permite
    remover itens individualmente e reordenar a fila arrastando. }
  TfrVideoQueue = class(TFrame)
    sb_itens: TScrollBox;
    lbl_vazio: TLabel;
    procedure FrameResize(Sender: TObject);
    procedure TimerMiniaturasTimer(Sender: TObject);
  private
FFila       : TVideoQueue;
    FViews      : TList;
    FSelecionado: TVideoQueueItemView;
    FTimer      : TTimer;
    FPool       : TQueuePool;
    FProcessando: Boolean;
    pnl_marcador: TPanel;

    FArrastando  : Boolean;
    FItemArrasto : TVideoQueueItem;
    FIndiceDestino: Integer;

procedure FilaAlterou(Sender: TObject);
    procedure Selecionar(AView: TVideoQueueItemView);
    procedure RemoverItem(AItem: TVideoQueueItem);
    procedure ProcessarConcluidos;
    procedure AplicarMiniatura(ATarefa: TThumbPoolTask);
    procedure LargurarItens;
    procedure ReaplicarOrdem(AInicio: Integer);
    procedure MostrarMarcador(APosicao: Integer);
    procedure EsconderMarcador;
    function  MouseNoScrollBox: TPoint;
    function  IndiceDestinoEmY(AY: Integer): Integer;
    function  ViewForaDoArraste(APosicao: Integer): TVideoQueueItemView;
    function  PrimeiroDesalinhado: Integer;
    function  ViewDe(AItem: TVideoQueueItem): TVideoQueueItemView;
    function  ContidoNaFila(AItem: TVideoQueueItem): Boolean;
    function  GetSelecionado: TVideoQueueItem;
    procedure AplicarNovosItens(AInicio: Integer);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

function  Adicionar(const AOrigem: string): TVideoQueueItem;
    function  AdicionarArquivos(const AArquivos: TStrings): Integer;
    function  AdicionarURLs(const AURLs: TStrings): Integer;
    function  AdicionarVarias(const ALista: TStrings): Integer;
    procedure EnfileirarMiniatura(AItem: TVideoQueueItem;
                                  const AArquivo: string);
    procedure EnfileirarMiniaturaURL(AItem: TVideoQueueItem;
                                     const AURL: string);
    procedure RemoverSelecionado;
    procedure RemoverItemPublico(AItem: TVideoQueueItem);
    procedure RemoverFinalizados;
    procedure LimparTudo;
    procedure AtualizarItem(AItem: TVideoQueueItem);

    { Exposta só para os testes: entrega uma tarefa de miniatura já
      concluída pelo mesmo caminho que o timer usa. }
    procedure AplicarMiniaturaPublico(ATarefa: TThumbPoolTask);
    procedure AtualizarGeral;
    procedure AbrirPasta(const APasta: string);
    procedure AbrirItemDblClick(Sender: TObject);
    procedure SelecionarItem(AItem: TVideoQueueItem);

    { Usadas pelo painel do item durante o arraste. }
    procedure IniciarArrasto(AItem: TVideoQueueItem);
    procedure MoverMarcador;
    procedure ConcluirArrasto;

    function  QtItens: Integer;
    procedure SetProcessando(AValor: Boolean);

    property Fila        : TVideoQueue read FFila;
    property Selecionado  : TVideoQueueItem read GetSelecionado;
    property Processando : Boolean read FProcessando write SetProcessando;
    property Arrastando  : Boolean read FArrastando;
  end;

var
  frVideoQueue: TfrVideoQueue;

  { Sequência monotônica de nomes: os painéis da fila compartilham o mesmo
    owner, então cada um precisa de um Name próprio. Fica no nível da unit
    para não se reiniciar quando o frame é recriado ao trocar de tela. }
  FSequenciaItem: Integer;

implementation

{$R *.lfm}

const
  { Altura compacta do item: cinco linhas curtas dentro de 80 px, para
    exibir vários vídeos ao mesmo tempo sem perder nenhuma informação.
    Expandido, a mesma pilha cresce para 136 px e os rótulos passam a
    quebrar linha. A barra de progresso ocupa 6 px na base quando visível;
    as contas consideram as duas situações. }
  ALTURA_ITEM        = 80;
  ALTURA_ITEM_EXP    = 136;
  LARGURA_THUMB      = 96;
  MARGEM_THUMB       = 5;
  LARGURA_STATUS     = 140;
  LARGURA_BOTAO      = 24;
  LARGURA_EXPANDIR   = 16;

  ALTURA_TITULO      = 17;
  ALTURA_TITULO_EXP  = 32;
  ALTURA_LINHA       = 13;
  ALTURA_LINHA_EXP   = 24;
  ALTURA_DETALHE_EXP = 21;
  ALTURA_BARRA       = 6;
  ALTURA_BADGE       = 20;

  { Miniaturas são geradas no dobro do tamanho exibido para o
    redimensionamento ficar nítido em telas de alta densidade. }
  LARGURA_THUMB_BIT = (LARGURA_THUMB - (MARGEM_THUMB * 2)) * 2;
  ALTURA_THUMB_BIT  = (ALTURA_ITEM - (MARGEM_THUMB * 2)) * 2;

{ Cores fixas escritas como literal inteiro na ordem
    R + G*256 + B*65536 (a mesma de RGBToColor). Um initializer de const
    precisa ser resolvido em tempo de compilação, então não dá para usar
    RGBToColor aqui.

    O literal tem de conter as três parcelas: um valor pequeno como 245
    decodifica para R=245, G=0, B=0 — vermelho puro — e pintava o item
    inteiro de vermelho ao ser criado. Para gerar outro tom, use
    R + (G*256) + (B*65536) e confira o resultado. }
  COR_ITEM          = 15790320;  { 240,240,240 }
  COR_ITEM_SEL      = 16442062;  { 206,226,250 }
  COR_TEXTO         = clBtnFace;
  COR_BORDA_THUMB   = 9207928;   { 120,128,140 }
  COR_FUNDO_THUMB   = 3158064;   {  48, 48, 48 }
  COR_MARCADOR      = 14120960;  {   0,120,215 }

{ TThumbPanel }

constructor TThumbPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Raio     := 6;
  CorBorda := COR_BORDA_THUMB;
end;

procedure TThumbPanel.Paint;
begin
  inherited;
  { O TPanel pinta o fundo; aqui só entra o contorno arredondado. }
  Canvas.Brush.Style := bsClear;
  Canvas.Pen.Style   := psSolid;
  Canvas.Pen.Color   := CorBorda;
  Canvas.Pen.Width   := 1;
  Canvas.RoundRect(0, 0, Width, Height, Raio, Raio);
end;

{ TVideoQueueItemView }

constructor TVideoQueueItemView.Create(AOwner: TComponent; AQuadro: TObject);
begin
  inherited Create(AOwner);
  FQuadro := AQuadro;
  Montar;
end;

destructor TVideoQueueItemView.Destroy;
begin
  FQuadro := nil;
  FItem := nil;
  inherited Destroy;
end;

function TVideoQueueItemView.Quadro: TfrVideoQueue;
begin
  Result := nil;
  if Assigned(FQuadro) then
    Result := TfrVideoQueue(FQuadro);
end;

function TVideoQueueItemView.Truncar(const ATexto: string;
                                    AMaxChars: Integer): string;
begin
  if Length(ATexto) <= AMaxChars then
    Result := ATexto
  else
    Result := Copy(ATexto, 1, AMaxChars - 3) + '...';
end;

{ A coluna de status tem largura fixa: a mensagem do item é quebrada em
  até duas linhas curtas para nunca invadir as informações vizinhas. }
function TVideoQueueItemView.MensagemCompacta(const ATexto: string): string;
var
  Linha: string;
begin
  Linha := StringReplace(Trim(ATexto), LineEnding, ' ', [rfReplaceAll]);
  if Linha = '' then
    Exit('');

  if Length(Linha) <= 24 then
    Exit(Linha);

  Result := Copy(Linha, 1, 23) + '...';
  if Pos(' ', Copy(Linha, 24, Length(Linha) - 23)) > 0 then
    Result := Copy(Linha, 1, 22);
end;

{ Todo painel nasce sem Caption visível: é o que impedia que nomes
  internos como "ItemFila5_Texto" aparecessem na interface. }
function TVideoQueueItemView.NovoPainel(APai: TWinControl;
  const ANome: string; AAlinhar: TAlign): TPanel;
begin
  Result := TPanel.Create(Self);
  Result.Name        := ANome;
  Result.Caption     := '';
  Result.Parent      := APai;
  Result.Align       := AAlinhar;
  Result.BevelOuter  := bvNone;
  Result.Color       := COR_TEXTO;
end;

{ Os rótulos e a miniatura ficariam "furos" para o mouse, impedindo o
  arraste; por isso repassam os eventos do item. Os dois botões ficam
  de fora para não iniciar um arraste ao serem clicados. }
procedure TVideoQueueItemView.RepassarMouse(AControle: TPanel);
begin
  AControle.OnMouseDown := @ItemMouseDown;
  AControle.OnMouseMove := @ItemMouseMove;
  AControle.OnMouseUp   := @ItemMouseUp;
  AControle.OnDblClick  := @ItemDblClick;
end;

procedure TVideoQueueItemView.RepassarMouse(AControle: TLabel);
begin
  AControle.OnMouseDown := @ItemMouseDown;
  AControle.OnMouseMove := @ItemMouseMove;
  AControle.OnMouseUp   := @ItemMouseUp;
  AControle.OnDblClick  := @ItemDblClick;
end;

procedure TVideoQueueItemView.RepassarMouse(AControle: TImage);
begin
  AControle.OnMouseDown := @ItemMouseDown;
  AControle.OnMouseMove := @ItemMouseMove;
  AControle.OnMouseUp   := @ItemMouseUp;
  AControle.OnDblClick  := @ItemDblClick;
end;

procedure TVideoQueueItemView.Montar;
var
  Prefixo: string;
begin
  Inc(FSequenciaItem);
  Prefixo := 'ItemFila' + IntToStr(FSequenciaItem) + '_';
  Name   := Copy(Prefixo, 1, Length(Prefixo) - 1);

  { Layout do item, da esquerda para a direita:
      [status][X][miniatura][informações][expandir]
    e a barra de progresso de largura inteira na base. O status fica numa
    coluna fixa à esquerda para nunca ser empurrado ou cortado pelas
    informações; o texto vive no meio (alClient) e a miniatura ocupa a
    moldura à esquerda do X.

    Atenção: no LCL o alinhamento empilha os filhos de mesmo Align na
    ordem INVERSA da criação (último criado = topo em alTop e esquerda em
    alLeft), e a ordem de resolução dos Align é alTop, alBottom, alLeft,
    alRight, alClient — por isso os blocos abaixo são construídos de baixo
    para cima e as colunas são criadas ao contrário da ordem visual.
    Recolhido, cada rótulo traz o texto truncado com reticências e o Hint
    guarda o texto inteiro; o botão da borda direita expande o item para
    quebrar as linhas e mostrar tudo. }
  Height      := ALTURA_ITEM;
  Align       := alTop;   { alLeft empilharia os itens lado a lado }
  ParentColor := False;
  Color       := COR_ITEM;
  BevelOuter  := bvLowered;
  BorderSpacing.Around := 1;
  Caption     := '';
  Cursor      := crDefault;
  OnMouseDown := @ItemMouseDown;
  OnMouseMove := @ItemMouseMove;
  OnMouseUp   := @ItemMouseUp;
  OnDblClick  := @ItemDblClick;

  { --- informações, criadas de baixo para cima: o título é o último,
       portanto fica no topo da coluna --- }
  pnl_info := NovoPainel(Self, Prefixo + 'Textos', alClient);
  pnl_info.Color := COR_ITEM;

  { --- barra de progresso na base, de largura inteira (alBottom é
       resolvido antes dos alLeft, então as colunas ficam acima dela e
       a barra desaparece da conta quando invisível) --- }
  pbar_item := TProgressBar.Create(Self);
  pbar_item.Name      := Prefixo + 'Progresso';
  pbar_item.Parent    := Self;
  pbar_item.Align     := alBottom;
  pbar_item.Height    := ALTURA_BARRA;
  pbar_item.Min       := 0;
  pbar_item.Max       := 100;
  pbar_item.Position  := 0;
  pbar_item.Style     := pbstNormal;
  pbar_item.Visible   := False;

  lbl_download := TLabel.Create(Self);
  lbl_download.Name         := Prefixo + 'Download';
  lbl_download.Parent      := pnl_info;
  lbl_download.Align       := alTop;
  lbl_download.Height      := ALTURA_LINHA;
  lbl_download.AutoSize    := False;
  lbl_download.Layout      := tlCenter;
  lbl_download.Font.Size   := 8;
  lbl_download.Font.Color  := clGray;
  lbl_download.Transparent := True;

  lbl_formatos := TLabel.Create(Self);
  lbl_formatos.Name         := Prefixo + 'Formatos';
  lbl_formatos.Parent      := pnl_info;
  lbl_formatos.Align       := alTop;
  lbl_formatos.Height      := ALTURA_LINHA;
  lbl_formatos.AutoSize    := False;
  lbl_formatos.Layout      := tlCenter;
  lbl_formatos.Font.Size   := 8;
  lbl_formatos.Font.Color  := clGray;
  lbl_formatos.Transparent := True;

  { linha separada de destino: antes ela só aparecia no Hint do resumo do
    download, e o usuário quer ver a pasta de saída sem precisar passar o
    mouse. Criada antes da origem para ficar abaixo dela na pilha. }
  lbl_destino := TLabel.Create(Self);
  lbl_destino.Name         := Prefixo + 'Destino';
  lbl_destino.Parent      := pnl_info;
  lbl_destino.Align       := alTop;
  lbl_destino.Height      := ALTURA_LINHA;
  lbl_destino.AutoSize    := False;
  lbl_destino.Layout      := tlCenter;
  lbl_destino.Font.Size   := 8;
  lbl_destino.Font.Color  := RGBToColor(80, 80, 80);
  lbl_destino.Transparent := True;

  lbl_origem := TLabel.Create(Self);
  lbl_origem.Name         := Prefixo + 'Origem';
  lbl_origem.Parent      := pnl_info;
  lbl_origem.Align       := alTop;
  lbl_origem.Height      := ALTURA_LINHA;
  lbl_origem.AutoSize    := False;
  lbl_origem.Layout      := tlCenter;
  lbl_origem.Font.Size   := 8;
  lbl_origem.Font.Color  := RGBToColor(70, 100, 160);
  lbl_origem.Transparent := True;

  lbl_titulo := TLabel.Create(Self);
  lbl_titulo.Name         := Prefixo + 'Titulo';
  lbl_titulo.Parent      := pnl_info;
  lbl_titulo.Align       := alTop;
  lbl_titulo.Height      := ALTURA_TITULO;
  lbl_titulo.AutoSize    := False;
  lbl_titulo.Layout      := tlCenter;
  lbl_titulo.Font.Style  := [fsBold];
  lbl_titulo.Font.Size   := 9;
  lbl_titulo.Transparent := True;

  { --- miniatura: área fixa, borda arredondada e proporção mantida.
       É o primeiro alLeft criado, portanto o que fica mais à direita
       da pilha de colunas. --- }
  pnl_thumb := TThumbPanel.Create(Self);
  pnl_thumb.Name       := Prefixo + 'Moldura';
  pnl_thumb.Caption    := '';
  pnl_thumb.Parent     := Self;
  pnl_thumb.Align      := alLeft;
  pnl_thumb.Width      := LARGURA_THUMB;
  pnl_thumb.Color      := COR_FUNDO_THUMB;

  img_thumb := TImage.Create(Self);
  img_thumb.Name         := Prefixo + 'Thumb';
  img_thumb.Parent       := pnl_thumb;
  img_thumb.Align        := alClient;
  img_thumb.AutoSize     := False;
  img_thumb.Proportional := True;   { mantém a proporção original }
  img_thumb.Stretch      := False;  { nunca deforma nem invade a moldura }
  img_thumb.Transparent  := False;
  img_thumb.Color        := COR_FUNDO_THUMB;
  img_thumb.BorderSpacing.Around := MARGEM_THUMB;

  { --- remoção individual, entre a miniatura e o status --- }
  btn_remover := TSpeedButton.Create(Self);
  btn_remover.Name         := Prefixo + 'Remover';
  btn_remover.Parent       := Self;
  btn_remover.Align        := alLeft;
  btn_remover.Width        := LARGURA_BOTAO;
  btn_remover.Caption      := 'X';
  btn_remover.Flat         := True;
  btn_remover.Font.Size    := 9;
  btn_remover.Font.Style   := [fsBold];
  btn_remover.Color        := clBtnFace;
  btn_remover.OnClick      := @BtnRemoverClick;
  btn_remover.Hint         := 'Remover este vídeo da fila';

  { --- status na ponta esquerda: sendo o último alLeft criado, é o que
       fica mais à esquerda. Coluna de largura fixa, com o selo do estado
       no topo e a mensagem embaixo — nunca é empurrado pelas
       informações, que começam depois da miniatura. --- }
  pnl_status := NovoPainel(Self, Prefixo + 'Status', alLeft);
  pnl_status.Width      := LARGURA_STATUS;
  pnl_status.BevelOuter := bvLowered;
  pnl_status.Color      := RGBToColor(232, 232, 232);
  pnl_status.Cursor     := crSizeAll;
  pnl_status.Hint       := 'Arraste para reordenar a fila';

  pnl_badge := NovoPainel(pnl_status, Prefixo + 'Selo', alTop);
  pnl_badge.Height := ALTURA_BADGE;
  pnl_badge.Color  := RGBToColor(228, 228, 228);

  lbl_mensagem := TLabel.Create(Self);
  lbl_mensagem.Name         := Prefixo + 'Mensagem';
  lbl_mensagem.Parent      := pnl_status;
  lbl_mensagem.Align       := alClient;
  lbl_mensagem.AutoSize    := False;
  lbl_mensagem.Layout      := tlCenter;
  lbl_mensagem.Alignment   := taCenter;
  lbl_mensagem.Font.Size   := 8;
  lbl_mensagem.Transparent := True;

  lbl_status := TLabel.Create(Self);
  lbl_status.Name         := Prefixo + 'Estado';
  lbl_status.Parent      := pnl_badge;
  lbl_status.Align       := alClient;
  lbl_status.AutoSize    := False;
  lbl_status.Layout      := tlCenter;
  lbl_status.Alignment   := taCenter;
  lbl_status.Font.Style  := [fsBold];
  lbl_status.Font.Size   := 9;
  lbl_status.Font.Color  := clBlack;

  { --- alça de expansão na borda direita (alRight é resolvido antes do
       alClient, então ocupa a tira à direita das informações) --- }
  btn_expandir := TSpeedButton.Create(Self);
  btn_expandir.Name       := Prefixo + 'Expandir';
  btn_expandir.Parent     := Self;
  btn_expandir.Align      := alRight;
  btn_expandir.Width      := LARGURA_EXPANDIR;
  btn_expandir.Caption    := '+';
  btn_expandir.Flat       := True;
  btn_expandir.Font.Size  := 9;
  btn_expandir.Font.Style := [fsBold];
  btn_expandir.Color      := clBtnFace;
  btn_expandir.OnClick    := @BtnExpandirClick;
  btn_expandir.Hint       := 'Expandir os detalhes do item';

  RepassarMouse(pnl_info);
  RepassarMouse(lbl_titulo);
  RepassarMouse(lbl_origem);
  RepassarMouse(lbl_destino);
  RepassarMouse(lbl_formatos);
  RepassarMouse(lbl_download);
  RepassarMouse(pnl_thumb);
  RepassarMouse(img_thumb);
  RepassarMouse(pnl_status);
  RepassarMouse(pnl_badge);
  RepassarMouse(lbl_status);
  RepassarMouse(lbl_mensagem);
end;

procedure TVideoQueueItemView.Atualizar;
var
  Texto, Origem, Destino, RotuloDestino: string;
begin
  if not Assigned(FItem) then
    Exit;

  Texto := FItem.Titulo;
  if FItem.OrigemLocal then
    Texto := Texto + FItem.ExtensaoOrigem;

  if FItem.OrigemLocal then
    Origem := 'Arquivo: ' + ExtractFileName(FItem.ArquivoLocal)
  else
    Origem := 'URL: ' + FItem.URL;

  if FItem.PastaDestino <> '' then
    Destino := FItem.PastaDestino
  else if FItem.ResumoDestino <> '' then
    Destino := ExtractFileDir(FItem.ResumoDestino)
  else
    Destino := '';

  if Destino <> '' then
    RotuloDestino := 'Destino: ' + Destino
  else
    RotuloDestino := 'Destino: (a definir)';

  { Recolhido, cada linha é truncada com reticências e o Hint guarda o
    texto inteiro; expandido, o texto corre inteiro porque os rótulos
    quebram linha. O número da fila entra no título porque a coluna de
    índice foi retirada do layout. }
  if FExpandido then
  begin
    lbl_titulo.Caption   := IntToStr(FItem.Indice) + '. ' + Texto;
    lbl_origem.Caption   := Origem;
    lbl_destino.Caption  := RotuloDestino;
    lbl_formatos.Caption := FItem.ResumoFormatos;
    lbl_download.Caption := FItem.ResumoDownload;
  end
  else
  begin
    lbl_titulo.Caption   := IntToStr(FItem.Indice) + '. ' + Truncar(Texto, 68);
    lbl_origem.Caption   := Truncar(Origem, 74);
    lbl_destino.Caption  := Truncar(RotuloDestino, 74);
    lbl_formatos.Caption := Truncar(FItem.ResumoFormatos, 74);
    lbl_download.Caption := Truncar(FItem.ResumoDownload, 74);
  end;

  lbl_titulo.Hint      := Texto;
  lbl_origem.Hint      := Origem;
  lbl_destino.Hint     := RotuloDestino;
  lbl_formatos.Hint    := FItem.ResumoFormatos;
  lbl_download.Hint    := FItem.ResumoDownload + LineEnding +
                          RotuloDestino;

  lbl_status.Caption   := FItem.StatusTexto;

  pbar_item.Position := FItem.Progresso;
  pbar_item.Visible  := (FItem.Status = vqsProcessando);

  if FItem.Miniatura <> nil then
    img_thumb.Picture.Assign(FItem.Miniatura)
  else
    img_thumb.Picture.Clear;

  case FItem.Status of
    vqsAguardando:
    begin
      lbl_status.Font.Color  := RGBToColor(70, 70, 70);
      pnl_badge.Color        := RGBToColor(228, 228, 228);
      lbl_mensagem.Font.Color := RGBToColor(90, 90, 90);
    end;
    vqsProcessando:
    begin
      lbl_status.Font.Color  := RGBToColor(20, 52, 120);
      pnl_badge.Color        := RGBToColor(212, 226, 250);
      lbl_mensagem.Font.Color := RGBToColor(20, 70, 170);
    end;
    vqsConcluido:
    begin
      lbl_status.Font.Color  := RGBToColor(20, 96, 32);
      pnl_badge.Color        := RGBToColor(214, 240, 216);
      lbl_mensagem.Font.Color := RGBToColor(20, 96, 32);
    end;
    vqsErro:
    begin
      lbl_status.Font.Color  := RGBToColor(140, 16, 16);
      pnl_badge.Color        := RGBToColor(250, 214, 214);
      lbl_mensagem.Font.Color := RGBToColor(160, 24, 24);
    end;
    vqsCancelado:
    begin
      lbl_status.Font.Color  := RGBToColor(140, 82, 12);
      pnl_badge.Color        := RGBToColor(248, 234, 206);
      lbl_mensagem.Font.Color := RGBToColor(150, 96, 16);
    end;
  end;

  case FItem.Status of
    vqsConcluido:
      lbl_mensagem.Caption := 'Salvo em ' + Truncar(ExtractFileName(FItem.ResumoDestino), 24);
    else
      lbl_mensagem.Caption := MensagemCompacta(FItem.Mensagem);
  end;
  lbl_mensagem.Hint := FItem.Mensagem;

  btn_remover.Enabled := not FBloqueado;
  AtualizarVisual;
end;

procedure TVideoQueueItemView.SetBloqueado(AValor: Boolean);
begin
  if FBloqueado = AValor then
    Exit;
  FBloqueado := AValor;
  if Assigned(btn_remover) then
  begin
    btn_remover.Enabled := not FBloqueado;
    { A alça de arraste é a coluna de status: com a fila em processamento
      ela perde o cursor de mover, como o item inteiro. }
    if FBloqueado then
      pnl_status.Cursor := crDefault
    else
      pnl_status.Cursor := crSizeAll;
    Cursor := crDefault;
  end;
end;

function TVideoQueueItemView.CorDoPainelDeTextos: TColor;
begin
  Result := pnl_info.Color;
end;

procedure TVideoQueueItemView.AtualizarVisual;
begin
  if FSelecionado then
  begin
    Color       := COR_ITEM_SEL;
    pnl_info.Color := COR_ITEM_SEL;
  end
  else
  begin
    Color           := COR_ITEM;
    pnl_info.Color  := COR_ITEM;
  end;
end;

procedure TVideoQueueItemView.SetSelecionado(AValor: Boolean);
begin
  FSelecionado := AValor;
  AtualizarVisual;
end;

procedure TVideoQueueItemView.ItemMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  FPressionado  := (Button = mbLeft);
  FPosicaoMouse := Point(X, Y);

  if Assigned(FItem) and Assigned(Quadro) then
    Quadro.SelecionarItem(FItem);

  if FPressionado then
    SetCaptureControl(Self);
end;

{ Arrastar é feito manualmente sobre o painel: evita depender da
  implementação de drag-and-drop do widgetset e dá controle exato sobre
  a posição de inserção. }
procedure TVideoQueueItemView.ItemMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
var
  Q: TfrVideoQueue;
  Deslocamento: Integer;
begin
  Q := Quadro;

  { Já em arraste: basta reposicionar a linha de inserção. }
  if Assigned(Q) and Q.Arrastando then
  begin
    Q.MoverMarcador;
    Exit;
  end;

  if not FPressionado then
    Exit;

  Deslocamento := Abs(X - FPosicaoMouse.X) + Abs(Y - FPosicaoMouse.Y);
  if Deslocamento < 5 then
    Exit;

  FPressionado := False;
  if Assigned(FItem) and Assigned(Q) then
    Q.IniciarArrasto(FItem);
end;

procedure TVideoQueueItemView.ItemMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Q: TfrVideoQueue;
begin
  ReleaseCapture;
  FPressionado := False;

  Q := Quadro;
  if Assigned(Q) and Q.Arrastando then
    Q.ConcluirArrasto;
end;

procedure TVideoQueueItemView.BtnRemoverClick(Sender: TObject);
begin
  if Assigned(FItem) and Assigned(Quadro) then
    Quadro.RemoverItemPublico(FItem);
end;

{ Expande/recolhe a área de texto do item. Recolhido, o item mantém a
  altura compacta e uma linha por informação (truncada com Hint);
  expandido, os rótulos ganham WordWrap e mostram o texto inteiro. Como
  a altura muda, a pilha de itens é realinhada no fim. }
procedure TVideoQueueItemView.BtnExpandirClick(Sender: TObject);
begin
  FExpandido := not FExpandido;
  if FExpandido then
  begin
    btn_expandir.Caption := '-';
    btn_expandir.Hint    := 'Recolher os detalhes do item';
  end
  else
  begin
    btn_expandir.Caption := '+';
    btn_expandir.Hint    := 'Expandir os detalhes do item';
  end;

  { A mudança de Height já realinha os vizinhos: o LCL reordena a pilha
    de alTop quando os limites de um filho mudam (verificado com o LCL). }
  AplicarAlturaExpandida;
  Atualizar;
end;

procedure TVideoQueueItemView.AplicarAlturaExpandida;
begin
  if FExpandido then
  begin
    Height := ALTURA_ITEM_EXP;
    lbl_titulo.Height     := ALTURA_TITULO_EXP;
    lbl_origem.Height     := ALTURA_LINHA_EXP;
    lbl_destino.Height    := ALTURA_LINHA_EXP;
    lbl_formatos.Height   := ALTURA_DETALHE_EXP;
    lbl_download.Height   := ALTURA_DETALHE_EXP;
    lbl_titulo.WordWrap   := True;
    lbl_origem.WordWrap   := True;
    lbl_destino.WordWrap  := True;
    lbl_formatos.WordWrap := True;
    lbl_download.WordWrap := True;
  end
  else
  begin
    Height := ALTURA_ITEM;
    lbl_titulo.Height     := ALTURA_TITULO;
    lbl_origem.Height     := ALTURA_LINHA;
    lbl_destino.Height    := ALTURA_LINHA;
    lbl_formatos.Height   := ALTURA_LINHA;
    lbl_download.Height   := ALTURA_LINHA;
    lbl_titulo.WordWrap   := False;
    lbl_origem.WordWrap   := False;
    lbl_destino.WordWrap  := False;
    lbl_formatos.WordWrap := False;
    lbl_download.WordWrap := False;
  end;
end;

procedure TVideoQueueItemView.ItemDblClick(Sender: TObject);
begin
  if (not Assigned(Quadro)) or (not Assigned(FItem)) then
    Exit;
  Quadro.AbrirItemDblClick(Self);
end;

{ TThumbPoolTask }

{ Roda na thread do pool: não pode criar TBitmap nem tocar na interface.
  O BMP vai para um arquivo temporário com o sufixo único pedido ao pool;
  no caso de URL, a mesma chamada devolve o título do vídeo. }
procedure TThumbPoolTask.Executar;
begin
  SaidaBMP := '';
  Titulo := '';
  if EhURL then
    SaidaBMP := TThumbnailService.DoURLParaArquivo(Origem, Largura, Altura,
                                                   Sufixo, Titulo)
  else
    SaidaBMP := TThumbnailService.DoArquivoParaArquivo(Origem, Largura, Altura,
                                                       Sufixo);
end;

{ TfrVideoQueue }

constructor TfrVideoQueue.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FViews      := TList.Create;
  FPool       := TQueuePool.Create(4);
  FArrastando := False;
  FItemArrasto := nil;
  FIndiceDestino := -1;

  FFila := TVideoQueue.Unica;
  FFila.OnAlterado := @FilaAlterou;

  pnl_marcador := TPanel.Create(Self);
  pnl_marcador.Name        := 'MarcaInsercao';
  pnl_marcador.Caption     := '';
  pnl_marcador.Align       := alNone;
  pnl_marcador.Height      := 3;
  pnl_marcador.BevelOuter  := bvNone;
  pnl_marcador.Color       := COR_MARCADOR;
  pnl_marcador.Visible     := False;
  pnl_marcador.Parent      := sb_itens;

  FTimer := TTimer.Create(Self);
  FTimer.Interval := 150;
  FTimer.Enabled  := True;
  FTimer.OnTimer  := @TimerMiniaturasTimer;

  OnResize := @FrameResize;

  AtualizarGeral;
end;

destructor TfrVideoQueue.Destroy;
var
  i: Integer;
begin
FArrastando := False;
  if Assigned(FFila) then
    FFila.OnAlterado := nil;

  { O timer deve parar antes do pool: sem ele não há callback pendente
    tocando os painéis durante a destruição. O pool por si não entrega
    nada na interface — os resultados ficam na lista de concluídos e são
    libertados aqui a seu tempo. }
  FTimer.Enabled := False;
  FPool.Free;

  for i := 0 to FViews.Count - 1 do
    TVideoQueueItemView(FViews[i]).Free;
  FViews.Free;

  inherited Destroy;
end;

procedure TfrVideoQueue.LargurarItens;
var
  i, W: Integer;
begin
  if not Assigned(sb_itens) then
    Exit;
  W := sb_itens.ClientWidth;
  if W <= 0 then
    Exit;
  for i := 0 to FViews.Count - 1 do
    TVideoQueueItemView(FViews[i]).Width := W;
end;

procedure TfrVideoQueue.FrameResize(Sender: TObject);
begin
  LargurarItens;
  if not Assigned(lbl_vazio) then
    Exit;
  lbl_vazio.Left := (sb_itens.ClientWidth - lbl_vazio.Width) div 2;
  lbl_vazio.Top  := (sb_itens.ClientHeight - lbl_vazio.Height) div 2;
end;

procedure TfrVideoQueue.FilaAlterou(Sender: TObject);
begin
  AtualizarGeral;
end;

function TfrVideoQueue.ViewDe(AItem: TVideoQueueItem): TVideoQueueItemView;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to FViews.Count - 1 do
    if TVideoQueueItemView(FViews[i]).Item = AItem then
      Exit(TVideoQueueItemView(FViews[i]));
end;

function TfrVideoQueue.ContidoNaFila(AItem: TVideoQueueItem): Boolean;
begin
  Result := ViewDe(AItem) <> nil;
end;

function TfrVideoQueue.GetSelecionado: TVideoQueueItem;
begin
  Result := nil;
  if Assigned(FSelecionado) then
    Result := FSelecionado.Item;
end;

procedure TfrVideoQueue.Selecionar(AView: TVideoQueueItemView);
var
  i: Integer;
begin
  for i := 0 to FViews.Count - 1 do
    TVideoQueueItemView(FViews[i]).SetSelecionado(
      TVideoQueueItemView(FViews[i]) = AView);
  FSelecionado := AView;
end;

{ Clicar num item o marca como selecionado: é o que dá alvo ao botão de
  remover da barra de comandos. }
procedure TfrVideoQueue.SelecionarItem(AItem: TVideoQueueItem);
begin
  if not Assigned(AItem) then
    Exit;
  Selecionar(ViewDe(AItem));
end;

procedure TfrVideoQueue.AbrirItemDblClick(Sender: TObject);
var
  View: TVideoQueueItemView;
  Alvo: string;
begin
  View := TVideoQueueItemView(Sender);
  if (not Assigned(View)) or (not Assigned(View.Item)) then
    Exit;

  Alvo := View.Item.Destino;
  if Alvo = '' then
    Alvo := View.Item.ArquivoLocal;
  if Alvo = '' then
    Exit;

  { O destino pode trazer "arquivo|pasta"; interessa só a pasta. }
  if Pos('|', Alvo) > 0 then
    Alvo := Copy(Alvo, Pos('|', Alvo) + 1, MaxInt);

  AbrirPasta(Alvo);
end;

{ Devolve o primeiro índice em que a lista de visões deixou de casar com
  o modelo, FViews.Count quando quantidade e ordem estão idênticas, ou -1
  quando as quantidades diferem. AtualizarGeral usa isso para decidir se
  basta refrescar os painéis existentes ou se é preciso criar/realinhar
  visões. }
function TfrVideoQueue.PrimeiroDesalinhado: Integer;
var
  i: Integer;
begin
  if FViews.Count <> FFila.QtItens then
    Exit(-1);
  for i := 0 to FViews.Count - 1 do
    if TVideoQueueItemView(FViews[i]).Item <> FFila.Item(i) then
      Exit(i);
  Result := FViews.Count;
end;

{ Os itens usam Align = alTop e o LCL empilha na ordem inversa à de
  criação: o último filho de sb_itens aparece no topo. Por isso a
  reaplicação percorre o modelo de trás para frente, para que o primeiro
  item da fila fique visualmente no alto. AInicio limita a operação ao
  trecho que mudou de lugar; o que já está alinhado acima dele não é
  tocado. }
procedure TfrVideoQueue.ReaplicarOrdem(AInicio: Integer);
var
  i: Integer;
  View: TVideoQueueItemView;
begin
  if AInicio < 0 then
    AInicio := 0;
  if AInicio >= FViews.Count then
    Exit;
  EsconderMarcador;
  for i := FViews.Count - 1 downto AInicio do
  begin
    View := TVideoQueueItemView(FViews[i]);
    View.Parent := nil;
    View.Parent := sb_itens;
    View.Width  := sb_itens.ClientWidth;
  end;
end;

procedure TfrVideoQueue.AtualizarGeral;
var
  i: Integer;
  Item: TVideoQueueItem;
  View: TVideoQueueItemView;
  PrimeiroFora: Integer;
  Nova: TList;
begin
  { 1. Remove as visões cujo item saiu do modelo. }
  i := 0;
  while i < FViews.Count do
  begin
    if not FFila.ContidoEm(TVideoQueueItemView(FViews[i]).Item) then
    begin
      if FSelecionado = TVideoQueueItemView(FViews[i]) then
        FSelecionado := nil;
      TVideoQueueItemView(FViews[i]).Free;
      FViews.Delete(i);
    end
    else
      Inc(i);
  end;

  { 2. Onde a lista de visões já espelha o modelo, nada é reconstruído:
     uma colagem de 500 links adiciona 500 painéis ao fim sem reescrever
     os que já existiam, e a janela não pisca a cada notificação. }
  PrimeiroFora := PrimeiroDesalinhado;

  { O caminho rápido só vale quando PrimeiroFora = FViews.Count: aí a
    quantidade é exatamente a do modelo E a ordem bate. Antes isso usava
    ">=" e quebrava justamente o primeiro item: com 0 visões e 1 item,
    PrimeiroDesalinhado devolvia 0 e o "0 >= 0" mandava atualizar apenas
    painéis existentes — que não existem — e a fila nunca aparecia. }
  if PrimeiroFora = FViews.Count then
  begin
    sb_itens.DisableAlign;
    try
      for i := 0 to FViews.Count - 1 do
      begin
        View := TVideoQueueItemView(FViews[i]);
        View.SetBloqueado(FProcessando);
        View.Atualizar;
      end;
    finally
      sb_itens.EnableAlign;
    end;
  end
  else
  begin
    Nova := TList.Create;
    try
      sb_itens.DisableAlign;
      try
        for i := 0 to FFila.QtItens - 1 do
        begin
          Item := FFila.Item(i);
          View := ViewDe(Item);
          if View = nil then
          begin
            View := TVideoQueueItemView.Create(Self, Self);
            View.Item   := Item;
            View.Parent := sb_itens;
            View.Width  := sb_itens.ClientWidth;
          end;
          View.SetBloqueado(FProcessando);
          View.Atualizar;
          Nova.Add(View);
        end;
      finally
        sb_itens.EnableAlign;
      end;
      FViews.Assign(Nova);
    finally
      Nova.Free;
    end;
  end;

  { 3. Reempilha sempre que algo foi criado ou realinhado: alTop empilha na
     ordem inversa da criação, e os painéis novos precisam entrar na ordem
     certa da fila. }
  if PrimeiroFora <> FViews.Count then
    ReaplicarOrdem(0);

  LargurarItens;
  lbl_vazio.Visible := (FViews.Count = 0);
  FrameResize(Self);
end;

procedure TfrVideoQueue.AtualizarItem(AItem: TVideoQueueItem);
var
  View: TVideoQueueItemView;
begin
  if not Assigned(AItem) then
    Exit;
  View := ViewDe(AItem);
  if Assigned(View) then
    View.Atualizar;
end;

function TfrVideoQueue.Adicionar(const AOrigem: string): TVideoQueueItem;
var
  Item: TVideoQueueItem;
begin
  Result := nil;
  Item := FFila.Adicionar(AOrigem);
  if not Assigned(Item) then
    Exit;

  Item.AtribuirMiniatura(
    TThumbnailService.Representacao(Item.Titulo,
      LARGURA_THUMB_BIT, ALTURA_THUMB_BIT));

  { Arquivos locais usam um quadro do próprio vídeo; URLs usam a
    miniatura publicada pela fonte, baixada em segundo plano pelo pool. }
  if Item.OrigemLocal then
    EnfileirarMiniatura(Item, Item.ArquivoLocal)
  else
    EnfileirarMiniaturaURL(Item, Item.URL);

  { A notificação do modelo já criou o painel; o representante visual
    colocado agora precisa pintar sem esperar o pool. }
  AtualizarItem(Item);

  Result := Item;
end;

{ Adições em lote. O timer fica desligado durante o preparo para o pool
  não aplicar metade das miniaturas antes da leva inteira estar na fila —
  nada impede o timer de continuar rodando depois, quando a fila já está
  completa. Cada bloco engaja um único AtualizarGeral no fim. }

function TfrVideoQueue.AdicionarArquivos(const AArquivos: TStrings): Integer;
begin
  if not Assigned(AArquivos) then
    Exit(0);
  FTimer.Enabled := False;
  try
    Result := FFila.AdicionarArquivos(AArquivos);
    if Result > 0 then
      AplicarNovosItens(FFila.QtItens - Result);
  finally
    FTimer.Enabled := True;
  end;
end;

function TfrVideoQueue.AdicionarURLs(const AURLs: TStrings): Integer;
begin
  if not Assigned(AURLs) then
    Exit(0);
  FTimer.Enabled := False;
  try
    Result := FFila.AdicionarURLs(AURLs);
    if Result > 0 then
      AplicarNovosItens(FFila.QtItens - Result);
  finally
    FTimer.Enabled := True;
  end;
end;

function TfrVideoQueue.AdicionarVarias(const ALista: TStrings): Integer;
begin
  if not Assigned(ALista) then
    Exit(0);
  FTimer.Enabled := False;
  try
    Result := FFila.AdicionarVarias(ALista);
    if Result > 0 then
      AplicarNovosItens(FFila.QtItens - Result);
  finally
    FTimer.Enabled := True;
  end;
end;

{ Dá vista às entradas novas a partir de AInicio: o representante visual
  aparece na hora e a miniatura real é pedida ao pool em segundo plano. }
procedure TfrVideoQueue.AplicarNovosItens(AInicio: Integer);
var
  i: Integer;
  Item: TVideoQueueItem;
begin
  if AInicio < 0 then
    AInicio := 0;
  if AInicio > FFila.QtItens - 1 then
    Exit;

  for i := AInicio to FFila.QtItens - 1 do
  begin
    Item := FFila.Item(i);
    Item.AtribuirMiniatura(
      TThumbnailService.Representacao(Item.Titulo,
        LARGURA_THUMB_BIT, ALTURA_THUMB_BIT));

    if Item.OrigemLocal then
      EnfileirarMiniatura(Item, Item.ArquivoLocal)
    else
      EnfileirarMiniaturaURL(Item, Item.URL);
  end;

  AtualizarGeral;
end;

procedure TfrVideoQueue.EnfileirarMiniatura(AItem: TVideoQueueItem;
                                            const AArquivo: string);
var
  Tarefa: TThumbPoolTask;
begin
  if (not Assigned(AItem)) or (AArquivo = '') then
    Exit;
  if not FileExists(AArquivo) then
    Exit;

  Tarefa := TThumbPoolTask.Create;
  Tarefa.Item    := AItem;
  Tarefa.EhURL   := False;
  Tarefa.Origem  := AArquivo;
  Tarefa.Sufixo  := FPool.NovoIdentificador;
  Tarefa.Largura := LARGURA_THUMB_BIT;
  Tarefa.Altura  := ALTURA_THUMB_BIT;
  FPool.Enfileirar(Tarefa);
end;

procedure TfrVideoQueue.EnfileirarMiniaturaURL(AItem: TVideoQueueItem;
                                               const AURL: string);
var
  Tarefa: TThumbPoolTask;
begin
  if (not Assigned(AItem)) or (Trim(AURL) = '') then
    Exit;

  Tarefa := TThumbPoolTask.Create;
  Tarefa.Item    := AItem;
  Tarefa.EhURL   := True;
  Tarefa.Origem  := Trim(AURL);
  Tarefa.Sufixo  := FPool.NovoIdentificador;
  Tarefa.Largura := LARGURA_THUMB_BIT;
  Tarefa.Altura  := ALTURA_THUMB_BIT;
  FPool.Enfileirar(Tarefa);
end;

{ A interface não vai atrás das miniaturas: os workers entregam o BMP
  pronto e o timer apenas drena a fila de concluídos. Tudo que envolve
  TBitmap acontece aqui. Uma falha do worker chega como SaidaBMP vazio e
  mantém o representante visual no lugar. }
procedure TfrVideoQueue.ProcessarConcluidos;
var
  Concluidas: TList;
  i: Integer;
begin
  Concluidas := TList.Create;
  try
    if FPool.RetirarConcluidos(Concluidas) = 0 then
      Exit;

    for i := 0 to Concluidas.Count - 1 do
    begin
      try
        AplicarMiniatura(TThumbPoolTask(Concluidas[i]));
      finally
        TThumbPoolTask(Concluidas[i]).Free;
      end;
    end;
  finally
    Concluidas.Free;
  end;
end;

procedure TfrVideoQueue.AplicarMiniaturaPublico(ATarefa: TThumbPoolTask);
begin
  AplicarMiniatura(ATarefa);
end;

procedure TfrVideoQueue.AplicarMiniatura(ATarefa: TThumbPoolTask);
var
  Item: TVideoQueueItem;
  Miniatura: TBitmap;
begin
  Item := ATarefa.Item;
  try
    { O item pode ter saído da fila enquanto o worker trabalhava; a
      verificação compara ponteiros (ViewDe), sem tocar num item que já
      não existe mais. }
    if not ContidoNaFila(Item) then
      Exit;

    { A miniatura real substitui o representante que a interface desenhou
      logo após a inserção. O guard antigo (só aplicava se Miniatura fosse
      nil) bloqueava justamente a chegada da imagem: o placeholder já
      ocupava o slot, e AtribuirMiniatura liberta o bitmap anterior. }
    Miniatura := TThumbnailService.CarregarBMP(ATarefa.SaidaBMP);
    if Assigned(Miniatura) then
      Item.AtribuirMiniatura(Miniatura);

    { O título descoberto substitui a URL enquanto o vídeo não é baixado. }
    if (ATarefa.Titulo <> '') and (Item.Titulo = Item.URL) then
      Item.Titulo := ATarefa.Titulo;

    AtualizarItem(Item);
  finally
    TThumbnailService.ApagarBMP(ATarefa.SaidaBMP);
  end;
end;

procedure TfrVideoQueue.TimerMiniaturasTimer(Sender: TObject);
begin
  ProcessarConcluidos;
end;

procedure TfrVideoQueue.RemoverItem(AItem: TVideoQueueItem);
begin
  if not Assigned(AItem) then
    Exit;

  if FArrastando and (FItemArrasto = AItem) then
    ConcluirArrasto;

  { Nada a tirar das pendências: os workers terminam de gerar a miniatura
    no arquivo temporário e a AplicarMiniatura a descarta ao ver que o
    item saiu da fila. }
  FFila.Remover(AItem);
end;

procedure TfrVideoQueue.RemoverItemPublico(AItem: TVideoQueueItem);
begin
  if FProcessando then
  begin
    ShowMessage('Aguarde o término do processamento para remover itens.');
    Exit;
  end;
  RemoverItem(AItem);
end;

procedure TfrVideoQueue.RemoverSelecionado;
begin
  if (FSelecionado = nil) or (not Assigned(FSelecionado.Item)) then
    Exit;
  RemoverItem(FSelecionado.Item);
end;

procedure TfrVideoQueue.RemoverFinalizados;
var
  i: Integer;
begin
  for i := FFila.QtItens - 1 downto 0 do
    case FFila.Item(i).Status of
      vqsConcluido, vqsErro, vqsCancelado:
        RemoverItem(FFila.Item(i));
    end;
end;

procedure TfrVideoQueue.LimparTudo;
begin
  FSelecionado := nil;
  FArrastando := False;
  FItemArrasto := nil;
  EsconderMarcador;
  FFila.Limpar;
end;

{ ====================== Reordenação por arrastar ====================== }

function TfrVideoQueue.MouseNoScrollBox: TPoint;
var
  P: TPoint;
begin
  Result := Point(0, 0);
  P := Point(0, 0);
  if not GetCursorPos(P) then
    Exit;
  Result := sb_itens.ScreenToClient(P);
end;

{ Devolve o painel que ocupa a posição desejada depois do arrasto, ignorando
  o próprio item que está sendo movido — é sobre essa visão da lista que
  o usuário decide onde soltar. }
function TfrVideoQueue.ViewForaDoArraste(APosicao: Integer):
  TVideoQueueItemView;
var
  i, k: Integer;
  View: TVideoQueueItemView;
begin
  Result := nil;
  k := 0;
  for i := 0 to FViews.Count - 1 do
  begin
    View := TVideoQueueItemView(FViews[i]);
    if View.Item = FItemArrasto then
      Continue;
    if k = APosicao then
      Exit(View);
    Inc(k);
  end;
end;

{ Calcula a posição final (base 0) do item arrastado. A posição é contada
  sobre a lista já sem o próprio item, por isso mover para baixo não
  suffer deslocamento de um lugar. Metade do caminho permite soltar acima
  ou abaixo de cada linha, como em qualquer lista reordenável. }
function TfrVideoQueue.IndiceDestinoEmY(AY: Integer): Integer;
var
  i, k: Integer;
  View: TVideoQueueItemView;
begin
  k := 0;
  for i := 0 to FViews.Count - 1 do
  begin
    View := TVideoQueueItemView(FViews[i]);
    if View.Item = FItemArrasto then
      Continue;
    if AY < View.Top + (View.Height div 2) then
      Exit(k);
    Inc(k);
  end;
  Result := k;
end;

procedure TfrVideoQueue.MostrarMarcador(APosicao: Integer);
var
  Y: Integer;
  View: TVideoQueueItemView;
begin
  if FViews.Count = 0 then
  begin
    EsconderMarcador;
    Exit;
  end;

  View := ViewForaDoArraste(APosicao);
  if View = nil then
  begin
    { Soltar no fim: a linha fica logo abaixo do último painel. }
    View := TVideoQueueItemView(FViews[FViews.Count - 1]);
    Y := View.Top + View.Height;
  end
  else
    Y := View.Top;

  pnl_marcador.Left    := View.Left;
  pnl_marcador.Top     := Y;
  pnl_marcador.Width   := View.Width;
  pnl_marcador.BringToFront;
  pnl_marcador.Visible := True;
end;

procedure TfrVideoQueue.EsconderMarcador;
begin
  FIndiceDestino := -1;
  if Assigned(pnl_marcador) then
    pnl_marcador.Visible := False;
end;

procedure TfrVideoQueue.IniciarArrasto(AItem: TVideoQueueItem);
begin
  if FProcessando then
    Exit;
  if not Assigned(AItem) then
    Exit;

  FArrastando   := True;
  FItemArrasto  := AItem;
  FIndiceDestino := -1;
  MoverMarcador;
end;

procedure TfrVideoQueue.MoverMarcador;
var
  P: TPoint;
  Alvo: Integer;
  Origem: TVideoQueueItemView;
begin
  if not FArrastando then
    Exit;

  P := MouseNoScrollBox;
  Origem := ViewDe(FItemArrasto);

  { Sobre a posição atual o marcador some: não há nada a mover. }
  if Assigned(Origem) and (P.Y >= Origem.Top) and
     (P.Y < Origem.Top + Origem.Height) then
  begin
    EsconderMarcador;
    Exit;
  end;

  Alvo := IndiceDestinoEmY(P.Y);
  if Alvo < 0 then
    Alvo := 0;
  if Alvo > FFila.QtItens - 1 then
    Alvo := FFila.QtItens - 1;

  FIndiceDestino := Alvo;
  MostrarMarcador(Alvo);
end;

{ A reordenação altera a lista do modelo, e portanto também a ordem em que
  os itens serão processados. }
procedure TfrVideoQueue.ConcluirArrasto;
var
  Alvo: TVideoQueueItem;
  Destino: Integer;
begin
  if not FArrastando then
    Exit;

  Alvo   := FItemArrasto;
  Destino := FIndiceDestino;

  FArrastando := False;
  FItemArrasto := nil;
  FIndiceDestino := -1;
  if Assigned(pnl_marcador) then
    pnl_marcador.Visible := False;

  if not Assigned(Alvo) then
    Exit;

  if FFila.ContidoEm(Alvo) then
    Selecionar(ViewDe(Alvo));

  if Destino >= 0 then
    FFila.Mover(Alvo, Destino + 1);
end;

procedure TfrVideoQueue.AbrirPasta(const APasta: string);
var
  Destino: string;
  Abriu: Boolean;
  Link: UnicodeString;
begin
  Destino := APasta;
  if Destino = '' then
    Exit;
  if FileExists(Destino) then
    Destino := ExtractFilePath(Destino);
  if Destino = '' then
    Exit;

  { OpenURL no Windows recebe PWideChar, então o caminho é convertido
    explicitamente para UnicodeString em vez de relyar na conversão
    implícita de AnsiString. }
  {$IFDEF WINDOWS}
  Destino := 'file:///' + StringReplace(Destino, '\', '/', [rfReplaceAll]);
  Link := UnicodeString(Destino);
  Abriu := OpenURL(PWideChar(Link));
  {$ELSE}
  Destino := 'file://' + Destino;
  Abriu := OpenURL(Destino);
  {$ENDIF}

  if not Abriu then
    ShowMessage('Não foi possível abrir a pasta: ' + Destino);
end;

function TfrVideoQueue.QtItens: Integer;
begin
  Result := FFila.QtItens;
end;

{ Enquanto o pipeline roda, remover e reordenar quebrariam a sequência de
  processamento; os itens ficam bloqueados até o fim. }
procedure TfrVideoQueue.SetProcessando(AValor: Boolean);
var
  i: Integer;
begin
  if FProcessando = AValor then
    Exit;

  FProcessando := AValor;
  if not AValor then
  begin
    EsconderMarcador;
    FArrastando := False;
    FItemArrasto := nil;
  end;

  for i := 0 to FViews.Count - 1 do
    TVideoQueueItemView(FViews[i]).SetBloqueado(AValor);
end;

end.
