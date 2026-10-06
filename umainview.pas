unit uMainView;

{$mode objfpc}{$H+}
{$CODEPAGE UTF8}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, EditBtn,
  Menus, ExtCtrls, RTTICtrls, Process, uDependencyManager, LCLIntf, LMessages,
  LCLType, ComCtrls, uMediaPipeline, uDownloadService, uAboutView,
  uImageProcView,
  {$IFDEF UNIX}
  Unix
  {$ENDIF}
  {$IFDEF WINDOWS}
  Windows
  {$ENDIF} ;

type
  { TfrmMainView }
  TfrmMainView = class(TForm)
    btn_DownloadService: TButton;
    btn_MediaPipeline: TButton;
    btn_VideoProcessor: TButton;
    btn_atividades: TButton;
    btn_fila: TButton;
    btn_previa: TButton;
    btn_predefinidos: TButton;
    btn_ImageProcessor: TButton;
    GroupBox_Options2: TGroupBox;
    MenuItem1: TMenuItem;
    MenuItem10: TMenuItem;
    MenuItem11: TMenuItem;
    MenuItem12: TMenuItem;
    MenuItem13: TMenuItem;
    MenuItem14: TMenuItem;
    MenuItem15: TMenuItem;
    MenuItem16: TMenuItem;
    MenuItem17: TMenuItem;
    MenuItem18: TMenuItem;
    MenuItem19: TMenuItem;
    MenuItem2: TMenuItem;
    MenuItem20: TMenuItem;
    MenuItem21: TMenuItem;
    MenuItem22: TMenuItem;
    MenuItem23: TMenuItem;
    MenuItem24: TMenuItem;
    MenuItem25: TMenuItem;
    MenuItem26: TMenuItem;
    MenuItem27: TMenuItem;
    MenuItem28: TMenuItem;
    MenuItem29: TMenuItem;
    MenuItem3: TMenuItem;
    MenuItem30: TMenuItem;
    MenuItem31: TMenuItem;
    MenuItem4: TMenuItem;
    MenuItem5: TMenuItem;
    MenuItem6: TMenuItem;
    MenuItem7: TMenuItem;
    MenuItem8: TMenuItem;
    MenuItem9: TMenuItem;
    mnuPrincipal: TMainMenu;
    pnl_Conteiner: TPanel;
    pnl_MainView: TPanel;
    Separator1: TMenuItem;
    Separator2: TMenuItem;
    Separator3: TMenuItem;
    Separator4: TMenuItem;
    Separator5: TMenuItem;
    Separator6: TMenuItem;
    procedure btn_DownloadServiceClick(Sender: TObject);
    procedure btn_MediaPipelineClick(Sender: TObject);
    procedure btn_ImageProcessorClick(Sender: TObject);
    procedure btn_VideoProcessorClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure MenuItem10Click(Sender: TObject);
    procedure ExibirFrame(AFrameClass: TCustomFrameClass);
    procedure MenuItem30Click(Sender: TObject);
    procedure MenuItem31Click(Sender: TObject);
    procedure btn_filaClick(Sender: TObject);
    procedure MenuItem11Click(Sender: TObject);
    procedure MenuItem12Click(Sender: TObject);
    procedure MenuItem13Click(Sender: TObject);
    procedure MenuItem14Click(Sender: TObject);
    procedure MenuItem15Click(Sender: TObject);
    procedure MenuItem19Click(Sender: TObject);
  private
    FFrameAtivo: TCustomFrame;
  public
  end;

var
  frmMainView: TfrmMainView;

implementation

{$R *.lfm}

{$IFDEF WINDOWS}
  const BIN_YTDLP = 'yt-dlp.exe';
  const BIN_FFMPEG = 'ffmpeg.exe';
{$ELSE}
  const BIN_YTDLP = 'yt-dlp';
  const BIN_FFMPEG = 'ffmpeg';
{$ENDIF}

{ TfrmMainView }

procedure TfrmMainView.FormCreate(Sender: TObject);
begin
  { Texto com acento definido por codigo: o leitor de LFM usa a codepage do
    sistema e quebraria o texto. Ver TEXTO_BOTAO em uAboutView. }
  MenuItem30.Caption := TEXTO_BOTAO;
  ExibirFrame(TfrMediaPipeline);
end;

procedure TfrmMainView.ExibirFrame(AFrameClass: TCustomFrameClass);
begin
  if Assigned(FFrameAtivo) then
  begin
    FreeAndNil(FFrameAtivo);
  end;
  FFrameAtivo := AFrameClass.Create(Self);
  FFrameAtivo.Parent := pnl_Conteiner;
  FFrameAtivo.Align := alClient;
  FFrameAtivo.Visible := True;
end;

procedure TfrmMainView.btn_MediaPipelineClick(Sender: TObject);
begin
  ExibirFrame(TfrMediaPipeline);
end;

{ Processamento em lote de imagens. O frame e recriado a cada exibicao, mas
  a fila e um singleton: trocar de aba e voltar nao perde os itens. }
procedure TfrmMainView.btn_ImageProcessorClick(Sender: TObject);
begin
  ExibirFrame(TfrImageProc);
end;

procedure TfrmMainView.btn_VideoProcessorClick(Sender: TObject);
begin
  ExibirFrame(TfrMediaPipeline);
end;

procedure TfrmMainView.btn_DownloadServiceClick(Sender: TObject);
begin
  ExibirFrame(TfrDownloadService);
end;

procedure TfrmMainView.MenuItem30Click(Sender: TObject);
var
  Abriu: Boolean;
  Link: UnicodeString;
begin
  { Documentacao online no repositorio oficial. O mesmo endereco e usado pelos
    botoes da tela Sobre. No Windows o OpenURL espera PWideChar, entao a string
    e passada como UnicodeString explicita. }
  Link := UnicodeString(URL_REPOSITORIO);
  {$IFDEF WINDOWS}
  Abriu := OpenURL(PWideChar(Link));
  {$ELSE}
  Abriu := OpenURL(Link);
  {$ENDIF}

  if not Abriu then
    ShowMessage('Não foi possível abrir a documentação online no navegador.' + LineEnding +
      URL_REPOSITORIO);
end;

procedure TfrmMainView.MenuItem31Click(Sender: TObject);
begin
  ExibirFrame(TfrAboutView);
end;

{ Atalho para o pipeline quando outro frame está em exibicao. }

procedure TfrmMainView.btn_filaClick(Sender: TObject);
begin
  ExibirFrame(TfrMediaPipeline);
end;

procedure TfrmMainView.MenuItem11Click(Sender: TObject);
begin
  if not (FFrameAtivo is TfrMediaPipeline) then
  begin
    ExibirFrame(TfrMediaPipeline);
    Exit;
  end;
  TfrMediaPipeline(FFrameAtivo).AdicionarURLDaFila;
end;

procedure TfrmMainView.MenuItem12Click(Sender: TObject);
begin
  if not (FFrameAtivo is TfrMediaPipeline) then
  begin
    ExibirFrame(TfrMediaPipeline);
    Exit;
  end;
  TfrMediaPipeline(FFrameAtivo).AdicionarArquivosNaFila;
end;

procedure TfrmMainView.MenuItem13Click(Sender: TObject);
begin
  if not (FFrameAtivo is TfrMediaPipeline) then
  begin
    ExibirFrame(TfrMediaPipeline);
    Exit;
  end;
  TfrMediaPipeline(FFrameAtivo).AdicionarTodosDaFila;
end;

procedure TfrmMainView.MenuItem14Click(Sender: TObject);
begin
  if not (FFrameAtivo is TfrMediaPipeline) then
    ExibirFrame(TfrMediaPipeline)
  else
    TfrMediaPipeline(FFrameAtivo).IniciarFila;
end;

procedure TfrmMainView.MenuItem15Click(Sender: TObject);
begin
  if (FFrameAtivo is TfrMediaPipeline) then
    TfrMediaPipeline(FFrameAtivo).CancelarFila;
end;

procedure TfrmMainView.MenuItem19Click(Sender: TObject);
begin
  ExibirFrame(TfrMediaPipeline);
  TfrMediaPipeline(FFrameAtivo).EnfocarFila;
end;

procedure TfrmMainView.MenuItem10Click(Sender: TObject);
begin
  Close;
end;


end.
