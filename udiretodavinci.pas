unit uDiretoDaVinci;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, ExtCtrls,
  StdCtrls, EditBtn, ComCtrls, Dialogs, Process;

type

  { TfrDiretoDaVinci }

  TfrDiretoDaVinci = class(TFrame)
    button_process_DiretoDaVinci: TButton;
    ComboBox_Format_Audios: TComboBox;
    ComboBox_Format_Videos: TComboBox;
    ComboBox_options: TComboBox;
    DirectoryEdit: TDirectoryEdit;
    edt_definir: TEdit;
    grp_console: TGroupBox;
    grp_convertionFormate: TGroupBox;
    grp_definicao: TGroupBox;
    grp_fileConfig: TGroupBox;
    Label10: TLabel;
    Label11: TLabel;
    Label9: TLabel;
    Memo_visual_console: TMemo;
    pbar_console: TProgressBar;
    pnl_button: TPanel;
    pnl_DiretoDaVinci: TPanel;
    pnl_DiretoDaVinci_Group: TPanel;
    RadioButton1: TRadioButton;
    RadioButton2: TRadioButton;
    rbtm_definir: TRadioButton;
    rbtm_padrao: TRadioButton;
    rbtm_ytdlp: TRadioButton;
    url_web: TEdit;
    procedure button_process_DiretoDaVinciClick(Sender: TObject);
  private
    FVerificado: Boolean;
    FCancelar: Boolean;
    function GetYtdlpFormat(Index: Integer): string;
    procedure GetFFmpegProfile(Index: Integer; out AParams, AExt, AMerge: string);
    function GetAudioCodecParams(AudioIndex, VideoIndex: Integer): string;
    function GerarIDAleatorio(Tamanho: Integer): string;
    procedure ConfigurarInterface();
  public
    constructor Create(AOwner: TComponent); override;
  end;

implementation

{$R *.lfm}

{ TfrDiretoDaVinci }

constructor TfrDiretoDaVinci.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ConfigurarInterface;
  Randomize;
end;

procedure TfrDiretoDaVinci.button_process_DiretoDaVinciClick(Sender: TObject);
var
  AProcess: TProcess;
  Cmd, Buffer, RawOutput, PercentStr, NomePrefixo, IDAleatorio: string;
  BytesRead: LongInt;
  PStart: Integer;
  PercentVal: Double;
  Available: Integer;
  ParamsAudio, ParamsFormat, VideoParams, ExtFinal, MergeFormat, SortRes: string;
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
  ParamsAudio := GetAudioCodecParams(ComboBox_Format_Audios.ItemIndex, ComboBox_options.ItemIndex);
  GetFFmpegProfile(ComboBox_options.ItemIndex, VideoParams, ExtFinal, MergeFormat);

  case ComboBox_Format_Videos.ItemIndex of
      1: SortRes := 'res:2160';
      2: SortRes := 'res:1440';
      3: SortRes := 'res:1080';
      4: SortRes := 'res:720';
      else SortRes := 'res';
  end;

  IDAleatorio := '[' + GerarIDAleatorio(8) + ']';

  if rbtm_ytdlp.Checked then
      NomePrefixo := '%(title)s'
    else if rbtm_padrao.Checked then
      NomePrefixo := 'davinci_ready_' + FormatDateTime('yyyy_mm_dd_hhnnss', Now) + IDAleatorio
    else if rbtm_definir.Checked and (Length(Trim(edt_definir.Text)) > 0) then
      NomePrefixo := Trim(edt_definir.Text)
    else
      NomePrefixo := 'processado_' + FormatDateTime('hhnnss', Now);

  AProcess := TProcess.Create(nil);
  try
    Cmd := Format('yt-dlp -S "%s,ext" --merge-output-format %s -P "%s" "%s" ' +
                      '--exec "ffmpeg -y -i %%(filepath)q %s %s \"%s/%s%s\""', [
                   SortRes,
                   MergeFormat,
                   DirectoryEdit.Directory,
                   Trim(url_web.Text),
                   VideoParams,   // Primeiro %s do exec (Vídeo)
                   ParamsAudio,   // Segundo %s do exec (Áudio - Dinâmico!)
                   DirectoryEdit.Directory,
                   NomePrefixo,
                   ExtFinal
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
      Sleep(50);
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

    if FCancelar then
       Memo_visual_console.Lines.Add(LineEnding + '[AVISO] Processo cancelado pelo usuário.')
    else if AProcess.ExitCode <> 0 then
       Memo_visual_console.Lines.Add(LineEnding + '[ERRO] O comando retornou erro: ' + IntToStr(AProcess.ExitCode))
    else
       Memo_visual_console.Lines.Add(LineEnding + '[SUCESSO] Arquivo processado e pronto para o DaVinci Resolve.');

  finally
    button_process_DiretoDaVinci.Enabled := True;
    button_process_DiretoDaVinci.Caption := 'PROCESSAR';
    AProcess.Free;
  end;
end;

function TfrDiretoDaVinci.GetYtdlpFormat(Index: Integer): string;
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

procedure TfrDiretoDaVinci.GetFFmpegProfile(Index: Integer; out AParams, AExt, AMerge: string);
begin
  case Index of
    0..3: begin // Família MOV (Editáveis)
      AMerge := 'mkv';
      AExt := '.mov';
      if Index = 0 then AParams := '-c:v dnxhd -profile:v dnxhr_hqx -pix_fmt yuv422p10le'
      else if Index = 1 then AParams := '-c:v dnxhd -profile:v dnxhr_lb -pix_fmt yuv422p'
      else if Index = 2 then AParams := '-c:v prores_ks -profile:v 3 -vendor apl0 -pix_fmt yuv422p10le'
      else AParams := '-c:v prores_ks -profile:v 1 -vendor apl0 -pix_fmt yuv422p';
    end;

    4: begin // Google VP9 (WebM) - OTIMIZADO
      AMerge := 'mkv';
      AExt := '.mov';
      // Adicionado -row-mt 1 e -threads 0 para velocidade máxima no Linux
      AParams := '--c:v libvpx-vp9 -crf 18 -b:v 0 -quality good -speed 1 -pix_fmt yuv420p';
    end;

    5: begin // AV1 - OTIMIZADO
      AMerge := 'mkv';
      AExt := '.mov';
      // AV1 é o mais pesado de todos. Usamos cpu-used 5 para não demorar horas.
      AParams := '-c:v libaom-av1 -crf 25 -b:v 0 -cpu-used 4 -pix_fmt yuv420p -strict experimental';
    end;

    6: begin // Somente Áudio
      AMerge := 'm4a';
      AExt := '.wav';
      AParams := '-vn';
    end;
    else begin
      AMerge := 'mkv';
      AExt := '.mkv';
      AParams := '-c:v copy';
    end;
  end;
end;

function TfrDiretoDaVinci.GetAudioCodecParams(AudioIndex, VideoIndex: Integer): string;
begin
  case AudioIndex of
      0: Result := '-c:a pcm_s16le'; // Original
      1: Result := '-c:a pcm_s24le -ar 96000'; // Master
      2: Result := '-c:a pcm_s24le -ar 48000'; // Pro
      3: Result := '-c:a pcm_s16le -ar 44100'; // CD
      else Result := '-c:a pcm_s16le';
    end;
end;

function TfrDiretoDaVinci.GerarIDAleatorio(Tamanho: Integer): string;
const
  Caracteres = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
var
  i: Integer;
begin
  Result := '';
  for i := 1 to Tamanho do
      Result := Result + Caracteres[Random(Length(Caracteres)) + 1];
end;

procedure TfrDiretoDaVinci.ConfigurarInterface();
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
    ComboBox_Format_Audios.ItemIndex := 0;
  finally
    ComboBox_Format_Audios.Items.EndUpdate;
  end;

  ComboBox_options.Items.BeginUpdate;
  try
    ComboBox_options.Items.Clear;
    // --- DNxHR
    ComboBox_options.Items.Add('Master: DNxHR HQX (10-bit .MOV)');
    ComboBox_options.Items.Add('Proxy: DNxHR LB (Leve .MOV)');

    // --- Apple ProRes
    ComboBox_options.Items.Add('ProRes 422 HQ (Alta Qualidade .MOV)');
    ComboBox_options.Items.Add('ProRes 422 LT (Econômica .MOV)');

    // --- Google/Xiph
    ComboBox_options.Items.Add('Google VP9 (WebM Open Souce)');
    ComboBox_options.Items.Add('Alliance AV1 (Próxima Geração)');

    // --- Somente Audio
    ComboBox_options.Items.Add('Audio: PCM High-End (24-bit .WAV)');
    ComboBox_options.ItemIndex := 0;
  finally
    ComboBox_options.Items.EndUpdate;
  end;

  PastaDownloads := GetUserDir + 'Downloads';

  // Verificamos se a pasta realmente existe antes de atribuir
  if DirectoryExists(PastaDownloads) then
    DirectoryEdit.Directory := PastaDownloads
  else
    DirectoryEdit.Directory := GetCurrentDir;

  rbtm_padrao.Checked := True;
end;

end.

