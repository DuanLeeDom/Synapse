unit uDownloadCatalog;

{$mode ObjFPC}{$H+}

{ uDownloadCatalog

  Catalogo de capacidades verificadas do Download Service.

  Tudo que esta unit afirma sobre codecs, containers e faixas de qualidade
  foi medido executando o FFmpeg instalado, e nao deduzido de documentacao.
  O metodo esta em C:\Users\domcat\AppData\Local\Temp\opencode\matrix.ps1:
  cada combinacao era gravada e depois lida de volta com ffprobe, porque o
  codigo de saida sozinho nao prova nada - ver a ressalva do AVI abaixo.

  Tres regras emergeu da medicao e explicam quase toda a logica de
  capacidade do Download Service:

  1) Container restringe codec. WebM aceita so VP9/AV1 com Opus/Vorbis.
     MOV aceita Opus e FLAC apenas quando o destino e MP4. ProRes nao tem
     tag em MP4. MKV e o unico container que aceitou tudo.

  2) Codec restringe o controle de qualidade. Nao existe um slider unico de
     "qualidade": x264/x265 usam CRF, VP9 e AV1 usam CRF em faixa propria,
     MJPEG usa qscale invertido (menor e melhor), ProRes usa perfil e
     FFV1 usa nivel de compressao. offering um CRF para ProRes produziria
     um controle que nao faz nada.

  3) Codec e nem sempre gravado no codec pedido. HEVC em AVI termina com
     codigo 0 e escreve rawvideo, isto e, um AVI gigante e sem compressao,
     sem nenhum aviso. Por isso o catalogo tambem guarda os codec aceitos
     por container, e nao apenas a lista de containers "validos". }

interface

uses
  Classes, SysUtils;

type
  { Como a qualidade do video e controlada pelo encoder escolhido. }
  TControleVideo = (
    cvSemControle,   { o stream vai copiado, nao ha encoder }
    cvCRF,           { -crf, faixa propria de cada codec }
    cvQScale,        { -q:v, invertido: menor e melhor }
    cvPerfil,        { -profile:v, usado por ProRes }
    cvCompressao     { -level, usado por FFV1 }
  );

  { Como a qualidade do audio e controlada pelo encoder escolhido. }
  TControleAudio = (
    caSemControle,   { sem encoder ou sem parametro de qualidade }
    caBitrate,       { -b:a }
    caQualidade,     { -q:a, VBR }
    caCompressao     { -compression_level, usado por FLAC }
  );

  TCodecVideo = (
    cvOriginal,   { sem recodificacao: copia o stream da fonte }
    cvH264,
    cvH265,
    cvVP9,
    cvAV1,
    cvMJPEG,
    cvProRes,
    cvFFV1
  );

  TCodecAudio = (
    caOriginal,
    caAAC,
    caMP3,
    caOpus,
    caVorbis,
    caFLAC,
    caWAV,
    caALAC
  );

  { Container de saida. Os cinco primeiros sao containers de video; os seis
    seguintes so aceitam audio, e por isso nao tem codec de video. }
  TContainer = (
    ctMP4, ctMKV, ctWebM, ctMOV, ctAVI,
    ctMP3, ctM4A, ctWAV, ctFLAC, ctOpus, ctOGG
  );

  TInfoContainer = record
    Rotulo        : string;
    Extensao      : string;
    SomenteAudio  : Boolean;
    AceitaVideo   : set of TCodecVideo;
    AceitaAudio   : set of TCodecAudio;
  end;

  TInfoCodecVideo = record
    Rotulo      : string;      { como aparece na interface }
    Encoder     : string;      { -c:v }
    Controle    : TControleVideo;
    { Faixa epadrao do controle. QMin/QMax sao do slider; QPadrao e onde
      ele nasce. QMenorMelhor inverte o sentido do rotulo. }
    QMin        : Integer;
    QMax        : Integer;
    QPadrao     : Integer;
    QMenorMelhor: Boolean;
    ExigeBZero  : Boolean;     { VP9 so respeita CRF com -b:v 0 }
    { Este encoder obedece -b:v? Medido com uma fonte de 30s pedindo
      2000k: x264 chegou a 1994k, x265 a 2012k e AV1 a 2123k, os tres
      dentro da margem que o usuario espera. VP9 pediu 2000k e entregou
      1283k, e repetiu o mesmo desvio em 500k, 1000k e 4000k: anda na
      direcao certa, mas nunca chega. MJPEG, ProRes e FFV1 simplesmente
      ignoraram o numero e gravaram o que quiseram. So os tres que
      batem no alvo recebem o controle de taxa de bits. }
    AceitaTaxaBits: Boolean;
    { Faixa do slider de taxa de bits, em kbps. Min e o piso que faz
      sentido pro encoder, Max e o teto alem do qual nao vale a pena
      ir, e Padrao e onde o controle nasce. }
    TbMin        : Integer;
    TbMax        : Integer;
    TbPadrao     : Integer;
    Presets     : string;      { lista separada por ';' }
    Obs         : string;
  end;

  TInfoCodecAudio = record
    Rotulo      : string;
    Encoder     : string;      { -c:a }
    Controle    : TControleAudio;
    QMin        : Integer;
    QMax        : Integer;
    QPadrao     : Integer;
    QMenorMelhor: Boolean;
    Obs         : string;
  end;

  { Resolucoes oferecidas na interface, em pixels de altura. A ordem e
    crescente de qualidade porque a lista vai nessa ordem. }
  TResolucao = record
    Altura    : Integer;
    Rotulo    : string;
    Formato   : string;   { filtro do yt-dlp: bestvideo[height<=144]+... }
    EscalaFF  : string;   { valor do scale=-2:H do ffmpeg }
  end;

  TGerenciadorCatalogo = class
  public
    { --- containers --- }
    class function TotalContainers: Integer;
    class function Container(AInd: Integer): TContainer;
    class function RotuloContainer(ACont: TContainer): string;
    { Rotulo de volta ao enum. Existe porque a lista de containers
      disponiveis e filtrada: o indice dentro dela nao e o numero do enum,
      entao converter o indice com TContainer(n) devolve um container
      errado. Pelo rotulo a procura e sempre certa. }
    class function ContainerPorRotulo(const ARotulo: string): TContainer;
    class function ExtensaoContainer(ACont: TContainer): string;
    class function SomenteAudio(ACont: TContainer): Boolean;
    class function ContainerAceitaVideo(ACont: TContainer;
      ACodec: TCodecVideo): Boolean;
    class function ContainerAceitaAudio(ACont: TContainer;
      ACodec: TCodecAudio): Boolean;

    { Lista os containers que aceitam um codec, na ordem do catalogo.
      E o que alimenta a interface quando o usuario escolhe um codec: mudar
      para ProRes tem de fazer o container pular para MOV ou MKV. }
    class function ContainersParaVideo(ACodec: TCodecVideo): TStringList;
    class function ContainersParaAudio(ACodec: TCodecAudio): TStringList;

    { --- codecs de video --- }
    class function TotalCodecsVideo: Integer;
    class function CodecVideo(AInd: Integer): TCodecVideo;
    class function RotuloCodecVideo(ACodec: TCodecVideo): string;
    { Rotulo de volta ao enum. Mesmo motivo do ContainerPorRotulo: a lista
      de codecs oferecidos e filtrada, e o indice dela nao e o ordinal. }
    class function CodecVideoPorRotulo(const ARotulo: string): TCodecVideo;
    class function EncoderVideo(ACodec: TCodecVideo): string;
    class function ControleVideo(ACodec: TCodecVideo): TControleVideo;
    class function FaixaVideo(ACodec: TCodecVideo; out AMin, AMax,
      APadrao: Integer): Boolean;
    class function MenorMelhorVideo(ACodec: TCodecVideo): Boolean;
    { Este encoder obedece -b:v? A interface so mostra o controle de taxa
      de bits quando a resposta e True. }
    class function AceitaTaxaBits(ACodec: TCodecVideo): Boolean;
    { Faixa do slider de taxa de bits, em kbps. So devolve True quando
      AceitaTaxaBits; nos demais casos zera a saida para que a interface
      nunca fique com um intervalo antigo na mao. }
    class function FaixaTaxaBits(ACodec: TCodecVideo; out AMin, AMax,
      APadrao: Integer): Boolean;
    class function PresetsVideo(ACodec: TCodecVideo): TStringList;
    class function ExigeBZero(ACodec: TCodecVideo): Boolean;
    class function ObsVideo(ACodec: TCodecVideo): string;

    { --- codecs de audio --- }
    class function TotalCodecsAudio: Integer;
    class function CodecAudio(AInd: Integer): TCodecAudio;
    class function RotuloCodecAudio(ACodec: TCodecAudio): string;
    class function CodecAudioPorRotulo(const ARotulo: string): TCodecAudio;
    class function EncoderAudio(ACodec: TCodecAudio): string;
    class function ControleAudio(ACodec: TCodecAudio): TControleAudio;
    class function FaixaAudio(ACodec: TCodecAudio; out AMin, AMax,
      APadrao: Integer): Boolean;
    class function MenorMelhorAudio(ACodec: TCodecAudio): Boolean;
    class function ObsAudio(ACodec: TCodecAudio): string;

    { --- resolucoes --- }
    class function TotalResolucoes: Integer;
    class function Resolucao(AInd: Integer): TResolucao;
    class function AlturaResolucao(AInd: Integer): Integer;
    class function IndiceAltura(AAltura: Integer): Integer;

    { Codecs de video que podem ser gerados sem recodificar, isto e,
      devolvendo o stream como veio. }
    class function SemRecodificar(ACodec: TCodecVideo): Boolean;
    { Codec que faz transcodificar. Separado de cvOriginal porque a
      interface precisa dizer "vai ser convertido" e nao "formato". }
    class function Recodifica(ACodec: TCodecVideo): Boolean;
  end;

implementation

const
  { Nota sobre os dados abaixo: sao o resultado da medicao descrita no
    cabecalho. Alterar um valor aqui muda o que a interface oferece, e a
    medicao e o unico jeito de saber se o valor novo continua certo. }

  CAT_CONTAINERS: array[TContainer] of TInfoContainer = (
    { --- containers de video --- }
    (Rotulo: 'MP4';  Extensao: 'mp4'; SomenteAudio: False;
     AceitaVideo: [cvOriginal, cvH264, cvH265, cvVP9, cvAV1, cvMJPEG, cvFFV1];
     AceitaAudio: [caOriginal, caAAC, caMP3, caOpus, caVorbis, caFLAC]),
    (Rotulo: 'MKV';  Extensao: 'mkv'; SomenteAudio: False;
     AceitaVideo: [cvOriginal, cvH264, cvH265, cvVP9, cvAV1, cvMJPEG, cvProRes,
                   cvFFV1];
     AceitaAudio: [caOriginal, caAAC, caMP3, caOpus, caVorbis, caFLAC, caWAV,
                   caALAC]),
    (Rotulo: 'WebM'; Extensao: 'webm'; SomenteAudio: False;
     AceitaVideo: [cvOriginal, cvVP9, cvAV1];
     AceitaAudio: [caOriginal, caOpus, caVorbis]),
    { MOV: Opus e FLAC foram recusados com "opus only supported in MP4".
      VP9 e AV1 recusados com "vp9 only supported in MP4". }
    (Rotulo: 'MOV';  Extensao: 'mov'; SomenteAudio: False;
     AceitaVideo: [cvOriginal, cvH264, cvH265, cvMJPEG, cvProRes, cvFFV1];
     AceitaAudio: [caOriginal, caAAC, caMP3, caVorbis]),
    { AVI: Opus nunca entra e o video HEVC e gravado como rawvideo. }
    (Rotulo: 'AVI';  Extensao: 'avi'; SomenteAudio: False;
     AceitaVideo: [cvOriginal, cvH264, cvVP9, cvAV1, cvMJPEG, cvFFV1];
     AceitaAudio: [caOriginal, caAAC, caMP3, caVorbis, caFLAC]),
    { --- containers so de audio --- }
    (Rotulo: 'MP3';  Extensao: 'mp3';  SomenteAudio: True;
     AceitaVideo: []; AceitaAudio: [caMP3]),
    (Rotulo: 'M4A';  Extensao: 'm4a';  SomenteAudio: True;
     AceitaVideo: []; AceitaAudio: [caAAC, caALAC]),
    (Rotulo: 'WAV';  Extensao: 'wav';  SomenteAudio: True;
     AceitaVideo: []; AceitaAudio: [caWAV]),
    (Rotulo: 'FLAC'; Extensao: 'flac'; SomenteAudio: True;
     AceitaVideo: []; AceitaAudio: [caFLAC]),
    (Rotulo: 'Opus'; Extensao: 'opus'; SomenteAudio: True;
     AceitaVideo: []; AceitaAudio: [caOpus]),
    (Rotulo: 'OGG';  Extensao: 'ogg';  SomenteAudio: True;
     AceitaVideo: []; AceitaAudio: [caVorbis, caOpus])
  );

  CAT_VIDEO: array[TCodecVideo] of TInfoCodecVideo = (
    (Rotulo: 'Original (sem recodificar)'; Encoder: 'copy';
     Controle: cvSemControle; QMin: 0; QMax: 0; QPadrao: 0;
     QMenorMelhor: False; ExigeBZero: False;
     AceitaTaxaBits: False; TbMin: 0; TbMax: 0; TbPadrao: 0;
     Presets: '';
     Obs: 'Baixa o stream como o site publicou. Nao e possivel escolher '
          + 'resolucao, fps ou qualidade: o que existe e o que vem.'),
    (Rotulo: 'H.264 / AVC'; Encoder: 'libx264';
     Controle: cvCRF; QMin: 0; QMax: 51; QPadrao: 23;
     QMenorMelhor: True; ExigeBZero: False;
     AceitaTaxaBits: True; TbMin: 100; TbMax: 20000; TbPadrao: 8000;
     Presets: 'ultrafast;superfast;veryfast;faster;fast;medium;slow;slower;veryslow';
     Obs: 'CRF 0 e sem perda, 51 e o pior aceitavel. O FFmpeg aceita '
          + 'valores acima de 51 e corrige sozinho, entao o limite da '
          + 'interface existe para nao gravar um numero que nao sera o '
          + 'que o usuario digitou.'),
    (Rotulo: 'H.265 / HEVC'; Encoder: 'libx265';
     Controle: cvCRF; QMin: 0; QMax: 51; QPadrao: 26;
     QMenorMelhor: True; ExigeBZero: False;
     AceitaTaxaBits: True; TbMin: 100; TbMax: 20000; TbPadrao: 5000;
     Presets: 'ultrafast;superfast;veryfast;faster;fast;medium;slow;slower';
     Obs: 'Metade do tamanho do H.264 na mesma aparencia. Encodificar e '
          + 'bem mais lento que H.264.'),
    (Rotulo: 'VP9'; Encoder: 'libvpx-vp9';
     Controle: cvCRF; QMin: 0; QMax: 63; QPadrao: 31;
     QMenorMelhor: True; ExigeBZero: True;
     AceitaTaxaBits: False; TbMin: 0; TbMax: 0; TbPadrao: 0;
     Presets: '';
     Obs: 'Faixa de CRF vai ate 63, e nao 51. Sem -b:v 0 o VP9 ignora o '
          + 'CRF e passa a limpar por taxa de bits.'),
    (Rotulo: 'AV1'; Encoder: 'libsvtav1';
     Controle: cvCRF; QMin: 0; QMax: 63; QPadrao: 35;
     QMenorMelhor: True; ExigeBZero: False;
     AceitaTaxaBits: True; TbMin: 100; TbMax: 20000; TbPadrao: 4000;
     Presets: '6;8;10;12';
     Obs: 'O mais compacto dos quatro, e de longe o mais lento de '
          + 'encodificar. Vale para arquivos que ficam parados.'),
    (Rotulo: 'MJPEG'; Encoder: 'mjpeg';
     Controle: cvQScale; QMin: 2; QMax: 31; QPadrao: 5;
     QMenorMelhor: True; ExigeBZero: False;
     AceitaTaxaBits: False; TbMin: 0; TbMax: 0; TbPadrao: 0;
     Presets: '';
     Obs: 'Escala invertida: aqui o numero pequeno e a melhor qualidade. '
          + 'Um JPEG por quadro, entao o arquivo fica muito grande.'),
    (Rotulo: 'ProRes'; Encoder: 'prores_ks';
     Controle: cvPerfil; QMin: 0; QMax: 4; QPadrao: 2;
     QMenorMelhor: False; ExigeBZero: False;
     AceitaTaxaBits: False; TbMin: 0; TbMax: 0; TbPadrao: 0;
     Presets: '';
     Obs: 'Codec de edicao. Nao aceita CRF: o controle e o perfil, que '
          + 'escolhe entre Proxy, LT, 422, HQ e 4444. So entra em MOV e MKV.'),
    (Rotulo: 'FFV1'; Encoder: 'ffv1';
     Controle: cvCompressao; QMin: 0; QMax: 8; QPadrao: 3;
     QMenorMelhor: False; ExigeBZero: False;
     AceitaTaxaBits: False; TbMin: 0; TbMax: 0; TbPadrao: 0;
     Presets: '';
     Obs: 'Sem perda, para guarda. O nivel 3 ja usa compressao suficiente '
          + 'para uso normal e so faz sentido no que for copia literal.')
  );

  CAT_AUDIO: array[TCodecAudio] of TInfoCodecAudio = (
    (Rotulo: 'Original (sem recodificar)'; Encoder: 'copy';
     Controle: caSemControle; QMin: 0; QMax: 0; QPadrao: 0;
     QMenorMelhor: False;
     Obs: 'Baixa o audio como o site publicou. O container final e '
          + 'escolhido pelo proprio site.'),
    (Rotulo: 'AAC'; Encoder: 'aac';
     Controle: caBitrate; QMin: 64; QMax: 320; QPadrao: 192;
     QMenorMelhor: False;
     Obs: 'O que o yt-dlp chama de m4a. Cabe em MP4, M4A e MKV.'),
    (Rotulo: 'MP3'; Encoder: 'libmp3lame';
     Controle: caBitrate; QMin: 64; QMax: 320; QPadrao: 192;
     QMenorMelhor: False;
     Obs: 'O unico que todo mundo abre, e o unico aqui que aceita VBR.'),
    (Rotulo: 'Opus'; Encoder: 'libopus';
     Controle: caBitrate; QMin: 32; QMax: 256; QPadrao: 128;
     QMenorMelhor: False;
     Obs: 'Melhor qualidade por bit do MP3. Nao entra em MOV.'),
    (Rotulo: 'Vorbis'; Encoder: 'libvorbis';
     Controle: caBitrate; QMin: 32; QMax: 256; QPadrao: 128;
     QMenorMelhor: False;
     Obs: 'O audio padrao dos arquivos OGG.'),
    (Rotulo: 'FLAC'; Encoder: 'flac';
     Controle: caCompressao; QMin: 0; QMax: 12; QPadrao: 5;
     QMenorMelhor: False;
     Obs: 'Sem perda. O numero e o nivel de compressao, e nao uma taxa '
          + 'de bits: nao existe "320k" para FLAC.'),
    (Rotulo: 'WAV'; Encoder: 'pcm_s16le';
     Controle: caSemControle; QMin: 0; QMax: 0; QPadrao: 0;
     QMenorMelhor: False;
     Obs: 'Sem compressao nenhuma. Serve para edicao, nao para guardar.'),
    (Rotulo: 'ALAC'; Encoder: 'alac';
     Controle: caSemControle; QMin: 0; QMax: 0; QPadrao: 0;
     QMenorMelhor: False;
     Obs: 'Sem perda, como o FLAC, e cabe num M4A.')
  );

  { Resolucoes em ordem crescente de qualidade. O yt-dlp escolhe o melhor
    formato que nao passa do limite de altura; o ffmpeg reescala para a
    altura pedida mantendo a proporcao. }
  CAT_RESOLUCOES: array[0..8] of TResolucao = (
    (Altura:  144; Rotulo: '144p';   Formato: 'bestvideo[height<=144]+bestaudio/best[height<=144]';  EscalaFF: '-2:144'),
    (Altura:  240; Rotulo: '240p';   Formato: 'bestvideo[height<=240]+bestaudio/best[height<=240]';  EscalaFF: '-2:240'),
    (Altura:  360; Rotulo: '360p';   Formato: 'bestvideo[height<=360]+bestaudio/best[height<=360]';  EscalaFF: '-2:360'),
    (Altura:  480; Rotulo: '480p';   Formato: 'bestvideo[height<=480]+bestaudio/best[height<=480]';  EscalaFF: '-2:480'),
    (Altura:  720; Rotulo: '720p  (HD)';      Formato: 'bestvideo[height<=720]+bestaudio/best[height<=720]';  EscalaFF: '-2:720'),
    (Altura: 1080; Rotulo: '1080p (Full HD)'; Formato: 'bestvideo[height<=1080]+bestaudio/best[height<=1080]'; EscalaFF: '-2:1080'),
    (Altura: 1440; Rotulo: '1440p (2K)';      Formato: 'bestvideo[height<=1440]+bestaudio/best[height<=1440]'; EscalaFF: '-2:1440'),
    (Altura: 2160; Rotulo: '2160p (4K)';      Formato: 'bestvideo[height<=2160]+bestaudio/best[height<=2160]'; EscalaFF: '-2:2160'),
    (Altura: 4320; Rotulo: '4320p (8K)';      Formato: 'bestvideo[height<=4320]+bestaudio/best[height<=4320]'; EscalaFF: '-2:4320')
  );

{ ------------------------------------------------------------------------ }
{ Containers                                                               }
{ ------------------------------------------------------------------------ }

class function TGerenciadorCatalogo.TotalContainers: Integer;
begin
  Result := Ord(High(TContainer)) + 1;
end;

class function TGerenciadorCatalogo.Container(AInd: Integer): TContainer;
begin
  Result := TContainer(AInd);
end;

class function TGerenciadorCatalogo.RotuloContainer(
  ACont: TContainer): string;
begin
  Result := CAT_CONTAINERS[ACont].Rotulo;
end;

class function TGerenciadorCatalogo.ContainerPorRotulo(
  const ARotulo: string): TContainer;
var
  c: TContainer;
begin
  for c := Low(TContainer) to High(TContainer) do
    if SameText(CAT_CONTAINERS[c].Rotulo, ARotulo) then
      Exit(c);
  { Nao achou: mantem o que ja estava, que e melhor que inventar um. }
  Result := Low(TContainer);
end;

class function TGerenciadorCatalogo.ExtensaoContainer(
  ACont: TContainer): string;
begin
  Result := CAT_CONTAINERS[ACont].Extensao;
end;

class function TGerenciadorCatalogo.SomenteAudio(ACont: TContainer): Boolean;
begin
  Result := CAT_CONTAINERS[ACont].SomenteAudio;
end;

class function TGerenciadorCatalogo.ContainerAceitaVideo(
  ACont: TContainer; ACodec: TCodecVideo): Boolean;
var
  aceitos: set of TCodecVideo;
begin
  { O 'in' do FPC exige um conjunto em variavel: testar direto no campo do
    registro constante nao compila. Copiar para uma local resolve e deixa
    a assinatura igual. }
  aceitos := CAT_CONTAINERS[ACont].AceitaVideo;
  Result := ACodec in aceitos;
end;

class function TGerenciadorCatalogo.ContainerAceitaAudio(
  ACont: TContainer; ACodec: TCodecAudio): Boolean;
var
  aceitos: set of TCodecAudio;
begin
  aceitos := CAT_CONTAINERS[ACont].AceitaAudio;
  Result := ACodec in aceitos;
end;

class function TGerenciadorCatalogo.ContainersParaVideo(
  ACodec: TCodecVideo): TStringList;
var
  c: TContainer;
  aceitos: set of TCodecVideo;
begin
  Result := TStringList.Create;
  for c := Low(TContainer) to High(TContainer) do
  begin
    aceitos := CAT_CONTAINERS[c].AceitaVideo;
    if (not CAT_CONTAINERS[c].SomenteAudio) and (ACodec in aceitos) then
      Result.Add(CAT_CONTAINERS[c].Rotulo);
  end;
end;

class function TGerenciadorCatalogo.ContainersParaAudio(
  ACodec: TCodecAudio): TStringList;
var
  c: TContainer;
  aceitos: set of TCodecAudio;
begin
  Result := TStringList.Create;
  for c := Low(TContainer) to High(TContainer) do
  begin
    aceitos := CAT_CONTAINERS[c].AceitaAudio;
    if ACodec in aceitos then
      Result.Add(CAT_CONTAINERS[c].Rotulo);
  end;
end;

{ ------------------------------------------------------------------------ }
{ Codecs de video                                                           }
{ ------------------------------------------------------------------------ }

class function TGerenciadorCatalogo.TotalCodecsVideo: Integer;
begin
  Result := Ord(High(TCodecVideo)) + 1;
end;

class function TGerenciadorCatalogo.CodecVideo(AInd: Integer): TCodecVideo;
begin
  Result := TCodecVideo(AInd);
end;

class function TGerenciadorCatalogo.RotuloCodecVideo(
  ACodec: TCodecVideo): string;
begin
  Result := CAT_VIDEO[ACodec].Rotulo;
end;

class function TGerenciadorCatalogo.CodecVideoPorRotulo(
  const ARotulo: string): TCodecVideo;
var
  c: TCodecVideo;
begin
  for c := Low(TCodecVideo) to High(TCodecVideo) do
    if SameText(CAT_VIDEO[c].Rotulo, ARotulo) then
      Exit(c);
  { Nao achou: o "Original" e a resposta segura, porque nao recodifica. }
  Result := cvOriginal;
end;

class function TGerenciadorCatalogo.EncoderVideo(ACodec: TCodecVideo): string;
begin
  Result := CAT_VIDEO[ACodec].Encoder;
end;

class function TGerenciadorCatalogo.ControleVideo(
  ACodec: TCodecVideo): TControleVideo;
begin
  Result := CAT_VIDEO[ACodec].Controle;
end;

class function TGerenciadorCatalogo.FaixaVideo(ACodec: TCodecVideo;
  out AMin, AMax, APadrao: Integer): Boolean;
begin
  { cvSemControle e cvPerfil nao tem faixa numerica util de slider: o
    primeiro nao tem encoder, o segundo e uma escolha discreta. }
  AMin    := 0;
  AMax    := 0;
  APadrao := 0;
  case CAT_VIDEO[ACodec].Controle of
    cvCRF, cvQScale, cvCompressao:
      begin
        AMin    := CAT_VIDEO[ACodec].QMin;
        AMax    := CAT_VIDEO[ACodec].QMax;
        APadrao := CAT_VIDEO[ACodec].QPadrao;
        Result  := True;
      end;
  else
    Result := False;
  end;
end;

class function TGerenciadorCatalogo.MenorMelhorVideo(
  ACodec: TCodecVideo): Boolean;
begin
  Result := CAT_VIDEO[ACodec].QMenorMelhor;
end;

class function TGerenciadorCatalogo.AceitaTaxaBits(
  ACodec: TCodecVideo): Boolean;
begin
  Result := CAT_VIDEO[ACodec].AceitaTaxaBits;
end;

class function TGerenciadorCatalogo.FaixaTaxaBits(ACodec: TCodecVideo;
  out AMin, AMax, APadrao: Integer): Boolean;
begin
  AMin    := 0;
  AMax    := 0;
  APadrao := 0;
  if not CAT_VIDEO[ACodec].AceitaTaxaBits then
    Exit(False);
  AMin    := CAT_VIDEO[ACodec].TbMin;
  AMax    := CAT_VIDEO[ACodec].TbMax;
  APadrao := CAT_VIDEO[ACodec].TbPadrao;
  Result  := True;
end;

class function TGerenciadorCatalogo.PresetsVideo(
  ACodec: TCodecVideo): TStringList;
var
  i: Integer;
  partes: TStringList;
begin
  Result := TStringList.Create;
  if CAT_VIDEO[ACodec].Presets = '' then
    Exit;
  partes := TStringList.Create;
  try
    partes.Delimiter := ';';
    partes.DelimitedText := CAT_VIDEO[ACodec].Presets;
    for i := 0 to partes.Count - 1 do
      if Trim(partes[i]) <> '' then
        Result.Add(Trim(partes[i]));
  finally
    partes.Free;
  end;
end;

class function TGerenciadorCatalogo.ExigeBZero(ACodec: TCodecVideo): Boolean;
begin
  Result := CAT_VIDEO[ACodec].ExigeBZero;
end;

class function TGerenciadorCatalogo.ObsVideo(ACodec: TCodecVideo): string;
begin
  Result := CAT_VIDEO[ACodec].Obs;
end;

class function TGerenciadorCatalogo.SemRecodificar(
  ACodec: TCodecVideo): Boolean;
begin
  Result := ACodec = cvOriginal;
end;

class function TGerenciadorCatalogo.Recodifica(ACodec: TCodecVideo): Boolean;
begin
  Result := ACodec <> cvOriginal;
end;

{ ------------------------------------------------------------------------ }
{ Codecs de audio                                                           }
{ ------------------------------------------------------------------------ }

class function TGerenciadorCatalogo.TotalCodecsAudio: Integer;
begin
  Result := Ord(High(TCodecAudio)) + 1;
end;

class function TGerenciadorCatalogo.CodecAudio(AInd: Integer): TCodecAudio;
begin
  Result := TCodecAudio(AInd);
end;

class function TGerenciadorCatalogo.RotuloCodecAudio(
  ACodec: TCodecAudio): string;
begin
  Result := CAT_AUDIO[ACodec].Rotulo;
end;

class function TGerenciadorCatalogo.EncoderAudio(ACodec: TCodecAudio): string;
begin
  Result := CAT_AUDIO[ACodec].Encoder;
end;

class function TGerenciadorCatalogo.CodecAudioPorRotulo(
  const ARotulo: string): TCodecAudio;
var
  a: TCodecAudio;
begin
  for a := Low(TCodecAudio) to High(TCodecAudio) do
    if SameText(CAT_AUDIO[a].Rotulo, ARotulo) then
      Exit(a);
  Result := caOriginal;
end;

class function TGerenciadorCatalogo.ControleAudio(
  ACodec: TCodecAudio): TControleAudio;
begin
  Result := CAT_AUDIO[ACodec].Controle;
end;

class function TGerenciadorCatalogo.FaixaAudio(ACodec: TCodecAudio;
  out AMin, AMax, APadrao: Integer): Boolean;
begin
  AMin    := 0;
  AMax    := 0;
  APadrao := 0;
  case CAT_AUDIO[ACodec].Controle of
    caBitrate, caQualidade, caCompressao:
      begin
        AMin    := CAT_AUDIO[ACodec].QMin;
        AMax    := CAT_AUDIO[ACodec].QMax;
        APadrao := CAT_AUDIO[ACodec].QPadrao;
        Result  := True;
      end;
  else
    Result := False;
  end;
end;

class function TGerenciadorCatalogo.MenorMelhorAudio(
  ACodec: TCodecAudio): Boolean;
begin
  Result := CAT_AUDIO[ACodec].QMenorMelhor;
end;

class function TGerenciadorCatalogo.ObsAudio(ACodec: TCodecAudio): string;
begin
  Result := CAT_AUDIO[ACodec].Obs;
end;

{ ------------------------------------------------------------------------ }
{ Resolucoes                                                                }
{ ------------------------------------------------------------------------ }

class function TGerenciadorCatalogo.TotalResolucoes: Integer;
begin
  Result := High(CAT_RESOLUCOES) + 1;
end;

class function TGerenciadorCatalogo.Resolucao(AInd: Integer): TResolucao;
begin
  if (AInd < Low(CAT_RESOLUCOES)) or (AInd > High(CAT_RESOLUCOES)) then
  begin
    Result := CAT_RESOLUCOES[Low(CAT_RESOLUCOES)];
    Exit;
  end;
  Result := CAT_RESOLUCOES[AInd];
end;

class function TGerenciadorCatalogo.AlturaResolucao(AInd: Integer): Integer;
begin
  Result := Resolucao(AInd).Altura;
end;

class function TGerenciadorCatalogo.IndiceAltura(AAltura: Integer): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := Low(CAT_RESOLUCOES) to High(CAT_RESOLUCOES) do
    if CAT_RESOLUCOES[i].Altura = AAltura then
      Exit(i);
end;

end.
