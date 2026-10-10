unit uDownloadService;

{$mode ObjFPC}{$H+}

{ uDownloadService

  Tela do Download Service.

  A regra fica toda em uDownloadModel e uDownloadCatalog: esta unit so le o
  que o usuario pediu, pede ao modelo para harmonizar e limitar, mostra o
  que pode ser feito e executa as fases. As tres fases e por que sao tres
  estao explicadas em uDownloadModel.

  A tela segue o mesmo visual do Media Pipeline: grupos numerados que vao
  somando de cima para baixo, area de trabalho no meio que sobra, e o botao
  verde #556F22 com a mesma fonte. A revelacao progressiva e de verdade:
  o que o metodo escolhido nao consegue fazer some, em vez de ficar
  desabilitado fazendo o usuario adivinhar o porque. }

interface

uses
    Classes, SysUtils, Forms, Controls, ExtCtrls,
    StdCtrls, EditBtn, ComCtrls, Dialogs,
    uDownloadModel, uDownloadCatalog, uDependencias, uProcessos, uConfig,
    uCookies;

type

  { TfrDownloadService }

  TfrDownloadService = class(TFrame)
    button_process_DiretoDaVinci: TButton;
    button_console: TButton;
    cbx_codec_audio: TComboBox;
    cbx_codec_video: TComboBox;
    cbx_container: TComboBox;
    cbx_fps: TComboBox;
    cbx_perfil: TComboBox;
    cbx_preset: TComboBox;
    cbx_resolucao: TComboBox;
    chk_nome_proprio: TCheckBox;
    DirectoryEdit: TDirectoryEdit;
    edt_altura: TEdit;
    edt_largura: TEdit;
    edt_nome: TEdit;
    edt_url: TEdit;
    grp_console: TGroupBox;
    grp_formato: TGroupBox;
    grp_metodo: TGroupBox;
    grp_origem: TGroupBox;
    grp_qualidade: TGroupBox;
    grp_resumo: TGroupBox;
    grp_tamanho: TGroupBox;
    lbl_audio: TLabel;
    lbl_codec_audio: TLabel;
    lbl_codec_video: TLabel;
    lbl_container: TLabel;
    lbl_explicacao: TLabel;
    lbl_pasta: TLabel;
    lbl_preset: TLabel;
    lbl_qual_valor: TLabel;
    lbl_url: TLabel;
    Memo_visual_console: TMemo;
    memo_resumo: TMemo;
    pbar_processo: TProgressBar;
    pnl_button: TPanel;
    pnl_DownloadService: TPanel;
    pnl_DownloadService_01: TPanel;
    pnl_workarea: TPanel;
    rbtm_fps_original: TRadioButton;
    rbtm_fps_personalizado: TRadioButton;
    rbtm_metodo_completo: TRadioButton;
    rbtm_metodo_simples: TRadioButton;
    rbtm_qual_constante: TRadioButton;
    rbtm_qual_taxa: TRadioButton;
    rbtm_res_original: TRadioButton;
    rbtm_res_personalizada: TRadioButton;
    rbtm_res_predefinida: TRadioButton;
    trk_qual_audio: TTrackBar;
    trk_qual_video: TTrackBar;
    procedure button_consoleClick(Sender: TObject);
    procedure button_process_DiretoDaVinciClick(Sender: TObject);
    procedure trk_qual_audioChange(Sender: TObject);
    procedure trk_qual_videoChange(Sender: TObject);

    { Evento compartilhado por todos os controles que mudam as opcoes. Fica
      aqui, publicado, porque o leitor de LFM procura os manipuladores por
      RTTI: um metodo privado ou publico nao e achado e a leitura do .lfm
      aborta com "Invalid value for property". }
    procedure AoMudar(Sender: TObject);
  private
    FOpcoes: TDownloadOpcoes;
    FProcesso: TProcessoGerenciado;
    FProcessando: Boolean;
    FCancelar: Boolean;
    FAtualizando: Boolean;
    FViewConsole: Boolean;
    FProgressoBase: Integer;
    FProgressoEspaco: Integer;
    FTotalSeg: Double;
    FAtualSeg: Double;
    procedure AtualizarTudo;
    procedure LerOpcoes;
    procedure EscreverOpcoes;
    procedure AjustarSliderVideo;
    procedure AjustarSliderAudio;
    procedure AtualizarVisibilidade;
    procedure AtualizarRotulos;
    procedure RegistrarBombas;
    procedure IniciarProcessamento;
    procedure CancelarProcesso;
    function  ExecutarFase(const AExe: string; const AArgs: TStringList;
      ABase, AEspaco: Integer): Boolean;
    procedure ProcessarTrecho(const ATexto: string);
    procedure LerProgresso(const ATexto: string);
    procedure SubstituirFFmpegLocation(AArgs: TStringList);
    function  IndiceItem(const ALista: TStrings; const ARotulo: string): Integer;
    function  ExtrairFps(const ARotulo: string): Integer;
    function  SegundosDoTexto(const ATexto: string): Double;
    { Arquivos de uma extensao numa pasta, ordenados. Usado para descobrir o
      que o yt-dlp deixou na pasta temporaria. }
    function  ListarArquivos(const APasta, AExt: string): TStringList;
    function  ArquivoMaisRecente(const APasta: string;
      const AExt: string): string;
    { Nome com o titulo que o yt-dlp gerou na fase 1: difere a pasta
      temporaria e, se nada aparecer, cai no arquivo mais recente. }
    function  IntermediarioDepoisDe(AAntes: TStringList): string;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

implementation

{$R *.lfm}

{ Ponte entre o procedimento simples exigido por uProcessos e o metodo do
  LCL que trata a fila de mensagens. E um procedimento global porque o
  TProcBombeio nao e "procedure of object". }
procedure BombearMensagensDownload;
begin
  Application.ProcessMessages;
end;

procedure TfrDownloadService.RegistrarBombas;
begin
  uProcessosDefinirBombearMensagens(@BombearMensagensDownload);
end;

{ ------------------------------------------------------------------------ }
{ Sincronizacao tela <-> modelo                                            }
{ ------------------------------------------------------------------------ }

constructor TfrDownloadService.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  TGerenciadorDownload.Inicializar(FOpcoes);
  { Pasta padrao vinda das Preferências quando a tela ainda nao tem uma. }
  if FOpcoes.Pasta = '' then
    FOpcoes.Pasta := Configuracoes.PastaDestinoEfetiva;
  RegistrarBombas;
  FViewConsole := False;
  grp_console.Align := alNone;
  grp_console.Visible := False;
  button_console.Caption := 'MOSTRAR CONSOLE';
  AtualizarTudo;
end;

destructor TfrDownloadService.Destroy;
begin
  if FProcessando then
  begin
    FCancelar := True;
    if Assigned(FProcesso) then
      FProcesso.Encerrar(encForcar);
  end;
  inherited Destroy;
end;

procedure TfrDownloadService.AoMudar(Sender: TObject);
begin
  if FAtualizando then
    Exit;

  { Escolher da lista predefinida ou digitar WxH ja marca o radio certo:
    nao faz sentido exigir dois cliques. As atribuicoes ficam sob o guarda
    para nao disparar uma segunda rodada inteira de AtualizarTudo. }
  if (Sender = cbx_resolucao) and not rbtm_res_predefinida.Checked then
  begin
    FAtualizando := True;
    try
      rbtm_res_predefinida.Checked := True;
    finally
      FAtualizando := False;
    end;
  end;

  if (Sender = edt_largura) or (Sender = edt_altura) then
    if not rbtm_res_personalizada.Checked then
    begin
      FAtualizando := True;
      try
        rbtm_res_personalizada.Checked := True;
      finally
        FAtualizando := False;
      end;
    end;

  if (Sender = cbx_fps) and not rbtm_fps_personalizado.Checked then
  begin
    FAtualizando := True;
    try
      rbtm_fps_personalizado.Checked := True;
    finally
      FAtualizando := False;
    end;
  end;

  AtualizarTudo;
end;

procedure TfrDownloadService.AtualizarTudo;
begin
  if FAtualizando then
    Exit;
  FAtualizando := True;
  try
    LerOpcoes;
    { Harmonizar primeiro: e ele quem troca metodo simples para codec
      original, container para o que o codec aceita, etc. Depois sim
      LimitarQualidade trava os numeros nas faixas reais. }
    TGerenciadorDownload.Harmonizar(FOpcoes);
    TGerenciadorDownload.LimitarQualidade(FOpcoes);
    EscreverOpcoes;
    AtualizarVisibilidade;
    AtualizarRotulos;
  finally
    FAtualizando := False;
  end;
end;

procedure TfrDownloadService.LerOpcoes;
begin
  FOpcoes.URL := Trim(edt_url.Text);

  if DirectoryEdit.Directory <> '' then
    FOpcoes.Pasta := IncludeTrailingPathDelimiter(DirectoryEdit.Directory);

  if chk_nome_proprio.Checked then
  begin
    FOpcoes.EscolhaNome := enDefinido;
    FOpcoes.Nome := Trim(edt_nome.Text);
  end
  else
    FOpcoes.EscolhaNome := enAutomatico;

  if rbtm_metodo_simples.Checked then
    FOpcoes.Metodo := mdYtDlp
  else
    FOpcoes.Metodo := mdYtDlpFFmpeg;

  { O container escolhido define o modo de conteudo: container so de audio
    faz o download virar extracao de audio, e o modelo passa a oferecer so
    as opcoes que um arquivo de audio aceita. }
  if cbx_container.ItemIndex >= 0 then
  begin
    FOpcoes.Container := TGerenciadorCatalogo.ContainerPorRotulo(
      cbx_container.Items[cbx_container.ItemIndex]);
    if TGerenciadorCatalogo.SomenteAudio(FOpcoes.Container) then
      FOpcoes.SomenteAudio := mcAudio
    else
      FOpcoes.SomenteAudio := mcVideo;
  end;

  if cbx_codec_video.ItemIndex >= 0 then
    FOpcoes.CodecVideo := TGerenciadorCatalogo.CodecVideoPorRotulo(
      cbx_codec_video.Items[cbx_codec_video.ItemIndex]);

  if cbx_codec_audio.ItemIndex >= 0 then
    FOpcoes.CodecAudio := TGerenciadorCatalogo.CodecAudioPorRotulo(
      cbx_codec_audio.Items[cbx_codec_audio.ItemIndex]);

  if rbtm_res_personalizada.Checked then
  begin
    FOpcoes.Resolucao := erPersonalizada;
    FOpcoes.Largura := StrToIntDef(edt_largura.Text, 0);
    FOpcoes.Altura  := StrToIntDef(edt_altura.Text, 0);
  end
  else if rbtm_res_predefinida.Checked then
  begin
    FOpcoes.Resolucao := erPredefinida;
    if cbx_resolucao.ItemIndex >= 0 then
      FOpcoes.IndiceRes := cbx_resolucao.ItemIndex;
  end
  else
    FOpcoes.Resolucao := erOriginal;

  if rbtm_fps_personalizado.Checked then
  begin
    FOpcoes.EscolhaFps := efPersonalizado;
    if cbx_fps.ItemIndex >= 0 then
      FOpcoes.FpsValor := ExtrairFps(cbx_fps.Items[cbx_fps.ItemIndex]);
  end
  else
    FOpcoes.EscolhaFps := efOriginal;

  if rbtm_qual_taxa.Visible and rbtm_qual_taxa.Checked then
    FOpcoes.ModoQualidadeVideo := mqTaxaBits
  else
    FOpcoes.ModoQualidadeVideo := mqQualidade;

  if cbx_preset.ItemIndex > 0 then
    FOpcoes.PresetVideo := cbx_preset.Items[cbx_preset.ItemIndex]
  else
    FOpcoes.PresetVideo := '';

  if cbx_perfil.ItemIndex >= 0 then
    FOpcoes.ProfileProRes := cbx_perfil.ItemIndex;

  { Metadados e miniatura seguem sempre ligados: o download e do usuario e
    os metadados originais sao a forma mais fiel de guardar a obra. }
  FOpcoes.EmbedMiniatura := True;
  FOpcoes.EmbedMetadados := True;
  FOpcoes.EmbedCapitulos := True;
end;

procedure TfrDownloadService.EscreverOpcoes;
var
  lista: TStringList;
  i: Integer;
begin
  edt_url.Text := FOpcoes.URL;
  if FOpcoes.Pasta <> '' then
    DirectoryEdit.Directory := FOpcoes.Pasta;

  chk_nome_proprio.Checked := (FOpcoes.EscolhaNome = enDefinido);
  edt_nome.Enabled := chk_nome_proprio.Checked;
  edt_nome.Text := FOpcoes.Nome;

  rbtm_metodo_simples.Checked := (FOpcoes.Metodo = mdYtDlp);
  rbtm_metodo_completo.Checked := (FOpcoes.Metodo = mdYtDlpFFmpeg);

  lista := TGerenciadorDownload.ContainersDisponiveis(FOpcoes);
  try
    cbx_container.Items.Assign(lista);
    cbx_container.ItemIndex := IndiceItem(lista,
      TGerenciadorCatalogo.RotuloContainer(FOpcoes.Container));
  finally
    lista.Free;
  end;

  lista := TGerenciadorDownload.CodecsVideoDisponiveis(FOpcoes);
  try
    cbx_codec_video.Items.Assign(lista);
    cbx_codec_video.ItemIndex := IndiceItem(lista,
      TGerenciadorCatalogo.RotuloCodecVideo(FOpcoes.CodecVideo));
  finally
    lista.Free;
  end;

  lista := TGerenciadorDownload.CodecsAudioDisponiveis(FOpcoes);
  try
    cbx_codec_audio.Items.Assign(lista);
    cbx_codec_audio.ItemIndex := IndiceItem(lista,
      TGerenciadorCatalogo.RotuloCodecAudio(FOpcoes.CodecAudio));
  finally
    lista.Free;
  end;

  { Resolucoes predefinidas. }
  cbx_resolucao.Items.Clear;
  for i := 0 to TGerenciadorCatalogo.TotalResolucoes - 1 do
    cbx_resolucao.Items.Add(TGerenciadorCatalogo.Resolucao(i).Rotulo);
  cbx_resolucao.ItemIndex := FOpcoes.IndiceRes;

  lista := TGerenciadorDownload.FpsDisponiveis;
  try
    cbx_fps.Items.Assign(lista);
    cbx_fps.ItemIndex := IndiceItem(lista,
      IntToStr(FOpcoes.FpsValor) + ' fps');
  finally
    lista.Free;
  end;

  { Preset: o primeiro item e sempre "nao usar", para o encoder escolher. }
  cbx_preset.Items.Clear;
  cbx_preset.Items.Add('Padrão do encoder');
  lista := TGerenciadorCatalogo.PresetsVideo(FOpcoes.CodecVideo);
  try
    for i := 0 to lista.Count - 1 do
      cbx_preset.Items.Add(lista[i]);
  finally
    lista.Free;
  end;
  cbx_preset.ItemIndex := cbx_preset.Items.IndexOf(FOpcoes.PresetVideo);
  if cbx_preset.ItemIndex < 0 then
    cbx_preset.ItemIndex := 0;

  { Perfil do ProRes, quando visivel. }
  cbx_perfil.ItemIndex := FOpcoes.ProfileProRes;

  rbtm_res_original.Checked := (FOpcoes.Resolucao = erOriginal);
  rbtm_res_predefinida.Checked := (FOpcoes.Resolucao = erPredefinida);
  rbtm_res_personalizada.Checked := (FOpcoes.Resolucao = erPersonalizada);
  edt_largura.Text := IntToStr(FOpcoes.Largura);
  edt_altura.Text := IntToStr(FOpcoes.Altura);

  rbtm_fps_original.Checked := (FOpcoes.EscolhaFps = efOriginal);
  rbtm_fps_personalizado.Checked := (FOpcoes.EscolhaFps = efPersonalizado);

  rbtm_qual_constante.Checked := (FOpcoes.ModoQualidadeVideo = mqQualidade);
  rbtm_qual_taxa.Checked := (FOpcoes.ModoQualidadeVideo = mqTaxaBits);

  AjustarSliderVideo;
  AjustarSliderAudio;
end;

procedure TfrDownloadService.AtualizarVisibilidade;
var
  lo, hi, pad: Integer;
  temFaixa, temTaxa, perfil, temQual, temAudio: Boolean;
  presets: TStringList;
begin
  if FProcessando then
  begin
    edt_url.Enabled := False;
    DirectoryEdit.Enabled := False;
    chk_nome_proprio.Enabled := False;
    edt_nome.Enabled := False;
    rbtm_metodo_simples.Enabled := False;
    rbtm_metodo_completo.Enabled := False;
    cbx_container.Enabled := False;
    cbx_codec_video.Enabled := False;
    cbx_codec_audio.Enabled := False;
    rbtm_res_original.Enabled := False;
    rbtm_res_predefinida.Enabled := False;
    cbx_resolucao.Enabled := False;
    rbtm_res_personalizada.Enabled := False;
    edt_largura.Enabled := False;
    edt_altura.Enabled := False;
    rbtm_fps_original.Enabled := False;
    rbtm_fps_personalizado.Enabled := False;
    cbx_fps.Enabled := False;
    rbtm_qual_constante.Enabled := False;
    rbtm_qual_taxa.Enabled := False;
    trk_qual_video.Enabled := False;
    cbx_preset.Enabled := False;
    cbx_perfil.Enabled := False;
    trk_qual_audio.Enabled := False;
    Exit;
  end;

  { Codecs: no metodo sem FFmpeg o original e a unica escolha honesta. }
  cbx_codec_video.Enabled := TGerenciadorDownload.PodeEscolherCodecVideo(FOpcoes);
  cbx_codec_audio.Enabled := TGerenciadorDownload.PodeEscolherCodecAudio(FOpcoes);
  cbx_container.Enabled  := TGerenciadorDownload.PodeEscolherContainer(FOpcoes);

  { Resolucao. }
  rbtm_res_personalizada.Enabled :=
    TGerenciadorDownload.PodeEscolherResolucaoPersonalizada(FOpcoes);
  edt_largura.Enabled := rbtm_res_personalizada.Checked and
    rbtm_res_personalizada.Enabled;
  edt_altura.Enabled := edt_largura.Enabled;
  cbx_resolucao.Enabled := TGerenciadorDownload.PodeLimitarAltura(FOpcoes);
  rbtm_res_predefinida.Enabled := cbx_resolucao.Enabled;

  { Fps: so o FFmpeg troca a taxa de quadros, e isso quando reencoda. }
  rbtm_fps_original.Visible := TGerenciadorDownload.PodeEscolherFps(FOpcoes);
  rbtm_fps_personalizado.Visible := rbtm_fps_original.Visible;
  cbx_fps.Visible := rbtm_fps_original.Visible;

  { Qualidade de video. A combinacao de controles depende do codec:
      - CRF (H.264/H.265/VP9/AV1): slider de qualidade constante e, para os
        que medem direito, o par de modos com taxa de bits.
      - ProRes: perfil discreto em combo.
      - Original (nesse metodo o codec nem aparece): nada. }
  temFaixa := TGerenciadorCatalogo.FaixaVideo(FOpcoes.CodecVideo, lo, hi, pad);
  temTaxa  := TGerenciadorDownload.PodeEscolherTaxaBits(FOpcoes);
  perfil   := (TGerenciadorCatalogo.ControleVideo(FOpcoes.CodecVideo) = cvPerfil);
  temQual  := temFaixa or temTaxa or perfil;

  rbtm_qual_constante.Visible := temQual;
  rbtm_qual_constante.Enabled := temQual;
  rbtm_qual_taxa.Visible := temTaxa;
  rbtm_qual_taxa.Enabled := temTaxa;
  trk_qual_video.Visible := temFaixa or temTaxa;
  trk_qual_video.Enabled := trk_qual_video.Visible;
  cbx_perfil.Visible := perfil;
  cbx_perfil.Enabled := perfil;
  lbl_qual_valor.Visible := temQual;

  presets := TGerenciadorCatalogo.PresetsVideo(FOpcoes.CodecVideo);
  try
    lbl_preset.Visible := presets.Count > 0;
    cbx_preset.Visible := presets.Count > 0;
  finally
    presets.Free;
  end;

  { Qualidade de audio: sumir quando o codec nao tem numero (WAV, ALAC). }
  temAudio := TGerenciadorCatalogo.FaixaAudio(FOpcoes.CodecAudio, lo, hi, pad);
  trk_qual_audio.Visible := temAudio;
  trk_qual_audio.Enabled := temAudio;
  lbl_audio.Visible := temAudio;
end;

procedure TfrDownloadService.AtualizarRotulos;
begin
  lbl_explicacao.Caption := TGerenciadorDownload.ExplicacaoMetodo(FOpcoes);
  memo_resumo.Lines.Text := TGerenciadorDownload.Resumo(FOpcoes);
  lbl_qual_valor.Caption := TGerenciadorDownload.ResumoQualidadeVideo(FOpcoes);
  lbl_audio.Caption := TGerenciadorDownload.ResumoQualidadeAudio(FOpcoes);
end;

function TfrDownloadService.IndiceItem(const ALista: TStrings;
  const ARotulo: string): Integer;
begin
  Result := ALista.IndexOf(ARotulo);
  if (Result < 0) and (ALista.Count > 0) then
    Result := 0;
end;

function TfrDownloadService.ExtrairFps(const ARotulo: string): Integer;
var
  p: Integer;
begin
  p := Pos('fps', ARotulo);
  if p > 0 then
    Result := StrToIntDef(Trim(Copy(ARotulo, 1, p - 1)), 0)
  else
    Result := 0;
end;

{ O slider de qualidade usa duas unidades que nao se misturam: por isso a
  faixa e o valor corrente sao decididos aqui, junto com a visibilidade, e
  nao no evento do controle. Em modo de taxa de bits o slider grita em
  kbps; em qualidade constante, na unidade que o encoder entende (CRF,
  qscale, nivel). }

procedure TfrDownloadService.AjustarSliderVideo;
var
  lo, hi, pad: Integer;
begin
  if (FOpcoes.ModoQualidadeVideo = mqTaxaBits) and
     TGerenciadorCatalogo.FaixaTaxaBits(FOpcoes.CodecVideo, lo, hi, pad) then
  begin
    trk_qual_video.Min := lo;
    trk_qual_video.Max := hi;
    trk_qual_video.Position := FOpcoes.TaxaBitsVideo;
  end
  else if TGerenciadorCatalogo.FaixaVideo(FOpcoes.CodecVideo, lo, hi, pad) then
  begin
    trk_qual_video.Min := lo;
    trk_qual_video.Max := hi;
    trk_qual_video.Position := FOpcoes.QualidadeVideo;
  end;
end;

procedure TfrDownloadService.AjustarSliderAudio;
var
  lo, hi, pad: Integer;
begin
  if TGerenciadorCatalogo.FaixaAudio(FOpcoes.CodecAudio, lo, hi, pad) then
  begin
    trk_qual_audio.Min := lo;
    trk_qual_audio.Max := hi;
    trk_qual_audio.Position := FOpcoes.QualidadeAudio;
  end;
end;

procedure TfrDownloadService.trk_qual_videoChange(Sender: TObject);
begin
  if FAtualizando then
    Exit;
  { O numero muda de significado conforme o modo: guardar no campo certo e
    marcar "o usuario escolheu isto", que e o que impede LimitarQualidade
    de reescrever a escolha dele pelo padrao do codec. }
  if FOpcoes.ModoQualidadeVideo = mqTaxaBits then
  begin
    FOpcoes.TaxaBitsVideo := trk_qual_video.Position;
    FOpcoes.TaxaBitsVideoDefinida := True;
  end
  else
  begin
    FOpcoes.QualidadeVideo := trk_qual_video.Position;
    FOpcoes.QualidadeVideoDefinida := True;
  end;
  AtualizarTudo;
end;

procedure TfrDownloadService.trk_qual_audioChange(Sender: TObject);
begin
  if FAtualizando then
    Exit;
  FOpcoes.QualidadeAudio := trk_qual_audio.Position;
  FOpcoes.QualidadeAudioDefinida := True;
  AtualizarTudo;
end;

{ ------------------------------------------------------------------------ }
{ Execucao                                                                 }
{ ------------------------------------------------------------------------ }

procedure TfrDownloadService.IniciarProcessamento;
var
  erros: TStringList;
  args: TStringList;
  antes: TStringList;
  inter: string;
  base: string;
  ok: Boolean;
  i: Integer;
begin
  { Uma rodada completa de sincronizacao antes de validar: e isto que torna
    valida uma opcao que alguem digitou direto no controle. }
  LerOpcoes;
  TGerenciadorDownload.Harmonizar(FOpcoes);
  TGerenciadorDownload.LimitarQualidade(FOpcoes);

  erros := TGerenciadorDownload.Validar(FOpcoes);
  try
    if erros.Count > 0 then
    begin
      for i := 0 to erros.Count - 1 do
        ShowMessage(erros[i]);
      Exit;
    end;
  finally
    erros.Free;
  end;

  ForceDirectories(FOpcoes.Pasta);
  if FOpcoes.Metodo = mdYtDlpFFmpeg then
    ForceDirectories(TGerenciadorDownload.PastaTemporaria(FOpcoes));

  FProcessando := True;
  FCancelar := False;
  button_process_DiretoDaVinci.Caption := 'CANCELAR';
  AtualizarVisibilidade;

  Memo_visual_console.Lines.Clear;
  Memo_visual_console.Lines.Add(TGerenciadorDownload.ExplicacaoMetodo(FOpcoes));
  pbar_processo.Position := 0;
  pbar_processo.Max := 100;

  ok := True;

  if FOpcoes.Metodo = mdYtDlp then
  begin
    { Fase unica: o yt-dlp baixa e o arquivo final sai pronto. }
    args := TGerenciadorDownload.MontarYtDlp(FOpcoes, False);
    try
      if not ExecutarFase(TGerenciadorDependencias.Caminho(depYtDlp),
        args, 0, 100) then
        ok := False;
    finally
      args.Free;
    end;
  end
  else
  begin
    { Fase 1: yt-dlp baixa a melhor pista de cada e junta num MKV na pasta
      temporaria. No nome automatico o arquivo sai com o titulo (e nao com
      um nome fixo), entao o que a fase 2 recebe e descoberto abaixo. }
    antes := ListarArquivos(TGerenciadorDownload.PastaTemporaria(FOpcoes), 'mkv');
    args := TGerenciadorDownload.MontarYtDlp(FOpcoes, True);
    try
      if not ExecutarFase(TGerenciadorDependencias.Caminho(depYtDlp),
        args, 0, 60) then
        ok := False;
    finally
      args.Free;
    end;

    if ok and not FCancelar then
    begin
      inter := IntermediarioDepoisDe(antes);
      if inter = '' then
      begin
        ok := False;
        Memo_visual_console.Lines.Add(
          'Não foi possível localizar o arquivo baixado na pasta temporária.');
      end
      else
      begin
        { Fase 2: o FFmpeg transforma em MP4/MOV/etc. O nome-base do arquivo
          final e o mesmo que o yt-dlp deu; so a extensao muda. }
        base := ChangeFileExt(ExtractFileName(inter), '');
        args := TGerenciadorDownload.MontarFFmpeg(FOpcoes, inter,
          TGerenciadorDownload.CaminhoFinal(FOpcoes, base));
        try
          if not ExecutarFase(TGerenciadorDependencias.Caminho(depFFmpeg),
            args, 60, 40) then
            ok := False;
        finally
          args.Free;
        end;
      end;
    end;
    antes.Free;
  end;

  if FCancelar then
    Memo_visual_console.Lines.Add('Processo cancelado pelo usuário.')
  else if not ok then
  begin
    Memo_visual_console.Lines.Add('Falha durante o processamento.');
    if Configuracoes.UsandoCookies then
    begin
      if (Configuracoes.ModoCookies = COOKIES_NAVEGADOR) and
         NavegadorEmExecucao(Configuracoes.TokenNavegador) then
        Memo_visual_console.Lines.Add(
          'Dica: o navegador de cookies está aberto e trava o arquivo de ' +
          'cookies, o que faz o yt-dlp falhar. Feche o navegador e tente de ' +
          'novo (Preferências > Cookies > Fechar navegador).')
      else
        Memo_visual_console.Lines.Add(
          'Dica: os cookies estavam ativos. Se o vídeo exige login ou aparece ' +
          '"Sign in to confirm you''re not a bot", abra a página no navegador, ' +
          'faça login e resolva o captcha, e tente de novo (Preferências > ' +
          'Cookies > Abrir login/captcha).');
    end;
  end
  else
    Memo_visual_console.Lines.Add('Pronto.');

  pbar_processo.Position := 100;

  FProcessando := False;
  button_process_DiretoDaVinci.Caption := 'PROCESSAR';
  AtualizarVisibilidade;
  AtualizarRotulos;
end;

procedure TfrDownloadService.CancelarProcesso;
begin
  { O sinal e global nas fases: o laco de ExecutarFase o le e encerra o
    processo com forca. O yt-dlp nao le stdin 'q' como o ffmpeg. }
  FCancelar := True;
  if Assigned(FProcesso) then
    FProcesso.Encerrar(encForcar);
  button_process_DiretoDaVinci.Caption := 'CANCELANDO...';
end;

function TfrDownloadService.ExecutarFase(const AExe: string;
  const AArgs: TStringList; ABase, AEspaco: Integer): Boolean;
var
  trecho: string;
begin
  Result := False;
  FProcesso := TProcessoGerenciado.Create;
  try
    SubstituirFFmpegLocation(AArgs);
    FProgressoBase := ABase;
    FProgressoEspaco := AEspaco;
    FTotalSeg := 0;
    FAtualSeg := 0;
    pbar_processo.Position := ABase;

    if not FProcesso.Iniciar(AExe, AArgs, nil, True) then
    begin
      Memo_visual_console.Lines.Add('Não foi possível iniciar: ' + AExe);
      Exit;
    end;

    { O laco bombeia a saida do processo enquanto ele roda. LerDisponivel
      e nao bloqueante, como manda a regra dos pipes: esperar o fim para
      ler travaria os dois para sempre se a saida enchesse o buffer. }
    while FProcesso.Ativo do
    begin
      if FProcesso.LerDisponivel(trecho) > 0 then
        ProcessarTrecho(trecho);
      if FCancelar then
      begin
        FProcesso.Encerrar(encForcar);
        Break;
      end;
      Sleep(5);
      Application.ProcessMessages;
    end;

    trecho := FProcesso.LerTudo;
    if trecho <> '' then
      ProcessarTrecho(trecho);

    Result := FCancelar or (FProcesso.CodigoSaida = 0);
    if (not FCancelar) and (FProcesso.CodigoSaida <> 0) then
      Memo_visual_console.Lines.Add('Falhou com código ' +
        IntToStr(FProcesso.CodigoSaida) + '.');
  finally
    FreeAndNil(FProcesso);
  end;
end;

procedure TfrDownloadService.ProcessarTrecho(const ATexto: string);
begin
  Memo_visual_console.Lines.Add(TrimRight(ATexto));
  LerProgresso(ATexto);
end;

procedure TfrDownloadService.LerProgresso(const ATexto: string);
var
  p, q: Integer;
  s: string;
  percent: Double;
begin
  { yt-dlp: [download]  12.3% of 1.24MiB at ... }
  p := Pos('[download]', ATexto);
  if p > 0 then
  begin
    q := Pos('%', ATexto, p + 10);
    if q > 0 then
    begin
      s := Copy(ATexto, p + 10, q - p - 10);
      if TryStrToFloat(Trim(s), percent) then
        pbar_processo.Position := Round(FProgressoBase +
          FProgressoEspaco * percent / 100);
    end;
  end;

  { FFmpeg escreve time=... na saida apenas quando o loglevel permite; o
    modelo usa error, entao quase nunca ha o que ler. A leitura fica de
    qualquer forma: se um dia o loglevel mudar, o progresso volta sozinho. }
  p := Pos('Duration:', ATexto);
  if p > 0 then
    FTotalSeg := SegundosDoTexto(Copy(ATexto, p + 9, 11));
  p := Pos('time=', ATexto);
  if p > 0 then
  begin
    FAtualSeg := SegundosDoTexto(Copy(ATexto, p + 5, 11));
    if FTotalSeg > 0 then
      pbar_processo.Position := Round(FProgressoBase +
        FProgressoEspaco * FAtualSeg / FTotalSeg);
  end;
end;

function TfrDownloadService.SegundosDoTexto(const ATexto: string): Double;
begin
  { Aceita "HH:MM:SS" ou "HH:MM:SS.NN". }
  Result := StrToIntDef(Copy(ATexto, 1, 2), 0) * 3600 +
            StrToIntDef(Copy(ATexto, 4, 2), 0) * 60 +
            StrToIntDef(Copy(ATexto, 7, 2), 0);
end;

function TfrDownloadService.ListarArquivos(const APasta, AExt: string): TStringList;
var
  SR: TSearchRec;
  caminho: string;
begin
  Result := TStringList.Create;
  Result.Sorted := True;
  caminho := IncludeTrailingPathDelimiter(APasta) + '*.' + AExt;
  if FindFirst(caminho, faAnyFile - faDirectory, SR) = 0 then
  begin
    repeat
      Result.Add(IncludeTrailingPathDelimiter(APasta) + SR.Name);
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;

function TfrDownloadService.ArquivoMaisRecente(const APasta: string;
  const AExt: string): string;
var
  lista: TStringList;
  i: Integer;
begin
  Result := '';
  lista := ListarArquivos(APasta, AExt);
  try
    if lista.Count > 0 then
    begin
      Result := lista[0];
      for i := 1 to lista.Count - 1 do
        if FileAge(lista[i]) > FileAge(Result) then
          Result := lista[i];
    end;
  finally
    lista.Free;
  end;
end;

function TfrDownloadService.IntermediarioDepoisDe(AAntes: TStringList): string;
const
  { A ordem importa: a fase 1 junta as pistas em MKV, mas no modo so de
    audio o yt-dlp pode nao remuxar e deixar a extensao do site. }
  EXTS: array[0..4] of string = ('mkv', 'webm', 'opus', 'ogg', 'm4a');
var
  dep: TStringList;
  i, k: Integer;
begin
  Result := '';

  { 1) Diferenca da pasta: o que nao existia antes do download e o arquivo
     intermediario. E o caminho de verdade, com o titulo que o yt-dlp deu. }
  dep := ListarArquivos(TGerenciadorDownload.PastaTemporaria(FOpcoes), 'mkv');
  try
    for i := 0 to dep.Count - 1 do
      if AAntes.IndexOf(dep[i]) < 0 then
      begin
        Result := dep[i];
        Break;
      end;
  finally
    dep.Free;
  end;

  { 2) Sem diferenca, cai no arquivo mais recente: cobre a pista de audio
     que nao passou pelo juntador. }
  if Result = '' then
    for k := Low(EXTS) to High(EXTS) do
    begin
      Result := ArquivoMaisRecente(TGerenciadorDownload.PastaTemporaria(FOpcoes),
        EXTS[k]);
      if Result <> '' then
        Break;
    end;
end;

procedure TfrDownloadService.SubstituirFFmpegLocation(AArgs: TStringList);
var
  i: Integer;
  dir: string;
begin
  { MontarYtDlp acrescenta '--ffmpeg-location' sem o valor, que so o
    executor conhece: a pasta onde o FFmpeg esta. Sem isso o yt-dlp não
    acha o FFmpeg para juntar as pistas. }
  i := AArgs.IndexOf('--ffmpeg-location');
  if i < 0 then
    Exit;
  dir := ExtractFileDir(TGerenciadorDependencias.Caminho(depFFmpeg));
  AArgs.Insert(i + 1, dir);
end;

procedure TfrDownloadService.button_process_DiretoDaVinciClick(
  Sender: TObject);
begin
  if FProcessando then
    CancelarProcesso
  else
    IniciarProcessamento;
end;

procedure TfrDownloadService.button_consoleClick(Sender: TObject);
begin
  FViewConsole := not FViewConsole;
  if FViewConsole then
  begin
    { O console nasce ancorado em Align=alNone escondido; para mostrar ele
      passa a deitar embaixo, e o grupo de Resumo cede o espaço. }
    grp_console.Align := alBottom;
    grp_console.Height := 160;
    grp_console.Visible := True;
    button_console.Caption := 'OCULTAR CONSOLE';
  end
  else
  begin
    grp_console.Visible := False;
    grp_console.Align := alNone;
    button_console.Caption := 'MOSTRAR CONSOLE';
  end;
end;

end.