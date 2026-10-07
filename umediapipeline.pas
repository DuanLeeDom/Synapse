unit uMediaPipeline;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, StrUtils, Forms, Controls, ExtCtrls,
  StdCtrls, EditBtn, ComCtrls, Dialogs, ComboEx, Process, FileUtil,
  uUIResources, uHardwareDetector, uVideoQueue, uVideoQueueView,
  uProcessos, uDependencias;

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

  { TfrMediaPipeline }

  TfrMediaPipeline = class(TFrame)
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
    pnl_versionDaVinci: TPanel;
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
    url_web: TMemo;
    btn_fila_addURL: TButton;
    btn_fila_addFiles: TButton;
    btn_fila_remover: TButton;
    btn_fila_limpar: TButton;
    btn_fila_abrir: TButton;
    grp_fila: TGroupBox;
    pnl_fila_botoes: TPanel;
    pnl_workarea: TPanel;
    procedure button_consoleClick(Sender: TObject);
    procedure ComboBox_optionsChange(Sender: TObject);
    procedure button_P(Sender: TObject);
    procedure url_webKeyDown(Sender: TObject; var Key: Integer;
      Shift: TShiftState);
    procedure rbtm_definirChange(Sender: TObject);
    procedure cbx_option_video_editorChange(Sender: TObject);
    procedure FrameResize(Sender: TObject);
    procedure btn_fila_addURLClick(Sender: TObject);
    procedure btn_fila_addFilesClick(Sender: TObject);
    procedure btn_fila_removerClick(Sender: TObject);
    procedure btn_fila_limparClick(Sender: TObject);
    procedure btn_fila_abrirClick(Sender: TObject);
  private
    FCancelar      : Boolean;
    FProcessando   : Boolean;   // estado real do PROCESSAR/Cancelar
    FControle      : TProcessoControlado;  // substitui FCancelar
    FCurrentProfile: TEditorProfile;
    FCurrentCodecs : TCodecList;
    FAssistant     : TSystemAssistant;  // instância do helper
    FHardware      : THardwareDetector; // detecção de GPU

    FVideoQueue    : TfrVideoQueue;      // área da fila de vídeos
    FFila          : TVideoQueue;        // modelo dos itens da fila
    FGPUAtiva      : TGPUVendor;         // GPU já detectada para a fila
    FQtPendentes   : Integer;            // itens na fila (para a barra geral)
    FIndiceAtual   : Integer;            // item em execução (1..FQtPendentes)

    procedure MontarFila;
    procedure AjustarAlturaConsole;
    procedure ProcessarFila;
    procedure ProcessarItem(Item: TVideoQueueItem; Indice, Total: Integer;
                             DeletarOriginal: Boolean);
    procedure PrepararGPU;
    procedure AtualizarParametrosPendentes;

    function  ItemSelecionado: TVideoQueueItem;

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
    function  CodecSelecionado: string;
    function  NomePrefixoParaItem(AItem: TVideoQueueItem): string;
    procedure AtualizarParametrosDoItem(AItem: TVideoQueueItem);
    function  ProcessoCancelado: Boolean;
    function  ExecutarComando(const ACmd: string; const ATagLog: string;
                               AItem: TVideoQueueItem;
                               AFase: TVideoQueueFase): Boolean;
    procedure AtualizarProgresso(AItem: TVideoQueueItem;
                                 AFase: TVideoQueueFase;
                                 APorcentagem: Integer);
    procedure LogLinha(const S: string);
    procedure Fase1_YtDlp(AItem: TVideoQueueItem;
                           const APasta: string;
                           const ArquivosBaixados: TStringList);
    procedure Fase2_FFmpeg(AItem: TVideoQueueItem;
                           const APasta: string;
                           const ArquivosBaixados: TStringList;
                           const DeletarOriginal: Boolean);
    function  NomeDestino(AItem: TVideoQueueItem; const APasta,
                           ArqOrigem: string; Indice, Total: Integer): string;
    function  ArquivoMaisRecente(const APasta: string;
                                 const AExt: string): string;
    function  SnapshotPasta(const APasta: string;
                            const AExt: string): TStringList;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure AdicionarURLNaFila(const AURL: string);
    procedure AdicionarURLsColadas;
    procedure AdicionarArquivosNaFila;
    procedure IniciarProcessamento;
    procedure EnfocarFila;

    { Usados pelo menu principal da janela. }
    procedure AdicionarURLDaFila;
    procedure AdicionarTodosDaFila;
    procedure IniciarFila;
    procedure CancelarFila;
    procedure AlternarConsole;
  end;

implementation

{$R *.lfm}

{ TfrMediaPipeline }

constructor TfrMediaPipeline.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Randomize;
  FAssistant := TSystemAssistant.Create;
  FHardware  := THardwareDetector.Create;
  FControle := TProcessoControlado.Create(button_process_DiretoDaVinci);
  FFila     := TVideoQueue.Unica;
  FGPUAtiva := gpuNone;
  FCancelar := False;
  FProcessando := False;
  ConfigurarInterface;
end;

destructor TfrMediaPipeline.Destroy;
begin
  FProcessando := False;
  FVideoQueue := nil;   // destruído junto com o frame (owner)

  { Cada objeto só existe se o construtor chegou até ele. Sem esta guarda,
    uma falha durante a criação do frame — por exemplo no carregamento do
    .lfm — derrubaria aqui um Access violation e esconderia a exceção
    original, que é a informação útil. }
  if Assigned(FControle) then
  begin
    FControle.Cancelar;
    FControle.Free;
    FControle := nil;
  end;
  if Assigned(FAssistant) then
  begin
    FAssistant.Free;
    FAssistant := nil;
  end;
  if Assigned(FHardware) then
  begin
    FHardware.Free;
    FHardware := nil;
  end;
  inherited Destroy;
end;

procedure TfrMediaPipeline.MontarFila;
begin
  if Assigned(FVideoQueue) then
    Exit;

  FVideoQueue := TfrVideoQueue.Create(Self);
  FVideoQueue.Parent := grp_fila;
  FVideoQueue.Align  := alClient;
end;

procedure TfrMediaPipeline.FrameResize(Sender: TObject);
begin
  AjustarAlturaConsole;
end;

{ Mantém o console dentro de uma cota razoável da área de trabalho para
  que a fila nunca seja espremida a ponto de sumir. }
procedure TfrMediaPipeline.AjustarAlturaConsole;
var
  Limite: Integer;
begin
  if not Assigned(grp_console) or (not grp_console.Visible) then
    Exit;

  Limite := (pnl_workarea.ClientHeight * 45) div 100;
  if Limite < 70 then
    Limite := 70;
  if grp_console.Height > Limite then
    grp_console.Height := Limite;
end;

function TfrMediaPipeline.GetEditorProfile(EditorID: TVideoEditorID): TEditorProfile;
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

function TfrMediaPipeline.ActiveEditorID: TVideoEditorID;
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

function TfrMediaPipeline.BuildCodecList(const Profile: TEditorProfile): TCodecList;
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

procedure TfrMediaPipeline.GetFFmpegProfile(CodecIndex: Integer;
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

function TfrMediaPipeline.GetAudioCodecParams(AudioIndex, CodecIndex: Integer): string;
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

procedure TfrMediaPipeline.AtualizarOpcoesAudio(CodecIndex: Integer);
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

procedure TfrMediaPipeline.AtualizarPerfilEditor;
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

procedure TfrMediaPipeline.cbx_option_video_editorChange(Sender: TObject);
begin
  FAssistant.RecarregarDependentes([ComboBox_options, ComboBox_Format_Audios]);
  AtualizarPerfilEditor;
end;

procedure TfrMediaPipeline.ComboBox_optionsChange(Sender: TObject);
begin
  AtualizarOpcoesAudio(ComboBox_options.ItemIndex);
end;

procedure TfrMediaPipeline.rbtm_definirChange(Sender: TObject);
begin
  edt_definir.Visible := rbtm_definir.Checked;
end;

procedure TfrMediaPipeline.button_consoleClick(Sender: TObject);
begin
  grp_console.Visible := not grp_console.Visible;

  if grp_console.Visible then
  begin
    grp_console.Align := alBottom;
    button_console.Caption := 'OCULTAR CONSOLE';
    AjustarAlturaConsole;
  end
  else
  begin
    grp_console.Align   := alNone;
    button_console.Caption := 'EXIBIR CONSOLE';
  end;
end;

{ O PROCESSAR agora conduz a fila inteira. A URL digitada no campo de
  origem continua funcionando: se ainda não estiver na fila, entra
  nela antes do processamento (comportamento do fluxo antigo).
  O estado vem de FProcessando, e não da legenda do botão: comparar
  texto deixava o botão travado em "Cancelar" e a próxima clique apenas
  cancelava, mantendo todos os itens em Aguardando. }
procedure TfrMediaPipeline.button_P(Sender: TObject);
begin
  if FProcessando then
  begin
    FCancelar := True;
    FControle.Cancelar;
    Exit;
  end;

  IniciarProcessamento;
end;

procedure TfrMediaPipeline.IniciarProcessamento;
begin
  if DirectoryEdit.Directory = '' then
  begin
    ShowMessage('Por favor, selecione a pasta de destino!');
    Exit;
  end;

  if FFila.QtPendentes = 0 then
  begin
    { Um link ou uma lista inteira colada no campo entram na fila antes de
      começar, sem exigir um clique extra em "ADICIONAR URL". }
    if Trim(url_web.Text) <> '' then
      AdicionarURLsColadas
    else
    begin
      ShowMessage('Adicione um ou mais vídeos à fila (pela URL ou pelos ' +
                  'arquivos locais) antes de processar.');
      Exit;
    end;
  end;

  if FFila.QtPendentes = 0 then
    Exit;

  ProcessarFila;
end;

procedure TfrMediaPipeline.PrepararGPU;
begin
  FGPUAtiva := gpuNone;
  if not rbtm_process_gpu.Checked then
    Exit;

  FGPUAtiva := FHardware.DetectarGPU;
  case FGPUAtiva of
    gpuNone:
    begin
      rbtm_process_cpu.Checked := True;
      ShowMessage('Nenhuma placa de vídeo compatível encontrada.'
                  + #13#10 + 'Usando CPU.');
    end;
    gpuNVIDIA: LogLinha('[GPU] NVIDIA detectada — usando NVENC');
    gpuAMD:    LogLinha('[GPU] AMD detectada — usando AMF');
    gpuIntel:  LogLinha('[GPU] Intel detectada — usando QSV');
  end;
end;

{ Processa um item da fila isolando falhas: uma excecao em um item nunca
  interrompe os demais. }
procedure TfrMediaPipeline.ProcessarItem(Item: TVideoQueueItem;
                                          Indice, Total: Integer;
                                          DeletarOriginal: Boolean);
var
  Arquivos: TStringList;
begin
  Arquivos := TStringList.Create;
  try
    AtualizarParametrosDoItem(Item);
    Item.Status    := vqsProcessando;
    Item.Progresso := 0;
    Item.Destino   := '';
    Item.Mensagem  := 'Iniciando...';
    FVideoQueue.AtualizarItem(Item);
    LogLinha(LineEnding + Format('=== [%d/%d] %s ===',
      [Indice, Total, Item.Titulo]));

    if Item.OrigemLocal then
    begin
      if not FileExists(Item.ArquivoLocal) then
      begin
        Item.Status   := vqsErro;
        Item.Mensagem := 'Arquivo local não encontrado';
        FVideoQueue.AtualizarItem(Item);
        LogLinha('[ERRO] ' + Item.Mensagem + ': ' + Item.ArquivoLocal);
        Exit;
      end;
      Arquivos.Add(Item.ArquivoLocal);
      FVideoQueue.EnfileirarMiniatura(Item, Item.ArquivoLocal);
    end
    else
    begin
      Fase1_YtDlp(Item, DirectoryEdit.Directory, Arquivos);

      if Arquivos.Count > 0 then
      begin
        Item.Titulo := ChangeFileExt(ExtractFileName(Arquivos[0]), '');
        FVideoQueue.EnfileirarMiniatura(Item, Arquivos[0]);
      end;
    end;

    if ProcessoCancelado then
    begin
      Item.Status   := vqsCancelado;
      Item.Mensagem := 'Cancelado pelo usuário';
      FVideoQueue.AtualizarItem(Item);
      Exit;
    end;

    if Arquivos.Count = 0 then
    begin
      Item.Status   := vqsErro;
      Item.Mensagem := 'O download não gerou nenhum arquivo';
      FVideoQueue.AtualizarItem(Item);
      LogLinha('[ERRO] ' + Item.Mensagem + '.');
      Exit;
    end;

    Fase2_FFmpeg(Item, DirectoryEdit.Directory, Arquivos, DeletarOriginal);
    FVideoQueue.AtualizarItem(Item);
  finally
    Arquivos.Free;
  end;
end;

{ Gera o processamento de todos os itens que ainda estão aguardando. Um
  item que falha não interrompe os demais. }
procedure TfrMediaPipeline.ProcessarFila;
var
  i, Total: Integer;
  Item: TVideoQueueItem;
  DeletarOriginal: Boolean;
begin
  { Reentrada: dois cliques no PROCESSAR nao podem abrir dois lacos. }
  if FProcessando then
    Exit;

  Total := FFila.QtPendentes;
  if Total = 0 then
    Exit;

  FVideoQueue.Processando  := True;
  FProcessando             := True;
  btn_fila_remover.Enabled := False;
  btn_fila_limpar.Enabled  := False;
  btn_fila_addURL.Enabled  := False;
  btn_fila_addFiles.Enabled:= False;

  FCancelar    := False;
  FQtPendentes := Total;
  FIndiceAtual := 0;

  pbar_console.Position := 0;
  Memo_visual_console.Clear;

  try
    FControle.IniciarProcesso;
    PrepararGPU;

    DeletarOriginal := rbtm_substituir.Checked;

    LogLinha(Format('[INFO] %d vídeo(s) na fila.', [Total]));
    LogLinha(Format('[INFO] Conversão: %s', [CodecSelecionado]));

    for i := 0 to FFila.QtItens - 1 do
    begin
      Item := FFila.Item(i);
      if Item.Status <> vqsAguardando then
        Continue;

      if ProcessoCancelado then
        Break;

      Inc(FIndiceAtual);

      try
        ProcessarItem(Item, FIndiceAtual, Total, DeletarOriginal);
      except
        on E: Exception do
        begin
          Item.Status   := vqsErro;
          Item.Mensagem := 'Erro: ' + E.Message;
          FVideoQueue.AtualizarItem(Item);
          LogLinha('[ERRO] Item ' + IntToStr(FIndiceAtual) + ': ' + E.Message);
        end;
      end;

      if ProcessoCancelado then
        Break;

      pbar_console.Position := Round(((i + 1) / Total) * 100);
      Application.ProcessMessages;
    end;
  finally
    FVideoQueue.Processando  := False;
    FProcessando             := False;
    btn_fila_remover.Enabled := True;
    btn_fila_limpar.Enabled  := True;
    btn_fila_addURL.Enabled  := True;
    btn_fila_addFiles.Enabled:= True;
    FControle.FinalizarProcesso;   { restaura a legenda PROCESSAR }
    pbar_console.Position := 100;
    FQtPendentes := 0;
    FIndiceAtual := 0;
  end;
end;

{ ====================== Fila:Inclusion, remo e leitura ====================== }

procedure TfrMediaPipeline.AdicionarURLNaFila(const AURL: string);
var
  Item: TVideoQueueItem;
  Antes: Integer;
begin
  Antes := FFila.QtItens;
  Item  := FVideoQueue.Adicionar(Trim(AURL));

  if not Assigned(Item) then
  begin
    if Antes < FFila.QtItens then
      Exit;
    if Trim(AURL) <> '' then
      ShowMessage('Esta origem já está na fila.');
    Exit;
  end;

  AtualizarParametrosDoItem(Item);
  FVideoQueue.AtualizarItem(Item);
  url_web.Clear;
  LogLinha(Format('[FILA] Item %d adicionado (%d na fila).',
    [Item.Indice, FFila.QtItens]));
end;

{ Adiciona em lote tudo que foi colado no campo de URL, reaproveitando
  exatamente o mesmo caminho de AdicionarURLNaFila: cada origem vira um
  item comum da fila, com os parâmetros que já estiverem selecionados. }
procedure TfrMediaPipeline.AdicionarURLsColadas;
var
  Lista: TStringList;
  i, Qt: Integer;
begin
  if Trim(url_web.Text) = '' then
  begin
    ShowMessage('Cole a URL do vídeo no campo acima antes de adicionar à fila.');
    Exit;
  end;

  Lista := ExtrairURLs(url_web.Text);
  try
    if Lista.Count = 0 then
    begin
      ShowMessage('Nenhuma URL válida foi reconhecida no texto colado. ' +
                  'Verifique se o link começa com http:// ou https://.');
      Exit;
    end;

    { Adição única em lote: a view constrói os painéis novos de uma vez
      e anima o timer só depois, em vez de notificar a cada entrada. }
    Qt := FVideoQueue.AdicionarVarias(Lista);

    if Qt = 0 then
    begin
      ShowMessage('Todas as URLs coladas já estão na fila.');
      Exit;
    end;

    { Aplica as predefinições atuais a cada item novo do lote. }
    for i := FFila.QtItens - Qt to FFila.QtItens - 1 do
    begin
      AtualizarParametrosDoItem(FFila.Item(i));
      FVideoQueue.AtualizarItem(FFila.Item(i));
    end;

    url_web.Clear;

    if Qt = 1 then
      LogLinha(Format('[FILA] Item %d adicionado (%d na fila).',
        [FFila.Item(FFila.QtItens - 1).Indice, FFila.QtItens]))
    else
      LogLinha(Format('[FILA] %d URLs adicionadas (%d na fila).',
        [Qt, FFila.QtItens]));
  finally
    Lista.Free;
  end;
end;

procedure TfrMediaPipeline.AdicionarArquivosNaFila;
var
  Dialogo: TOpenDialog;
  Selecionados: TStringList;
  i, Antes, Total: Integer;
begin
  Selecionados := TStringList.Create;
  Dialogo := TOpenDialog.Create(Self);
  try
    Dialogo.Title  := 'Selecione os vídeos para a fila';
    Dialogo.Options := [ofAllowMultiSelect, ofFileMustExist, ofPathMustExist];
    Dialogo.Filter := 'Vídeos|*.mp4;*.mkv;*.mov;*.avi;*.webm;*.flv;*.wmv;*.m4v;' +
                      '*.mpg;*.mpeg;*.ts;*.m2ts;*.3gp;*.ogv;*.vob;*.mts;*.mxf|' +
                      'Todos os arquivos|*.*';
    if Dialogo.Execute then
      Selecionados.Assign(Dialogo.Files);
  finally
    Dialogo.Free;
  end;

  try
    Antes := FFila.QtItens;
    Total := FVideoQueue.AdicionarArquivos(Selecionados);

    for i := Antes to FFila.QtItens - 1 do
    begin
      AtualizarParametrosDoItem(FFila.Item(i));
      FVideoQueue.AtualizarItem(FFila.Item(i));
    end;
  finally
    Selecionados.Free;
  end;

  if Total > 0 then
    LogLinha(Format('[FILA] %d arquivo(s) adicionado(s) — %d na fila.',
      [Total, FFila.QtItens]));
end;

procedure TfrMediaPipeline.btn_fila_addURLClick(Sender: TObject);
begin
  AdicionarURLsColadas;
end;

{ Enter adiciona o que está colado, como o TEdit permitia; Shift+Enter
  quebra linha, para quem quiser digitar a lista à mão. }
procedure TfrMediaPipeline.url_webKeyDown(Sender: TObject; var Key: Integer;
  Shift: TShiftState);
begin
  if Key <> 13 then
    Exit;
  if ssShift in Shift then
    Exit;
  Key := 0;
  AdicionarURLsColadas;
end;

procedure TfrMediaPipeline.btn_fila_addFilesClick(Sender: TObject);
begin
  AdicionarArquivosNaFila;
end;

procedure TfrMediaPipeline.btn_fila_removerClick(Sender: TObject);
begin
  FVideoQueue.RemoverSelecionado;
end;

procedure TfrMediaPipeline.btn_fila_limparClick(Sender: TObject);
begin
  if FVideoQueue.Processando then
  begin
    ShowMessage('Aguarde o término do processamento para limpar a fila.');
    Exit;
  end;
  FVideoQueue.LimparTudo;
end;

procedure TfrMediaPipeline.btn_fila_abrirClick(Sender: TObject);
var
  Item: TVideoQueueItem;
  Alvo: string;
begin
  Item := FVideoQueue.Selecionado;
  Alvo := '';
  if Assigned(Item) then
    Alvo := Item.Destino;
  if Alvo = '' then
    Alvo := DirectoryEdit.Directory;
  if Alvo = '' then
    Exit;

  Alvo := Copy(Alvo, 1, Pos('|', Alvo) - 1);
  FVideoQueue.AbrirPasta(Alvo);
end;

procedure TfrMediaPipeline.EnfocarFila;
begin
  if not Assigned(grp_fila) then
    Exit;
  grp_fila.Visible := True;
  if Assigned(button_process_DiretoDaVinci) then
    button_process_DiretoDaVinci.SetFocus;
end;

{ ====================== Fila:parametros por item ====================== }

function TfrMediaPipeline.CodecSelecionado: string;
var
  i: Integer;
begin
  Result := '';
  if (ComboBox_options.ItemIndex < 0) or
     (ComboBox_options.ItemIndex >= Length(FCurrentCodecs)) then
    Exit;
  Result := FCurrentCodecs[ComboBox_options.ItemIndex].Caption;
end;

function TfrMediaPipeline.NomePrefixoParaItem(AItem: TVideoQueueItem): string;
begin
  { Em modo "YT-DLP" o prefixo vazio diz ao resto do fluxo para preservar o
    nome que o yt-dlp gerou (titulo): o destino sai do proprio arquivo
    baixado, so trocando a extensao. Um literal aqui renomearia o video
    para algo que o usuario nunca pediu. }
  if rbtm_ytdlp.Checked then
    Result := ''
  else if rbtm_padrao.Checked then
    Result := 'editor_ready_' + FormatDateTime('yyyy_mm_dd_hhnnss', Now) +
              '_' + GerarIDAleatorio(8)
  else if rbtm_definir.Checked and (Trim(edt_definir.Text) <> '') then
    Result := Trim(edt_definir.Text)
  else
    Result := 'processado_' + GerarIDAleatorio(8);

  { nomes digitados pelo usuário se repetem entre itens da fila }
  if rbtm_definir.Checked and (Trim(edt_definir.Text) <> '') and
     (FFila.QtPendentes > 1) then
    Result := Result + Format('_%2.2d', [AItem.Indice]);
end;

procedure TfrMediaPipeline.AtualizarParametrosDoItem(AItem: TVideoQueueItem);
var
  VideoParams, ExtFinal, MergeFormat, ParamsAudio: string;
  IsAudioOnly: Boolean;
begin
  if not Assigned(AItem) then
    Exit;

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

  if rbtm_process_gpu.Checked and (FGPUAtiva <> gpuNone) then
    VideoParams := FHardware.ObterParamsGPU(VideoParams, FGPUAtiva);

  if IsAudioOnly then
  begin
    AItem.FormatoYtdlp := 'bestaudio/best';
    MergeFormat        := 'mkv';
  end
  else
    AItem.FormatoYtdlp := GetYtdlpFormat(ComboBox_Format_Videos.ItemIndex);

  AItem.VideoParams   := VideoParams;
  AItem.ParamsAudio   := ParamsAudio;
  AItem.ExtDestino    := ExtFinal;
  AItem.MergeFormat   := MergeFormat;
  AItem.CodecDestino  := CodecSelecionado;
  AItem.NomePrefixo   := NomePrefixoParaItem(AItem);
  AItem.PastaDestino  := DirectoryEdit.Directory;
end;

procedure TfrMediaPipeline.AtualizarParametrosPendentes;
var
  i: Integer;
begin
  for i := 0 to FFila.QtItens - 1 do
    if FFila.Item(i).Status = vqsAguardando then
    begin
      AtualizarParametrosDoItem(FFila.Item(i));
      FVideoQueue.AtualizarItem(FFila.Item(i));
    end;
end;

function TfrMediaPipeline.ItemSelecionado: TVideoQueueItem;
begin
  Result := FVideoQueue.Selecionado;
end;

{ ====================== Cancelamento ====================== }

function TfrMediaPipeline.ProcessoCancelado: Boolean;
begin
  Result := FCancelar or FControle.EstaCancelado;
end;

procedure TfrMediaPipeline.AtualizarProgresso(AItem: TVideoQueueItem;
                                              AFase: TVideoQueueFase;
                                              APorcentagem: Integer);
var
  Fracao: Double;
begin
  if not Assigned(AItem) then
    Exit;

  if APorcentagem < 0 then APorcentagem := 0;
  if APorcentagem > 100 then APorcentagem := 100;

  case AFase of
    vqfDownload  : AItem.Progresso := Round(APorcentagem * 0.5);
    vqfConversao: AItem.Progresso := 50 + Round(APorcentagem * 0.5);
  end;

  FVideoQueue.AtualizarItem(AItem);

  if FQtPendentes > 0 then
  begin
    Fracao := ((FIndiceAtual - 1) + (AItem.Progresso / 100)) / FQtPendentes;
    pbar_console.Position := Round(Fracao * 100);
  end;
end;

procedure TfrMediaPipeline.LogLinha(const S: string);
begin
  Memo_visual_console.Lines.Add(S);
  Memo_visual_console.SelStart := Length(Memo_visual_console.Text);
  Application.ProcessMessages;
end;

{ ---------- Acoes expostas para o menu da janela principal ---------- }

procedure TfrMediaPipeline.AdicionarURLDaFila;
begin
  EnfocarFila;
  btn_fila_addURLClick(Self);
end;

procedure TfrMediaPipeline.AdicionarTodosDaFila;
var
  Selecionados: TStringList;
  i, Qt: Integer;
begin
  EnfocarFila;
  Selecionados := TStringList.Create;
  try
    for i := 0 to FFila.QtItens - 1 do
      if FFila.Item(i).OrigemLocal and (FFila.Item(i).Status = vqsAguardando) then
        Selecionados.Add(FFila.Item(i).ArquivoLocal);
    Qt := FVideoQueue.AdicionarArquivos(Selecionados);
    if Qt > 0 then
      LogLinha(Format('[FILA] %d arquivo(s) adicionado(s) — %d na fila.',
        [Qt, FFila.QtItens]));
  finally
    Selecionados.Free;
  end;
  AtualizarParametrosPendentes;
end;

procedure TfrMediaPipeline.IniciarFila;
begin
  EnfocarFila;
  IniciarProcessamento;
end;

{ O cancelamento usa o mesmo caminho do botao: sinaliza FCancelar e
  mata o processo externo em execucao. FVideoQueue.Processando fica a
  cargo do finally de ProcessarFila, que encerra o laco. }
procedure TfrMediaPipeline.CancelarFila;
begin
  if not FProcessando then
    Exit;
  FCancelar := True;
  FControle.Cancelar;
  LogLinha('[AVISO] Cancelamento solicitado...');
end;

procedure TfrMediaPipeline.AlternarConsole;
begin
  if Assigned(grp_console) then
    grp_console.Visible := not grp_console.Visible;
  AjustarAlturaConsole;
end;

function TfrMediaPipeline.ExecutarComando(const ACmd: string;
                                           const ATagLog: string;
                                           AItem: TVideoQueueItem;
                                           AFase: TVideoQueueFase): Boolean;
var
  AProcess  : TProcess;
  Buffer    : string;
  BytesRead : LongInt;
  RawOutput, PercentStr: string;
  PStart    : Integer;
  PercentVal: Double;
  Duracao, Momento: Double;
  UltimoPct : Integer;
  Pct       : Integer;
  EhFFmpeg  : Boolean;
  Partes    : TStringList;
  Executavel: string;
  i         : Integer;
const
  BUF_SIZE = 8192;

  { Converte "HH:MM:SS.ss" em segundos; devolve -1 se não encontrar. }
  function TempoDe(const ATexto, AMarcador: string): Double;
  var
    P, i, j: Integer;
    H, M, Seg: Double;
    Resto, Parte: string;
  begin
    Result := -1;
    P := Pos(AMarcador, ATexto);
    if P = 0 then
      Exit;

    Parte := Copy(ATexto, P + Length(AMarcador), 16);

    i := Pos(':', Parte);
    if i = 0 then
      Exit;
    if not TryStrToFloat(Trim(Copy(Parte, 1, i - 1)), H) then
      Exit;

    Resto := Copy(Parte, i + 1, 15);
    j := Pos(':', Resto);
    if j = 0 then
      Exit;
    if not TryStrToFloat(Trim(Copy(Resto, 1, j - 1)), M) then
      Exit;

    Parte := Copy(Resto, j + 1, 8);
    i := Pos(' ', Parte);
    if i > 0 then
      Parte := Copy(Parte, 1, i - 1);
    if not TryStrToFloat(Parte, Seg) then
      Exit;

    Result := H * 3600 + M * 60 + Seg;
  end;

begin
  Result     := False;
  Buffer     := '';
  Duracao    := 0;
  UltimoPct  := -1;
  EhFFmpeg   := (Pos('ffmpeg', ACmd) > 0);

  { O comando chega como uma unica string montada com Format, com aspas
    em volta dos caminhos. Executar isso via 'cmd.exe /c' delegava o
    trabalho a um interpretador de comandos que o Windows ja vem com,
    com tudo o que isso traz de quoting fragil. Em vez disso a linha e
    quebrada em executavel e argumentos e o binario e chamado direto. }
  Partes := TGerenciadorDependencias.DividirArgumentos(ACmd);
  try
    if Partes.Count = 0 then
    begin
      LogLinha('[ERRO] Comando vazio');
      Exit;
    end;

    Executavel := ExtractFileExt(Partes[0]);
    if Executavel = '' then
      Executavel := Partes[0];

    { Nome solto no comando vira caminho absoluto: o catalogo procura o
      binario em synapse.ini, tools, pasta do executavel e PATH. }
    if ExtractFilePath(Partes[0]) = '' then
    begin
      case Executavel of
        'yt-dlp.exe', 'yt-dlp':
          Partes[0] := TGerenciadorDependencias.Caminho(depYtDlp);
        'ffmpeg.exe', 'ffmpeg':
          Partes[0] := TGerenciadorDependencias.Caminho(depFFmpeg);
        'ffprobe.exe', 'ffprobe':
          Partes[0] := TGerenciadorDependencias.Caminho(depQT);
      end;
      if Partes[0] = '' then
        Partes[0] := Executavel;
    end;

    AProcess := TProcess.Create(nil);
    try
      AProcess.Executable := Partes[0];
      for i := 1 to Partes.Count - 1 do
        AProcess.Parameters.Add(Partes[i]);
      AProcess.Options := [poUsePipes, poStderrToOutPut, poNoConsole];
      AProcess.Execute;

      { Vincular ao Job do aplicativo e o que garante que um ffmpeg ou
        yt-dlp em andamento nao sobreviva ao fechamento da janela. }
      {$IFDEF WINDOWS}
      TGerenciadorProcessos.Vincular(THandle(AProcess.ProcessHandle));
      {$ENDIF}

      FControle.RegistrarProcesso(AProcess);

    while AProcess.Running do
    begin
      if ProcessoCancelado then
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

          if Assigned(AItem) then
          begin
            if EhFFmpeg then
            begin
              if Duracao <= 0 then
                Duracao := TempoDe(RawOutput, 'Duration: ');
              if Duracao > 0 then
              begin
                Momento := TempoDe(RawOutput, 'time=');
                if Momento >= 0 then
                begin
                  Pct := Round((Momento / Duracao) * 100);
                  if Pct > 100 then Pct := 100;
                  if Pct > UltimoPct then
                  begin
                    UltimoPct := Pct;
                    AItem.Mensagem := Format('Convertendo... %d%%', [Pct]);
                    AtualizarProgresso(AItem, AFase, Pct);
                  end;
                end;
              end;
            end
            else if Pos('[download]', RawOutput) > 0 then
            begin
              PStart := Pos('%', RawOutput);
              if PStart > 5 then
              begin
                PercentStr := Trim(Copy(RawOutput, PStart - 6, 6));
                if TryStrToFloat(PercentStr, PercentVal, DefaultFormatSettings) then
                begin
                  Pct := Round(PercentVal);
                  if (Pct > UltimoPct) and (Pct <= 100) then
                  begin
                    UltimoPct := Pct;
                    AItem.Mensagem := Format('Baixando... %d%%', [Pct]);
                    AtualizarProgresso(AItem, AFase, Pct);
                  end;
                end;
              end;
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
  finally
    Partes.Free;
  end;
end;

function TfrMediaPipeline.SnapshotPasta(const APasta, AExt: string): TStringList;
var
  SR      : TSearchRec;
  ArqPath : string;
  Exts    : TStringList;
  k       : Integer;
begin
  Result := TStringList.Create;
  Exts := TStringList.Create;
  try
    if LowerCase(AExt) = 'm4a' then
    begin
      Exts.Add('m4a');
      Exts.Add('webm');
      Exts.Add('opus');
      Exts.Add('ogg');
    end
    else if LowerCase(AExt) = 'mkv' then
    begin
      Exts.Add('mkv');
      Exts.Add('webm');
      Exts.Add('opus');
      Exts.Add('ogg');
    end
    else
      Exts.Add(AExt);

    Result.Sorted := True;
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

function TfrMediaPipeline.ArquivoMaisRecente(const APasta,
                                             AExt: string): string;
var
  Lista: TStringList;
  i: Integer;
begin
  Result := '';
  Lista := SnapshotPasta(APasta, AExt);
  try
    if Lista.Count > 0 then
    begin
      Result := Lista[0];
      for i := 1 to Lista.Count - 1 do
        if FileAge(Lista[i]) > FileAge(Result) then
          Result := Lista[i];
    end;
  finally
    Lista.Free;
  end;
end;

function TfrMediaPipeline.NomeDestino(AItem: TVideoQueueItem;
                                      const APasta, ArqOrigem: string;
                                      Indice, Total: Integer): string;
begin
  if AItem.NomePrefixo = '' then
    Result := ChangeFileExt(ArqOrigem, AItem.ExtDestino)
  else if Total = 1 then
    Result := IncludeTrailingPathDelimiter(APasta) + AItem.NomePrefixo +
              AItem.ExtDestino
  else
    Result := IncludeTrailingPathDelimiter(APasta) + AItem.NomePrefixo +
              Format('_%2.2d', [Indice + 1]) + AItem.ExtDestino;
end;

procedure TfrMediaPipeline.Fase1_YtDlp(AItem: TVideoQueueItem;
                                       const APasta: string;
                                       const ArquivosBaixados: TStringList);
var
  CmdYtdlp : string;
  ArqAntes, ArqDepois: TStringList;
  i: Integer;
  ExtAlvo, sRecente : string;
begin
  ExtAlvo := LowerCase(AItem.MergeFormat);
  if ExtAlvo = '' then
    ExtAlvo := LowerCase(AItem.ExtDestino);

  ArqAntes := SnapshotPasta(APasta, ExtAlvo);
  ArqDepois := nil;
  try
    CmdYtdlp := Format(
      'yt-dlp -f "%s" --merge-output-format %s -P "%s" "%s"',
      [AItem.FormatoYtdlp, AItem.MergeFormat, APasta, AItem.Url]
    );

    AItem.Fase     := vqfDownload;
    AItem.Mensagem := 'Baixando...';
    FVideoQueue.AtualizarItem(AItem);
    LogLinha('[CMD] ' + CmdYtdlp);

    if not ExecutarComando(CmdYtdlp, 'yt-dlp', AItem, vqfDownload) then
    begin
      if not ProcessoCancelado then
        AItem.Mensagem := 'Falha no download';
      Exit;
    end;

    ArqDepois := SnapshotPasta(APasta, ExtAlvo);
    for i := 0 to ArqDepois.Count - 1 do
      if ArqAntes.IndexOf(ArqDepois[i]) < 0 then
        ArquivosBaixados.Add(ArqDepois[i]);

    if ArquivosBaixados.Count = 0 then
    begin
      { fallback: usa o arquivo mais recente da pasta }
      sRecente := ArquivoMaisRecente(APasta, ExtAlvo);
      if sRecente <> '' then
      begin
        ArquivosBaixados.Add(sRecente);
        LogLinha('[AVISO] Usando arquivo mais recente: ' + sRecente);
      end;
    end;

    if ArquivosBaixados.Count > 0 then
    begin
      AItem.Mensagem := Format('%d arquivo(s) baixado(s)', [ArquivosBaixados.Count]);
      LogLinha(Format('[FASE 1] Concluída. %d arquivo(s) prontos.',
        [ArquivosBaixados.Count]));
    end
    else
    begin
      AItem.Mensagem := 'Nenhum arquivo baixado';
      LogLinha('[ERRO] Nenhum arquivo detectado após o download.');
    end;
  finally
    ArqAntes.Free;
    ArqDepois.Free;
  end;
end;

procedure TfrMediaPipeline.Fase2_FFmpeg(AItem: TVideoQueueItem;
                                       const APasta: string;
                                       const ArquivosBaixados: TStringList;
                                       const DeletarOriginal: Boolean);
var
  i: Integer;
  ArqOrigem, ArqDestino, CmdFFmpeg: string;
  OK, AlgumOK: Boolean;
  TotalArquivos: Integer;
begin
  TotalArquivos := ArquivosBaixados.Count;
  if TotalArquivos = 0 then
  begin
    AItem.Status   := vqsErro;
    AItem.Mensagem := 'Nada para converter';
    FVideoQueue.AtualizarItem(AItem);
    LogLinha('[ERRO] Nenhum arquivo para converter.');
    Exit;
  end;

  AItem.Fase     := vqfConversao;
  AItem.Mensagem := 'Convertendo...';
  FVideoQueue.AtualizarItem(AItem);

  { Rotulo do log: no modo "YT-DLP" o prefixo e vazio e o que vale e o nome
    original do primeiro arquivo baixado. }
  if AItem.NomePrefixo = '' then
    LogLinha(Format('[FASE 2] FFmpeg — %d arquivo(s) com nome original do yt-dlp',
      [TotalArquivos]))
  else
    LogLinha(Format('[FASE 2] FFmpeg — %d arquivo(s) em %s',
      [TotalArquivos, AItem.NomePrefixo]));

  AlgumOK := False;

  for i := 0 to TotalArquivos - 1 do
  begin
    if ProcessoCancelado then
      Break;

    ArqOrigem := ArquivosBaixados[i];
    ArqDestino := NomeDestino(AItem, APasta, ArqOrigem, i, TotalArquivos);

    if ArqOrigem = ArqDestino then
      ArqDestino := ChangeFileExt(ArqDestino, '') + '_v_ready' + AItem.ExtDestino;

    if rbtm_naoSubstituir.Checked and FileExists(ArqDestino) then
    begin
      LogLinha(Format('[PULO] Destino já existe: %s', [ArqDestino]));
      AItem.Destino := ArqDestino;
      AlgumOK := True;
      Continue;
    end;

    CmdFFmpeg := Format('ffmpeg -y -i "%s" %s %s "%s"',
      [ArqOrigem, AItem.VideoParams, AItem.ParamsAudio, ArqDestino]);

    LogLinha(Format('[FASE 2] Convertendo [%d/%d]: %s',
      [i + 1, TotalArquivos, ExtractFileName(ArqOrigem)]));

    OK := ExecutarComando(CmdFFmpeg, 'FFmpeg', AItem, vqfConversao);

    if OK then
    begin
      AlgumOK := True;
      AItem.Destino := ArqDestino;
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
    begin
      AItem.Mensagem := 'Falha na conversão';
      LogLinha('[ERRO] Falha ao converter: ' + ExtractFileName(ArqOrigem));
      Exit;
    end;

    AItem.Progresso := 50 + Round(((i + 1) / TotalArquivos) * 50);
    FVideoQueue.AtualizarItem(AItem);
  end;

  if ProcessoCancelado then
  begin
    AItem.Status := vqsCancelado;
    Exit;
  end;

  if AlgumOK then
  begin
    AItem.Status    := vqsConcluido;
    AItem.Progresso := 100;
    AItem.Mensagem  := 'Concluído';
    LogLinha(LineEnding + '[SUCESSO] Item concluído.');
  end
  else
  begin
    AItem.Status   := vqsErro;
    AItem.Mensagem := 'Nada foi convertido';
  end;

  FVideoQueue.AtualizarItem(AItem);
end;

procedure TfrMediaPipeline.ConfigurarPlataformas;
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

function TfrMediaPipeline.GetYtdlpFormat(Index: Integer): string;
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

function TfrMediaPipeline.GerarIDAleatorio(Tamanho: Integer): string;
const
  Chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
var
  i: Integer;
begin
  Result := '';
  for i := 1 to Tamanho do
    Result := Result + Chars[Random(Length(Chars)) + 1];
end;

procedure TfrMediaPipeline.HelpManager;
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
    'Padrão Original: Mantém o nome que o yt-dlp deu ao arquivo (título extraído ' +
    'da fonte); a conversão preserva esse nome, trocando apenas a extensão.',
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

procedure TfrMediaPipeline.ConfigurarInterface;
var
  PastaDownloads: string;
begin
  ConfigurarPlataformas;
  HelpManager;
  AtualizarPerfilEditor;
  MontarFila;

  PastaDownloads := GetUserDir + 'Downloads';
  if DirectoryExists(PastaDownloads) then
    DirectoryEdit.Directory := PastaDownloads
  else
    DirectoryEdit.Directory := GetCurrentDir;
end;

end.
