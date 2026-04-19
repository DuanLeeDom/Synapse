unit uDiretoDaVinci;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, StrUtils, Forms, Controls, ExtCtrls,
  StdCtrls, EditBtn, ComCtrls, Dialogs, ComboEx, Process, FileUtil, uSystemAssistant;

type
  TVideoEditorID = (
    veDaVinciFree,
    veDaVinciStudio,
    veKdenlive,
    veShotcut,
    veOpenShot,
    veLightwerksFree,
    veLightworks,
    veFlowblade,
    veCinelerra
  );

  TEditorProfile = record
    EditorID   : TVideoEditorID;
    IsStudio   : Boolean;
    HasDNxHR   : Boolean;
    HasProRes  : Boolean;
    HasMJPEG   : Boolean;
    HasH264    : Boolean;
    HasH265    : Boolean;
    HasAV1     : Boolean;
    HasVP9     : Boolean;
    HasMPEG2   : Boolean;
    HasCineForm: Boolean;
  end;

  TCodecEntry = record
    Caption     : string;
    VideoParams : string;
    Ext         : string;
    MergeFormat : string;
    IsAudioOnly : Boolean;
  end;

  TCodecList = array of TCodecEntry;

type

  { TfrDiretoDaVinci }

  TfrDiretoDaVinci = class(TFrame)
    button_console: TButton;
    button_process_DiretoDaVinci: TButton;
    cbx_option_video_editor: TComboBoxEx;
    chk_Oversample: TCheckBox;
    DirectoryEdit: TDirectoryEdit;
    edt_definir: TEdit;
    GroupBox1: TGroupBox;
    GroupBox2: TGroupBox;
    GroupBox4: TGroupBox;
    grp_definicao: TGroupBox;
    grp_fileConfig: TGroupBox;
    imgl_options_edit: TImageList;
    Label11: TLabel;
    Label12: TLabel;
    Label13: TLabel;
    Label9: TLabel;
    pbar_console: TProgressBar;
    pnl_files_options: TPanel;
    rbtm_definir: TRadioButton;
    rbtm_naoSubstituir: TRadioButton;
    rbtm_padrao: TRadioButton;
    rbtm_process_cpu: TRadioButton;
    rbtm_process_gpu: TRadioButton;
    ComboBox_Format_Audios: TComboBox;
    ComboBox_Format_Videos: TComboBox;
    ComboBox_options: TComboBox;
    grp_console: TGroupBox;
    grp_convertionFormate: TGroupBox;
    Label10: TLabel;
    Memo_visual_console: TMemo;
    pnl_button: TPanel;
    pnl_DiretoDaVinci: TPanel;
    pnl_DiretoDaVinci_Group: TPanel;
    rbtm_substituir: TRadioButton;
    rbtm_ytdlp: TRadioButton;
    url_web: TEdit;
    procedure button_consoleClick(Sender: TObject);
    procedure ComboBox_optionsChange(Sender: TObject);
    procedure button_P(Sender: TObject);
    procedure rbtm_definirChange(Sender: TObject);
    procedure cbx_option_video_editorChange(Sender: TObject);
  private
    FCancelar      : Boolean;
    FCurrentProfile: TEditorProfile;
    FCurrentCodecs : TCodecList;
    FAssistant     : TSystemAssistant;  // instância do helper

    procedure ConfigurarPlataformas;
    procedure HelpManager;
    function  GetYtdlpFormat(Index: Integer): string;
    function  GetEditorProfile(EditorID: TVideoEditorID): TEditorProfile;
    function  ActiveEditorID: TVideoEditorID;
    function  BuildCodecList(const Profile: TEditorProfile): TCodecList;
    procedure GetFFmpegProfile(CodecIndex: Integer;
                                out AVideoParams, AExt, AMergeFormat: string;
                                out AIsAudioOnly: Boolean);
    function  GetAudioCodecParams(AudioIndex, CodecIndex: Integer): string;
    procedure AtualizarPerfilEditor;
    procedure AtualizarOpcoesAudio(CodecIndex: Integer);
    function  GerarIDAleatorio(Tamanho: Integer): string;
    procedure ConfigurarInterface;
    function  ExecutarComando(const ACmd: string; const ATagLog: string): Boolean;
    procedure LogLinha(const S: string);
    procedure Fase1_YtDlp(const AURL, APasta, AFormatoYtdlp, AMergeFormat: string;
                           out ArquivosBaixados: TStringList);
    procedure Fase2_FFmpeg(const APasta: string;
                            const ArquivosBaixados: TStringList;
                            const AVideoParams, AParamsAudio, AExt: string;
                            const NomePrefixo: string;
                            const DeletarOriginal: Boolean);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

implementation

{$R *.lfm}

{ TfrDiretoDaVinci }

constructor TfrDiretoDaVinci.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Randomize;
  FAssistant := TSystemAssistant.Create;  // cria a instância
  ConfigurarInterface;
end;

destructor TfrDiretoDaVinci.Destroy;
begin
  FAssistant.Free;  // libera a memória ao fechar
  inherited Destroy;
end;

function TfrDiretoDaVinci.GetEditorProfile(EditorID: TVideoEditorID): TEditorProfile;
begin
  Result          := Default(TEditorProfile);
  Result.EditorID := EditorID;

  case EditorID of
    veDaVinciFree:
    begin
      Result.IsStudio  := False;
      Result.HasDNxHR  := True;
      Result.HasProRes := True;
      Result.HasMJPEG  := True;
      Result.HasAV1    := True;
    end;
    veDaVinciStudio:
    begin
      Result.IsStudio   := True;
      Result.HasDNxHR   := True;
      Result.HasProRes  := True;
      Result.HasMJPEG   := True;
      Result.HasH264    := True;
      Result.HasH265    := True;
      Result.HasAV1     := True;
      Result.HasVP9     := True;
      Result.HasMPEG2   := True;
      Result.HasCineForm:= True;
    end;
    veKdenlive:
    begin
      Result.IsStudio := False;
      Result.HasH264  := True;
      Result.HasAV1   := True;
      Result.HasVP9   := True;
      Result.HasMJPEG := True;
    end;
    veShotcut:
    begin
      Result.IsStudio := False;
      Result.HasH264  := True;
      Result.HasH265  := True;
      Result.HasAV1   := True;
      Result.HasVP9   := True;
      Result.HasMJPEG := True;
    end;
    veOpenShot:
    begin
      Result.IsStudio := False;
      Result.HasH264  := True;
      Result.HasAV1   := True;
      Result.HasVP9   := True;
      Result.HasMJPEG := True;
    end;
    veLightwerksFree:
    begin
      Result.IsStudio := False;
      Result.HasDNxHR := True;
      Result.HasH264  := True;
      Result.HasMJPEG := True;
    end;
    veLightworks:
    begin
      Result.IsStudio  := True;
      Result.HasDNxHR  := True;
      Result.HasProRes := True;
      Result.HasH264   := True;
      Result.HasH265   := True;
      Result.HasMJPEG  := True;
      Result.HasAV1    := True;
    end;
    veFlowblade:
    begin
      Result.IsStudio := False;
      Result.HasH264  := True;
      Result.HasAV1   := True;
      Result.HasVP9   := True;
      Result.HasMJPEG := True;
    end;
    veCinelerra:
    begin
      Result.IsStudio := False;
      Result.HasMJPEG := True;
      Result.HasAV1   := True;
      Result.HasVP9   := True;
    end;
  end;
end;

function TfrDiretoDaVinci.ActiveEditorID: TVideoEditorID;
begin
  case cbx_option_video_editor.ItemIndex of
    0: Result := veDaVinciFree;
    1: Result := veDaVinciStudio;
    2: Result := veKdenlive;
    3: Result := veShotcut;
    4: Result := veOpenShot;
    5: Result := veLightwerksFree;
    6: Result := veLightworks;
    7: Result := veFlowblade;
    8: Result := veCinelerra;
  else
    Result := veDaVinciFree;
  end;
end;

function TfrDiretoDaVinci.BuildCodecList(const Profile: TEditorProfile): TCodecList;
var
  List: TCodecList;
  N: Integer;

  procedure Add(const ACaption, AVideoParams, AExt, AMergeFormat: string;
                AIsAudioOnly: Boolean);
  begin
    SetLength(List, N + 1);
    List[N].Caption     := ACaption;
    List[N].VideoParams := AVideoParams;
    List[N].Ext         := AExt;
    List[N].MergeFormat := AMergeFormat;
    List[N].IsAudioOnly := AIsAudioOnly;
    Inc(N);
  end;

begin
  SetLength(List, 0);
  N := 0;

  if Profile.HasDNxHR then
  begin
    if Profile.IsStudio then
    begin
      Add('DNxHR HQ  — Master 8-bit .MOV',
          '-c:v dnxhd -profile:v dnxhr_hq -pix_fmt yuv422p',      '.mov','mkv', False);
      Add('DNxHR HQX — Master 10-bit .MOV',
          '-c:v dnxhd -profile:v dnxhr_hqx -pix_fmt yuv422p10le', '.mov','mkv', False);
      Add('DNxHR LB  — Proxy Leve .MOV',
          '-c:v dnxhd -profile:v dnxhr_lb -pix_fmt yuv422p',       '.mov','mkv', False);
    end
    else
    begin
      Add('DNxHR HQ  — Master 8-bit .MOV  ✔ Free',
          '-c:v dnxhd -profile:v dnxhr_hq -pix_fmt yuv422p',      '.mov','mkv', False);
      Add('DNxHR HQX — Master 10-bit .MOV ✔ Free',
          '-c:v dnxhd -profile:v dnxhr_hqx -pix_fmt yuv422p10le', '.mov','mkv', False);
      Add('DNxHR LB  — Proxy Leve .MOV    ✔ Free',
          '-c:v dnxhd -profile:v dnxhr_lb -pix_fmt yuv422p',       '.mov','mkv', False);
    end;
  end;

  if Profile.HasProRes then
  begin
    if Profile.IsStudio then
    begin
      Add('ProRes 4444 — 12-bit Alpha .MOV',
          '-c:v prores_ks -profile:v 4 -vendor apl0 -pix_fmt yuva444p10le','.mov','mkv',False);
      Add('ProRes 422 HQ — 10-bit .MOV',
          '-c:v prores_ks -profile:v 3 -vendor apl0 -pix_fmt yuv422p10le', '.mov','mkv',False);
      Add('ProRes 422 LT — Econômico .MOV',
          '-c:v prores_ks -profile:v 1 -vendor apl0 -pix_fmt yuv422p',     '.mov','mkv',False);
    end
    else
    begin
      Add('ProRes 422 HQ — 10-bit .MOV    ✔ Free',
          '-c:v prores_ks -profile:v 3 -vendor apl0 -pix_fmt yuv422p10le', '.mov','mkv',False);
      Add('ProRes 422 LT — Econômico .MOV ✔ Free',
          '-c:v prores_ks -profile:v 1 -vendor apl0 -pix_fmt yuv422p',     '.mov','mkv',False);
    end;
  end;

  if Profile.HasMJPEG then
  begin
    if Profile.IsStudio then
      Add('MJPEG — Proxy Rápido .MOV',
          '-c:v mjpeg -q:v 2 -pix_fmt yuvj422p', '.mov','mkv', False)
    else
      Add('MJPEG — Proxy Rápido .MOV      ✔ Free',
          '-c:v mjpeg -q:v 2 -pix_fmt yuvj422p', '.mov','mkv', False);
  end;

  if Profile.HasH264 then
  begin
    if Profile.IsStudio then
      Add('H.264 — Alta Compatibilidade .MP4',
          '-c:v libx264 -crf 18 -preset slow -pix_fmt yuv420p', '.mp4','mp4', False)
    else
      Add('H.264 — Alta Compatibilidade .MP4 ✔ Free',
          '-c:v libx264 -crf 18 -preset slow -pix_fmt yuv420p', '.mp4','mp4', False);
  end;

  if Profile.HasH265 then
  begin
    if Profile.IsStudio then
      Add('H.265 / HEVC — Alta Compressão .MP4',
          '-c:v libx265 -crf 18 -preset slow -pix_fmt yuv420p', '.mp4','mp4', False)
    else
      Add('H.265 / HEVC — Alta Compressão .MP4 ✔ Free',
          '-c:v libx265 -crf 18 -preset slow -pix_fmt yuv420p', '.mp4','mp4', False);
  end;

  if Profile.HasAV1 then
  begin
    if Profile.IsStudio then
      Add('AV1 — Máxima Compressão .MP4',
          '-c:v libaom-av1 -crf 25 -b:v 0 -cpu-used 5 -pix_fmt yuv420p -strict experimental',
          '.mp4','mp4', False)
    else
      Add('AV1 — Compacto .MP4            ✔ Free',
          '-c:v libaom-av1 -crf 25 -b:v 0 -cpu-used 5 -pix_fmt yuv420p -strict experimental',
          '.mp4','mp4', False);
  end;

  if Profile.HasVP9 then
  begin
    if Profile.IsStudio then
      Add('VP9 — Open Source .WEBM',
          '-c:v libvpx-vp9 -crf 18 -b:v 0 -quality good -speed 2 -row-mt 1 -pix_fmt yuv420p',
          '.webm','webm', False)
    else
      Add('VP9 — Open Source .WEBM        ✔ Free',
          '-c:v libvpx-vp9 -crf 18 -b:v 0 -quality good -speed 2 -row-mt 1 -pix_fmt yuv420p',
          '.webm','webm', False);
  end;

  if Profile.HasMPEG2 then
    Add('MPEG-2 — Broadcast .MPG',
        '-c:v mpeg2video -q:v 2 -pix_fmt yuv420p', '.mpg','mpg', False);

  if Profile.HasCineForm then
    Add('CineForm — GoPro .MOV',
        '-c:v cfhd -quality film3+ -pix_fmt yuv422p10', '.mov','mkv', False);

  if Profile.IsStudio then
    Add('Somente Áudio: PCM .WAV', '-vn', '.wav', 'mkv', True)
  else
    Add('Somente Áudio: PCM .WAV ✔ Free', '-vn', '.wav', 'mkv', True);

  Result := List;
end;

procedure TfrDiretoDaVinci.GetFFmpegProfile(CodecIndex: Integer;
                                             out AVideoParams, AExt, AMergeFormat: string;
                                             out AIsAudioOnly: Boolean);
begin
  if (CodecIndex < 0) or (CodecIndex >= Length(FCurrentCodecs)) then
    CodecIndex := 0;

  AVideoParams := FCurrentCodecs[CodecIndex].VideoParams;
  AExt         := FCurrentCodecs[CodecIndex].Ext;
  AMergeFormat := FCurrentCodecs[CodecIndex].MergeFormat;
  AIsAudioOnly := FCurrentCodecs[CodecIndex].IsAudioOnly;
end;

function TfrDiretoDaVinci.GetAudioCodecParams(AudioIndex, CodecIndex: Integer): string;
var
  Ext: string;
begin
  Result := '-c:a pcm_s16le';

  if (CodecIndex < 0) or (CodecIndex >= Length(FCurrentCodecs)) then
    Exit;

  if FCurrentCodecs[CodecIndex].IsAudioOnly then
  begin
    Result := '-c:a pcm_s24le';
    Exit;
  end;

  Ext := LowerCase(FCurrentCodecs[CodecIndex].Ext);

  if Ext = '.webm' then
  begin
    case AudioIndex of
      0: Result := '-c:a libopus -b:a 192k -vbr on -ar 48000';
      1: Result := '-c:a libopus -b:a 320k -vbr on -ar 48000';
      2: Result := '-c:a libopus -b:a 128k -vbr on -ar 48000';
      3: Result := '-c:a libvorbis -q:a 6';
    else Result := '-c:a libopus -b:a 192k -vbr on -ar 48000';
    end;
    Exit;
  end;

  if Ext = '.mpg' then
  begin
    case AudioIndex of
      0: Result := '-c:a mp2 -b:a 320k -ar 48000';
      1: Result := '-c:a pcm_s16le';
      2: Result := '-c:a aac -b:a 256k -ar 48000';
    else Result := '-c:a mp2 -b:a 320k -ar 48000';
    end;
    Exit;
  end;

  if Ext = '.mp4' then
  begin
    if FCurrentProfile.IsStudio then
    begin
      case AudioIndex of
        0: Result := '-c:a pcm_s16le';
        1: Result := '-c:a pcm_s24le';
        2: Result := '-c:a aac -b:a 320k -ar 48000';
        3: Result := '-c:a libmp3lame -b:a 320k -ar 48000';
        4: Result := '-c:a flac -strict experimental';
      else Result := '-c:a aac -b:a 256k -ar 48000';
      end;
    end
    else
    begin
      case AudioIndex of
        0: Result := '-c:a pcm_s16le';
        1: Result := '-c:a libmp3lame -b:a 320k -ar 48000';
        2: Result := '-c:a aac -b:a 320k -ar 48000';
      else Result := '-c:a pcm_s16le';
      end;
    end;
    Exit;
  end;

  if FCurrentProfile.IsStudio then
  begin
    case AudioIndex of
      0: Result := '-c:a pcm_s16le';
      1: Result := '-c:a pcm_s24le';
      2: Result := '-c:a pcm_s32le';
      3: Result := '-c:a pcm_s24le';
      4: Result := '-c:a aac -b:a 320k -ar 48000';
      5: Result := '-c:a libopus -b:a 192k -vbr on -ar 48000';
    else Result := '-c:a pcm_s16le';
    end;
  end
  else
  begin
    case AudioIndex of
      0: Result := '-c:a pcm_s16le';
      1: Result := '-c:a pcm_s24le';
      2: Result := '-c:a pcm_s32le';
      3: Result := '-c:a pcm_s24le';
    else Result := '-c:a pcm_s16le';
    end;
  end;
end;

procedure TfrDiretoDaVinci.AtualizarOpcoesAudio(CodecIndex: Integer);
var
  Ext: string;
begin
  if (CodecIndex < 0) or (CodecIndex >= Length(FCurrentCodecs)) then
    CodecIndex := 0;

  ComboBox_Format_Audios.Items.BeginUpdate;
  try
    ComboBox_Format_Audios.Items.Clear;

    if FCurrentCodecs[CodecIndex].IsAudioOnly then
    begin
      ComboBox_Format_Audios.Items.Add('PCM 24-bit (taxa original)');
      ComboBox_Format_Audios.ItemIndex := 0;
      Exit;
    end;

    Ext := LowerCase(FCurrentCodecs[CodecIndex].Ext);

    if Ext = '.webm' then
    begin
      ComboBox_Format_Audios.Items.Add('Opus 192k / 48kHz ✔ Free');
      ComboBox_Format_Audios.Items.Add('Opus 320k / 48kHz ✔ Free');
      ComboBox_Format_Audios.Items.Add('Opus 128k / 48kHz ✔ Free');
      ComboBox_Format_Audios.Items.Add('Vorbis q6 (taxa original) ✔ Free');
    end
    else if Ext = '.mpg' then
    begin
      ComboBox_Format_Audios.Items.Add('MP2 320k / 48kHz (nativo)');
      ComboBox_Format_Audios.Items.Add('PCM 16-bit (taxa original)');
      ComboBox_Format_Audios.Items.Add('AAC 256k / 48kHz');
    end
    else if Ext = '.mp4' then
    begin
      if FCurrentProfile.IsStudio then
      begin
        ComboBox_Format_Audios.Items.Add('PCM 16-bit (taxa original)');
        ComboBox_Format_Audios.Items.Add('PCM 24-bit (taxa original)');
        ComboBox_Format_Audios.Items.Add('AAC 320k / 48kHz ✔ Studio');
        ComboBox_Format_Audios.Items.Add('MP3 320k / 48kHz');
        ComboBox_Format_Audios.Items.Add('FLAC (taxa original, MP4 only)');
      end
      else
      begin
        ComboBox_Format_Audios.Items.Add('PCM 16-bit (taxa original) ✔ Free');
        ComboBox_Format_Audios.Items.Add('MP3 320k / 48kHz ✔ Free');
        ComboBox_Format_Audios.Items.Add('AAC 320k / 48kHz');
      end;
    end
    else
    begin
      if FCurrentProfile.IsStudio then
      begin
        ComboBox_Format_Audios.Items.Add('PCM 16-bit (taxa original) ✔');
        ComboBox_Format_Audios.Items.Add('PCM 24-bit (taxa original) ✔');
        ComboBox_Format_Audios.Items.Add('PCM 32-bit (taxa original) ✔');
        ComboBox_Format_Audios.Items.Add('PCM 24-bit (FLAC→PCM .mov)');
        ComboBox_Format_Audios.Items.Add('AAC 320k / 48kHz ✔ Studio');
        ComboBox_Format_Audios.Items.Add('Opus 192k / 48kHz ✔ Studio');
      end
      else
      begin
        ComboBox_Format_Audios.Items.Add('PCM 16-bit (taxa original) ✔ Free');
        ComboBox_Format_Audios.Items.Add('PCM 24-bit (taxa original) ✔ Free');
        ComboBox_Format_Audios.Items.Add('PCM 32-bit (taxa original) ✔ Free');
        ComboBox_Format_Audios.Items.Add('PCM 24-bit (FLAC→PCM .mov)');
      end;
    end;

  finally
    ComboBox_Format_Audios.Items.EndUpdate;
  end;

  ComboBox_Format_Audios.ItemIndex := 0;
end;

procedure TfrDiretoDaVinci.AtualizarPerfilEditor;
var
  i: Integer;
begin
  FCurrentProfile := GetEditorProfile(ActiveEditorID);
  FCurrentCodecs  := BuildCodecList(FCurrentProfile);

  ComboBox_Format_Videos.Items.BeginUpdate;
  try
    ComboBox_Format_Videos.Items.Clear;
    ComboBox_Format_Videos.Items.Add('Original (melhor disponível)');
    ComboBox_Format_Videos.Items.Add('4K Ultra HD (2160p)');
    ComboBox_Format_Videos.Items.Add('2K Quad HD (1440p)');
    ComboBox_Format_Videos.Items.Add('Full HD (1080p)');
    ComboBox_Format_Videos.Items.Add('HD (720p)');
    ComboBox_Format_Videos.Items.Add('SD (480p)');
    ComboBox_Format_Videos.Items.Add('360p');
    ComboBox_Format_Videos.Items.Add('240p');
    ComboBox_Format_Videos.Items.Add('144p');
    ComboBox_Format_Videos.ItemIndex := 0;
  finally
    ComboBox_Format_Videos.Items.EndUpdate;
  end;

  ComboBox_options.Items.BeginUpdate;
  try
    ComboBox_options.Items.Clear;
    for i := 0 to High(FCurrentCodecs) do
      ComboBox_options.Items.Add(FCurrentCodecs[i].Caption);
    ComboBox_options.ItemIndex := 0;
  finally
    ComboBox_options.Items.EndUpdate;
  end;

  AtualizarOpcoesAudio(0);
end;

procedure TfrDiretoDaVinci.cbx_option_video_editorChange(Sender: TObject);
begin
  FAssistant.RecarregarDependentes([ComboBox_options, ComboBox_Format_Audios]);
  AtualizarPerfilEditor;
end;

procedure TfrDiretoDaVinci.ComboBox_optionsChange(Sender: TObject);
begin
  AtualizarOpcoesAudio(ComboBox_options.ItemIndex);
end;

procedure TfrDiretoDaVinci.rbtm_definirChange(Sender: TObject);
begin
  edt_definir.Visible := rbtm_definir.Checked;
end;

procedure TfrDiretoDaVinci.button_consoleClick(Sender: TObject);
begin
  grp_console.Visible := not grp_console.Visible;
  if grp_console.Visible then
    grp_console.Align := alTop
  else
    grp_console.Align := alClient;
end;

procedure TfrDiretoDaVinci.button_P(Sender: TObject);
var
  ArquivosBaixados: TStringList;
  VideoParams, ExtFinal, MergeFormat: string;
  ParamsAudio, FormatoYtdlp, NomePrefixo, IDAleatorio: string;
  IsAudioOnly, DeletarOriginal: Boolean;
  EditorName: string;
  GPUDetectada: TGPUVendor;  // variável declarada corretamente
begin
  if button_process_DiretoDaVinci.Caption = 'Cancelar' then
  begin
    FCancelar := True;
    Exit;
  end;

  if (Trim(url_web.Text) = '') or (DirectoryEdit.Directory = '') then
  begin
    ShowMessage('Por favor, insira a URL e selecione a pasta de destino!');
    Exit;
  end;

  FCancelar       := False;
  DeletarOriginal := rbtm_substituir.Checked;

  pbar_console.Position := 0;
  Memo_visual_console.Clear;

  EditorName := cbx_option_video_editor.ItemsEx[cbx_option_video_editor.ItemIndex].Caption;
  LogLinha(Format('[INFO] Editor: %s', [EditorName]));
  LogLinha('[INFO] Iniciando pipeline...');

  GetFFmpegProfile(ComboBox_options.ItemIndex,
                   VideoParams, ExtFinal, MergeFormat, IsAudioOnly);

  ParamsAudio := GetAudioCodecParams(ComboBox_Format_Audios.ItemIndex,
                                      ComboBox_options.ItemIndex);

  if chk_Oversample.Checked and (not IsAudioOnly) then
  begin
    case ComboBox_Format_Videos.ItemIndex of
      1: VideoParams := VideoParams + ' -vf "scale=-2:2160"';
      2: VideoParams := VideoParams + ' -vf "scale=-2:1440"';
      3: VideoParams := VideoParams + ' -vf "scale=-2:1080"';
      4: VideoParams := VideoParams + ' -vf "scale=-2:720"';
    else
      VideoParams := VideoParams + ' -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2"';
    end;
  end
  else if not IsAudioOnly then
    VideoParams := VideoParams + ' -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2"';

  // --- detecção e aplicação de GPU ---
  if rbtm_process_gpu.Checked then
  begin
    GPUDetectada := FAssistant.DetectarGPU;

    case GPUDetectada of
      gpuNone:
      begin
        ShowMessage('Nenhuma placa de vídeo compatível encontrada.'
                    + #13#10 + 'Usando CPU.');
        rbtm_process_cpu.Checked := True;
      end;
      gpuNVIDIA: LogLinha('[GPU] NVIDIA detectada — usando NVENC');
      gpuAMD:    LogLinha('[GPU] AMD detectada — usando AMF');
      gpuIntel:  LogLinha('[GPU] Intel detectada — usando QSV');
    end;

    if GPUDetectada <> gpuNone then
      VideoParams := FAssistant.ObterParamsGPU(VideoParams, GPUDetectada);
  end;

  if IsAudioOnly then
  begin
    FormatoYtdlp := 'bestaudio/best';
    MergeFormat  := 'mkv';
  end
  else
    FormatoYtdlp := GetYtdlpFormat(ComboBox_Format_Videos.ItemIndex);

  IDAleatorio := GerarIDAleatorio(8);
  if rbtm_ytdlp.Checked then
    NomePrefixo := 'ORIGINAL_YTDLP'
  else if rbtm_padrao.Checked then
    NomePrefixo := 'editor_ready_' + FormatDateTime('yyyy_mm_dd_hhnnss', Now) + '_' + IDAleatorio
  else if rbtm_definir.Checked and (Trim(edt_definir.Text) <> '') then
    NomePrefixo := Trim(edt_definir.Text)
  else
    NomePrefixo := 'processado_' + IDAleatorio;

  button_process_DiretoDaVinci.Enabled := True;
  button_process_DiretoDaVinci.Caption := 'Cancelar';

  ArquivosBaixados := nil;
  try
    Fase1_YtDlp(Trim(url_web.Text), DirectoryEdit.Directory,
                 FormatoYtdlp, MergeFormat, ArquivosBaixados);

    if FCancelar or (ArquivosBaixados = nil) or (ArquivosBaixados.Count = 0) then
      LogLinha('[AVISO] Nenhum arquivo baixado ou processo cancelado.')
    else
      Fase2_FFmpeg(DirectoryEdit.Directory, ArquivosBaixados,
                   VideoParams, ParamsAudio, ExtFinal, NomePrefixo, DeletarOriginal);
  finally
    FreeAndNil(ArquivosBaixados);
    button_process_DiretoDaVinci.Enabled := True;
    button_process_DiretoDaVinci.Caption := 'PROCESSAR';
    pbar_console.Position := 100;
  end;
end;

procedure TfrDiretoDaVinci.LogLinha(const S: string);
begin
  Memo_visual_console.Lines.Add(S);
  Memo_visual_console.SelStart := Length(Memo_visual_console.Text);
  Application.ProcessMessages;
end;

function TfrDiretoDaVinci.ExecutarComando(const ACmd: string;
                                           const ATagLog: string): Boolean;
var
  AProcess  : TProcess;
  Buffer    : string;
  BytesRead : LongInt;
  RawOutput, PercentStr: string;
  PStart    : Integer;
  PercentVal: Double;
const
  BUF_SIZE = 8192;
begin
  Result   := False;
  Buffer   := '';
  AProcess := TProcess.Create(nil);
  try
    {$IFDEF WINDOWS}
    AProcess.Executable := 'cmd.exe';
    AProcess.Parameters.Add('/c');
    {$ELSE}
    AProcess.Executable := '/usr/bin/bash';
    AProcess.Parameters.Add('-c');
    {$ENDIF}
    AProcess.Parameters.Add(ACmd);
    AProcess.Options := [poUsePipes, poStderrToOutPut, poNoConsole];
    AProcess.Execute;

    while AProcess.Running do
    begin
      if FCancelar then
      begin
        AProcess.Terminate(0);
        LogLinha('[AVISO] Cancelado pelo usuário.');
        Exit;
      end;

      if AProcess.Output.NumBytesAvailable > 0 then
      begin
        SetLength(Buffer, BUF_SIZE);
        BytesRead := AProcess.Output.Read(Buffer[1], BUF_SIZE);
        if BytesRead > 0 then
        begin
          SetLength(Buffer, BytesRead);
          RawOutput := Buffer;

          if Pos('[download]', RawOutput) > 0 then
          begin
            PStart := Pos('%', RawOutput);
            if PStart > 5 then
            begin
              PercentStr := Trim(Copy(RawOutput, PStart - 6, 6));
              if TryStrToFloat(PercentStr, PercentVal, DefaultFormatSettings) then
                pbar_console.Position := Round(PercentVal);
            end;
          end;

          Memo_visual_console.Lines.BeginUpdate;
          try
            Memo_visual_console.SelStart := Length(Memo_visual_console.Text);
            Memo_visual_console.SelText  := Buffer;
            Memo_visual_console.SelStart := Length(Memo_visual_console.Text);
          finally
            Memo_visual_console.Lines.EndUpdate;
          end;
        end;
      end;

      Application.ProcessMessages;
      Sleep(50);
    end;

    while AProcess.Output.NumBytesAvailable > 0 do
    begin
      SetLength(Buffer, AProcess.Output.NumBytesAvailable);
      BytesRead := AProcess.Output.Read(Buffer[1], Length(Buffer));
      if BytesRead > 0 then
      begin
        SetLength(Buffer, BytesRead);
        Memo_visual_console.SelStart := Length(Memo_visual_console.Text);
        Memo_visual_console.SelText  := Buffer;
      end;
    end;

    Result := (AProcess.ExitCode = 0);
    if not Result then
      LogLinha(Format('[ERRO] %s retornou código %d', [ATagLog, AProcess.ExitCode]));
  finally
    AProcess.Free;
  end;
end;

procedure TfrDiretoDaVinci.Fase1_YtDlp(const AURL, APasta,
                                         AFormatoYtdlp, AMergeFormat: string;
                                         out ArquivosBaixados: TStringList);
var
  AProcess  : TProcess;
  CmdYtdlp, Buffer: string;
  BytesRead : LongInt;
  ArqAntes, ArqDepois: TStringList;
  i, PStart : Integer;
  PS        : string;
  PV        : Double;
  ExtAlvo   : string;
const
  BUF_SIZE = 8192;

  function SnapshotPasta(const Ext: string): TStringList;
  var
    SR     : TSearchRec;
    ArqPath: string;
    Exts   : TStringList;
    k      : Integer;
  begin
    Result := TStringList.Create;
    Result.Sorted := True;
    Exts := TStringList.Create;
    try
      if LowerCase(Ext) = 'm4a' then
      begin
        Exts.Add('m4a');
        Exts.Add('webm');
        Exts.Add('opus');
        Exts.Add('ogg');
      end
      else if LowerCase(Ext) = 'mkv' then
      begin
        Exts.Add('mkv');
        Exts.Add('webm');
        Exts.Add('opus');
        Exts.Add('ogg');
      end
      else
        Exts.Add(Ext);

      for k := 0 to Exts.Count - 1 do
        if FindFirst(IncludeTrailingPathDelimiter(APasta) + '*.' + Exts[k],
                     faAnyFile - faDirectory, SR) = 0 then
        begin
          repeat
            ArqPath := IncludeTrailingPathDelimiter(APasta) + SR.Name;
            if Result.IndexOf(ArqPath) < 0 then
              Result.Add(ArqPath);
          until FindNext(SR) <> 0;
          FindClose(SR);
        end;
    finally
      Exts.Free;
    end;
  end;

begin
  Buffer  := '';
  ArquivosBaixados := TStringList.Create;
  ExtAlvo := LowerCase(AMergeFormat);

  ArqAntes := SnapshotPasta(ExtAlvo);
  try
    CmdYtdlp := Format(
      'yt-dlp -f "%s" --merge-output-format %s -P "%s" "%s"',
      [AFormatoYtdlp, AMergeFormat, APasta, AURL]
    );

    LogLinha('[FASE 1] Iniciando yt-dlp...');
    LogLinha('[CMD] ' + CmdYtdlp);

    AProcess := TProcess.Create(nil);
    try
      {$IFDEF WINDOWS}
      AProcess.Executable := 'cmd.exe';
      AProcess.Parameters.Add('/c');
      {$ELSE}
      AProcess.Executable := '/usr/bin/bash';
      AProcess.Parameters.Add('-c');
      {$ENDIF}
      AProcess.Parameters.Add(CmdYtdlp);
      AProcess.Options := [poUsePipes, poStderrToOutPut, poNoConsole];
      AProcess.Execute;

      while AProcess.Running do
      begin
        if FCancelar then
        begin
          AProcess.Terminate(0);
          LogLinha('[AVISO] Cancelado na Fase 1.');
          Exit;
        end;

        if AProcess.Output.NumBytesAvailable > 0 then
        begin
          SetLength(Buffer, BUF_SIZE);
          BytesRead := AProcess.Output.Read(Buffer[1], BUF_SIZE);
          if BytesRead > 0 then
          begin
            SetLength(Buffer, BytesRead);

            if Pos('[download]', Buffer) > 0 then
            begin
              PStart := Pos('%', Buffer);
              if PStart > 5 then
              begin
                PS := Trim(Copy(Buffer, PStart - 6, 6));
                if TryStrToFloat(PS, PV, DefaultFormatSettings) then
                  pbar_console.Position := Round(PV);
              end;
            end;

            Memo_visual_console.Lines.BeginUpdate;
            try
              Memo_visual_console.SelStart := Length(Memo_visual_console.Text);
              Memo_visual_console.SelText  := Buffer;
              Memo_visual_console.SelStart := Length(Memo_visual_console.Text);
            finally
              Memo_visual_console.Lines.EndUpdate;
            end;
          end;
        end;
        Application.ProcessMessages;
        Sleep(50);
      end;

      while AProcess.Output.NumBytesAvailable > 0 do
      begin
        SetLength(Buffer, AProcess.Output.NumBytesAvailable);
        BytesRead := AProcess.Output.Read(Buffer[1], Length(Buffer));
        if BytesRead > 0 then
        begin
          SetLength(Buffer, BytesRead);
          Memo_visual_console.SelStart := Length(Memo_visual_console.Text);
          Memo_visual_console.SelText  := Buffer;
        end;
      end;

      if AProcess.ExitCode <> 0 then
        LogLinha(Format('[AVISO] yt-dlp código %d — verificando arquivos...',
                 [AProcess.ExitCode]));
    finally
      AProcess.Free;
    end;

    ArqDepois := SnapshotPasta(ExtAlvo);
    try
      for i := 0 to ArqDepois.Count - 1 do
        if ArqAntes.IndexOf(ArqDepois[i]) < 0 then
        begin
          ArquivosBaixados.Add(ArqDepois[i]);
          LogLinha('[ARQUIVO] ' + ArqDepois[i]);
        end;
    finally
      ArqDepois.Free;
    end;

    if ArquivosBaixados.Count = 0 then
      LogLinha('[AVISO] Nenhum arquivo novo detectado após o download.')
    else
      LogLinha(Format('[FASE 1] Concluída. %d arquivo(s) prontos.',
               [ArquivosBaixados.Count]));
  finally
    ArqAntes.Free;
  end;
end;

procedure TfrDiretoDaVinci.Fase2_FFmpeg(const APasta: string;
                                         const ArquivosBaixados: TStringList;
                                         const AVideoParams, AParamsAudio, AExt: string;
                                         const NomePrefixo: string;
                                         const DeletarOriginal: Boolean);
var
  i: Integer;
  ArqOrigem, ArqDestino, CmdFFmpeg: string;
  OK: Boolean;
  TotalArquivos: Integer;
begin
  TotalArquivos := ArquivosBaixados.Count;
  if TotalArquivos = 0 then
  begin
    LogLinha('[AVISO] Nenhum arquivo para converter.');
    Exit;
  end;

  LogLinha(Format('[FASE 2] Iniciando FFmpeg para %d arquivo(s)...', [TotalArquivos]));
  pbar_console.Position := 0;

  for i := 0 to TotalArquivos - 1 do
  begin
    if FCancelar then Break;

    ArqOrigem := ArquivosBaixados[i];

    if NomePrefixo = 'ORIGINAL_YTDLP' then
      ArqDestino := ChangeFileExt(ArqOrigem, AExt)
    else
    begin
      if TotalArquivos = 1 then
        ArqDestino := IncludeTrailingPathDelimiter(APasta) + NomePrefixo + AExt
      else
        ArqDestino := IncludeTrailingPathDelimiter(APasta) +
                      NomePrefixo + Format('_%2.2d', [i + 1]) + AExt;
    end;

    if ArqOrigem = ArqDestino then
      ArqDestino := ChangeFileExt(ArqDestino, '') + '_v_ready' + AExt;

    if rbtm_naoSubstituir.Checked and FileExists(ArqDestino) then
    begin
      LogLinha(Format('[PULO] Destino já existe: %s', [ArqDestino]));
      Continue;
    end;

    CmdFFmpeg := Format('ffmpeg -y -i "%s" %s %s "%s"',
                        [ArqOrigem, AVideoParams, AParamsAudio, ArqDestino]);

    LogLinha(Format('[FASE 2] Convertendo [%d/%d]: %s',
             [i + 1, TotalArquivos, ExtractFileName(ArqOrigem)]));
    LogLinha('[CMD] ' + CmdFFmpeg);

    OK := ExecutarComando(CmdFFmpeg, 'FFmpeg');

    if OK then
    begin
      LogLinha('[OK] Convertido: ' + ArqDestino);
      if DeletarOriginal then
      begin
        if DeleteFile(ArqOrigem) then
          LogLinha('[LIMPEZA] Deletado: ' + ArqOrigem)
        else
          LogLinha('[AVISO] Não foi possível deletar: ' + ArqOrigem);
      end;
    end
    else
      LogLinha('[ERRO] Falha ao converter: ' + ExtractFileName(ArqOrigem));

    pbar_console.Position := Round(((i + 1) / TotalArquivos) * 100);
  end;

  if not FCancelar then
    LogLinha(LineEnding + '[SUCESSO] Arquivo pronto para edição!');
end;

procedure TfrDiretoDaVinci.ConfigurarPlataformas;
var
  Item: TComboExItem;
begin
  cbx_option_video_editor.ItemsEx.Clear;

  Item := cbx_option_video_editor.ItemsEx.Add;
  Item.Caption := 'DaVinci Resolve (Free)'; Item.ImageIndex := 0; Item.Indent := 0;

  Item := cbx_option_video_editor.ItemsEx.Add;
  Item.Caption := 'DaVinci Resolve Studio'; Item.ImageIndex := 0; Item.Indent := 0;

  Item := cbx_option_video_editor.ItemsEx.Add;
  Item.Caption := 'Kdenlive';               Item.ImageIndex := 1; Item.Indent := 0;

  Item := cbx_option_video_editor.ItemsEx.Add;
  Item.Caption := 'Shotcut';                Item.ImageIndex := 2; Item.Indent := 0;

  Item := cbx_option_video_editor.ItemsEx.Add;
  Item.Caption := 'OpenShot';               Item.ImageIndex := 3; Item.Indent := 0;

  Item := cbx_option_video_editor.ItemsEx.Add;
  Item.Caption := 'Lightworks (Free)';      Item.ImageIndex := 4; Item.Indent := 0;

  Item := cbx_option_video_editor.ItemsEx.Add;
  Item.Caption := 'Lightworks';             Item.ImageIndex := 4; Item.Indent := 0;

  Item := cbx_option_video_editor.ItemsEx.Add;
  Item.Caption := 'Flowblade';              Item.ImageIndex := 5; Item.Indent := 0;

  Item := cbx_option_video_editor.ItemsEx.Add;
  Item.Caption := 'Cinelerra';              Item.ImageIndex := 6; Item.Indent := 0;

  cbx_option_video_editor.ItemIndex := 0;
end;

function TfrDiretoDaVinci.GetYtdlpFormat(Index: Integer): string;
begin
  case Index of
    0: Result := 'bestvideo+bestaudio/best';
    1: Result := 'bestvideo[height<=?2160]+bestaudio/best';
    2: Result := 'bestvideo[height<=?1440]+bestaudio/best';
    3: Result := 'bestvideo[height<=?1080]+bestaudio/best';
    4: Result := 'bestvideo[height<=?720]+bestaudio/best';
    5: Result := 'bestvideo[height<=?480]+bestaudio/best';
    6: Result := 'bestvideo[height<=?360]+bestaudio/best';
    7: Result := 'bestvideo[height<=?240]+bestaudio/best';
    8: Result := 'bestvideo[height<=?144]+bestaudio/best';
  else
    Result := 'bestvideo+bestaudio/best';
  end;
end;

function TfrDiretoDaVinci.GerarIDAleatorio(Tamanho: Integer): string;
const
  Chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
var
  i: Integer;
begin
  Result := '';
  for i := 1 to Tamanho do
    Result := Result + Chars[Random(Length(Chars)) + 1];
end;

procedure TfrDiretoDaVinci.HelpManager;
begin
  FAssistant.AddHelp(cbx_option_video_editor,
    'Perfil de Compatibilidade: Ajusta automaticamente container e codec ' +
    'para o editor selecionado, respeitando as limitações de codec de cada ' +
    'plataforma (especialmente no Linux, onde royalties restringem H.264/AAC).',
    0, -10, 50);
  FAssistant.AddHelp(ComboBox_Format_Videos,
    'Resolução e Encode: Define a qualidade para o download via yt-dlp ' +
    'e o preset de transcodificação aplicado pelo FFmpeg.',
    0, -10, 50);
  FAssistant.AddHelp(ComboBox_Format_Audios,
    'Stream de Áudio: Codec e bitrate de áudio. Lista filtrada automaticamente ' +
    'para garantir compatibilidade com o container de vídeo escolhido.',
    0, -10, 50);
  FAssistant.AddHelp(ComboBox_options,
    'Perfil de Edição (NLE): Ao mudar o editor no seletor acima, esta lista ' +
    'é reconstruída automaticamente com apenas os codecs que aquele editor suporta.',
    0, -10, 50);
  FAssistant.AddHelp(rbtm_process_cpu,
    'Processamento via Software (CPU): Prioriza qualidade de compressão. ' +
    'Ideal para arquivos finais.',
    0, -10, 50);
  FAssistant.AddHelp(rbtm_process_gpu,
    'Aceleração por Hardware (GPU): NVENC/VAAPI para codificação rápida.',
    0, -10, 50);
  FAssistant.AddHelp(rbtm_padrao,
    'Nomeação Inteligente: Padrão do Synapse com timestamp do momento da conversão.',
    0, -10, 50);
  FAssistant.AddHelp(rbtm_definir,
    'Nomeação Personalizada: Habilita o campo de texto para definir o nome manualmente.',
    0, -10, 50);
  FAssistant.AddHelp(rbtm_ytdlp,
    'Padrão Original: Mantém o nome definido pelo yt-dlp (título extraído da fonte).',
    0, -10, 50);
  FAssistant.AddHelp(rbtm_naoSubstituir,
    'Preservar Originais: Interrompe o processo se o arquivo de destino já existir.',
    0, -10, 50);
  FAssistant.AddHelp(DirectoryEdit,
    'Pasta de destino onde o arquivo convertido será salvo.',
    0, -10, 50);
  FAssistant.AddHelp(rbtm_substituir,
    'Fluxo de Limpeza: Apaga os temporários do yt-dlp após a conversão pelo FFmpeg.',
    0, -10, 50);
  FAssistant.AddHelp(chk_Oversample,
    'Oversample: Força redimensionamento para a resolução selecionada. ' +
    'Útil para compatibilidade com timelines de alta definição.',
    0, -10, 50);
end;

procedure TfrDiretoDaVinci.ConfigurarInterface;
var
  PastaDownloads: string;
begin
  ConfigurarPlataformas;
  HelpManager;
  AtualizarPerfilEditor;

  PastaDownloads := GetUserDir + 'Downloads';
  if DirectoryExists(PastaDownloads) then
    DirectoryEdit.Directory := PastaDownloads
  else
    DirectoryEdit.Directory := GetCurrentDir;
end;

end.
