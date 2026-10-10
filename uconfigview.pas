unit uConfigView;

{$mode ObjFPC}{$H+}
{$CODEPAGE UTF8}

interface

uses
  Classes, SysUtils, Forms, Controls, ExtCtrls, StdCtrls, EditBtn, Graphics,
  Dialogs, LCLIntf, uConfig, uDependencias, uProcessos, uCookies;

const
  { Textos acentuados: atribuídos no construtor para não passarem pelo leitor
    de LFM (que usa a codepage do sistema). Não usar UTF8Encode aqui. }
  TEXTO_TITULO      = 'Configurações';
  TEXTO_SUBTITULO   = 'Preferências gerais de download e processamento.';
  TEXTO_GRP_DESTINO = '1. Pasta de destino';
  TEXTO_DESTINO     = 'Pasta padrão onde os arquivos baixados e convertidos são salvos:';
  TEXTO_GRP_NOME    = '2. Nome do arquivo final';
  TEXTO_NOME        = 'Como o arquivo de saída deve ser nomeado:';
  TEXTO_RB_ORIGINAL = 'Usar o título original do vídeo (padrão do yt-dlp)';
  TEXTO_RB_PADRAO   = 'Nome automático do Synapse (com data e hora)';
  TEXTO_RB_DEFINIR  = 'Nome personalizado:';
  TEXTO_GRP_FORMATO = '3. Formato de saída e conversão';
  TEXTO_FORMATO     = 'Formato / resolução de saída:';
  TEXTO_EDITOR      = 'Editor de vídeo (define codecs compatíveis):';
  TEXTO_PROC        = 'Tipo de processamento:';
  TEXTO_RB_CPU      = 'CPU / Processador';
  TEXTO_RB_GPU      = 'GPU / Placa de vídeo';
  TEXTO_OVERSAMPLE  = 'Oversample: forçar o redimensionamento para a resolução escolhida';
  TEXTO_GRP_COOKIES = '4. Cookies (YouTube / "não sou um robô")';
  TEXTO_COOK_INFO   =
    'Para vídeos que exigem login ou exibem "Sign in to confirm you''re not a bot". ' +
    'Fluxo recomendado: abra o login/captcha no navegador, entre na conta, e ' +
    'FECHE o navegador — enquanto ele está aberto o Windows trava o arquivo de ' +
    'cookies e o yt-dlp não consegue lê-lo. O Synapse não lê, copia nem grava o ' +
    'conteúdo dos cookies: só repassa o navegador ou o caminho do arquivo ao yt-dlp.';
  TEXTO_RB_COOK_NENHUM = 'Não usar cookies';
  TEXTO_RB_COOK_NAVEG  = 'Usar navegador:';
  TEXTO_BTN_LOGIN      = '1) Abrir login/captcha';
  TEXTO_BTN_FECHAR     = '2) Fechar navegador (liberar cookies)';
  TEXTO_RB_COOK_ARQ    = 'Usar arquivo cookies.txt:';
  TEXTO_BTN_PROCURAR   = 'Procurar...';
  TEXTO_BTN_EXPORTAR   = 'Exportar do navegador (.txt)';
  TEXTO_CHK_ATUAL      = 'Verificar atualizações ao abrir o Synapse';
  TEXTO_BTN_SALVAR     = 'Salvar configurações';
  TEXTO_BTN_RESTAURAR  = 'Restaurar padrões';

type
  TfrConfigView = class(TFrame)
    Sb: TScrollBox;
    Conteudo: TPanel;
    LblTitulo: TLabel;
    LblSubtitulo: TLabel;
    grpDestino: TGroupBox;
    lblDestino: TLabel;
    FDirectory: TDirectoryEdit;
    grpNome: TGroupBox;
    lblNome: TLabel;
    FRbOriginal: TRadioButton;
    FRbPadrao: TRadioButton;
    FRbDefinir: TRadioButton;
    FEdtNome: TEdit;
    grpFormato: TGroupBox;
    lblFormato: TLabel;
    lblEditor: TLabel;
    lblProc: TLabel;
    FCmbFormato: TComboBox;
    FCmbEditor: TComboBox;
    FRbCpu: TRadioButton;
    FRbGpu: TRadioButton;
    FChkOversample: TCheckBox;
    grpCookies: TGroupBox;
    lblCookInfo: TLabel;
    FRbCookNenhum: TRadioButton;
    FRbCookNaveg: TRadioButton;
    FCmbNavegador: TComboBox;
    FBtnLogin: TButton;
    FBtnFechar: TButton;
    FRbCookArquivo: TRadioButton;
    FEdtArquivo: TEdit;
    FBtnProcurar: TButton;
    FBtnExportar: TButton;
    FLblCookAviso: TLabel;
    FChkAtualizacoes: TCheckBox;
    BtnSalvar: TButton;
    BtnRestaurar: TButton;
    FLblStatus: TLabel;
    procedure RbModoChange(Sender: TObject);
    procedure RbCookChange(Sender: TObject);
    procedure BtnLoginClick(Sender: TObject);
    procedure BtnFecharClick(Sender: TObject);
    procedure BtnProcurarClick(Sender: TObject);
    procedure BtnExportarClick(Sender: TObject);
    procedure BtnSalvarClick(Sender: TObject);
    procedure BtnRestaurarClick(Sender: TObject);
  private
    procedure PreencherCombo(ACmb: TComboBox; const ANomes: array of string);
    procedure AtualizarHabilitacao;
    procedure AtualizarDicaCookies;
    procedure Aplicar;
    procedure MostrarStatus(const ATexto: string; AErro: Boolean);
  public
    constructor Create(AOwner: TComponent); override;
  end;

implementation

{$R *.lfm}

constructor TfrConfigView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  LblTitulo.Caption        := TEXTO_TITULO;
  LblSubtitulo.Caption     := TEXTO_SUBTITULO;
  grpDestino.Caption       := TEXTO_GRP_DESTINO;
  lblDestino.Caption       := TEXTO_DESTINO;
  grpNome.Caption          := TEXTO_GRP_NOME;
  lblNome.Caption          := TEXTO_NOME;
  FRbOriginal.Caption      := TEXTO_RB_ORIGINAL;
  FRbPadrao.Caption        := TEXTO_RB_PADRAO;
  FRbDefinir.Caption       := TEXTO_RB_DEFINIR;
  grpFormato.Caption       := TEXTO_GRP_FORMATO;
  lblFormato.Caption       := TEXTO_FORMATO;
  lblEditor.Caption        := TEXTO_EDITOR;
  lblProc.Caption          := TEXTO_PROC;
  FRbCpu.Caption           := TEXTO_RB_CPU;
  FRbGpu.Caption           := TEXTO_RB_GPU;
  FChkOversample.Caption   := TEXTO_OVERSAMPLE;
  grpCookies.Caption       := TEXTO_GRP_COOKIES;
  lblCookInfo.Caption      := TEXTO_COOK_INFO;
  FRbCookNenhum.Caption    := TEXTO_RB_COOK_NENHUM;
  FRbCookNaveg.Caption     := TEXTO_RB_COOK_NAVEG;
  FBtnLogin.Caption        := TEXTO_BTN_LOGIN;
  FBtnFechar.Caption       := TEXTO_BTN_FECHAR;
  FRbCookArquivo.Caption   := TEXTO_RB_COOK_ARQ;
  FBtnProcurar.Caption     := TEXTO_BTN_PROCURAR;
  FBtnExportar.Caption     := TEXTO_BTN_EXPORTAR;
  FChkAtualizacoes.Caption := TEXTO_CHK_ATUAL;
  BtnSalvar.Caption        := TEXTO_BTN_SALVAR;
  BtnRestaurar.Caption     := TEXTO_BTN_RESTAURAR;

  PreencherCombo(FCmbFormato, FORMATOS_VIDEO_NOMES);
  PreencherCombo(FCmbEditor, EDITORES_NOMES);
  PreencherCombo(FCmbNavegador, NAVEGADORES_NOMES);

  Aplicar;
end;

procedure TfrConfigView.PreencherCombo(ACmb: TComboBox;
  const ANomes: array of string);
var
  i: Integer;
begin
  ACmb.Items.BeginUpdate;
  try
    ACmb.Items.Clear;
    for i := Low(ANomes) to High(ANomes) do
      ACmb.Items.Add(ANomes[i]);
  finally
    ACmb.Items.EndUpdate;
  end;
end;

procedure TfrConfigView.AtualizarHabilitacao;
begin
  FEdtNome.Enabled := FRbDefinir.Checked;
  FCmbNavegador.Enabled := FRbCookNaveg.Checked;
  FBtnLogin.Enabled := FRbCookNaveg.Checked;
  FBtnFechar.Enabled := FRbCookNaveg.Checked and (FCmbNavegador.ItemIndex > 0);
  FEdtArquivo.Enabled := FRbCookArquivo.Checked;
  FBtnProcurar.Enabled := FRbCookArquivo.Checked;
  FBtnExportar.Enabled := FRbCookNaveg.Checked and (FCmbNavegador.ItemIndex > 0);
  AtualizarDicaCookies;
end;

{ Mostra, abaixo do grupo de cookies, se o navegador escolhido está aberto.
  Estando aberto, o yt-dlp não consegue copiar o banco de cookies e o download
  falha; por isso o aviso em vermelho e a instrução de fechar o navegador. }
procedure TfrConfigView.AtualizarDicaCookies;
var
  Token: string;
begin
  if FRbCookArquivo.Checked then
  begin
    FLblCookAviso.Font.Color := clGray;
    FLblCookAviso.Caption := 'Modo por arquivo: informe um cookies.txt exportado ' +
      'do navegador (o navegador pode ficar aberto nesse modo).';
    Exit;
  end;

  if not (FRbCookNaveg.Checked and (FCmbNavegador.ItemIndex > 0)) then
  begin
    FLblCookAviso.Font.Color := clGray;
    FLblCookAviso.Caption := '';
    Exit;
  end;

  Token := NAVEGADORES_TOKENS[FCmbNavegador.ItemIndex];
  if NavegadorEmExecucao(Token) then
  begin
    FLblCookAviso.Font.Color := clRed;
    FLblCookAviso.Caption := FCmbNavegador.Text + ' está aberto: o arquivo de ' +
      'cookies fica travado e o yt-dlp falha. Feche o navegador (botão ao lado) ' +
      'antes de baixar.';
  end
  else
  begin
    FLblCookAviso.Font.Color := clGreen;
    FLblCookAviso.Caption := FCmbNavegador.Text + ' está fechado: os cookies estão ' +
      'liberados para o yt-dlp.';
  end;
end;

procedure TfrConfigView.RbModoChange(Sender: TObject);
begin
  AtualizarHabilitacao;
end;

procedure TfrConfigView.RbCookChange(Sender: TObject);
begin
  AtualizarHabilitacao;
end;

procedure TfrConfigView.MostrarStatus(const ATexto: string; AErro: Boolean);
begin
  FLblStatus.Caption := ATexto;
  if AErro then
    FLblStatus.Font.Color := clRed
  else
    FLblStatus.Font.Color := clGreen;
end;

procedure TfrConfigView.Aplicar;
var
  C: TConfiguracoes;
begin
  C := Configuracoes;
  FDirectory.Directory := C.PastaDestinoEfetiva;

  case C.ModoNome of
    MODO_NOME_PADRAO : FRbPadrao.Checked  := True;
    MODO_NOME_DEFINIR: FRbDefinir.Checked := True;
  else
    FRbOriginal.Checked := True;
  end;
  FEdtNome.Text := C.NomeArquivo;

  if (C.FormatoVideo >= 0) and (C.FormatoVideo < FCmbFormato.Items.Count) then
    FCmbFormato.ItemIndex := C.FormatoVideo
  else
    FCmbFormato.ItemIndex := 0;

  if (C.EditorVideo >= 0) and (C.EditorVideo < FCmbEditor.Items.Count) then
    FCmbEditor.ItemIndex := C.EditorVideo
  else
    FCmbEditor.ItemIndex := 0;

  if C.Processamento = PROCESSO_GPU then
    FRbGpu.Checked := True
  else
    FRbCpu.Checked := True;

  FChkOversample.Checked := C.Oversample;

  case C.ModoCookies of
    COOKIES_NAVEGADOR: FRbCookNaveg.Checked := True;
    COOKIES_ARQUIVO  : FRbCookArquivo.Checked := True;
  else
    FRbCookNenhum.Checked := True;
  end;
  if (C.NavegadorCookies >= 0) and (C.NavegadorCookies < FCmbNavegador.Items.Count) then
    FCmbNavegador.ItemIndex := C.NavegadorCookies
  else
    FCmbNavegador.ItemIndex := 0;
  FEdtArquivo.Text := C.ArquivoCookies;

  FChkAtualizacoes.Checked := C.VerificaAtual;

  AtualizarHabilitacao;
end;

procedure TfrConfigView.BtnLoginClick(Sender: TObject);
var
  Token: string;
begin
  if not FRbCookNaveg.Checked then
    Exit;
  Token := NAVEGADORES_TOKENS[FCmbNavegador.ItemIndex];
  if Token = '' then
  begin
    MostrarStatus('Selecione um navegador diferente de "Não usar cookies".', True);
    Exit;
  end;
  try
    OpenURL('https://www.youtube.com/');
    MostrarStatus('Página do YouTube aberta. Faça login e resolva o captcha; ' +
      'depois feche o navegador para liberar os cookies.', False);
    AtualizarDicaCookies;
  except
    on E: Exception do
      MostrarStatus('Não foi possível abrir o navegador: ' + E.Message, True);
  end;
end;

procedure TfrConfigView.BtnFecharClick(Sender: TObject);
var
  Token: string;
begin
  if not (FRbCookNaveg.Checked and (FCmbNavegador.ItemIndex > 0)) then
    Exit;

  Token := NAVEGADORES_TOKENS[FCmbNavegador.ItemIndex];
  if not NavegadorEmExecucao(Token) then
  begin
    MostrarStatus(FCmbNavegador.Text + ' já está fechado.', False);
    AtualizarDicaCookies;
    Exit;
  end;

  if MessageDlg('Fechar todas as janelas do ' + FCmbNavegador.Text + '?',
    'O yt-dlp só consegue ler os cookies com o navegador fechado. ' +
    'Feche o ' + FCmbNavegador.Text + ' (o aplicativo fará isso agora) para ' +
    'liberar o arquivo de cookies. Salve o que estiver fazendo nele antes de continuar.',
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;

  MostrarStatus('Fechando ' + FCmbNavegador.Text + '...', False);
  if FecharNavegador(Token) then
    MostrarStatus(FCmbNavegador.Text + ' fechado. Cookies liberados para o download.', False)
  else
    MostrarStatus('Não foi possível fechar o ' + FCmbNavegador.Text +
      '. Feche-o manualmente antes de baixar.', True);
  AtualizarDicaCookies;
end;

procedure TfrConfigView.BtnProcurarClick(Sender: TObject);
var
  Dlg: TOpenDialog;
begin
  Dlg := TOpenDialog.Create(Self);
  try
    Dlg.Title := 'Selecionar arquivo cookies.txt';
    Dlg.Filter := 'Arquivos de cookies (*.txt)|*.txt|Todos os arquivos (*.*)|*.*';
    Dlg.DefaultExt := 'txt';
    Dlg.FileName := FEdtArquivo.Text;
    if Dlg.Execute then
    begin
      FEdtArquivo.Text := Dlg.FileName;
      FRbCookArquivo.Checked := True;
      AtualizarHabilitacao;
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TfrConfigView.BtnExportarClick(Sender: TObject);
var
  Token, CookiesTxt, Saida, Yt: string;
  Args: TStringList;
  Cod: Integer;
begin
  if not FRbCookNaveg.Checked then
    Exit;
  Token := NAVEGADORES_TOKENS[FCmbNavegador.ItemIndex];
  if Token = '' then
  begin
    MostrarStatus('Selecione um navegador válido.', True);
    Exit;
  end;

  Yt := TGerenciadorDependencias.Caminho(depYtDlp);
  if (Yt = '') or (not FileExists(Yt)) then
  begin
    MostrarStatus('yt-dlp não encontrado. Configure as dependências.', True);
    Exit;
  end;

  { A exportação também precisa copiar o banco de cookies, então o navegador
    precisa estar fechado aqui também. }
  if NavegadorEmExecucao(Token) then
  begin
    MostrarStatus('Feche o ' + FCmbNavegador.Text + ' antes de exportar os cookies.', True);
    Exit;
  end;

  CookiesTxt := IncludeTrailingPathDelimiter(TGerenciadorDependencias.BaseDir) + 'cookies_export.txt';
  Args := TStringList.Create;
  try
    Args.Add('--cookies-from-browser');
    Args.Add(Token);
    Args.Add('--cookies');
    Args.Add(CookiesTxt);
    Args.Add('--skip-download');
    Args.Add('https://www.youtube.com/');
    MostrarStatus('Exportando cookies do ' + FCmbNavegador.Text + '...', False);
    if not TGerenciadorProcessos.CapturarSaida(Yt, Args, 30000, Saida, Cod) then
    begin
      MostrarStatus('Falha ao exportar cookies (timeout ou erro).', True);
      Exit;
    end;
    if not FileExists(CookiesTxt) then
    begin
      MostrarStatus('Exportação concluída, mas o arquivo de cookies não foi gerado.', True);
      Exit;
    end;
    FEdtArquivo.Text := CookiesTxt;
    FRbCookArquivo.Checked := True;
    AtualizarHabilitacao;
    MostrarStatus('Cookies exportados para ' + CookiesTxt + '. Salve as configurações.', False);
  finally
    Args.Free;
  end;
end;

procedure TfrConfigView.BtnRestaurarClick(Sender: TObject);
begin
  Configuracoes.RestaurarPadroes;
  Aplicar;
  MostrarStatus('Padrões restaurados e salvos.', False);
end;

procedure TfrConfigView.BtnSalvarClick(Sender: TObject);
var
  C: TConfiguracoes;
begin
  if FRbCookNaveg.Checked and (FCmbNavegador.ItemIndex <= 0) then
  begin
    MostrarStatus('Selecione um navegador para usar os cookies.', True);
    Exit;
  end;
  if FRbCookArquivo.Checked and (Trim(FEdtArquivo.Text) = '') then
  begin
    MostrarStatus('Selecione ou exporte um arquivo cookies.txt.', True);
    Exit;
  end;

  C := Configuracoes;
  C.PastaDestino := FDirectory.Directory;
  if FRbPadrao.Checked then
    C.ModoNome := MODO_NOME_PADRAO
  else if FRbDefinir.Checked then
    C.ModoNome := MODO_NOME_DEFINIR
  else
    C.ModoNome := MODO_NOME_YTDLP;
  C.NomeArquivo := FEdtNome.Text;
  C.FormatoVideo := FCmbFormato.ItemIndex;
  C.EditorVideo := FCmbEditor.ItemIndex;
  if FRbGpu.Checked then
    C.Processamento := PROCESSO_GPU
  else
    C.Processamento := PROCESSO_CPU;
  C.Oversample := FChkOversample.Checked;
  if FRbCookNaveg.Checked then
    C.ModoCookies := COOKIES_NAVEGADOR
  else if FRbCookArquivo.Checked then
    C.ModoCookies := COOKIES_ARQUIVO
  else
    C.ModoCookies := COOKIES_NENHUM;
  C.NavegadorCookies := FCmbNavegador.ItemIndex;
  C.ArquivoCookies := Trim(FEdtArquivo.Text);
  C.VerificaAtual := FChkAtualizacoes.Checked;

  try
    C.Salvar;
    AtualizarDicaCookies;
    if (C.ModoCookies = COOKIES_NAVEGADOR) and NavegadorEmExecucao(C.TokenNavegador) then
      MostrarStatus('Configurações salvas. Atenção: o ' + FCmbNavegador.Text +
        ' está aberto e travará os cookies até ser fechado.', True)
    else
      MostrarStatus('Configurações salvas.', False);
  except
    on E: Exception do
      MostrarStatus('Não foi possível salvar: ' + E.Message, True);
  end;
end;

end.
