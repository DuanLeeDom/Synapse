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
  Classes, SysUtils, uDownloadCatalog, uDependencias;

type
  { Como o download vai ser feito. }
  TMetodoDownload = (mdYtDlp, mdYtDlpFFmpeg);

  { O que o usuario quer no fim: um video ou so o audio. }
  TModoConteudo = (mcVideo, mcAudio);

  { Resolucao. erPredefinida escolhe da lista de alturas; erPersonalizada
    aceitaWxH; erOriginal mantem o que o site publicou. }
  TEscolhaResolucao = (erOriginal, erPredefinida, erPersonalizada);

  TEscolhaFps = (efOriginal, efPersonalizado);

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

    { --- nomes e caminhos --- }
    class function ExtensaoFinal(const AOp: TDownloadOpcoes): string;
    class function ExtensaoIntermediaria: string;
    class function NomeBase(const AOp: TDownloadOpcoes): string;
    class function CaminhoIntermediario(const AOp: TDownloadOpcoes): string;
    class function CaminhoFinal(const AOp: TDownloadOpcoes): string;
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
        n := cands.IndexOf(TGerenciadorCatalogo.RotuloContainer(AOp.Container));
        if n < 0 then
          n := 0;
        if cands[n] <> TGerenciadorCatalogo.RotuloContainer(AOp.Container)
        then
        begin
          AOp.Container := TGerenciadorCatalogo.Container(n);
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
begin
  if TGerenciadorCatalogo.FaixaVideo(AOp.CodecVideo, lo, hi, pad) then
  begin
    if AOp.QualidadeVideo < lo then AOp.QualidadeVideo := lo;
    if AOp.QualidadeVideo > hi then AOp.QualidadeVideo := hi;
  end
  else
    AOp.QualidadeVideo := 0;

  if TGerenciadorCatalogo.FaixaAudio(AOp.CodecAudio, lo, hi, pad) then
  begin
    if AOp.QualidadeAudio < lo then AOp.QualidadeAudio := lo;
    if AOp.QualidadeAudio > hi then AOp.QualidadeAudio := hi;
  end
  else
    AOp.QualidadeAudio := 0;

  if (AOp.ProfileProRes < 0) or (AOp.ProfileProRes > 4) then
    AOp.ProfileProRes := 2;
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
  const AOp: TDownloadOpcoes): string;
begin
  if AOp.EscolhaNome = enDefinido then
    Result := SemAcento(AOp.Nome)
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
  Result := IncludeTrailingPathDelimiter(PastaTemporaria(AOp)) +
            NomeBase(AOp) + '.' + ExtensaoIntermediaria;
end;

class function TGerenciadorDownload.CaminhoFinal(
  const AOp: TDownloadOpcoes): string;
var
  ext: string;
begin
  ext := ExtensaoFinal(AOp);
  { No metodo simples o container escolhido pode ser diferente do que o
    site ofereceu; nesse caso o --remux-video faz o renome. }
  Result := IncludeTrailingPathDelimiter(AOp.Pasta) + NomeBase(AOp) + '.' + ext;
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
    Result.Add(IncludeTrailingPathDelimiter(PastaTemporaria(AOp)) +
               NomeBase(AOp) + '.%(ext)s');
  end
  else
  begin
    { Metodo simples: um formato so, direto para a pasta do usuario. }
    Result.Add('-P');
    Result.Add(AOp.Pasta);
    Result.Add('-o');
    if AOp.EscolhaNome = enDefinido then
      Result.Add(SemAcento(AOp.Nome) + '.%(ext)s')
    else
      Result.Add('%(title)s.%(ext)s');

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

    Result := StringReplace(partes.Text, #10, ',', [rfReplaceAll]);
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
  case TGerenciadorCatalogo.ControleVideo(AOp.CodecVideo) of
    cvCRF:
      begin
        Result := 'CRF ' + IntToStr(v);
        if TGerenciadorCatalogo.MenorMelhorVideo(AOp.CodecVideo) then
          Result := Result + ' (menor e melhor)'
        else
          Result := Result + ' (menor e melhor)';
      end;
    cvQScale:      Result := 'qscale ' + IntToStr(v) + ' (menor e melhor)';
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
