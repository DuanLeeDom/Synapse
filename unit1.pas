unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, EditBtn,
  Menus, ExtCtrls, RTTICtrls, Process, Unit_Setup;

type
  { TfrmPrincipal }
  TfrmPrincipal = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    Button4: TButton;
    Button5: TButton;
    Button6: TButton;
    Button7: TButton;
    button_process: TButton;
    button_process1: TButton;
    ComboBox_options: TComboBox;
    ComboBox_Formatos: TComboBox;
    DirectoryEdit: TDirectoryEdit;
    DirectoryEdit1: TDirectoryEdit;
    GroupBox1: TGroupBox;
    GroupBox2: TGroupBox;
    GroupBox3: TGroupBox;
    GroupBox_Sobre: TGroupBox;
    GroupBox_Console1: TGroupBox;
    GroupBox_DiretoDaVinci: TGroupBox;
    GroupBox_Baixador: TGroupBox;
    GroupBox_Export1: TGroupBox;
    GroupBox_Options: TGroupBox;
    GroupBoxPrincipal: TGroupBox;
    GroupBox_Options1: TGroupBox;
    GroupBox_Source: TGroupBox;
    GroupBox_Export: TGroupBox;
    GroupBox_Console: TGroupBox;
    GroupBox_Source1: TGroupBox;
    Image1: TImage;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    lbl_info: TLabel;
    Memo_visual_console1: TMemo;
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
    Separator1: TMenuItem;
    Separator2: TMenuItem;
    Separator3: TMenuItem;
    Separator4: TMenuItem;
    Separator5: TMenuItem;
    Separator6: TMenuItem;
    url_web: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    Memo_visual_console: TMemo;
    url_web1: TEdit;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure button_processClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure MenuItem10Click(Sender: TObject);
    procedure MenuItem31Click(Sender: TObject);
    procedure MudarTela(Alvo: TGroupBox);
  private
    FVerificado: Boolean;
    function GetFFmpegProfile(Index: Integer): string;
  public
  end;

var
  frmPrincipal: TfrmPrincipal;

implementation

{$R *.lfm}

{ TfrmPrincipal }

procedure TfrmPrincipal.FormCreate(Sender: TObject);
begin
  FVerificado := False; // Garante que a verificação comece do zero
end;

procedure TfrmPrincipal.FormShow(Sender: TObject);
var
  DistroNome, Msg: string;
begin
  // 1. Bloqueio de repetição
  if FVerificado = True then
  begin
    Form_Setup.Show;
  end
  else
  begin
    Form_Setup.Show;
  end;

  // 2. Verificação Inicial: Os programas já existem no Linux?
  if not Form_Setup.VerificarAmbiente then
  begin
    DistroNome := Form_Setup.NomeDoSistema;
    if DistroNome = '' then DistroNome := 'Linux';

    Msg := 'Sistema Detectado: ' + DistroNome + sLineBreak +
           '🛠️ Status: yt-dlp ou ffmpeg não encontrados.' + sLineBreak +
           'O assistente de configuração será aberto agora.';

    MessageDlg('Configuração Necessária', Msg, mtInformation, [mbOK], 0);

    // ABRE O SETUP: O código para aqui e espera o usuário terminar o Setup
    if Form_Setup.ShowModal <> mrOk then
    begin
      // Se ele fechou o setup sem instalar ou deu erro, encerra o programa todo
      Application.Terminate;
      Exit;
    end;
  end;

  // 3. Chegando aqui, o ambiente está OK (ou já estava ou foi instalado agora)
  FVerificado := True;

  // 4. Configuração visual inicial (O que o usuário vê primeiro)
  MudarTela(GroupBox_DiretoDaVinci);

  // Preenche as opções de conversão
  ComboBox_options.Items.Clear;
  ComboBox_options.Items.Add('Master: DNxHR HQX (10-bit .MOV)');
  ComboBox_options.Items.Add('Proxy: DNxHR LB (Leve .MOV)');
  ComboBox_options.Items.Add('Audio: PCM High-End (24-bit .WAV)');
  ComboBox_options.ItemIndex := 0;

  // Preenche as opções do baixador comum
  ComboBox_Formatos.Items.Clear;
  ComboBox_Formatos.Items.Add('MP4 (H.264 + AAC)');
  ComboBox_Formatos.Items.Add('MKV (Matroska)');
  ComboBox_Formatos.Items.Add('MP3 (Apenas Áudio)');
  ComboBox_Formatos.ItemIndex := 0;

  // 5. Define pasta padrão de vídeos
  if DirectoryExists(GetEnvironmentVariable('HOME') + '/Vídeos') then
     DirectoryEdit.Directory := GetEnvironmentVariable('HOME') + '/Vídeos'
  else
     DirectoryEdit.Directory := GetCurrentDir;

  // 6. Log de Boas-vindas no Console
  Memo_visual_console.Lines.Clear;
  Memo_visual_console.Lines.Add('[SISTEMA] Synapse Media Tool Iniciada.');
  Memo_visual_console.Lines.Add('[SISTEMA] Distribuição: ' + Form_Setup.NomeDoSistema);
  Memo_visual_console.Lines.Add('[OK] Ambiente pronto para o DaVinci Resolve.');

  Self.Repaint;
end;

procedure TfrmPrincipal.MenuItem10Click(Sender: TObject);
begin
  Close;
end;

procedure TfrmPrincipal.MudarTela(Alvo: TGroupBox);
begin
  // 1. Esconde TODAS as telas primeiro
    GroupBox_DiretoDaVinci.Visible := False;
    GroupBox_Baixador.Visible := False;
    GroupBox_Sobre.Visible := False;
    // Adicione aqui os próximos GroupBox que criar (Conversor, etc)

    // 2. Mostra apenas a que foi pedida
    if Assigned(Alvo) then
      Alvo.Visible := True;
end;


function TfrmPrincipal.GetFFmpegProfile(Index: Integer): string;
begin
  // Perfis otimizados para edição no DaVinci Resolve (DNxHR)
  case Index of
    0: Result := '-c:v dnxhd -profile:v 4 -pix_fmt yuv422p10le -c:a pcm_s16le';
    1: Result := '-c:v dnxhd -profile:v 1 -pix_fmt yuv422p -c:a pcm_s16le';
    2: Result := '-vn -c:a pcm_s24le';
    else Result := '-c:v copy -c:a copy';
  end;
end;

procedure TfrmPrincipal.button_processClick(Sender: TObject);
var
  AProcess: TProcess;
  Cmd, Ext: string;
begin
  // Validação básica de entrada
  if (url_web.Text = '') or (DirectoryEdit.Directory = '') then
  begin
    ShowMessage('Por favor, insira a URL e selecione a pasta de destino!');
    Exit;
  end;

  // Define extensão baseada na escolha do ComboBox (Audio = .wav, Vídeo = .mov)
  if ComboBox_options.ItemIndex = 2 then Ext := '.wav' else Ext := '.mov';

  Memo_visual_console.Clear;
  Memo_visual_console.Lines.Add('[INFO] Iniciando processo via Terminal...');

  AProcess := TProcess.Create(nil);
  try
    // Montagem do comando: baixa via yt-dlp e converte via FFmpeg em pipeline
    Cmd := Format('yt-dlp -P "%s" "%s" --exec "ffmpeg -y -i {} %s ''%s/davinci_ready_%s%s''"', [
      DirectoryEdit.Directory,
      url_web.Text,
      GetFFmpegProfile(ComboBox_options.ItemIndex),
      DirectoryEdit.Directory,
      FormatDateTime('hhnnss', Now),
      Ext
    ]);

    AProcess.Executable := '/usr/bin/bash';
    AProcess.Parameters.Add('-c');
    AProcess.Parameters.Add(Cmd);

    // poStderrToOutPut é vital para ver o progresso do ffmpeg no Memo
    AProcess.Options := [poUsePipes, poStderrToOutPut, poWaitOnExit];

    button_process.Enabled := False;
    button_process.Caption := 'AGUARDE...';
    Application.ProcessMessages;

    AProcess.Execute;

    // Carrega a saída do terminal no Memo para o usuário acompanhar
    Memo_visual_console.Lines.LoadFromStream(AProcess.Output);

    if AProcess.ExitCode <> 0 then
       Memo_visual_console.Lines.Add('[ERRO] Ocorreu um problema no processamento.')
    else
       Memo_visual_console.Lines.Add('[SUCESSO] Arquivo pronto para o DaVinci Resolve!');

  finally
    button_process.Enabled := True;
    button_process.Caption := 'PROCESSAR';
    AProcess.Free;
  end;
end;

procedure TfrmPrincipal.Button1Click(Sender: TObject);
begin
  MudarTela(GroupBox_DiretoDaVinci);
end;

procedure TfrmPrincipal.Button2Click(Sender: TObject);
begin
  MudarTela(GroupBox_Baixador);
end;

procedure TfrmPrincipal.MenuItem31Click(Sender: TObject);
begin
  MudarTela(GroupBox_Sobre);
end;

end.
