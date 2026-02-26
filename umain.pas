unit uMain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, EditBtn,
  Menus, ExtCtrls, RTTICtrls, Process, uDependencyManager, LCLIntf, LMessages,
  LCLType, ComCtrls, uSetup,
  {$IFDEF UNIX}
  Unix,
  {$ENDIF}
  {$IFDEF WINDOWS}
  Windows;
  {$ENDIF}

type
  { TfrmPrincipal }
  TfrmPrincipal = class(TForm)
    btn_DiretoDaVinci: TButton;
    btn_Baixador: TButton;
    Button3: TButton;
    Button4: TButton;
    Button5: TButton;
    Button6: TButton;
    Button7: TButton;
    Button8: TButton;
    button_process1: TButton;
    button_process_DiretoDaVinci: TButton;
    ComboBox_Format_Audios: TComboBox;
    ComboBox_Formatos: TComboBox;
    ComboBox_Format_Videos: TComboBox;
    ComboBox_options: TComboBox;
    DirectoryEdit1: TDirectoryEdit;
    DirectoryEdit: TDirectoryEdit;
    edt_definir: TEdit;
    GroupBox1: TGroupBox;
    GroupBox2: TGroupBox;
    GroupBox3: TGroupBox;
    GroupBox_Console2: TGroupBox;
    GroupBox_DiretoDaVinci: TGroupBox;
    GroupBox_Export2: TGroupBox;
    GroupBox_Export3: TGroupBox;
    GroupBox_Options2: TGroupBox;
    GroupBox_Sobre: TGroupBox;
    GroupBox_Console1: TGroupBox;
    GroupBox_Baixador: TGroupBox;
    GroupBox_Export1: TGroupBox;
    GroupBoxPrincipal: TGroupBox;
    GroupBox_Options1: TGroupBox;
    GroupBox_Source1: TGroupBox;
    GroupBox_Source2: TGroupBox;
    Image1: TImage;
    Label10: TLabel;
    Label11: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Label9: TLabel;
    lbl_info: TLabel;
    Memo_visual_console1: TMemo;
    Memo_visual_console: TMemo;
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
    pbar_console: TProgressBar;
    rbtm_ytdlp: TRadioButton;
    rbtm_definir: TRadioButton;
    rbtm_padrao: TRadioButton;
    Separator1: TMenuItem;
    Separator2: TMenuItem;
    Separator3: TMenuItem;
    Separator4: TMenuItem;
    Separator5: TMenuItem;
    Separator6: TMenuItem;
    url_web1: TEdit;
    url_web: TEdit;
    procedure btn_DiretoDaVinciClick(Sender: TObject);
    procedure btn_BaixadorClick(Sender: TObject);
    procedure button_process_DiretoDaVinciClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure MenuItem10Click(Sender: TObject);
    procedure MenuItem31Click(Sender: TObject);
    procedure MudarTela(Alvo: TGroupBox);
  private
    FVerificado: Boolean;
    FCancelar: Boolean;
    function GetFFmpegProfile(Index: Integer): string;
    function GetYtdlpFormat(Index: Integer): string;
    function GerarIDAleatorio(Tamanho: Integer): string;
    function GetAudioCodecParams(Index: Integer): string;
    procedure ConfigurarInterface;
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
  FVerificado := False;
  ConfigurarInterface;
end;

procedure TfrmPrincipal.MudarTela(Alvo: TGroupBox);
begin
  GroupBox_DiretoDaVinci.Visible := False;
  GroupBox_Baixador.Visible := False;
  GroupBox_Sobre.Visible := False;

  if Assigned(Alvo) then
     Alvo.Visible := True;
end;

function TfrmPrincipal.GetYtdlpFormat(Index: Integer): string;
begin
  case Index of
      0: Result := 'bestvideo+bestaudio/best';               // Original
      1: Result := 'bestvideo[height<=2160]+bestaudio/best'; // 4K
      2: Result := 'bestvideo[height<=1440]+bestaudio/best'; // 2K
      3: Result := 'bestvideo[height<=1080]+bestaudio/best'; // Full HD 1080p
      4: Result := 'bestvideo[height<=720]+bestaudio/best';  // HD 720p
      5: Result := 'bestvideo[height<=480]+bestaudio/best';  // SD 480p
      6: Result := 'bestvideo[height<=360]+bestaudio/best';  // 360p
      7: Result := 'bestvideo[height<=240]+bestaudio/best';  // 240p
      8: Result := 'bestvideo[height<=144]+bestaudio/best';  // 144p
      else Result := 'best';
    end;
end;

function TfrmPrincipal.GetFFmpegProfile(Index: Integer): string;
begin
  case Index of
      0: Result := '-c:v dnxhd -profile:v 4 -pix_fmt yuv422p10le';
      1: Result := '-c:v dnxhd -profile:v 1 -pix_fmt yuv422p';
      2: Result := '-vn';
      else Result := '-c:v copy';
  end;
end;

function TfrmPrincipal.GetAudioCodecParams(Index: Integer): string;
begin
  case Index of
      0: Result := '-c:a pcm_s16le';           // Original (mas convertido para PCM para o DaVinci)
      1: Result := '-c:a pcm_s24le -ar 96000'; // 24-bit / 96kHz
      2: Result := '-c:a pcm_s24le -ar 48000'; // 24-bit / 48kHz
      3: Result := '-c:a pcm_s16le -ar 44100'; // 16-bit / 44.1kHz
      4: Result := '-c:a pcm_s16le -b:a 320k'; // Aqui o PCM ignora bitrate, mas mantemos PCM para o DaVinci
      else Result := '-c:a pcm_s16le';
    end;
end;

procedure TfrmPrincipal.ConfigurarInterface;
var
  PastaDownloads: string;
begin
  ComboBox_Format_Videos.Items.BeginUpdate;
  try
    ComboBox_Format_Videos.Items.Clear;
    ComboBox_Format_Videos.Items.Add('Original');                   // Index 0
    ComboBox_Format_Videos.Items.Add('4K Ultra HD (2160p)');        // Index 1
    ComboBox_Format_Videos.Items.Add('2K Quad HD (1440p)');         // Index 2
    ComboBox_Format_Videos.Items.Add('Full HD (1080p)');            // Index 3
    ComboBox_Format_Videos.Items.Add('HD (720p)');                  // Index 4
    ComboBox_Format_Videos.Items.Add('SD (480p)');                  // Index 5
    ComboBox_Format_Videos.Items.Add('360p');                       // Index 6
    ComboBox_Format_Videos.Items.Add('240p');                       // Index 7
    ComboBox_Format_Videos.Items.Add('144p');                       // Index 8
    ComboBox_Format_Videos.ItemIndex := 0;
  finally
    ComboBox_Format_Videos.Items.EndUpdate;
  end;

  ComboBox_Format_Audios.Items.BeginUpdate;
  try
    ComboBox_Format_Audios.Items.Clear;
    ComboBox_Format_Audios.Items.Add('Original');                   // Index 0
    ComboBox_Format_Audios.Items.Add('24-bit / 96kHz (Master)');    // Index 1
    ComboBox_Format_Audios.Items.Add('24-bit / 48kHz (Pro Video)'); // Index 2
    ComboBox_Format_Audios.Items.Add('16-bit / 44.1kHz (CD)');      // Index 3
    ComboBox_Format_Audios.Items.Add('320 kbps (Alta)');            // Index 4
    ComboBox_Format_Audios.Items.Add('192 kbps (Média)');           // Index 5
    ComboBox_Format_Audios.Items.Add('128 kbps (Padrão)');          // Index 6
    ComboBox_Format_Audios.ItemIndex := 2;
  finally
    ComboBox_Format_Audios.Items.EndUpdate;
  end;

  ComboBox_options.Items.BeginUpdate;
  try
    ComboBox_options.Items.Clear;
    ComboBox_options.Items.Add('Master: DNxHR HQX (10-bit .MOV)');   // Index 0
    ComboBox_options.Items.Add('Proxy: DNxHR LB (Leve .MOV)');       // Index 1
    ComboBox_options.Items.Add('Audio: PCM High-End (24-bit .WAV)'); // Index 2
    ComboBox_options.ItemIndex := 0;
  finally
    ComboBox_options.Items.EndUpdate;
  end;

  ComboBox_Formatos.Items.BeginUpdate;
  try
    ComboBox_Formatos.Items.Clear;
    ComboBox_Formatos.Items.Add('MP4 (H.264 + AAC)');  // Index 0
    ComboBox_Formatos.Items.Add('MKV (Matroska)');     // Index 1
    ComboBox_Formatos.Items.Add('MP3 (Apenas Áudio)'); // Index 2
    ComboBox_Formatos.ItemIndex := 0;
  finally
    ComboBox_Formatos.Items.EndUpdate;
  end;

  PastaDownloads := GetUserDir + 'Downloads';

  // Verificamos se a pasta realmente existe antes de atribuir
  if DirectoryExists(PastaDownloads) then
    DirectoryEdit.Directory := PastaDownloads
  else
    DirectoryEdit.Directory := GetCurrentDir;

  lbl_info.Caption := 'Sistema pronto para processamento.';
  rbtm_padrao.Checked := True;
end;

function TfrmPrincipal.GerarIDAleatorio(Tamanho: Integer): string;
const
  Caracteres = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
var
  i: Integer;
begin
  Result := '';
  for i := 1 to Tamanho do
      Result := Result + Caracteres[Random(Length(Caracteres)) + 1];
end;

procedure TfrmPrincipal.button_process_DiretoDaVinciClick(Sender: TObject);
var
  AProcess: TProcess;
  Cmd, Ext, Buffer, RawOutput, PercentStr, NomePrefixo, IDAleatorio: string;
  BytesRead: LongInt;
  PStart: Integer;
  PercentVal: Double;
  Available: Integer;
  ParamsVideo, ParamsAudio, ParamsFormat: string;
const
  BUF_SIZE = 8192;
begin
  if button_process_DiretoDaVinci.Caption = 'Cancelar' then
  begin
    FCancelar := True;
    Exit;
  end;

  if (url_web.Text = '') or (DirectoryEdit.Directory = '') then
  begin
    ShowMessage('Por favor, insira a URL e selecione a pasta de destino!');
    Exit;
  end;

  FCancelar := False;
  pbar_console.Position := 0;

  Memo_visual_console.Clear;
  Memo_visual_console.Lines.Add('[INFO] Iniciando processo...');

  ParamsFormat := GetYtdlpFormat(ComboBox_Format_Videos.ItemIndex);
  ParamsVideo := GetFFmpegProfile(ComboBox_options.ItemIndex);
  ParamsAudio := GetAudioCodecParams(ComboBox_Format_Audios.ItemIndex);

  if ComboBox_options.ItemIndex = 2 then Ext := '.wav' else Ext := '.mov';

  IDAleatorio := '[' + GerarIDAleatorio(8) + ']';

  if rbtm_ytdlp.Checked then
      NomePrefixo := '%%(title)s'
    else if rbtm_padrao.Checked then
      NomePrefixo := 'davinci_ready_' + FormatDateTime('yyyy_mm_dd_hhnnss', Now) + IDAleatorio
    else if rbtm_definir.Checked and (Length(edt_definir.Text) > 0) then
      NomePrefixo := edt_definir.Text
    else
      NomePrefixo := 'processado_' + FormatDateTime('hhnnss', Now);

  AProcess := TProcess.Create(nil);
  try
    Cmd := Format('yt-dlp -f "%s" --merge-output-format mkv -P "%s" "%s" ' +
                  '--exec "ffmpeg -y -i %%(filepath)q %s %s \"%s/%s%s\""', [
      ParamsFormat,
      DirectoryEdit.Directory,
      url_web.Text,
      ParamsVideo,
      ParamsAudio,
      DirectoryEdit.Directory,
      NomePrefixo,
      Ext
    ]);

    {$IFDEF WINDOWS}
    AProcess.Executable := 'cmd.exe';
    AProcess.Parameters.Add('/c');
    {$ELSE}
    AProcess.Executable := '/usr/bin/bash';
    AProcess.Parameters.Add('-c');
    {$ENDIF}


    AProcess.Parameters.Add(Cmd);
    AProcess.Options := [poUsePipes, poStderrToOutPut, poNoConsole];

    button_process_DiretoDaVinci.Enabled := False;
    button_process_DiretoDaVinci.Caption := 'Cancelar';

    AProcess.Execute;

    while AProcess.Running do
    begin
      if FCancelar then
      begin
        AProcess.Terminate(0);
        Break;
      end;

      if AProcess.Output.NumBytesAvailable > 0 then
      begin
        SetLength(Buffer, BUF_SIZE);
        BytesRead := AProcess.Output.Read(Buffer[1], Length(Buffer));
        if BytesRead > 0 then
        begin
          SetLength(Buffer, BytesRead);
          RawOutput := Buffer;

          // --- Lógica Corrigida da Progressbar ---
          if Pos('[download]', RawOutput) > 0 then
          begin
            PStart := Pos('%', RawOutput);
            if PStart > 0 then
            begin
              // Pegamos os 5 caracteres antes do símbolo de %
              PercentStr := Copy(RawOutput, PStart - 5, 5);
              PercentStr := Trim(PercentStr);
              // Usamos ponto como separador decimal (padrão do terminal)
              if TryStrToFloat(PercentStr, PercentVal, DefaultFormatSettings) then
                  pbar_console.Position := Round(PercentVal);
            end;
          end;

          // mover até o final
          Memo_visual_console.Lines.BeginUpdate;
          try
            Memo_visual_console.SelStart := Length(Memo_visual_console.Text);
            Memo_visual_console.SelText := Buffer;
            Memo_visual_console.SelStart := Length(Memo_visual_console.Text);
          finally
            Memo_visual_console.Lines.EndUpdate;
          end;
        end;
      end;

      Application.ProcessMessages;
      Sleep(10);
    end;

    // Leitura final para limpar o buffer residual do TProcess
    while AProcess.Output.NumBytesAvailable > 0 do
    begin
       Available := AProcess.Output.NumBytesAvailable;
       SetLength(Buffer, Available);
       AProcess.Output.Read(Buffer[1], Available);

       Memo_visual_console.SelStart := Length(Memo_visual_console.Text);
       Memo_visual_console.SelText := Buffer;
       Memo_visual_console.SelStart := Length(Memo_visual_console.Text);
    end;

    if AProcess.ExitCode <> 0 then
       Memo_visual_console.Lines.Add(LineEnding + '[ERRO] O comando retornou erro: ' + IntToStr(AProcess.ExitCode))
    else
       Memo_visual_console.Lines.Add(LineEnding + '[SUCESSO] Arquivo baixado e formatado para o DaVinci Resolve.');

  finally
    button_process_DiretoDaVinci.Enabled := True;
    button_process_DiretoDaVinci.Caption := 'PROCESSAR';
    AProcess.Free;
  end;
end;

procedure TfrmPrincipal.btn_DiretoDaVinciClick(Sender: TObject);
begin
  MudarTela(GroupBox_DiretoDaVinci);
end;

procedure TfrmPrincipal.btn_BaixadorClick(Sender: TObject);
begin
  MudarTela(GroupBox_Baixador);
end;

procedure TfrmPrincipal.MenuItem31Click(Sender: TObject);
begin
  MudarTela(GroupBox_Sobre);
end;

procedure TfrmPrincipal.MenuItem10Click(Sender: TObject);
begin
  Close;
end;

end.
