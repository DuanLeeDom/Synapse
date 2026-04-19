unit uMain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, EditBtn,
  Menus, ExtCtrls, RTTICtrls, Process, uDependencyManager, LCLIntf, LMessages,
  LCLType, ComCtrls, uSetup, uDiretoDaVinci, uBaixar, uSobre,
  {$IFDEF UNIX}
  Unix
  {$ENDIF}
  {$IFDEF WINDOWS}
  Windows
  {$ENDIF} ;

type
  { TfrmPrincipal }
  TfrmPrincipal = class(TForm)
    btn_Baixador: TButton;
    btn_DiretoDaVinci: TButton;
    btn_Conversor: TButton;
    btn_atividades: TButton;
    btn_fila: TButton;
    btn_previa: TButton;
    btn_predefinidos: TButton;
    btn_Imagem: TButton;
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
    pnl_Principal: TPanel;
    Separator1: TMenuItem;
    Separator2: TMenuItem;
    Separator3: TMenuItem;
    Separator4: TMenuItem;
    Separator5: TMenuItem;
    Separator6: TMenuItem;
    procedure btn_BaixadorClick(Sender: TObject);
    procedure btn_DiretoDaVinciClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure MenuItem10Click(Sender: TObject);
    procedure ExibirFrame(AFrameClass: TCustomFrameClass);
    procedure MenuItem31Click(Sender: TObject);
  private
    FFrameAtivo: TCustomFrame;
  public
  end;

var
  frmPrincipal: TfrmPrincipal;

implementation

{$R *.lfm}

{$IFDEF WINDOWS}
  const BIN_YTDLP = 'yt-dlp.exe';
  const BIN_FFMPEG = 'ffmpeg.exe';
{$ELSE}
  const BIN_YTDLP = 'yt-dlp';
  const BIN_FFMPEG = 'ffmpeg';
{$ENDIF}

{ TfrmPrincipal }

procedure TfrmPrincipal.FormCreate(Sender: TObject);
begin
  ExibirFrame(TfrDiretoDaVinci);
end;

procedure TfrmPrincipal.ExibirFrame(AFrameClass: TCustomFrameClass);
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

procedure TfrmPrincipal.btn_DiretoDaVinciClick(Sender: TObject);
begin
  ExibirFrame(TfrDiretoDaVinci);
end;

procedure TfrmPrincipal.btn_BaixadorClick(Sender: TObject);
begin
  ExibirFrame(TfrBaixar);
end;

procedure TfrmPrincipal.MenuItem31Click(Sender: TObject);
begin
  ExibirFrame(TfrSobre);
end;

procedure TfrmPrincipal.MenuItem10Click(Sender: TObject);
begin
  Close;
end;


end.
