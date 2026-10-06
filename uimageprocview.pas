unit uImageProcView;

{ uImageProcView

  Tela do processamento em lote de imagens.

  Reune o catalogo de formatos, a fila de itens e o conversor em um lugar
  so. A tela nao decide nada sobre conversao: ela apenas coleta o que o
  usuario escolheu, entrega para TFilaImagens e para TConversorImagens, e
  reflete o que os dois respondem.

  O painel de cada item e montado por codigo, como na fila de videos,
  porque todos os paineis compartilham o mesmo owner e cada um precisa de
  um Name proprio. Um designer nao daria nomes distintos a N paineis
  identicos. }

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, StdCtrls, ExtCtrls, Buttons,
  ComCtrls, Dialogs, Spin, LCLIntf, uDependencias, uImageFormats, uProcessos,
  uImageProcQueue, uImageProcRunner;

type
  TfrImageProc = class;

  { TThumbPanelImg
    Moldura da miniatura, desenhada no Paint para nao depender de estilos
    nativos de bevel. }
  TThumbPanelImg = class(TPanel)
  protected
    procedure Paint; override;
  public
    Raio     : Integer;
    CorBorda : TColor;
    constructor Create(AOwner: TComponent); override;
  end;

  { TImageProcItemView
    Painel visual de um item da fila: miniatura, titulo, formato de
    origem com dimensoes, formato e destino de saida, opcoes, situacao,
    progresso e o botao de remocao. }
  TImageProcItemView = class(TPanel)
  private
    FItem        : TItemImagem;
    FQuadro      : TObject;
    FSelecionado : Boolean;
    FBloqueado   : Boolean;

    pnl_thumb    : TThumbPanelImg;
    img_thumb    : TImage;
    lbl_indice   : TLabel;
    pnl_info     : TPanel;
    lbl_titulo   : TLabel;
    lbl_origem   : TLabel;
    lbl_saida    : TLabel;
    lbl_opcoes   : TLabel;
    pbar_item    : TProgressBar;
    pnl_status   : TPanel;
    pnl_badge    : TPanel;
    lbl_status   : TLabel;
    lbl_mensagem : TLabel;
    btn_remover  : TSpeedButton;

    procedure Montar;
    procedure ItemMouseDown(Sender: TObject; Button: TMouseButton;
                            Shift: TShiftState; X, Y: Integer);
    procedure BtnRemoverClick(Sender: TObject);
    procedure ItemDblClick(Sender: TObject);
    procedure AtualizarVisual;
    function  Quadro: TfrImageProc;
    function  Truncar(const ATexto: string; AMaxChars: Integer): string;
  public
    constructor Create(AOwner: TComponent; AQuadro: TObject); reintroduce;
    destructor Destroy; override;

    procedure Atualizar;
    procedure SetSelecionado(AValor: Boolean);
    procedure SetBloqueado(AValor: Boolean);

    property Item        : TItemImagem read FItem write FItem;
    property Selecionado : Boolean read FSelecionado;
  end;

  { TfrImageProc
    Area de interface do processamento de imagens: monta a fila, coleta
    formato e opcoes, e conduz a execucao. }
  TfrImageProc = class(TFrame)
    grp_opcoes: TGroupBox;
    grp_acoes: TGroupBox;
    sb_itens: TScrollBox;
    lbl_vazio: TLabel;
    dlg_Arquivos: TOpenDialog;

    btn_AdicionarArquivos: TButton;
    btn_AdicionarPasta: TButton;
    btn_Destino: TButton;
    btn_Remover: TButton;
    btn_Limpar: TButton;
    btn_Processar: TButton;
    btn_Cancelar: TButton;

    cmb_Formato: TComboBox;
    lbl_GrupoFormato: TLabel;
    lbl_RecursoFormato: TLabel;
    spn_Qualidade: TSpinEdit;
    lbl_Qualidade: TLabel;
    chk_Redimensionar: TCheckBox;
    spn_Largura: TSpinEdit;
    lbl_x: TLabel;
    spn_Altura: TSpinEdit;
    chk_ManterProporcao: TCheckBox;
    chk_RemoverFundo: TCheckBox;
    chk_RemoverMetadados: TCheckBox;
    chk_AplicarEmTodos: TCheckBox;

    lbl_geral: TLabel;
    pbar_geral: TProgressBar;
    memo_Log: TMemo;

    procedure FrameResize(Sender: TObject);
    procedure FormatoChange(Sender: TObject);
    procedure OpcoesAlteradas(Sender: TObject);
    procedure RedimensionarChange(Sender: TObject);
    procedure ManterProporcaoClick(Sender: TObject);
    procedure DestinoClick(Sender: TObject);
    procedure AdicionarArquivosClick(Sender: TObject);
    procedure AdicionarPastaClick(Sender: TObject);
    procedure RemoverSelecionadoClick(Sender: TObject);
    procedure LimparClick(Sender: TObject);
    procedure ProcessarClick(Sender: TObject);
    procedure CancelarClick(Sender: TObject);
    procedure ItemDblClick(Sender: TObject);
  private
    FFila       : TFilaImagens;
    FViews      : TList;
    FSelecionado: TImageProcItemView;
    FConversor  : TConversorImagens;
    FProcessando: Boolean;
    { Chave de formato de cada linha do combo, na mesma ordem. O combo
      mostra o rotulo e repete o grupo em cabecalhos, entao o texto da linha
      nao serve para descobrir o formato: e esta lista que faz a ligacao.
      Linha de cabecalho tem chave vazia. }
    FChavesCombo: TStringList;

    procedure FilaAlterou(Sender: TObject);
    procedure Selecionar(AView: TImageProcItemView);
    procedure RemoverItem(AItem: TItemImagem);
    procedure LargurarItens;
    procedure AtualizarGeral;
    procedure AtualizarControles;
    procedure EscreverOpcoesNaTela(const AOpcoes: TOpcoesConversao);
    function  OpcoesDaTela: TOpcoesConversao;
    function  FormatoSelecionado: string;
    function  ViewDe(AItem: TItemImagem): TImageProcItemView;
    procedure SelecionarItem(AItem: TItemImagem);
    procedure AbrirPasta(const APasta: string);
    procedure RegistrarBombas;
    procedure AtualizarBarraGeral;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    function  AdicionarArquivos(const AArquivos: TStrings): Integer;
    function  AdicionarPasta(const APasta: string): Integer;
    procedure Processar;
    procedure Cancelar;
    procedure AbrirPastaPublico(const APasta: string);

    property Fila        : TFilaImagens read FFila;
    property Processando : Boolean read FProcessando;
    property Conversor   : TConversorImagens read FConversor;
  end;

var
  frImageProc: TfrImageProc;

  { Sequencia monotonica de nomes: os paineis da fila compartilham o mesmo
    owner, entao cada um precisa de um Name proprio. Fica no nivel da unit
    para nao se reiniciar quando o frame e recriado ao trocar de tela. }
  FSequenciaItemImg: Integer;

implementation

{$R *.lfm}

const
  ALTURA_ITEM      = 74;
  LARGURA_INDICE   = 26;
  LARGURA_THUMB    = 96;
  MARGEM_THUMB     = 5;
  LARGURA_STATUS   = 190;
  LARGURA_BOTAO    = 24;

  ALTURA_TITULO    = 17;
  ALTURA_LINHA     = 13;
  ALTURA_BARRA     = 6;
  ALTURA_BADGE     = 20;

  { Miniaturas no dobro do tamanho exibido para ficarem nitidas em telas
    de alta densidade. }
  LARGURA_THUMB_BIT = (LARGURA_THUMB - (MARGEM_THUMB * 2)) * 2;
  ALTURA_THUMB_BIT  = (ALTURA_ITEM - (MARGEM_THUMB * 2)) * 2;

  { Cores fixas como literal inteiro na ordem R + G*256 + B*65536. Um
    initializer de const precisa ser resolvido em tempo de compilacao,
    entao nao da para usar RGBToColor aqui. O literal tem de conter as tres
    parcelas: um valor pequeno como 245 decodifica para vermelho puro. }
  COR_ITEM          = 15790320;  { 240,240,240 }
  COR_ITEM_SEL      = 16442062;  { 206,226,250 }
  COR_BORDA_THUMB   = 9207928;   { 120,128,140 }
  COR_FUNDO_THUMB   = 3158064;   {  48, 48, 48 }

{ TThumbPanelImg }

{ Ponte entre o procedimento simples exigido por uProcessos e o metodo do
  LCL que trata a fila de mensagens. }
procedure BombearMensagens;
begin
  Application.ProcessMessages;
end;

constructor TThumbPanelImg.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Raio     := 6;
  CorBorda := COR_BORDA_THUMB;
end;

procedure TThumbPanelImg.Paint;
begin
  inherited;
  Canvas.Brush.Style := bsClear;
  Canvas.Pen.Style   := psSolid;
  Canvas.Pen.Color   := CorBorda;
  Canvas.Pen.Width   := 1;
  Canvas.RoundRect(0, 0, Width, Height, Raio, Raio);
end;

{ TImageProcItemView }

constructor TImageProcItemView.Create(AOwner: TComponent; AQuadro: TObject);
begin
  inherited Create(AOwner);
  FQuadro := AQuadro;
  Montar;
end;

destructor TImageProcItemView.Destroy;
begin
  FQuadro := nil;
  FItem := nil;
  inherited Destroy;
end;

function TImageProcItemView.Quadro: TfrImageProc;
begin
  Result := nil;
  if Assigned(FQuadro) then
    Result := TfrImageProc(FQuadro);
end;

function TImageProcItemView.Truncar(const ATexto: string;
                                   AMaxChars: Integer): string;
begin
  if Length(ATexto) <= AMaxChars then
    Result := ATexto
  else
    Result := Copy(ATexto, 1, AMaxChars - 3) + '...';
end;

procedure TImageProcItemView.Montar;
var
  Prefixo: string;
  { Todos os controles repassam o mouse ao painel do item, senao o clique
    cairia num "furo" e o item nao seria selecionado. O botao fica de
    fora para nao misturar remocao com selecao.

    A atribuicao e feita um a um em vez de por vetor: OnMouseDown e
    OnDblClick sao eventos publicados em classes diferentes da hierarquia,
    e o compilador nao aceita garanti-los por uma variavel de um unico
    tipo ancestral. }
begin
  Inc(FSequenciaItemImg);
  Prefixo := 'ItemImg' + IntToStr(FSequenciaItemImg) + '_';
  Name   := Copy(Prefixo, 1, Length(Prefixo) - 1);

  { Atencao: no LCL o alinhamento empilha os filhos na ordem INVERSA a de
    criacao. Os blocos abaixo sao construidos de baixo para cima. }
  Height      := ALTURA_ITEM;
  Align       := alTop;
  ParentColor := False;
  Color       := COR_ITEM;
  BevelOuter  := bvLowered;
  BorderSpacing.Around := 1;
  Caption     := '';
  Cursor      := crDefault;
  OnMouseDown := @ItemMouseDown;
  OnDblClick  := @ItemDblClick;

  { --- textos, criados por ultimo para aparecerem no topo da coluna --- }
  pnl_info := TPanel.Create(Self);
  pnl_info.Name        := Prefixo + 'Textos';
  pnl_info.Caption     := '';
  pnl_info.Parent      := Self;
  pnl_info.Align       := alClient;
  pnl_info.BevelOuter  := bvNone;
  pnl_info.Color       := COR_ITEM;

  pbar_item := TProgressBar.Create(Self);
  pbar_item.Name      := Prefixo + 'Progresso';
  pbar_item.Parent   := pnl_info;
  pbar_item.Align    := alTop;
  pbar_item.Height   := ALTURA_BARRA;
  pbar_item.Min      := 0;
  pbar_item.Max      := 100;
  pbar_item.Position := 0;
  pbar_item.Style    := pbstNormal;
  pbar_item.Visible  := False;

  lbl_opcoes := TLabel.Create(Self);
  lbl_opcoes.Name         := Prefixo + 'Opcoes';
  lbl_opcoes.Parent      := pnl_info;
  lbl_opcoes.Align       := alTop;
  lbl_opcoes.Height      := ALTURA_LINHA;
  lbl_opcoes.AutoSize    := False;
  lbl_opcoes.Layout      := tlCenter;
  lbl_opcoes.Font.Size   := 8;
  lbl_opcoes.Font.Color  := clGray;
  lbl_opcoes.Transparent := True;

  lbl_saida := TLabel.Create(Self);
  lbl_saida.Name         := Prefixo + 'Saida';
  lbl_saida.Parent      := pnl_info;
  lbl_saida.Align       := alTop;
  lbl_saida.Height      := ALTURA_LINHA;
  lbl_saida.AutoSize    := False;
  lbl_saida.Layout      := tlCenter;
  lbl_saida.Font.Size   := 8;
  lbl_saida.Font.Color  := RGBToColor(70, 100, 160);
  lbl_saida.Transparent := True;

  lbl_origem := TLabel.Create(Self);
  lbl_origem.Name         := Prefixo + 'Origem';
  lbl_origem.Parent      := pnl_info;
  lbl_origem.Align       := alTop;
  lbl_origem.Height      := ALTURA_LINHA;
  lbl_origem.AutoSize    := False;
  lbl_origem.Layout      := tlCenter;
  lbl_origem.Font.Size   := 8;
  lbl_origem.Font.Color  := clGray;
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

  { --- remocao individual --- }
  btn_remover := TSpeedButton.Create(Self);
  btn_remover.Name         := Prefixo + 'Remover';
  btn_remover.Parent       := Self;
  btn_remover.Align        := alRight;
  btn_remover.Width        := LARGURA_BOTAO;
  btn_remover.Caption      := 'X';
  btn_remover.Flat         := True;
  btn_remover.Font.Size    := 9;
  btn_remover.Font.Style   := [fsBold];
  btn_remover.Color        := clBtnFace;
  btn_remover.OnClick      := @BtnRemoverClick;
  btn_remover.Hint         := 'Remover esta imagem da fila';

  { --- status no topo da coluna direita, mensagem logo abaixo --- }
  pnl_status := TPanel.Create(Self);
  pnl_status.Name        := Prefixo + 'Status';
  pnl_status.Caption     := '';
  pnl_status.Parent      := Self;
  pnl_status.Align       := alRight;
  pnl_status.Width       := LARGURA_STATUS;
  pnl_status.BevelOuter  := bvLowered;
  pnl_status.Color       := RGBToColor(232, 232, 232);

  pnl_badge := TPanel.Create(Self);
  pnl_badge.Name        := Prefixo + 'Selo';
  pnl_badge.Caption     := '';
  pnl_badge.Parent      := pnl_status;
  pnl_badge.Align       := alTop;
  pnl_badge.Height      := ALTURA_BADGE;
  pnl_badge.BevelOuter  := bvNone;
  pnl_badge.Color       := RGBToColor(228, 228, 228);

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

  { --- miniatura --- }
  pnl_thumb := TThumbPanelImg.Create(Self);
  pnl_thumb.Name    := Prefixo + 'Moldura';
  pnl_thumb.Caption := '';
  pnl_thumb.Parent  := Self;
  pnl_thumb.Align   := alLeft;
  pnl_thumb.Width   := LARGURA_THUMB;
  pnl_thumb.Color   := COR_FUNDO_THUMB;

  img_thumb := TImage.Create(Self);
  img_thumb.Name        := Prefixo + 'Thumb';
  img_thumb.Parent      := pnl_thumb;
  img_thumb.Align       := alClient;
  img_thumb.AutoSize    := False;
  img_thumb.Proportional := True;
  img_thumb.Stretch     := False;
  img_thumb.Transparent := False;
  img_thumb.Color       := COR_FUNDO_THUMB;
  img_thumb.BorderSpacing.Around := MARGEM_THUMB;

  { --- indice --- }
  lbl_indice := TLabel.Create(Self);
  lbl_indice.Name        := Prefixo + 'Indice';
  lbl_indice.Parent      := Self;
  lbl_indice.Align       := alLeft;
  lbl_indice.Width       := LARGURA_INDICE;
  lbl_indice.AutoSize    := False;
  lbl_indice.Layout      := tlCenter;
  lbl_indice.Alignment   := taCenter;
  lbl_indice.Font.Style  := [fsBold];
  lbl_indice.Font.Size   := 9;
  lbl_indice.Font.Color  := clGray;
  lbl_indice.Transparent := True;
  lbl_indice.Hint        := 'Posicao do item na fila';

  pnl_thumb.OnMouseDown := @ItemMouseDown;
  pnl_thumb.OnDblClick  := @ItemDblClick;
  img_thumb.OnMouseDown := @ItemMouseDown;
  img_thumb.OnDblClick  := @ItemDblClick;
  pnl_info.OnMouseDown  := @ItemMouseDown;
  pnl_info.OnDblClick   := @ItemDblClick;
  pnl_status.OnMouseDown := @ItemMouseDown;
  pnl_status.OnDblClick  := @ItemDblClick;
  pnl_badge.OnMouseDown  := @ItemMouseDown;
  pnl_badge.OnDblClick   := @ItemDblClick;
  lbl_titulo.OnMouseDown := @ItemMouseDown;
  lbl_titulo.OnDblClick  := @ItemDblClick;
  lbl_origem.OnMouseDown := @ItemMouseDown;
  lbl_origem.OnDblClick  := @ItemDblClick;
  lbl_saida.OnMouseDown  := @ItemMouseDown;
  lbl_saida.OnDblClick   := @ItemDblClick;
  lbl_opcoes.OnMouseDown := @ItemMouseDown;
  lbl_opcoes.OnDblClick  := @ItemDblClick;
  lbl_status.OnMouseDown := @ItemMouseDown;
  lbl_status.OnDblClick  := @ItemDblClick;
end;

procedure TImageProcItemView.Atualizar;
var
  Origem, Saida, Texto: string;
begin
  if not Assigned(FItem) then
    Exit;

  Origem := FItem.ExtensaoOriginal.ToUpper;
  if (FItem.LarguraOrigem > 0) and (FItem.AlturaOrigem > 0) then
    Origem := Origem + '  ' + IntToStr(FItem.LarguraOrigem) + 'x' +
              IntToStr(FItem.AlturaOrigem);

  Saida := FItem.RotuloSaida + '  ->  ' + FItem.CaminhoDestino;

  lbl_indice.Caption := IntToStr(FItem.Indice);
  lbl_titulo.Caption := FItem.Nome;
  lbl_titulo.Hint    := FItem.Arquivo;

  lbl_origem.Caption := Truncar(Origem, 74);
  lbl_origem.Hint    := FItem.Arquivo;

  lbl_saida.Caption := Truncar(Saida, 74);
  lbl_saida.Hint    := FItem.CaminhoDestino;

  lbl_opcoes.Caption := FItem.ResumoOpcoes;
  lbl_opcoes.Hint    := FItem.ResumoOpcoes;

  lbl_status.Caption := FItem.StatusTexto;

  pbar_item.Position := FItem.Progresso;
  pbar_item.Visible  := (FItem.Status = isiProcessando);

  if FItem.Miniatura <> nil then
    img_thumb.Picture.Assign(FItem.Miniatura)
  else
    img_thumb.Picture.Clear;

  case FItem.Status of
    isiAguardando:
    begin
      lbl_status.Font.Color   := RGBToColor(70, 70, 70);
      pnl_badge.Color         := RGBToColor(228, 228, 228);
      lbl_mensagem.Font.Color := RGBToColor(90, 90, 90);
    end;
    isiProcessando:
    begin
      lbl_status.Font.Color   := RGBToColor(20, 52, 120);
      pnl_badge.Color         := RGBToColor(212, 226, 250);
      lbl_mensagem.Font.Color := RGBToColor(20, 70, 170);
    end;
    isiConcluido:
    begin
      lbl_status.Font.Color   := RGBToColor(20, 96, 32);
      pnl_badge.Color         := RGBToColor(214, 240, 216);
      lbl_mensagem.Font.Color := RGBToColor(20, 96, 32);
    end;
    isiErro:
    begin
      lbl_status.Font.Color   := RGBToColor(140, 16, 16);
      pnl_badge.Color         := RGBToColor(250, 214, 214);
      lbl_mensagem.Font.Color := RGBToColor(160, 24, 24);
    end;
    isiCancelado:
    begin
      lbl_status.Font.Color   := RGBToColor(140, 82, 12);
      pnl_badge.Color         := RGBToColor(248, 234, 206);
      lbl_mensagem.Font.Color := RGBToColor(150, 96, 16);
    end;
  end;

  { Em erro o texto curto e a causa; a mensagem completa fica no hint,
    porque a causa real pode ser longa demais para a coluna. }
  case FItem.Status of
    isiErro:
      Texto := FItem.DetalheErro;
    isiConcluido:
      Texto := 'Salvo: ' + FItem.NomeDestino;
  else
    Texto := FItem.Mensagem;
  end;
  lbl_mensagem.Caption := Truncar(Texto, 30);
  lbl_mensagem.Hint := Texto;

  btn_remover.Enabled := not FBloqueado;
  AtualizarVisual;
end;

procedure TImageProcItemView.SetBloqueado(AValor: Boolean);
begin
  if FBloqueado = AValor then
    Exit;
  FBloqueado := AValor;
  if Assigned(btn_remover) then
    btn_remover.Enabled := not FBloqueado;
end;

procedure TImageProcItemView.AtualizarVisual;
begin
  if FSelecionado then
  begin
    Color         := COR_ITEM_SEL;
    pnl_info.Color := COR_ITEM_SEL;
  end
  else
  begin
    Color         := COR_ITEM;
    pnl_info.Color := COR_ITEM;
  end;
end;

procedure TImageProcItemView.SetSelecionado(AValor: Boolean);
begin
  FSelecionado := AValor;
  AtualizarVisual;
end;

procedure TImageProcItemView.ItemMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if (not Assigned(FItem)) or (not Assigned(Quadro)) then
    Exit;
  Quadro.SelecionarItem(FItem);
end;

procedure TImageProcItemView.BtnRemoverClick(Sender: TObject);
begin
  if (not Assigned(FItem)) or (not Assigned(Quadro)) then
    Exit;
  Quadro.RemoverItem(FItem);
end;

procedure TImageProcItemView.ItemDblClick(Sender: TObject);
var
  Q: TfrImageProc;
begin
  Q := Quadro;
  if (Q = nil) or (not Assigned(FItem)) then
    Exit;
  Q.AbrirPastaPublico(FItem.CaminhoDestino);
end;

{ TfrImageProc }

constructor TfrImageProc.Create(AOwner: TComponent);
var
  i, Indice: Integer;
  Itens: TStrings;
begin
  inherited Create(AOwner);

  FViews := TList.Create;
  FChavesCombo := TStringList.Create;

  FFila := TFilaImagens.Unica;
  FFila.OnAlterado := @FilaAlterou;

  RegistrarBombas;

  { A fila e um singleton, entao quem cria o frame nao e o dono dela: o
    callback e religado aqui senao trocar de aba silenciaria a tela. }
  EscreverOpcoesNaTela(FFila.OpcoesPadrao);

  { A lista de formatos e consultada uma vez, aqui, e o resultado fica em
    cache. O catalogo sozinho nao serve: um build do ImageMagick sem HEIC,
    por exemplo, desconhece o formato, e oferecer HEIC como destino seria
    prometer uma conversao que vai falhar. A consulta leva um instante, mas
    acontece na abertura da aba, nao a cada troca de formato. }
  TGerenciadorFormatos.AtualizarDisponibilidade;

  { Items e propriedade, e propriedade nao pode ser passada como var. A
    variavel resolve isso e deixa o codigo mais explicito. }
  Itens := cmb_Formato.Items;
  TGerenciadorFormatos.PreencherComboAgrupado(Itens, FChavesCombo);
  for i := 0 to FChavesCombo.Count - 1 do
    if FChavesCombo[i] = FFila.FormatoPadrao then
    begin
      cmb_Formato.ItemIndex := i;
      Break;
    end;
  if cmb_Formato.ItemIndex < 0 then
  begin
    { Default da fila: o primeiro formato de verdade da lista, nunca um
      cabecalho de grupo. ItemIndex e propriedade, e Inc() de propriedade
      nao compila, entao o indices anda numa variavel. }
    Indice := 0;
    while (Indice < FChavesCombo.Count - 1) and
      (FChavesCombo[Indice] = '') do
      Inc(Indice);
    cmb_Formato.ItemIndex := Indice;
  end;

  OnResize := @FrameResize;
  FormatoChange(Self);
  AtualizarGeral;
end;

destructor TfrImageProc.Destroy;
var
  i: Integer;
begin
  { Se a tela fechar no meio de uma execucao, o conversor precisa matar o
    processo filho antes de sair, senao o ImageMagick continua gravando em
    um arquivo que ninguem mais acompanha. }
  if Assigned(FConversor) then
    FConversor.Cancelar;

  if Assigned(FFila) then
    FFila.OnAlterado := nil;

  for i := 0 to FViews.Count - 1 do
    TImageProcItemView(FViews[i]).Free;
  FViews.Free;
  FChavesCombo.Free;

  inherited Destroy;
end;

procedure TfrImageProc.RegistrarBombas;
begin
  { O ImageMagick roda na thread da interface enquanto a fila le miniatura
    e dimensao de cada arquivo. Sem bombear mensagens aqui a janela
    ficaria congelada durante o lote. }

  { Application.ProcessMessages e um metodo, e uProcessos espera um
    procedimento simples: a ponte e necessaria. }
  uProcessosDefinirBombearMensagens(@BombearMensagens);
end;

procedure TfrImageProc.FrameResize(Sender: TObject);
begin
  LargurarItens;
  if not Assigned(lbl_vazio) then
    Exit;
  lbl_vazio.Left := (sb_itens.ClientWidth - lbl_vazio.Width) div 2;
  lbl_vazio.Top  := (sb_itens.ClientHeight - lbl_vazio.Height) div 2;
end;

procedure TfrImageProc.FilaAlterou(Sender: TObject);
begin
  AtualizarGeral;
end;

function TfrImageProc.ViewDe(AItem: TItemImagem): TImageProcItemView;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to FViews.Count - 1 do
    if TImageProcItemView(FViews[i]).Item = AItem then
      Exit(TImageProcItemView(FViews[i]));
end;

procedure TfrImageProc.Selecionar(AView: TImageProcItemView);
var
  i: Integer;
begin
  for i := 0 to FViews.Count - 1 do
    TImageProcItemView(FViews[i]).SetSelecionado(
      TImageProcItemView(FViews[i]) = AView);
  FSelecionado := AView;
end;

procedure TfrImageProc.SelecionarItem(AItem: TItemImagem);
begin
  if not Assigned(AItem) then
    Exit;
  Selecionar(ViewDe(AItem));
  AtualizarControles;
end;

procedure TfrImageProc.LargurarItens;
var
  i, W: Integer;
begin
  if not Assigned(sb_itens) then
    Exit;
  W := sb_itens.ClientWidth;
  if W <= 0 then
    Exit;
  for i := 0 to FViews.Count - 1 do
    TImageProcItemView(FViews[i]).Width := W;
end;

procedure TfrImageProc.AtualizarGeral;
var
  i: Integer;
  Item: TItemImagem;
  View: TImageProcItemView;
  Nova: TList;
begin
  { 1. Remove as visoes cujo item saiu do modelo. }
  i := 0;
  while i < FViews.Count do
  begin
    if not FFila.ContidoEm(TImageProcItemView(FViews[i]).Item) then
    begin
      if FSelecionado = TImageProcItemView(FViews[i]) then
        FSelecionado := nil;
      TImageProcItemView(FViews[i]).Free;
      FViews.Delete(i);
    end
    else
      Inc(i);
  end;

  { 2. Garante um painel por item e monta FViews na ordem do modelo. }
  Nova := TList.Create;
  try
    for i := 0 to FFila.QtItens - 1 do
    begin
      Item := FFila.Item(i);
      View  := ViewDe(Item);
      if View = nil then
      begin
        View := TImageProcItemView.Create(Self, Self);
        View.Item   := Item;
        View.Parent := sb_itens;
      end;
      Nova.Add(View);
      View.SetBloqueado(FProcessando);
      View.Atualizar;
    end;
    FViews.Assign(Nova);
  finally
    Nova.Free;
  end;

  { 3. Reempilha os paineis, porque o LCL alinha na ordem inversa a de
    criacao. }
  for i := FViews.Count - 1 downto 0 do
  begin
    View := TImageProcItemView(FViews[i]);
    View.Parent := nil;
    View.Parent := sb_itens;
  end;

  LargurarItens;
  lbl_vazio.Visible := (FViews.Count = 0);
  FrameResize(Self);
  AtualizarBarraGeral;
  AtualizarControles;
end;

procedure TfrImageProc.AtualizarBarraGeral;
var
  Total, Feitos: Integer;
begin
  Total := FFila.QtItens;
  Feitos := FFila.QtConcluidos + FFila.QtComErro;

  if Total = 0 then
  begin
    pbar_geral.Max      := 1;
    pbar_geral.Position := 0;
    lbl_geral.Caption   := 'Fila vazia';
    Exit;
  end;

  pbar_geral.Max      := Total;
  pbar_geral.Position := Feitos;

  { Durante a execucao o progresso do item em andamento e o que da a
    sensacao de avanco, entao entra na barra geral. }
  if FProcessando then
    lbl_geral.Caption := Format('%d de %d  (%d%%)', [Feitos, Total,
      ((Feitos * 100) + (Total div 2)) div Total])
  else
    lbl_geral.Caption := Format('%d de %d concluidos, %d com erro',
      [FFila.QtConcluidos, Total, FFila.QtComErro]);
end;

procedure TfrImageProc.AtualizarControles;
begin
  btn_Processar.Enabled       := (not FProcessando) and (FFila.QtPendentes > 0);
  btn_Cancelar.Enabled        := FProcessando;
  btn_Remover.Enabled         := (not FProcessando) and Assigned(FSelecionado);
  btn_Limpar.Enabled          := (not FProcessando) and (FFila.QtItens > 0);
  btn_AdicionarArquivos.Enabled := not FProcessando;
  btn_AdicionarPasta.Enabled     := not FProcessando;
  btn_Destino.Enabled         := not FProcessando;
end;

procedure TfrImageProc.RemoverItem(AItem: TItemImagem);
begin
  if not Assigned(AItem) then
    Exit;
  if FProcessando then
  begin
    ShowMessage('Aguarde o termino do processamento para remover itens.');
    Exit;
  end;
  FFila.Remover(AItem);
end;

procedure TfrImageProc.RemoverSelecionadoClick(Sender: TObject);
begin
  if (FSelecionado = nil) or (not Assigned(FSelecionado.Item)) then
    Exit;
  RemoverItem(FSelecionado.Item);
end;

procedure TfrImageProc.LimparClick(Sender: TObject);
begin
  if FProcessando then
  begin
    ShowMessage('Aguarde o termino do processamento para limpar a fila.');
    Exit;
  end;
  FSelecionado := nil;
  FFila.Limpar;
end;

function TfrImageProc.AdicionarArquivos(const AArquivos: TStrings): Integer;
var
  i: Integer;
  Item: TItemImagem;
begin
  Result := 0;
  if not Assigned(AArquivos) then
    Exit;

  for i := 0 to AArquivos.Count - 1 do
  begin
    Item := FFila.AdicionarArquivo(AArquivos[i]);
    if not Assigned(Item) then
      Continue;

    { A miniatura vem do proprio ImageMagick porque o LCL nao decodifica
      PNG, WebP, TIFF nem RAW. }
    if Item.Miniatura = nil then
      Item.AtribuirMiniatura(
        TThumbnailServiceImagem.DoArquivo(Item.Arquivo,
          LARGURA_THUMB_BIT, ALTURA_THUMB_BIT));
    Inc(Result);
  end;
end;

function TfrImageProc.AdicionarPasta(const APasta: string): Integer;
begin
  Result := FFila.AdicionarPasta(APasta);
end;

procedure TfrImageProc.AdicionarArquivosClick(Sender: TObject);
begin
  dlg_Arquivos.InitialDir := FFila.PastaPadrao;
  if dlg_Arquivos.Execute then
    AdicionarArquivos(dlg_Arquivos.Files);
end;

procedure TfrImageProc.AdicionarPastaClick(Sender: TObject);
var
  Pasta: string;
begin
  Pasta := FFila.PastaPadrao;
  if not SelectDirectory('Escolher a pasta com as imagens', '', Pasta) then
    Exit;
  AdicionarPasta(Pasta);
end;

procedure TfrImageProc.DestinoClick(Sender: TObject);
var
  Pasta: string;
begin
  Pasta := FFila.PastaPadrao;
  if not SelectDirectory('Escolher a pasta de destino', '', Pasta) then
    Exit;

  { DefinirPastaPadrao propaga para os itens que seguem o padrao, para que
    a lista e o conversor nunca apontem para pastas diferentes. }
  FFila.PastaPadrao := Pasta;
  btn_Destino.Hint := 'Destino: ' + Pasta;
end;

function TfrImageProc.FormatoSelecionado: string;
begin
  { Chave vazia e linha de cabecalho de grupo: nao e um formato, e nao pode
    virar o padrao da fila. }
  if (cmb_Formato.ItemIndex < 0) or
    (cmb_Formato.ItemIndex >= FChavesCombo.Count) then
    Exit('');
  Result := FChavesCombo[cmb_Formato.ItemIndex];
end;

procedure TfrImageProc.FormatoChange(Sender: TObject);
var
  Chave: string;
begin
  Chave := FormatoSelecionado;
  if Chave = '' then
    Exit;

  FFila.FormatoPadrao := Chave;
  lbl_GrupoFormato.Caption   := TGerenciadorFormatos.GrupoDe(Chave);
  lbl_RecursoFormato.Caption := TGerenciadorFormatos.ObservacaoDe(Chave);

  { O catalogo cobre a documentacao oficial inteira, mas o executavel
    instalado pode nao ter o delegate necessario. Dizer isso aqui evita que
    a fila inteira falhe no fim, depois de o usuario esperar a conversao. }
  if TGerenciadorFormatos.Disponivel(Chave) = dfIndisponivel then
    lbl_RecursoFormato.Caption :=
      lbl_RecursoFormato.Caption +
      ' - nao disponivel nesta instalacao do ImageMagick';

  { JPEG nao tem transparencia, WebP e PNG tem. Um controle que nao faz
    sentido para o formato escolhido e desabilitado, em vez de existir e
    ser ignorado em silencio. }
  chk_RemoverFundo.Enabled :=
    TGerenciadorFormatos.Suporta(Chave, rfAlpha) or
    TGerenciadorFormatos.Suporta(Chave, rfTransparencia);
  spn_Qualidade.Enabled := TGerenciadorFormatos.Suporta(Chave, rfQualidade);
  chk_Redimensionar.Enabled :=
    TGerenciadorFormatos.Suporta(Chave, rfRedimensionar);
end;

function TfrImageProc.OpcoesDaTela: TOpcoesConversao;
begin
  Result := FFila.OpcoesPadrao;

  Result.Largura := 0;
  Result.Altura  := 0;
  if chk_Redimensionar.Checked then
  begin
    Result.Redimensionar := True;
    { Zero em qualquer dimensao significa "manter", e e assim que o
      ImageMagick entende o pedido de preservar a proporcao. }
    Result.Largura := spn_Largura.Value;
    if not chk_ManterProporcao.Checked then
      Result.Altura := spn_Altura.Value;
    Result.ManterProporcao := chk_ManterProporcao.Checked;
  end;

  Result.AplicarAlpha     := not chk_RemoverFundo.Checked;
  Result.RemoverMetadados := chk_RemoverMetadados.Checked;

  { So mexe na qualidade quando o controle esta habilitado, que e o mesmo
    teste de capacidade do formato. }
  if spn_Qualidade.Enabled then
    Result.Qualidade := spn_Qualidade.Value;
end;

procedure TfrImageProc.EscreverOpcoesNaTela(const AOpcoes: TOpcoesConversao);
begin
  if not Assigned(chk_Redimensionar) then
    Exit;
  chk_Redimensionar.Checked     := AOpcoes.Redimensionar;
  chk_ManterProporcao.Checked   := AOpcoes.ManterProporcao;
  chk_RemoverFundo.Checked      := not AOpcoes.AplicarAlpha;
  chk_RemoverMetadados.Checked  := AOpcoes.RemoverMetadados;
  if AOpcoes.Largura > 0 then
    spn_Largura.Value := AOpcoes.Largura;
  if AOpcoes.Altura > 0 then
    spn_Altura.Value := AOpcoes.Altura;
  if AOpcoes.Qualidade >= 0 then
    spn_Qualidade.Value := AOpcoes.Qualidade;
  RedimensionarChange(Self);
end;

procedure TfrImageProc.OpcoesAlteradas(Sender: TObject);
begin
  { "Aplicar em todos" faz as opcoes da tela virarem o padrao global da
    fila. Sem essa opcao, mexer nos controles so mudaria o que vier a ser
    selecionado em seguida. }
  if chk_AplicarEmTodos.Checked then
    FFila.DefinirOpcoesPadrao(OpcoesDaTela);
end;

procedure TfrImageProc.RedimensionarChange(Sender: TObject);
begin
  spn_Largura.Enabled         := chk_Redimensionar.Checked;
  { Com a proporcao preservada a altura e calculada pelo ImageMagick a
    partir da largura, entao o campo e bloqueado para nao mandar um valor
    que seria ignorado. }
  spn_Altura.Enabled          := chk_Redimensionar.Checked and
                                  not chk_ManterProporcao.Checked;
  chk_ManterProporcao.Enabled := chk_Redimensionar.Checked;
end;

procedure TfrImageProc.ManterProporcaoClick(Sender: TObject);
begin
  RedimensionarChange(Self);
  if chk_ManterProporcao.Checked then
    spn_Altura.Value := 0
  else if spn_Altura.Value = 0 then
    spn_Altura.Value := spn_Largura.Value;
end;

procedure TfrImageProc.ProcessarClick(Sender: TObject);
begin
  Processar;
end;

procedure TfrImageProc.Processar;
begin
  if FProcessando then
    Exit;
  if FFila.QtPendentes = 0 then
    Exit;

  if TGerenciadorDependencias.Caminho(depImageMagick) = '' then
  begin
    ShowMessage('ImageMagick nao encontrado.' + LineEnding +
      'Defina o caminho em synapse.ini ou coloque magick.exe na pasta tools.');
    Exit;
  end;

  FProcessando       := True;
  FFila.Processando  := True;
  FFila.Cancelado    := False;
  AtualizarControles;

  FConversor := TConversorImagens.Create(FFila);
  try
    FConversor.Executar;

    { O log e copiado antes de liberar o conversor, porque pertence a ele. }
    memo_Log.Lines.Assign(FConversor.Log);
  finally
    FreeAndNil(FConversor);
    FProcessando      := False;
    FFila.Processando := False;
  end;

  AtualizarGeral;
end;

procedure TfrImageProc.CancelarClick(Sender: TObject);
begin
  Cancelar;
end;

procedure TfrImageProc.Cancelar;
begin
  if not FProcessando then
    Exit;
  if Assigned(FConversor) then
    FConversor.Cancelar;
end;

procedure TfrImageProc.ItemDblClick(Sender: TObject);
begin
  if (FFila.Selecionado = nil) then
    Exit;
  AbrirPasta(FFila.Selecionado.CaminhoDestino);
end;

procedure TfrImageProc.AbrirPasta(const APasta: string);
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

  { OpenURL no Windows recebe PWideChar, entao o caminho e convertido
    explicitamente para UnicodeString em vez de relyar na conversao
    implicita de AnsiString. }
  {$IFDEF WINDOWS}
  Destino := 'file:///' + StringReplace(Destino, '\', '/', [rfReplaceAll]);
  Link := UnicodeString(Destino);
  Abriu := OpenURL(PWideChar(Link));
  {$ELSE}
  Destino := 'file://' + Destino;
  Abriu := OpenURL(Destino);
  {$ENDIF}

  if not Abriu then
    ShowMessage('Nao foi possivel abrir a pasta: ' + Destino);
end;

procedure TfrImageProc.AbrirPastaPublico(const APasta: string);
begin
  AbrirPasta(APasta);
end;

end.