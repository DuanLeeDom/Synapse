unit uDownloadModel;

{$mode ObjFPC}{$H+}

{ uDownloadModel

  Regras do Download Service, sem interface e sem executar nada.

  Tudo aqui e decisao pura: recebe as opcoes do usuario e devolve o que pode
  ser feito, o que nao pode, e os argumentos de cada fase. A tela e o
  executor consomem esta unit; nenhum dos dois repete a regra.

  As tres fases do trabalho, e por que sao tres:

    1) Metodo "somente yt-dlp": uma unica chamada. O yt-dlp baixa um formato
       que ja vem com video e audio juntos, e no maximo troca o container
       com --remux-video, que nao reencoda. Nada de FFmpeg, nada de perda,
       e rapido. O limite honesto: so pode escolher entre as opcoes que o
       site oferece.

    2) Metodo "yt-dlp + FFmpeg", fase 1: o yt-dlp baixa a melhor pista de
       video e a melhor de audio e junta as duas num MKV intermediario.
       MKV porque e o unico container aceito por todos os codecs medidos.

    3) Metodo "yt-dlp + FFmpeg", fase 2: o FFmpeg transcodifica o MKV
       para o codec, container, resolucao e fps escolhidos.

  A fase 2 e um processo separado de proposito. Seria possivel tentar
  resolver tudo pelo --postprocessor-args do yt-dlp, e isso foi testado:
  sem um postprocessador dispara, o --postprocessor-args e aceito e
  ignorado, e o arquivo sai byte a byte igual a entrada. Descobrir isso
  pelo silencio do yt-dlp seria muito pior do que uma chamada a mais.

  Duas regras de seguranca: nomes de arquivo entram sempre entre aspas
  e nunca passam por cmd.exe: um processo filho com argumentos ja
  escalonados nao depende de interpretacao de aspas do Windows. }

interface

uses
  Classes, SysUtils, uDownloadCatalog, uDependencias, uConfig;

type
  { Como o download vai ser feito. }
  TMetodoDownload = (mdYtDlp, mdYtDlpFFmpeg);

  { O que o usuario quer no fim: um video ou so o audio. }
  TModoConteudo = (mcVideo, mcAudio);

  { Resolucao. erPredefinida escolhe da lista de alturas; erPersonalizada
    aceitaWxH; erOriginal mantem o que o site publicou. }
  TEscolhaResolucao = (erOriginal, erPredefinida, erPersonalizada);

  TEscolhaFps = (efOriginal, efPersonalizado);

  { Como o usuario controla a qualidade quando ele proprio escolheu um
    codec. Sao dois controles diferentes, e a interface so pode mostrar
    um por vez:

      mqQualidade - qualidade constante (CRF no x264, qscale no MJPEG).
        O usuario diz "quero isto de boa" e o encoder gasta o bitrate
        que precisar. E o padrao, e o que o HandBrake chama de RF.

      mqTaxaBits - taxa media de bits. O usuario diz "cabe neste tamanho"
        e o encoder faz o que der com isso. So tem efeito nos encoders
        que medem: x264, x265 e AV1 bateram no alvo nos testes; VP9
        andou na direcao certa mas ficou 35% abaixo do pedido, e
        MJPEG, ProRes e FFV1 ignoraram o numero inteiramente. }
  TModoQualidadeVideo = (mqQualidade, mqTaxaBits);

  { Nome do arquivo de saida. }
  TEscolhaNome = (enAutomatico, enDefinido);

  { Todas as opcoes de um download. Tudo e independente do controle visivel:
    a tela decide o que mostrar, mas quem decide o que e valido e o
    catalogo. }
  TDownloadOpcoes = record
    { --- destino --- }
    URL          : string;
    Pasta        : string;
    Nome         : string;      { sem extensao; so usado se enDefinido }
    EscolhaNome  : TEscolhaNome;

    { --- metodo --- }
    Metodo       : TMetodoDownload;
    SomenteAudio : TModoConteudo;

    { --- formato --- }
    Container    : TContainer;
    CodecVideo   : TCodecVideo;
    CodecAudio   : TCodecAudio;

    { --- resolucao e fps --- }
    Resolucao    : TEscolhaResolucao;
    IndiceRes    : Integer;     { indice na lista de resolucoes }
    Largura      : Integer;     { usadas so em erPersonalizada }
    Altura       : Integer;
    EscolhaFps   : TEscolhaFps;
    FpsValor     : Integer;

    { --- qualidade --- }
    { O significado de QualidadeVideo depende do codec: CRF no x264, qscale
      no MJPEG, nivel no FFV1, e ProfileProRes quando o codec e ProRes.
      Guardar o numero solto e o que permite ter um so slider que muda de
      sentido e de faixa conforme o codec escolhido. }
    QualidadeVideo : Integer;
    ProfileProRes  : Integer;
    PresetVideo    : string;
    QualidadeAudio : Integer;   { kbps, ou nivel de compressao no FLAC }

    { Falso significa "o usuario ainda nao mexeu neste controle". Enquanto
      for falso, LimitarQualidade coloca o padrao do codec em vez de
      aceitar o zero que veio do FillChar. Sem isto a primeira execucao
      sairia com CRF 0, que e lossless e gera um arquivo gigante sem
      ninguem ter pedido. O 0 continua valendo como escolha do usuario:
      so o semaforo distingue "escolhi 0" de "nada escolhido". }
    QualidadeVideoDefinida : Boolean;
    QualidadeAudioDefinida : Boolean;

    { Qualidade constante ou taxa de bits, escolhido pelo usuario quando
      ele trocou o codec de original para algo que recodifica. }
    ModoQualidadeVideo : TModoQualidadeVideo;
    { So usado quando ModoQualidadeVideo = mqTaxaBits. Em kbps, que e a
      unidade que o usuario le no controle e que o -b:v aceita com o
      sufixo k. }
    TaxaBitsVideo : Integer;
    { Idem como QualidadeVideoDefinida: separa "o usuario ainda nao
      escolheu, use o padrao do codec" de "o usuario digitou este
      valor, respeite". Sem isto, trocar de H.264 para AV1 reescreveria
      a escolha dele sem ele ver. }
    TaxaBitsVideoDefinida : Boolean;

    { --- audio ---
      Nao existe o par de modos que existe no video. Aqui o proprio codec
      ja diz qual e o controle: AAC, MP3, Opus e Vorbis usam bitrate
      (caBitrate, que grava -b:a em kbps), FLAC e ALAC usam qualidade
      constante (caQualidade, -q:a) e WAV usa nivel de compressao. O
      campo QualidadeAudio, acima, carrega a unidade certa para cada
      caso, entao "taxa de bits personalizada" para audio ja esta
      coberta por ele. }

    { --- metadados --- }
    EmbedMiniatura  : Boolean;
    EmbedMetadados  : Boolean;
    EmbedCapitulos  : Boolean;
  end;

  TGerenciadorDownload = class
  public
    { Preenche com os padroes: melhor qualidade possivel, sem recodificar,
      container MKV, nome automatico. }
    class procedure Inicializar(var AOp: TDownloadOpcoes);

    { --- o que esta disponivel --- }

    { O metodo sem FFmpeg so oferece codec original nos dois lados: qualquer
      outra escolha exigiria reencodificar, e ai ja seria o outro metodo. }
    class function PodeEscolherCodecVideo(const AOp: TDownloadOpcoes): Boolean;
    class function PodeEscolherCodecAudio(const AOp: TDownloadOpcoes): Boolean;
    class function PodeEscolherFps(const AOp: TDownloadOpcoes): Boolean;
    class function PodeEscolherResolucaoPersonalizada(
      const AOp: TDownloadOpcoes): Boolean;
    { Escalar para uma altura predefinida exige FFmpeg quando o codec
      escolhido reencoda, mas no metodo simples o yt-dlp sozinho consegue
      escolher uma rendition menor que a pedida. }
    class function PodeLimitarAltura(const AOp: TDownloadOpcoes): Boolean;
    class function PodeEscolherContainer(const AOp: TDownloadOpcoes): Boolean;
    { Lista de containers coerentes com codec de video, audio e modo. }
    class function ContainersDisponiveis(const AOp: TDownloadOpcoes): TStringList;
    class function CodecsVideoDisponiveis(const AOp: TDownloadOpcoes): TStringList;
    class function CodecsAudioDisponiveis(const AOp: TDownloadOpcoes): TStringList;
    { Taxas de quadros oferecidas no controle. O yt-dlp nao troca fps, so
      escolhe a rendition que o site publicou; recodificar para outro
      numero de quadros e tarefa do FFmpeg. }
    class function FpsDisponiveis: TStringList;

    { --- coerencia --- }

    { True quando as opcoes pedem algo que so o FFmpeg faz. }
    class function ExigeFFmpeg(const AOp: TDownloadOpcoes): Boolean;
    { Ajusta o que nao faz sentido no metodo escolhido e devolve quantas
      mudancas fez, para a tela poder avisar. }
    class function Harmonizar(var AOp: TDownloadOpcoes): Integer;
    { Problemas que impedem a execucao. Vazio significa que pode ir. }
    class function Validar(const AOp: TDownloadOpcoes): TStringList;
    { Trava os numeros nas faixas que o encoder aceita de verdade. }
    class procedure LimitarQualidade(var AOp: TDownloadOpcoes);

    { A interface so deve mostrar o par "Qualidade constante /
      Taxa de bits" quando o metodo ja vai recodificar, ha video, e o
      encoder escolhido obedece -b:v. Nos demais casos nao ha o que
      alternar e o controle some, em vez de ficar la mentindo. }
    class function PodeEscolherTaxaBits(const AOp: TDownloadOpcoes): Boolean;

    { --- nomes e caminhos --- }
    class function ExtensaoFinal(const AOp: TDownloadOpcoes): string;
    class function ExtensaoIntermediaria: string;
    { ABase e o nome que o yt-dlp deu ao arquivo baixado (o titulo). So e
      usado quando a escolha e automatica; com nome definido vale sempre o
      que o usuario digitou. }
    class function NomeBase(const AOp: TDownloadOpcoes;
      const ABase: string): string;
    class function CaminhoIntermediario(const AOp: TDownloadOpcoes): string;
    { Caminho do arquivo final. Com nome automatico, ABase e o nome-base do
      arquivo que o yt-dlp gerou, e a conversao so troca a extensao. }
    class function CaminhoFinal(const AOp: TDownloadOpcoes;
      const ABase: string): string;
    class function PastaTemporaria(const AOp: TDownloadOpcoes): string;

    { --- comandos --- }
    class function SeletorFormato(const AOp: TDownloadOpcoes): string;
    { Fase 1. AIntermediario escolhe entre o download simples e o
      download que prepara o MKV para o FFmpeg transformar. }
    class function MontarYtDlp(const AOp: TDownloadOpcoes;
      AIntermediario: Boolean): TStringList;
    { Fase 2. Devolve os argumentos do FFmpeg. }
    class function MontarFFmpeg(const AOp: TDownloadOpcoes;
      const AEntrada, ASaida: string): TStringList;

    { --- texto para a tela --- }
    class function Resumo(const AOp: TDownloadOpcoes): string;
    { Como o controle de qualidade deve ser chamado para este codec. }
    class function RotuloQualidadeVideo(const AOp: TDownloadOpcoes): string;
    class function RotuloQualidadeAudio(const AOp: TDownloadOpcoes): string;
    class function ResumoQualidadeVideo(const AOp: TDownloadOpcoes): string;
    class function ResumoQualidadeAudio(const AOp: TDownloadOpcoes): string;
    { Frase curta dizendo o que o metodo escolhido consegue e o que nao
      consegue, atualizada a cada mudanca de opcao. }
    class function ExplicacaoMetodo(const AOp: TDownloadOpcoes): string;
  end;

implementation

const
  { Pasta onde o MKV intermediario fica. Um ponto no nome mantem a pasta
    escondida em Explorador de Arquivos e a separa dos arquivos do usuario. }
  NOME_TEMP = '.synapse_download';

  { Nome que o yt-dlp da ao arquivo quando ninguem define -o: o titulo com
    o id do video. O id e o que mantem nomes unicos mesmo quando dois
    videos compartilham o titulo, e e este nome-base que a conversao
    preserva. Trocar o formato nao pode explodir este padrao, senao o
    arquivo convertido sairia com um nome diferente do baixado. }
  PADRAO_NOME_YTDLP = '%(title)s [%(id)s].%(ext)s';

  { Argumentos que o yt-dlp recebe sempre. }
  { --newline e --progress: sem isso o yt-dlp desenha a barra com CR e o
    log da aplicacao vira uma linha so. }
  { --no-playlist: um link com playlist baixa so o video pedido. }
  { --print after_move:filepath: imprime no stdout o caminho final
    exato. Evita procurar o arquivo por sufixo, que quebra quando o
    titulo do video termina com a propria extensao. }
  { --no-overwrites junto com --print nao foi usado de proposito: o
    usuario pode querer baixar de novo o mesmo arquivo. }
  YTDLP_COMUM: array[0..6] of string = (
    '--newline',
    '--progress',
    '--no-playlist',
    '--no-mtime',
    '--no-overwrites',
    '--print',
    'after_move:filepath'
  );

  { Resolucoes oferecidas no slider de fps. O yt-dlp nao escolhe fps: ele so
    pode pegar a rendition que o site fez. Escrever 30 num arquivo que so
    tem 25 exige converter quadro a quadro, e isso e FFmpeg. }
  FPS_VALIDOS: array[0..8] of Integer = (23, 24, 25, 30, 48, 50, 60, 120, 240);

{ ------------------------------------------------------------------------ }
{ Utilidades internas                                                       }
{ ------------------------------------------------------------------------ }

function SemAcento(const ATexto: string): string;
var
  i: Integer;
begin
  Result := ATexto;
  for i := 1 to Length(Result) do
    case Result[i] of
      'a'..'z', 'A'..'Z', '0'..'9', ' ', '.', '-', '_', '(', ')':
        { mantem }
    else
      Result[i] := '_';
    end;
  { Dois sublinhados seguidos nao ajudam ninguem a ler o nome. }
  while Pos('__', Result) > 0 do
    Result := StringReplace(Result, '__', '_', [rfReplaceAll]);
  Result := Trim(Result);
end;

function ContemVideo(const AOp: TDownloadOpcoes): Boolean;
begin
  Result := AOp.SomenteAudio = mcVideo;
end;

{ ------------------------------------------------------------------------ }
{ Opcoes e capacidade                                                       }
{ ------------------------------------------------------------------------ }

class procedure TGerenciadorDownload.Inicializar(var AOp: TDownloadOpcoes);
begin
  FillChar(AOp, SizeOf(AOp), 0);
  AOp.EscolhaNome   := enAutomatico;
  AOp.Metodo        := mdYtDlpFFmpeg;
  AOp.SomenteAudio  := mcVideo;
  AOp.Container     := ctMKV;
  AOp.CodecVideo    := cvOriginal;
  AOp.CodecAudio    := caOriginal;
  AOp.Resolucao     := erOriginal;
  AOp.IndiceRes     := -1;
  AOp.Largura       := 0;
  AOp.Altura        := 0;
  AOp.EscolhaFps    := efOriginal;
  AOp.FpsValor      := 0;
  AOp.ProfileProRes := 2;
  AOp.PresetVideo   := '';
  AOp.EmbedMiniatura := True;
  AOp.EmbedMetadados := True;
  AOp.EmbedCapitulos := True;
  LimitarQualidade(AOp);
end;

class function TGerenciadorDownload.PodeEscolherCodecVideo(
  const AOp: TDownloadOpcoes): Boolean;
begin
  { Sem FFmpeg nao existe recodificar, entao so ha uma escolha: deixar como
    veio. E honesto dizer isso a interface em vez de mostrar um combo com
    H.264 selecionado que nao sera usado. }
  Result := ContemVideo(AOp) and (AOp.Metodo = mdYtDlpFFmpeg);
end;

class function TGerenciadorDownload.PodeEscolherCodecAudio(
  const AOp: TDownloadOpcoes): Boolean;
begin
  Result := AOp.Metodo = mdYtDlpFFmpeg;
end;

class function TGerenciadorDownload.PodeEscolherFps(
  const AOp: TDownloadOpcoes): Boolean;
begin
  { Alterar fps e sempre reencodificar, mesmo com codec "original". Por isso
    so aparece quando o metodo ja vai passar pelo FFmpeg. }
  Result := ContemVideo(AOp) and (AOp.Metodo = mdYtDlpFFmpeg) and
            (AOp.CodecVideo <> cvOriginal);
end;

class function TGerenciadorDownload.PodeEscolherResolucaoPersonalizada(
  const AOp: TDownloadOpcoes): Boolean;
begin
  { Um WxH arbitrario so existe depois de reencodificar. }
  Result := ContemVideo(AOp) and (AOp.Metodo = mdYtDlpFFmpeg) and
            (AOp.CodecVideo <> cvOriginal);
end;

class function TGerenciadorDownload.PodeLimitarAltura(
  const AOp: TDownloadOpcoes): Boolean;
begin
  { Limitar a altura nao exige reencodificar: no metodo simples o yt-dlp
    sozinho escolhe a melhor rendition que cabe no limite. E a unica
    forma de "baixar em 720p" sem perder qualidade. }
  Result := ContemVideo(AOp);
end;

class function TGerenciadorDownload.PodeEscolherContainer(
  const AOp: TDownloadOpcoes): Boolean;
begin
  Result := True;
end;

class function TGerenciadorDownload.ContainersDisponiveis(
  const AOp: TDownloadOpcoes): TStringList;
var
  c: TContainer;
  ok: Boolean;
begin
  Result := TStringList.Create;
  for c := Low(TContainer) to High(TContainer) do
  begin
    if ContemVideo(AOp) then
      ok := not TGerenciadorCatalogo.SomenteAudio(c)
    else
      ok := TGerenciadorCatalogo.SomenteAudio(c);

    if ok and ContemVideo(AOp) and
       (AOp.CodecVideo <> cvOriginal) then
      ok := TGerenciadorCatalogo.ContainerAceitaVideo(c, AOp.CodecVideo);

    if ok and (AOp.CodecAudio <> caOriginal) then
      ok := TGerenciadorCatalogo.ContainerAceitaAudio(c, AOp.CodecAudio);

    { Um container so de audio nao faz sentido guardando video, e um
      container de video nao faz sentido numa extra so de audio. A regra
      acima ja cuida dos dois casos, mas o codec de video original tambem
      tem de caber no container. }
    if ok and ContemVideo(AOp) and
       (AOp.CodecVideo = cvOriginal) then
      ok := TGerenciadorCatalogo.ContainerAceitaVideo(c, cvOriginal);

    if ok then
      Result.Add(TGerenciadorCatalogo.RotuloContainer(c));
  end;
end;

class function TGerenciadorDownload.CodecsVideoDisponiveis(
  const AOp: TDownloadOpcoes): TStringList;
var
  v: TCodecVideo;
  ok: Boolean;
begin
  Result := TStringList.Create;
  if not ContemVideo(AOp) then
    Exit;
  for v := Low(TCodecVideo) to High(TCodecVideo) do
  begin
    if not PodeEscolherCodecVideo(AOp) then
    begin
      { Sem FFmpeg so o original existe. }
      if v = cvOriginal then
        Result.Add(TGerenciadorCatalogo.RotuloCodecVideo(v));
    end
    else
    begin
      { O codec so entra na lista se ao menos um container atual aceitar
        ele junto com o audio escolhido. Sem isso a interface ofereceria
        ProRes com MP4 selecionado, que e justamente a combinacao que o
        FFmpeg recusa. }
      ok := False;
      if AOp.Container <> ctMP3 then
        ok := TGerenciadorCatalogo.ContainerAceitaVideo(AOp.Container, v);
      if (not ok) and (AOp.CodecAudio <> caOriginal) then
        ok := TGerenciadorCatalogo.ContainerAceitaAudio(AOp.Container,
               AOp.CodecAudio) and
             TGerenciadorCatalogo.ContainerAceitaVideo(AOp.Container, v);
      if ok then
        Result.Add(TGerenciadorCatalogo.RotuloCodecVideo(v));
    end;
  end;
end;

class function TGerenciadorDownload.CodecsAudioDisponiveis(
  const AOp: TDownloadOpcoes): TStringList;
var
  a: TCodecAudio;
begin
  Result := TStringList.Create;
  if not PodeEscolherCodecAudio(AOp) then
  begin
    Result.Add(TGerenciadorCatalogo.RotuloCodecAudio(caOriginal));
    Exit;
  end;
  for a := Low(TCodecAudio) to High(TCodecAudio) do
    if TGerenciadorCatalogo.ContainerAceitaAudio(AOp.Container, a) then
      Result.Add(TGerenciadorCatalogo.RotuloCodecAudio(a));
end;

class function TGerenciadorDownload.FpsDisponiveis: TStringList;
var
  i: Integer;
begin
  Result := TStringList.Create;
  for i := Low(FPS_VALIDOS) to High(FPS_VALIDOS) do
    Result.Add(IntToStr(FPS_VALIDOS[i]) + ' fps');
end;

class function TGerenciadorDownload.ExigeFFmpeg(
  const AOp: TDownloadOpcoes): Boolean;
begin
  Result := AOp.Metodo = mdYtDlpFFmpeg;
  { Mesmo no metodo simples, trocar o container de audio para um formato que
    o site nao Tem e um caso real: --audio-format usa o FFmpeg. Mas como o
    metodo simples nao oferece codec de audio, ExigeFFmpeg aqui so
    precisa refletir a escolha de metodo. A distincao fica em
    SeletorFormato e MontarYtDlp, que sabem quando o remux basta. }
end;

class function TGerenciadorDownload.Harmonizar(var AOp: TDownloadOpcoes): Integer;
var
  mudou: Boolean;
  cands: TStringList;
  n: Integer;

  function Aceita: Boolean;
  begin
    if AOp.SomenteAudio = mcVideo then
      Result := TGerenciadorCatalogo.ContainerAceitaVideo(AOp.Container,
               AOp.CodecVideo) and
               TGerenciadorCatalogo.ContainerAceitaAudio(AOp.Container,
               AOp.CodecAudio)
    else
      Result := TGerenciadorCatalogo.SomenteAudio(AOp.Container) and
               TGerenciadorCatalogo.ContainerAceitaAudio(AOp.Container,
               AOp.CodecAudio);
  end;

begin
  Result := 0;
  mudou := False;

  { 1) No metodo simples nada pode ser reencodificado. }
  if AOp.Metodo = mdYtDlp then
  begin
    if AOp.CodecVideo <> cvOriginal then
    begin
      AOp.CodecVideo := cvOriginal;
      mudou := True;
      Inc(Result);
    end;
    if AOp.CodecAudio <> caOriginal then
    begin
      AOp.CodecAudio := caOriginal;
      mudou := True;
      Inc(Result);
    end;
    if AOp.EscolhaFps <> efOriginal then
    begin
      AOp.EscolhaFps := efOriginal;
      AOp.FpsValor := 0;
      mudou := True;
      Inc(Result);
    end;
    if AOp.Resolucao = erPersonalizada then
    begin
      AOp.Resolucao := erOriginal;
      mudou := True;
      Inc(Result);
    end;
  end;

  { 2) So audio nao tem codec nem resolucao de video. }
  if AOp.SomenteAudio = mcAudio then
  begin
    if (AOp.CodecVideo <> cvOriginal) or (AOp.Resolucao <> erOriginal) or
       (AOp.EscolhaFps <> efOriginal) then
    begin
      AOp.CodecVideo := cvOriginal;
      AOp.Resolucao  := erOriginal;
      AOp.EscolhaFps := efOriginal;
      AOp.FpsValor   := 0;
      mudou := True;
      Inc(Result);
    end;
  end;

  { 3) O container tem de aceitar o que foi escolhido. Quando nao aceita,
    procura o primeiro que aceita na ordem do catalogo. A lista e montada a
    partir dos codecs atuais, entao o primeiro item e sempre uma combinacao
    valida. }
  if not Aceita then
  begin
    cands := ContainersDisponiveis(AOp);
    try
      if cands.Count > 0 then
      begin
        { O primeiro da lista ja e uma combinacao valida com os codecs
          atuais. Repara que cands so tem os rotulos dos containers que
          passaram no filtro, entao o indice de la nao serve para
          reconstruir o enum: a conversao e feita pelo rotulo. }
        n := cands.IndexOf(TGerenciadorCatalogo.RotuloContainer(AOp.Container));
        if n < 0 then
          n := 0;
        if not SameText(cands[n],
                        TGerenciadorCatalogo.RotuloContainer(AOp.Container)) then
        begin
          AOp.Container := TGerenciadorCatalogo.ContainerPorRotulo(cands[n]);
          mudou := True;
          Inc(Result);
        end;
      end;
    finally
      cands.Free;
    end;
  end;

  { 4) Resolucao predefinida apontando fora da lista. }
  if (AOp.Resolucao = erPredefinida) and
     ((AOp.IndiceRes < 0) or
      (AOp.IndiceRes >= TGerenciadorCatalogo.TotalResolucoes)) then
  begin
    AOp.IndiceRes := 5;   { 1080p, o meio da lista }
    mudou := True;
    Inc(Result);
  end;

  { 5) Resolucao personalizada com medida invalida. }
  if (AOp.Resolucao = erPersonalizada) and
     ((AOp.Largura < 16) or (AOp.Altura < 16)) then
  begin
    AOp.Resolucao := erOriginal;
    mudou := True;
    Inc(Result);
  end;

  LimitarQualidade(AOp);

  { O registro inteiro nao e comparado de proposito: ele tem campos que o
    usuario nunca ve, como a pasta, e comparar tudo daria aviso falso a
    cada tecla digitada. A contagem acima e campo a campo. }
  if not mudou then
    Result := 0;
end;

class function TGerenciadorDownload.Validar(
  const AOp: TDownloadOpcoes): TStringList;
var
  i: Integer;
begin
  Result := TStringList.Create;

  if Trim(AOp.URL) = '' then
    Result.Add('Informe o endereco do video.')
  else if Pos('://', AOp.URL) = 0 then
    Result.Add('O endereco precisa ser completo, com http:// ou https://.');

  if Trim(AOp.Pasta) = '' then
    Result.Add('Escolha a pasta de destino.');

  { Nome definido pelo usuario tem de sobreviver ao sistema de arquivos. }
  if (AOp.EscolhaNome = enDefinido) and (Trim(AOp.Nome) = '') then
    Result.Add('Deixe o nome em branco para usar o titulo do video.');

  { Nome com caractere que o Windows proibe em nome de arquivo. A checagem
    e feita aqui e nao no SemAcento porque o usuario precisa saber que o
    nome foi recusado, e nao descobrir depois que o arquivo saiu com
    sublinhados no lugar dos acentos. }
  if AOp.EscolhaNome = enDefinido then
  begin
    for i := 1 to Length(AOp.Nome) do
      if Pos(AOp.Nome[i], '<>:"/\|?*') > 0 then
      begin
        Result.Add('O nome do arquivo nao pode conter: < > : " / \ | ? *');
        Break;
      end;
  end;

  if (AOp.Resolucao = erPersonalizada) and
     ((AOp.Largura mod 2 <> 0) or (AOp.Altura mod 2 <> 0)) then
    Result.Add('Largura e altura precisam ser numeros pares. Com numero '
             + 'impar o FFmpeg falha ao escolher o formato de pixel.');

  if AOp.Metodo = mdYtDlpFFmpeg then
    if not TGerenciadorDependencias.Localizado(depFFmpeg) then
      Result.Add('O metodo escolhido precisa do FFmpeg e ele nao foi '
               + 'encontrado. Use "somente yt-dlp" ou instale o FFmpeg.');
end;

class procedure TGerenciadorDownload.LimitarQualidade(var AOp: TDownloadOpcoes);
var
  lo, hi, pad: Integer;
  tbLo, tbHi, tbPad: Integer;
begin
  if TGerenciadorCatalogo.FaixaVideo(AOp.CodecVideo, lo, hi, pad) then
  begin
    { Ainda nao escolhido: usa o padrao do codec, nao o zero. Uma vez que
      o usuario mexeu, o zero e uma escolha e tem de ser respeitada. }
    if not AOp.QualidadeVideoDefinida then
      AOp.QualidadeVideo := pad;

    if AOp.QualidadeVideo < lo then AOp.QualidadeVideo := lo;
    if AOp.QualidadeVideo > hi then AOp.QualidadeVideo := hi;
  end
  else
  begin
    { Codec sem faixa (original, perfil): o numero nao significa nada e
      volta a servir de "nao escolhido" para o proximo codec. }
    AOp.QualidadeVideo := 0;
    AOp.QualidadeVideoDefinida := False;
  end;

  { --- taxa de bits do video --- }
  if TGerenciadorCatalogo.FaixaTaxaBits(AOp.CodecVideo, tbLo, tbHi, tbPad) then
  begin
    { Escolher taxa de bits so faz sentido se o encoder obedece. Se o
      usuario estava em taxa de bits e trocou para um codec que ignora
      -b:v, o modo volta para qualidade constante: manter o outro seria
      mostrar um controle que nao vai fazer nada. }
    if AOp.ModoQualidadeVideo = mqTaxaBits then
    begin
      if not AOp.TaxaBitsVideoDefinida then
        AOp.TaxaBitsVideo := tbPad;
      if AOp.TaxaBitsVideo < tbLo then AOp.TaxaBitsVideo := tbLo;
      if AOp.TaxaBitsVideo > tbHi then AOp.TaxaBitsVideo := tbHi;
    end;
  end
  else
    AOp.ModoQualidadeVideo := mqQualidade;

  { Sem recodificar nao ha qualidade para escolher de nenhum dos dois
    jeitos. }
  if AOp.CodecVideo = cvOriginal then
    AOp.ModoQualidadeVideo := mqQualidade;

  if TGerenciadorCatalogo.FaixaAudio(AOp.CodecAudio, lo, hi, pad) then
  begin
    if not AOp.QualidadeAudioDefinida then
      AOp.QualidadeAudio := pad;

    if AOp.QualidadeAudio < lo then AOp.QualidadeAudio := lo;
    if AOp.QualidadeAudio > hi then AOp.QualidadeAudio := hi;
  end
  else
  begin
    AOp.QualidadeAudio := 0;
    AOp.QualidadeAudioDefinida := False;
  end;

  { --- taxa de bits do audio ---
    Nao ha nada a fazer aqui. O codec ja escolhe a unidade: caBitrate
    grava -b:a em kbps usando o proprio QualidadeAudio, e os demais nem
    aceitam bitrate. Colocar um segundo campo seria ter dois numeros
    dizendo a mesma coisa, so que um deles enganoso. }

  if (AOp.ProfileProRes < 0) or (AOp.ProfileProRes > 4) then
    AOp.ProfileProRes := 2;
end;

class function TGerenciadorDownload.PodeEscolherTaxaBits(
  const AOp: TDownloadOpcoes): Boolean;
begin
  { Mesma condicao de escolher codec, mais o encoder ter medido certo
    quando testado. H.264, H.265 e AV1 passam; VP9 falhou por 35% no
    alvo e os outros nem olharam para o numero. }
  Result := PodeEscolherCodecVideo(AOp) and
            (AOp.CodecVideo <> cvOriginal) and
            TGerenciadorCatalogo.AceitaTaxaBits(AOp.CodecVideo);
end;

{ ------------------------------------------------------------------------ }
{ Nomes e caminhos                                                          }
{ ------------------------------------------------------------------------ }

class function TGerenciadorDownload.ExtensaoFinal(
  const AOp: TDownloadOpcoes): string;
begin
  Result := TGerenciadorCatalogo.ExtensaoContainer(AOp.Container);
end;

class function TGerenciadorDownload.ExtensaoIntermediaria: string;
begin
  Result := 'mkv';
end;

class function TGerenciadorDownload.NomeBase(
  const AOp: TDownloadOpcoes; const ABase: string): string;
begin
  { Automatico preserva o nome que o yt-dlp gerou (o titulo), exatamente
    como saiu: ele ja foi limpo pelo proprio yt-dlp para o sistema de
    arquivos, e passar de novo por SemAcento aqui reescreveria o texto que
    o usuario espera. So o nome escolhido a mao e normalizado. }
  if AOp.EscolhaNome = enDefinido then
    Result := SemAcento(AOp.Nome)
  else if ABase <> '' then
    Result := ABase
  else
    Result := 'download';
  if Result = '' then
    Result := 'download';
end;

class function TGerenciadorDownload.PastaTemporaria(
  const AOp: TDownloadOpcoes): string;
begin
  Result := IncludeTrailingPathDelimiter(AOp.Pasta) + NOME_TEMP;
end;

class function TGerenciadorDownload.CaminhoIntermediario(
  const AOp: TDownloadOpcoes): string;
begin
  { Com nome definido este caminho e exato: a fase 1 escreve la. No nome
    automatico o arquivo sai com o titulo, que so existe depois do download;
    por isso o executor procura o arquivo recem-chegado na pasta temporaria
    e usa o caminho real, em vez desta previsao. }
  Result := IncludeTrailingPathDelimiter(PastaTemporaria(AOp)) +
            NomeBase(AOp, '') + '.' + ExtensaoIntermediaria;
end;

class function TGerenciadorDownload.CaminhoFinal(
  const AOp: TDownloadOpcoes; const ABase: string): string;
var
  ext: string;
begin
  ext := ExtensaoFinal(AOp);
  { No nome automatico, ABase e o nome que o yt-dlp deu ao arquivo baixado:
    a conversao so troca a extensao e preserva o titulo. Com nome definido
    o ABase e ignorado e vale sempre o nome digitado. }
  Result := IncludeTrailingPathDelimiter(AOp.Pasta) + NomeBase(AOp, ABase) +
            '.' + ext;
end;

{ ------------------------------------------------------------------------ }
{ Seletor de formato                                                         }
{ ------------------------------------------------------------------------ }

class function TGerenciadorDownload.SeletorFormato(
  const AOp: TDownloadOpcoes): string;
var
  altura: Integer;
  sel: string;
begin
  { Este seletor tem tres camadas de reserva e cada uma existe por um
    motivo medido, nao por paranoia:

      bestvideo[height<=H]+bestaudio   o melhor par separado, ate a altura
      best[height<=H]                  o site ja entrega tudo junto
      best                             ultimo recurso

    A cauda "/best" e obrigatoria. Em um link direto para um arquivo, o
    yt-dlp ve um formato so, com vcodec e altura desconhecidos; um seletor
    com filtro de altura reprova esse unico formato e o download falha com
    "Requested format is not available". Foi exatamente o que aconteceu
    nos testes. }
  if AOp.SomenteAudio = mcAudio then
    Exit('ba/b');

  if (AOp.Resolucao = erPredefinida) and (AOp.IndiceRes >= 0) then
  begin
    altura := TGerenciadorCatalogo.AlturaResolucao(AOp.IndiceRes);
    sel := 'bestvideo[height<=' + IntToStr(altura) + ']+bestaudio' +
           '/best[height<=' + IntToStr(altura) + ']/best';
    Exit(sel);
  end;

  Result := 'bestvideo+bestaudio/best';
end;

{ ------------------------------------------------------------------------ }
{ Comando do yt-dlp                                                         }
{ ------------------------------------------------------------------------ }

class function TGerenciadorDownload.MontarYtDlp(
  const AOp: TDownloadOpcoes; AIntermediario: Boolean): TStringList;
var
  i: Integer;
  ext: string;
begin
  Result := TStringList.Create;

  for i := Low(YTDLP_COMUM) to High(YTDLP_COMUM) do
    Result.Add(YTDLP_COMUM[i]);

  { Cookies, conforme as Preferências: navegador (--cookies-from-browser) ou
    arquivo (--cookies). Repassa apenas token/caminho; nenhum dado de cookie
    e lido nem copiado por esta unit. }
  Configuracoes.AcrescentarCookies(Result);

  { --ffmpeg-location so faz sentido quando o yt-dlp precisa do FFmpeg:
    juntar pistas e extrair audio. No metodo simples ele fica de fora, e
    por isso aquele metodo funciona numa maquina sem FFmpeg. }
  if AOp.Metodo = mdYtDlpFFmpeg then
    Result.Add('--ffmpeg-location');  { resolvido pelo executor }

  Result.Add('-f');
  Result.Add(SeletorFormato(AOp));

  if AIntermediario then
  begin
    { Fase 1 do metodo com FFmpeg: as duas melhores pistas juntas num MKV.
      MKV porque e o unico container que aceitou todos os codecs medidos. }
    Result.Add('--merge-output-format');
    Result.Add(ExtensaoIntermediaria);
    Result.Add('-o');
    { No nome automatico o intermediario sai com o nome que o yt-dlp
      escolheria (titulo com id), porque e este nome-base que a fase 2
      vai preservar no arquivo final. }
    if AOp.EscolhaNome = enDefinido then
      Result.Add(IncludeTrailingPathDelimiter(PastaTemporaria(AOp)) +
                 SemAcento(AOp.Nome) + '.%(ext)s')
    else
      Result.Add(IncludeTrailingPathDelimiter(PastaTemporaria(AOp)) +
                 PADRAO_NOME_YTDLP);
  end
  else
  begin
    { Metodo simples: um formato so, direto para a pasta do usuario. }
    Result.Add('-P');
    Result.Add(AOp.Pasta);
    Result.Add('-o');
    { Automatico usa exatamente o nome que o yt-dlp usaria por padrao, com
      o id do video: dois titulos iguais nao colidem e nada e renomeado
      depois do download. }
    if AOp.EscolhaNome = enDefinido then
      Result.Add(SemAcento(AOp.Nome) + '.%(ext)s')
    else
      Result.Add(PADRAO_NOME_YTDLP);

    { Trocar de container sem reencodificar e trabalho do yt-dlp, e nao do
      FFmpeg: o --remux-video so troca as cabecalhas e nao toca num quadro.

      Em modo so de audio o container escolhido quase nunca bate com o que o
      site tem, e nao ha o que fazer: sem recodificar, o arquivo sai com a
      extensao que o proprio site usou. Por isso o remux so entra em modo de
      video, e apenas quando o destino e um container de video real. }
    if ContemVideo(AOp) and (AOp.Container <> ctMKV) then
    begin
      ext := TGerenciadorCatalogo.ExtensaoContainer(AOp.Container);
      if (ext <> '') and (ext <> 'mkv') then
      begin
        Result.Add('--merge-output-format');
        Result.Add(ext);
        Result.Add('--remux-video');
        Result.Add(ext);
      end;
    end;
  end;

  if AOp.EmbedMetadados then
    Result.Add('--embed-metadata');

  if AOp.EmbedMiniatura then
  begin
    { AVI nao aceita PNG, e o yt-dlp aborta o download inteiro em vez de
      pular a miniatura. Pedir JPEG resolve, mas o aviso fica ruidoso
      demais; o mais honesto e nao pedir miniatura nesse container. }
    if AOp.Container <> ctAVI then
      Result.Add('--embed-thumbnail');
  end;

  if AOp.EmbedCapitulos and ContemVideo(AOp) then
    Result.Add('--embed-chapters');

  Result.Add('--');
  Result.Add(AOp.URL);
end;

{ ------------------------------------------------------------------------ }
{ Comando do FFmpeg                                                         }
{ ------------------------------------------------------------------------ }

{ O formato de pixel e decide aqui e nao no catalogo porque so importa
  quando o codec vai reencodificar, que e uma condicao do comando e nao
  uma propriedade do codec. Sem yuv420p o FFmpeg pode escolher yuv444p a
  partir de uma entrada com chroma de alta resolucao, e o arquivo passa a
  nao tocar em metade dos aparelhos. }
function PixPadraoVideo(ACodec: TCodecVideo): string;
begin
  Result := 'yuv420p';
  if ACodec in [cvProRes] then
    Exit('yuv422p10le');
  if ACodec = cvFFV1 then
    Exit('yuv420p');
  if ACodec = cvMJPEG then
    Exit('yuvj420p');
end;

{ Monta o filtro de video. Escala e fps andam juntos no mesmo grafo porque
  o FFmpeg aceita um -vf so, e encadear dois filtros em -vf e mais rapido
  que dois passes. }
function GrafoVideo(const AOp: TDownloadOpcoes): string;
var
  partes: TStringList;
  i: Integer;
begin
  Result := '';
  partes := TStringList.Create;
  try
    case AOp.Resolucao of
      erPredefinida:
        if AOp.IndiceRes >= 0 then
          partes.Add('scale=' +
            TGerenciadorCatalogo.Resolucao(AOp.IndiceRes).EscalaFF);
      erPersonalizada:
        if (AOp.Largura > 0) and (AOp.Altura > 0) then
          partes.Add('scale=' + IntToStr(AOp.Largura) + ':' +
            IntToStr(AOp.Altura));
    end;

    if AOp.EscolhaFps = efPersonalizado then
      if AOp.FpsValor > 0 then
        partes.Add('fps=' + IntToStr(AOp.FpsValor));

    { Nao usar partes.Text: ele junta com LineEnding, que no Windows tem um
      #13 na frente, e o FFmpeg recebe 'escala=<CR>,fps=30'. O separador do
      -vf e a virgula, sem nada em volta. }
    Result := '';
    for i := 0 to partes.Count - 1 do
    begin
      if i > 0 then
        Result := Result + ',';
      Result := Result + partes[i];
    end;
  finally
    partes.Free;
  end;
end;

class function TGerenciadorDownload.MontarFFmpeg(
  const AOp: TDownloadOpcoes; const AEntrada, ASaida: string): TStringList;
var
  lo, hi, pad: Integer;
  grafo: string;
  enc: string;
begin
  Result := TStringList.Create;
  if (AEntrada = '') or (ASaida = '') then
    Exit;

  { -y sobrescreve sem perguntar: o usuario pediu para gerar este arquivo e
    ja respondeu isso na confirmacao. }
  Result.Add('-y');
  { -hide_banner tira a faixa de build que polui o log. }
  Result.Add('-hide_banner');
  Result.Add('-loglevel');
  Result.Add('error');
  Result.Add('-i');
  Result.Add(AEntrada);

  if AOp.SomenteAudio = mcAudio then
  begin
    Result.Add('-vn');
  end
  else
  begin
    { -map explicito: sem isso o FFmpeg pode levar junto legenda ou anexo
      que veio junto e produzir um arquivo com surpresas. O ? depois de 0:a
      faz o audio ser opcional, e o que salva os containers que ficaram
      sem trilha de audio. }
    Result.Add('-map');
    Result.Add('0:v:0');
    Result.Add('-map');
    Result.Add('0:a:0?');
    Result.Add('-sn');
    Result.Add('-dn');
  end;

  enc := TGerenciadorCatalogo.EncoderVideo(AOp.CodecVideo);
  if (AOp.SomenteAudio = mcVideo) and (AOp.CodecVideo <> cvOriginal) then
  begin
    Result.Add('-c:v');
    Result.Add(enc);

    grafo := GrafoVideo(AOp);
    if grafo <> '' then
    begin
      Result.Add('-vf');
      Result.Add(grafo);
    end;

    case TGerenciadorCatalogo.ControleVideo(AOp.CodecVideo) of
      cvCRF:
        begin
          { Os dois controles do video nao andam juntos: ou o usuario
            diz qual a qualidade e o encoder escolhe o tamanho, ou diz
            o tamanho e o encoder escolhe a qualidade. Neste segundo
            caso o -crf some, porque mandar as duas coisas e pedir para
            o encoder ignorar uma delas. }
          if AOp.ModoQualidadeVideo = mqTaxaBits then
          begin
            Result.Add('-b:v');
            Result.Add(IntToStr(AOp.TaxaBitsVideo) + 'k');
          end
          else
          begin
            Result.Add('-crf');
            Result.Add(IntToStr(AOp.QualidadeVideo));
            { VP9 so obedece ao CRF quando o bitrate e liberado. Sem esta
              opcao ele ignora o CRF e limpa por taxa, o que produz um
              arquivo muito maior do que o numero escolhido sugere. }
            if TGerenciadorCatalogo.ExigeBZero(AOp.CodecVideo) then
            begin
              Result.Add('-b:v');
              Result.Add('0');
            end;
          end;
        end;
      cvQScale:
        begin
          Result.Add('-q:v');
          Result.Add(IntToStr(AOp.QualidadeVideo));
        end;
      cvPerfil:
        begin
          Result.Add('-profile:v');
          Result.Add(IntToStr(AOp.ProfileProRes));
        end;
      cvCompressao:
        begin
          Result.Add('-level');
          Result.Add(IntToStr(AOp.QualidadeVideo));
        end;
    end;

    if AOp.PresetVideo <> '' then
    begin
      Result.Add('-preset');
      Result.Add(AOp.PresetVideo);
    end;

    if TGerenciadorCatalogo.FaixaVideo(AOp.CodecVideo, lo, hi, pad) then
    begin
      Result.Add('-pix_fmt');
      Result.Add(PixPadraoVideo(AOp.CodecVideo));
    end;
  end
  else
    Result.Add('-c:v');
    Result.Add('copy');

  { --- audio --- }
  enc := TGerenciadorCatalogo.EncoderAudio(AOp.CodecAudio);
  if AOp.CodecAudio = caOriginal then
  begin
    Result.Add('-c:a');
    Result.Add('copy');
  end
  else
  begin
    Result.Add('-c:a');
    Result.Add(enc);
    case TGerenciadorCatalogo.ControleAudio(AOp.CodecAudio) of
      caBitrate:
        begin
          Result.Add('-b:a');
          Result.Add(IntToStr(AOp.QualidadeAudio) + 'k');
        end;
      caQualidade:
        begin
          Result.Add('-q:a');
          Result.Add(IntToStr(AOp.QualidadeAudio));
        end;
      caCompressao:
        begin
          Result.Add('-compression_level');
          Result.Add(IntToStr(AOp.QualidadeAudio));
        end;
    end;
    if AOp.CodecAudio in [caAAC, caALAC] then
    begin
      Result.Add('-movflags');
      Result.Add('+faststart');
    end;
  end;

  Result.Add(ASaida);
end;

{ ------------------------------------------------------------------------ }
{ Textos para a interface                                                    }
{ ------------------------------------------------------------------------ }

class function TGerenciadorDownload.RotuloQualidadeVideo(
  const AOp: TDownloadOpcoes): string;
begin
  { Em modo taxa de bits o controle vira um slider de kbps, seja qual for
    o codec. So os encoders que medem -b:v chegam aqui de verdade, porque
    PodeEscolherTaxaBits ja esconde o resto. }
  if AOp.ModoQualidadeVideo = mqTaxaBits then
    Exit('Taxa (kbps)');
  case TGerenciadorCatalogo.ControleVideo(AOp.CodecVideo) of
    cvCRF:        Result := 'CRF';
    cvQScale:     Result := 'Escala JPEG';
    cvPerfil:     Result := 'Perfil ProRes';
    cvCompressao: Result := 'Nivel de compressao';
  else
    Result := 'Qualidade';
  end;
end;

class function TGerenciadorDownload.RotuloQualidadeAudio(
  const AOp: TDownloadOpcoes): string;
begin
  case TGerenciadorCatalogo.ControleAudio(AOp.CodecAudio) of
    caBitrate:     Result := 'Taxa (kbps)';
    caQualidade:   Result := 'Qualidade VBR';
    caCompressao:  Result := 'Nivel de compressao';
  else
    Result := 'Qualidade';
  end;
end;

class function TGerenciadorDownload.ResumoQualidadeVideo(
  const AOp: TDownloadOpcoes): string;
var
  v: Integer;
begin
  if AOp.CodecVideo = cvOriginal then
    Exit('sem recodificar');

  v := AOp.QualidadeVideo;
  if AOp.ModoQualidadeVideo = mqTaxaBits then
  begin
    { Formatar o kbps do jeito que o usuario le: 8000 mostra "8 Mbps"
      quando passar de mil, senao "512 kbps". }
    Result := IntToStr(AOp.TaxaBitsVideo) + ' kbps';
    if AOp.TaxaBitsVideo >= 1000 then
      Result := FormatFloat('0.#', AOp.TaxaBitsVideo / 1000) + ' Mbps';
  end
  else
  case TGerenciadorCatalogo.ControleVideo(AOp.CodecVideo) of
    cvCRF:
      begin
        Result := 'CRF ' + IntToStr(v);
        { CRF 0 e lossless e 51 e o pior aceitavel, entao no x264 e no
          VP9 o numero pequeno e o melhor. O catalogo diz qual e o sentido
          porque nem todo controle anda nessa direcao. }
        if TGerenciadorCatalogo.MenorMelhorVideo(AOp.CodecVideo) then
          Result := Result + ' (menor e melhor)'
        else
          Result := Result + ' (maior e melhor)';
      end;
    cvQScale:
      begin
        Result := 'qscale ' + IntToStr(v);
        if TGerenciadorCatalogo.MenorMelhorVideo(AOp.CodecVideo) then
          Result := Result + ' (menor e melhor)'
        else
          Result := Result + ' (maior e melhor)';
      end;
    cvPerfil:      Result := 'perfil ' + IntToStr(AOp.ProfileProRes);
    cvCompressao:  Result := 'nivel ' + IntToStr(v);
  else
    Result := '-';
  end;
  if AOp.PresetVideo <> '' then
    Result := Result + ', preset ' + AOp.PresetVideo;
end;

class function TGerenciadorDownload.ResumoQualidadeAudio(
  const AOp: TDownloadOpcoes): string;
begin
  if AOp.CodecAudio = caOriginal then
    Exit('sem recodificar');
  case TGerenciadorCatalogo.ControleAudio(AOp.CodecAudio) of
    caBitrate:     Result := IntToStr(AOp.QualidadeAudio) + ' kbps';
    caQualidade:   Result := 'VBR ' + IntToStr(AOp.QualidadeAudio);
    caCompressao:  Result := 'compressao ' + IntToStr(AOp.QualidadeAudio);
  else
    Result := '-';
  end;
end;

class function TGerenciadorDownload.Resumo(
  const AOp: TDownloadOpcoes): string;
var
  linha: string;
  altura: Integer;
begin
  Result := '';

  if AOp.Metodo = mdYtDlp then
    linha := 'Metodo       : somente yt-dlp (rapido, sem perder qualidade)'
  else
    linha := 'Metodo       : yt-dlp + FFmpeg (reconverte o arquivo)';
  Result := Result + linha + LineEnding;

  if AOp.SomenteAudio = mcAudio then
  begin
    Result := Result + 'Conteudo     : somente audio' + LineEnding;
    Result := Result + 'Audio        : ' +
      TGerenciadorCatalogo.RotuloCodecAudio(AOp.CodecAudio) + ', ' +
      ResumoQualidadeAudio(AOp) + LineEnding;
    Result := Result + 'Arquivo      : ' +
      TGerenciadorCatalogo.RotuloContainer(AOp.Container) + LineEnding;
    Exit;
  end;

  Result := Result + 'Conteudo     : video' + LineEnding;

  case AOp.Resolucao of
    erOriginal:
      Result := Result + 'Resolucao    : a maior disponivel no site' +
        LineEnding;
    erPredefinida:
      begin
        altura := TGerenciadorCatalogo.AlturaResolucao(AOp.IndiceRes);
        if AOp.Metodo = mdYtDlp then
          Result := Result + 'Resolucao    : ate ' + IntToStr(altura) +
            'p (escolhida entre as que o site tem)' + LineEnding
        else
          Result := Result + 'Resolucao    : ' + IntToStr(altura) + 'p' +
            LineEnding;
      end;
    erPersonalizada:
      Result := Result + 'Resolucao    : ' + IntToStr(AOp.Largura) + 'x' +
        IntToStr(AOp.Altura) + LineEnding;
  end;

  if AOp.EscolhaFps = efPersonalizado then
    Result := Result + 'Quadros      : ' + IntToStr(AOp.FpsValor) + ' fps'
      + LineEnding
  else
    Result := Result + 'Quadros      : os do arquivo original' + LineEnding;

  Result := Result + 'Video        : ' +
    TGerenciadorCatalogo.RotuloCodecVideo(AOp.CodecVideo) + ', ' +
    ResumoQualidadeVideo(AOp) + LineEnding;
  Result := Result + 'Audio        : ' +
    TGerenciadorCatalogo.RotuloCodecAudio(AOp.CodecAudio) + ', ' +
    ResumoQualidadeAudio(AOp) + LineEnding;
  Result := Result + 'Arquivo      : ' +
    TGerenciadorCatalogo.RotuloContainer(AOp.Container) + LineEnding;

  if AOp.Metodo = mdYtDlp then
    Result := Result + 'Observacao   : nenhuma conversao sera feita; so e '
      + 'escolhida entre as versoes que o site publica.' + LineEnding;
end;

class function TGerenciadorDownload.ExplicacaoMetodo(
  const AOp: TDownloadOpcoes): string;
begin
  if AOp.Metodo = mdYtDlp then
    Result := 'Baixa a versao que o site ja publicou, sem tocar num quadro '
      + 'so. Voce pode escolher a qualidade e o tamanho final, mas nao '
      + 'codec nem fps: nao existe conversao aqui.'
  else
  begin
    if AOp.CodecVideo = cvOriginal then
      Result := 'O video vai ser copiado como veio, entao o FFmpeg so entra '
        + 'se voce escolher um codec de audio diferente do original.'
    else
      Result := 'O arquivo sera reencodificado: leva tempo, e a qualidade '
        + 'final depende do numero escolhido, e nao da resolucao do site.';
    if AOp.CodecVideo = cvAV1 then
      Result := Result + ' Atencao: AV1 demora muito mais que os outros.';
  end;
end;

end.
