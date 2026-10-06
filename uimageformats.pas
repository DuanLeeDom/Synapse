unit uImageFormats;

{ uImageFormats

  Catalogo dos formatos de imagem e montagem dos argumentos do ImageMagick.

  O catalogo e uma lista de registros. Para adicionar um formato novo basta
  acrescentar uma linha em CATALOGO e mais nada: a lista da interface, a
  validacao de capacidade e a montagem dos argumentos leem todos a mesma
  fonte.

  O catalogo cobre os formatos que o ImageMagick consegue GRAVAR. A lista de
  entrada e maior que a de saida, porque muito formato serve para ler e nao
  para gravar, e o inverso tambem acontece: existem formatos que ele escreve
  e nao le.

  Qual ImageMagick esta instalado varia de maquina para maquina. Um build sem
  a biblioteca HEIC, por exemplo, simplesmente nao conhece o formato. Por isso
  o catalogo aqui e a lista completa do ImageMagick, e a classe
  TGerenciadorFormatos consulta o proprio executavel instalado
  ("magick -list format") para saber o que ele de fato consegue gravar. O que
  nao existe na maquina do usuario aparece marcado na interface em vez de
  falhar na hora de converter.

  Cada formato declara quais recursos aceita por um conjunto de marcas. E
  isso que permite a interface esconder ou marcar como inativo uma opcao
  que nao faz sentido - por exemplo, JPEG nao tem transparencia, entao o
  controle correspondente aparece desabilitado em vez de existir e ser
  ignorado em silencio.

  Os nomes das opcoes seguem a nomenclatura do proprio ImageMagick, para
  que a correspondencia com a documentacao oficial seja direta. }

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Graphics;

type
  { Recursos que um formato pode ou nao aceitar. }
  TRecursoFormato = (rfQualidade, rfCompressao, rfRedimensionar, rfAlpha,
                     rfTransparencia, rfCores, rfAnimacao, rfProgressivo,
                     rfMultiPagina, rfPerdaTotal, rfCamadas, rfLinear);

  { Se o ImageMagick instalado consegue gravar o formato. }
  TDisponibilidadeFormato = (dfDesconhecido, dfDisponivel, dfIndisponivel);

  { Descricao de um formato de saida. }
  TFormatoImagem = record
    Chave      : string;   { 'png' - extensao e chave de configuracao }
    Rotulo     : string;   { 'PNG' - como aparece na interface }
    Grupo      : string;   { 'Sem perda', 'Com perda', 'Vetorial' }
    Observacao : string;   { aviso curto para a interface }
    Recursos   : set of TRecursoFormato;
  end;

  { Opcoes de conversao de um item.

    Os valores sentinela -1 e 0 significam "nao mexer": -1 em qualidade
    significa nao passar -quality, e 0 em largura ou altura significa
    manter a dimensao original. A distincao importa porque o ImageMagick
    trata zero como dimensao invalida, e nao como "manter". }
  TOpcoesConversao = record
    Qualidade       : Integer;   { 0..100, ou -1 para nao enviar }
    Compressao      : Integer;   { 0..9, ou -1 para nao enviar }
    Redimensionar   : Boolean;
    Largura         : Integer;   { 0 = manter }
    Altura          : Integer;   { 0 = manter }
    ManterProporcao : Boolean;
    AplicarAlpha    : Boolean;   { False remove o canal alfa }
    CorFundo        : TColor;    { usado ao remover alpha }
    ReduzirCores    : Integer;   { 0 = manter }
    RemoverMetadados: Boolean;
    Progressivo     : Boolean;
    SemPerda        : Boolean;
  end;

  TGerenciadorFormatos = class
  public
    { Todas as chaves, na ordem em que devem aparecer na interface. }
    class function Todas: TStrings;

    { Preenche um TStrings com Rotulo = Chave, para uso em TComboBox. }
    class procedure PreencherCombo(ACombo: TStrings);

    { Como PreencherCombo, mas com um cabecalho de grupo antes de cada bloco
      e uma lista paralela de chaves. O indice do combo e o mesmo indice da
      lista de chaves, e o cabecalho tem chave vazia: quem usa salta o
      cabecalho em vez de tentar converter para um formato que nao existe. }
    class procedure PreencherComboAgrupado(AItems, AChaves: TStrings);

    class function Info(const AChave: string): TFormatoImagem;
    class function Existe(const AChave: string): Boolean;
    class function Suporta(const AChave: string;
      ARecurso: TRecursoFormato): Boolean;
    class function RotuloDe(const AChave: string): string;
    class function ObservacaoDe(const AChave: string): string;
    class function GrupoDe(const AChave: string): string;

    { Nome do grupo com o sufixo de espaco reservado, para o cabecalho do
      combo. Ex.: '--- Sem perda ---'. }
    class function CabecalhoDeGrupo(const AGrupo: string): string;

    { Normaliza qualquer escrita para a chave do catalogo: 'JPG' vira
      'jpeg', '.PNG' vira 'png'. Devolve '' quando nao reconhece. }
    class function ChaveNormalizada(const AExtensao: string): string;

    { Aceita tanto a chave quanto o rotulo, porque a interface trabalha com
      rotulo e a configuracao salva em disco, com chave. }
    class function ChaveDe(const ATexto: string): string;

    { True quando faz sentido usar o formato como entrada de um conversor
      que rasteriza. Formato de texto e amostra bruta nao servem: os dois
      precisam de argumentos extras para fazer sentido. }
    class function EntradaSuportada(const AChave: string): Boolean;

    { True quando o arquivo tem extensao de imagem conhecida. }
    class function EhEntradaDeImagem(const AArquivo: string): Boolean;

    { Extensao que o ImageMagick deve usar no arquivo de saida. }
    class function ExtensaoDe(const AChave: string): string;

    { Prefixo de formato para a linha de comando, no formato 'tag:'.
      E o que garante a gravacao em formatos exoticos cujo nome de arquivo
      nao identifica o formato, como 'jpt' ou 'j2c'. }
    class function PrefixoDe(const AChave: string): string;

    { Consulta "magick -list format" uma vez e guarda o que da para gravar.
      Devolve False quando o ImageMagick nao foi encontrado ou nao respondeu,
      caso em que nada e marcado como indisponivel. }
    class function AtualizarDisponibilidade: Boolean;

    { Estado de um formato na maquina. dfDesconhecido significa que a
      consulta ainda nao aconteceu, e nesse caso o formato e considerado
      utilizavel: e melhor tentar do que esconder a opcao sem motivo. }
    class function Disponivel(const AChave: string): TDisponibilidadeFormato;

    { Monta os argumentos de conversao. NAO inclui o executavel nem o
      caminho de origem e destino: quem chama monta a linha completa, para
      que a ordem de leitura siga a ordem de execucao. }
    class function ArgumentosConversao(const AExtensaoDestino: string;
      const AOpcoes: TOpcoesConversao): TStringList;

    class function OpcoesPadrao: TOpcoesConversao;
    class function CopiarOpcoes(const AOpcoes: TOpcoesConversao): TOpcoesConversao;
  end;

implementation

uses
  uDependencias, uProcessos;

const
  { Compressao do EXR: indice = nivel de compressao escolhido pelo usuario. }
  EXR_COMPRESSAO: array[0..9] of string = (
    'NONE', 'NONE', 'RLE', 'RLE', 'RLE', 'ZIPS', 'ZIP', 'ZIP', 'PIZ', 'PIZ');

  { Conjuntos de recursos reutilizados. Escreve-los uma vez aqui deixa a
    tabela legivel e evita o erro copiar uma marca e esquecer outra. }
  NADA = [];
  SO_REDIM = [rfRedimensionar];
  REDIM_ALFA =
                 [rfRedimensionar, rfAlpha, rfTransparencia];
  COM_PERDA =
                 [rfQualidade, rfRedimensionar, rfCores, rfProgressivo];
  WEB =
                 [rfQualidade, rfRedimensionar, rfAlpha, rfTransparencia,
                  rfCores, rfAnimacao, rfPerdaTotal];
  PNG =
                 [rfQualidade, rfCompressao, rfRedimensionar, rfAlpha,
                  rfTransparencia, rfCores, rfAnimacao, rfPerdaTotal];
  TIFF =
                 [rfQualidade, rfCompressao, rfRedimensionar, rfAlpha,
                  rfTransparencia, rfCores, rfMultiPagina];
  CAMADAS =
                 [rfCompressao, rfRedimensionar, rfAlpha, rfTransparencia,
                  rfCores, rfCamadas, rfMultiPagina];
  HDR =
                 [rfCompressao, rfRedimensionar, rfAlpha, rfTransparencia,
                  rfLinear];
  DOCUMENTO =
                 [rfQualidade, rfRedimensionar, rfAlpha, rfTransparencia,
                  rfCores, rfMultiPagina];
  VETORIAL =
                 [rfRedimensionar, rfCompressao, rfAlpha, rfTransparencia];
  BRUTO =
                 [rfRedimensionar, rfLinear];

  { Grupos. Nomes curtos porque aparecem num rotulo estreito. }
  G_SEMPERDA = 'Sem perda';
  G_COMPERDA = 'Com perda';
  G_CAMADAS  = 'Camadas';
  G_DOCUMENTO= 'Documento';
  G_VETORIAL = 'Vetorial';
  G_CINEMA   = 'Cinema e HDR';
  G_TEXTURA  = 'Texturas e 3D';
  G_CIENTIF  = 'Cientifico';
  G_FAX      = 'Fax';
  G_BRUTO    = 'Amostras brutas';
  G_TEXTO    = 'Texto';
  G_LEGADO   = 'Legado';

  { Cada entrada e um formato que o ImageMagick consegue GRAVAR a partir de
    uma imagem raster comum. Dois formatos da documentacao oficial ficaram de
    fora de proposito, e os dois foram testados com o executavel:

      JPT - o 'magick -list format' anuncia 'rw-', mas qualquer gravacao
            falha em error/jp2.c/WriteJP2Image. JP2, J2K, J2C, JPX, JPF e
            JPM gravam normalmente, entao e defeito do proprio ImageMagick.

      MVG - e um formato de comandos de desenho, nao de imagem. O gravador
            rejeita raster com 'no image vector graphics'. MSVG, que e o
            mesmo desenho renderizado, continua na lista.

    Formato que o usuario escolheria e receberia erro e pior do que formato
    que nunca aparece. }
  CATALOGO: array[0..141] of TFormatoImagem = (
    { ---------- Sem perda ---------- }
    (Chave: 'png'; Rotulo: 'PNG'; Grupo: G_SEMPERDA;
     Observacao: 'Padrao da web; alpha de verdade, ate 16 bits por canal';
     Recursos: PNG),
    (Chave: 'png00'; Rotulo: 'PNG00'; Grupo: G_SEMPERDA;
     Observacao: 'PNG que herda profundidade e tipo de cor da original';
     Recursos: PNG),
    (Chave: 'png32'; Rotulo: 'PNG32'; Grupo: G_SEMPERDA;
     Observacao: 'PNG RGBA de 32 bits, com ou sem transparencia';
     Recursos: PNG),
    (Chave: 'png24'; Rotulo: 'PNG24'; Grupo: G_SEMPERDA;
     Observacao: 'PNG RGB opaco de 24 bits';
     Recursos: PNG),
    (Chave: 'png8'; Rotulo: 'PNG8'; Grupo: G_SEMPERDA;
     Observacao: 'PNG indexado de 8 bits, no maximo 256 cores';
     Recursos: PNG),
    (Chave: 'png48'; Rotulo: 'PNG48'; Grupo: G_SEMPERDA;
     Observacao: 'PNG RGB de 48 bits, 16 por canal';
     Recursos: PNG),
    (Chave: 'png64'; Rotulo: 'PNG64'; Grupo: G_SEMPERDA;
     Observacao: 'PNG RGBA de 64 bits, 16 por canal';
     Recursos: PNG),
    (Chave: 'qoi'; Rotulo: 'QOI'; Grupo: G_SEMPERDA;
     Observacao: 'Muito rapido, sem perda, com alpha intacto';
     Recursos: [rfQualidade, rfRedimensionar, rfAlpha, rfTransparencia,
                rfPerdaTotal]),
    (Chave: 'tiff'; Rotulo: 'TIFF'; Grupo: G_SEMPERDA;
     Observacao: 'Paginas multiplas, ate 32 bits e varios compressores';
     Recursos: TIFF),
    (Chave: 'tiff64'; Rotulo: 'TIFF64'; Grupo: G_SEMPERDA;
     Observacao: 'TIFF com inteiros de 64 bits, para dados grandes';
     Recursos: TIFF),
    (Chave: 'ptif'; Rotulo: 'TIFF piramidal'; Grupo: G_SEMPERDA;
     Observacao: 'TIFF com varias copias em resolucoes menores';
     Recursos: TIFF),
    (Chave: 'apng'; Rotulo: 'APNG'; Grupo: G_SEMPERDA;
     Observacao: 'PNG animado; sem perda e com canal alfa';
     Recursos: PNG),
    (Chave: 'mng'; Rotulo: 'MNG'; Grupo: G_SEMPERDA;
     Observacao: 'Varias imagens em um PNG; base do APNG';
     Recursos: PNG),
    (Chave: 'jng'; Rotulo: 'JNG'; Grupo: G_SEMPERDA;
     Observacao: 'JPEG dentro de um container PNG transparente';
     Recursos: PNG),
    (Chave: 'bmp'; Rotulo: 'BMP'; Grupo: G_SEMPERDA;
     Observacao: 'Bitmap do Windows, versao 4; sem compressao nem alpha';
     Recursos: SO_REDIM),
    (Chave: 'bmp3'; Rotulo: 'BMP3'; Grupo: G_SEMPERDA;
     Observacao: 'Bitmap do Windows, versao 3, lido por todo mundo';
     Recursos: SO_REDIM),
    (Chave: 'bmp2'; Rotulo: 'BMP2'; Grupo: G_SEMPERDA;
     Observacao: 'Bitmap do Windows, versao 2, a mais antiga';
     Recursos: SO_REDIM),
    (Chave: 'dib'; Rotulo: 'DIB'; Grupo: G_SEMPERDA;
     Observacao: 'BMP sem o cabecalho, para embutir em outros formatos';
     Recursos: SO_REDIM),
    (Chave: 'tga'; Rotulo: 'TGA'; Grupo: G_SEMPERDA;
     Observacao: 'Truevision Targa; usada em texturas 3D';
     Recursos: REDIM_ALFA),
    (Chave: 'icb'; Rotulo: 'ICB'; Grupo: G_SEMPERDA;
     Observacao: 'Variante antiga do Targa';
     Recursos: REDIM_ALFA),
    (Chave: 'vda'; Rotulo: 'VDA'; Grupo: G_SEMPERDA;
     Observacao: 'Variante do Targa para video';
     Recursos: REDIM_ALFA),
    (Chave: 'vst'; Rotulo: 'VST'; Grupo: G_SEMPERDA;
     Observacao: 'Variante do Targa';
     Recursos: REDIM_ALFA),
    (Chave: 'ico'; Rotulo: 'ICO'; Grupo: G_SEMPERDA;
     Observacao: 'Icone do Windows com varios tamanhos no mesmo arquivo';
     Recursos: [rfRedimensionar, rfAlpha, rfTransparencia, rfMultiPagina]),
    (Chave: 'cur'; Rotulo: 'CUR'; Grupo: G_SEMPERDA;
     Observacao: 'Cursor do Windows, como o ICO';
     Recursos: [rfRedimensionar, rfAlpha, rfTransparencia, rfMultiPagina]),
    (Chave: 'icon'; Rotulo: 'ICON'; Grupo: G_SEMPERDA;
     Observacao: 'Nome alternativo do formato ICO';
     Recursos: [rfRedimensionar, rfAlpha, rfTransparencia, rfMultiPagina]),
    (Chave: 'farbfeld'; Rotulo: 'Farbfeld'; Grupo: G_SEMPERDA;
     Observacao: 'Sem perda, 16 bits por canal; simples e rapido';
     Recursos: [rfRedimensionar, rfAlpha, rfTransparencia, rfPerdaTotal]),
    (Chave: 'ff'; Rotulo: 'FF'; Grupo: G_SEMPERDA;
     Observacao: 'Nome curto do Farbfeld';
     Recursos: [rfRedimensionar, rfAlpha, rfTransparencia, rfPerdaTotal]),
    (Chave: 'pcx'; Rotulo: 'PCX'; Grupo: G_SEMPERDA;
     Observacao: 'ZSoft Paintbrush; o primeiro formato de disquete';
     Recursos: REDIM_ALFA),
    (Chave: 'dcx'; Rotulo: 'DCX'; Grupo: G_SEMPERDA;
     Observacao: 'PCX com varias paginas no mesmo arquivo';
     Recursos: REDIM_ALFA),
    (Chave: 'sgi'; Rotulo: 'SGI'; Grupo: G_SEMPERDA;
     Observacao: 'Irix RGB, ainda comum em efeitos';
     Recursos: REDIM_ALFA),
    (Chave: 'sun'; Rotulo: 'SUN'; Grupo: G_SEMPERDA;
     Observacao: 'SUN Rasterfile, dos anos 90';
     Recursos: REDIM_ALFA),
    (Chave: 'ras'; Rotulo: 'RAS'; Grupo: G_SEMPERDA;
     Observacao: 'Rasterfile do SunOS';
     Recursos: REDIM_ALFA),
    (Chave: 'viff'; Rotulo: 'VIFF'; Grupo: G_SEMPERDA;
     Observacao: 'Khoros Visualization, da epoca do SGI';
     Recursos: SO_REDIM),
    (Chave: 'xv'; Rotulo: 'XV'; Grupo: G_SEMPERDA;
     Observacao: 'Formato de thumbnails do Xv';
     Recursos: SO_REDIM),
    (Chave: 'miff'; Rotulo: 'MIFF'; Grupo: G_SEMPERDA;
     Observacao: 'Formato nativo do ImageMagick; guarda todos os metadados';
     Recursos: [rfRedimensionar, rfAlpha, rfTransparencia, rfCores,
                rfAnimacao, rfMultiPagina, rfCamadas, rfLinear]),
    (Chave: 'mpc'; Rotulo: 'MPC'; Grupo: G_SEMPERDA;
     Observacao: 'Cache de pixels do ImageMagick; gera um .cache junto';
     Recursos: [rfRedimensionar, rfAlpha, rfTransparencia, rfCores,
                rfAnimacao, rfMultiPagina, rfCamadas, rfLinear]),

    { ---------- Com perda ---------- }
    (Chave: 'jpeg'; Rotulo: 'JPEG'; Grupo: G_COMPERDA;
     Observacao: 'Universal; sem transparencia, com subamostragem 4:2:0';
     Recursos: COM_PERDA),
    (Chave: 'jpg'; Rotulo: 'JPG'; Grupo: G_COMPERDA;
     Observacao: 'Extensao alternativa do JPEG';
     Recursos: COM_PERDA),
    (Chave: 'jpe'; Rotulo: 'JPE'; Grupo: G_COMPERDA;
     Observacao: 'Extensao antiga do JPEG';
     Recursos: COM_PERDA),
    (Chave: 'pjpeg'; Rotulo: 'PJPEG'; Grupo: G_COMPERDA;
     Observacao: 'JPEG com cabecalho progressivo marcado';
     Recursos: COM_PERDA),
    (Chave: 'jps'; Rotulo: 'JPS'; Grupo: G_COMPERDA;
     Observacao: 'JPEG para fluxos de impressao';
     Recursos: COM_PERDA),
    (Chave: 'webp'; Rotulo: 'WebP'; Grupo: G_COMPERDA;
     Observacao: 'Leve, com alpha e animado; bom para previa';
     Recursos: WEB),
    (Chave: 'avif'; Rotulo: 'AVIF'; Grupo: G_COMPERDA;
     Observacao: 'Compressao forte; guarda alpha e varios quadros';
     Recursos: WEB),
    (Chave: 'heic'; Rotulo: 'HEIC'; Grupo: G_COMPERDA;
     Observacao: 'Formato de camera; qualidade 100 grava sem perda';
     Recursos: WEB),
    (Chave: 'jxl'; Rotulo: 'JPEG XL'; Grupo: G_COMPERDA;
     Observacao: 'Sucessor do JPEG, com alpha, animado e sem perda';
     Recursos: WEB),
    (Chave: 'gif'; Rotulo: 'GIF'; Grupo: G_COMPERDA;
     Observacao: 'Ate 256 cores; transparencia de 1 bit e animacao';
     Recursos: [rfQualidade, rfRedimensionar, rfAlpha, rfTransparencia,
                rfCores, rfAnimacao]),
    (Chave: 'gif87'; Rotulo: 'GIF87'; Grupo: G_COMPERDA;
     Observacao: 'A versao antiga do GIF, de 1987';
     Recursos: [rfQualidade, rfRedimensionar, rfAlpha, rfTransparencia,
                rfCores, rfAnimacao]),
    (Chave: 'jp2'; Rotulo: 'JPEG 2000'; Grupo: G_COMPERDA;
     Observacao: 'Qualidade 100 grava sem perda; bom para masters';
     Recursos: [rfQualidade, rfRedimensionar, rfAlpha, rfTransparencia,
                rfCores]),
    (Chave: 'jpm'; Rotulo: 'JPM'; Grupo: G_COMPERDA;
     Observacao: 'JPEG 2000 com varias paginas';
     Recursos: [rfQualidade, rfRedimensionar, rfAlpha, rfTransparencia,
                rfCores, rfMultiPagina]),
    (Chave: 'j2k'; Rotulo: 'J2K'; Grupo: G_COMPERDA;
     Observacao: 'Fluxo de codigo do JPEG 2000';
     Recursos: [rfQualidade, rfRedimensionar, rfAlpha, rfTransparencia,
                rfCores]),
    (Chave: 'j2c'; Rotulo: 'J2C'; Grupo: G_COMPERDA;
     Observacao: 'Fluxo de codigo do JPEG 2000';
     Recursos: [rfQualidade, rfRedimensionar, rfAlpha, rfTransparencia,
                rfCores]),

    { ---------- Camadas ---------- }
    (Chave: 'psd'; Rotulo: 'Photoshop'; Grupo: G_CAMADAS;
     Observacao: 'Preserva camadas, para editar depois';
     Recursos: CAMADAS),
    (Chave: 'psb'; Rotulo: 'Photoshop grande'; Grupo: G_CAMADAS;
     Observacao: 'O PSD para arquivos acima de 2 GB';
     Recursos: CAMADAS),

    { ---------- Documento ---------- }
    (Chave: 'pdf'; Rotulo: 'PDF'; Grupo: G_DOCUMENTO;
     Observacao: 'Documento com miniatura embutida';
     Recursos: DOCUMENTO),
    (Chave: 'pdfa'; Rotulo: 'PDF/A'; Grupo: G_DOCUMENTO;
     Observacao: 'PDF de arquivo, para guardar por muito tempo';
     Recursos: DOCUMENTO),
    (Chave: 'ps'; Rotulo: 'PostScript'; Grupo: G_DOCUMENTO;
     Observacao: 'PostScript com varias paginas';
     Recursos: DOCUMENTO),
    (Chave: 'ps2'; Rotulo: 'PostScript L2'; Grupo: G_DOCUMENTO;
     Observacao: 'PostScript nivel II';
     Recursos: DOCUMENTO),
    (Chave: 'ps3'; Rotulo: 'PostScript L3'; Grupo: G_DOCUMENTO;
     Observacao: 'PostScript nivel III, com compressao';
     Recursos: DOCUMENTO),
    (Chave: 'eps'; Rotulo: 'EPS'; Grupo: G_DOCUMENTO;
     Observacao: 'EPS com miniatura; precisa de Ghostscript para ler';
     Recursos: DOCUMENTO),
    (Chave: 'epsf'; Rotulo: 'EPSF'; Grupo: G_DOCUMENTO;
     Observacao: 'Encapsulated PostScript, o EPS classico';
     Recursos: DOCUMENTO),
    (Chave: 'epsi'; Rotulo: 'EPSI'; Grupo: G_DOCUMENTO;
     Observacao: 'EPS com preview em EPS proprio';
     Recursos: DOCUMENTO),
    (Chave: 'eps2'; Rotulo: 'EPS L2'; Grupo: G_DOCUMENTO;
     Observacao: 'EPS nivel II';
     Recursos: DOCUMENTO),
    (Chave: 'eps3'; Rotulo: 'EPS L3'; Grupo: G_DOCUMENTO;
     Observacao: 'EPS nivel III';
     Recursos: DOCUMENTO),
    (Chave: 'ept'; Rotulo: 'EPT'; Grupo: G_DOCUMENTO;
     Observacao: 'EPS com previa em TIFF';
     Recursos: DOCUMENTO),
    (Chave: 'ept2'; Rotulo: 'EPT L2'; Grupo: G_DOCUMENTO;
     Observacao: 'EPS nivel II com previa em TIFF';
     Recursos: DOCUMENTO),
    (Chave: 'ept3'; Rotulo: 'EPT L3'; Grupo: G_DOCUMENTO;
     Observacao: 'EPS nivel III com previa em TIFF';
     Recursos: DOCUMENTO),
    (Chave: 'epdf'; Rotulo: 'EPDF'; Grupo: G_DOCUMENTO;
     Observacao: 'PDF encapsulado, para paginas isoladas';
     Recursos: DOCUMENTO),
    (Chave: 'ai'; Rotulo: 'Illustrator'; Grupo: G_DOCUMENTO;
     Observacao: 'Adobe Illustrator, na pratica um PDF';
     Recursos: DOCUMENTO),
    (Chave: 'pocketmod'; Rotulo: 'PocketMod'; Grupo: G_DOCUMENTO;
     Observacao: 'PDF para sorteadores de bolso';
     Recursos: DOCUMENTO),

    { ---------- Vetorial ---------- }
    (Chave: 'svg'; Rotulo: 'SVG'; Grupo: G_VETORIAL;
     Observacao: 'Vetorial; a leitura depende de Inkscape, rsvg ou interno';
     Recursos: VETORIAL),
    (Chave: 'svgz'; Rotulo: 'SVGZ'; Grupo: G_VETORIAL;
     Observacao: 'SVG comprimido com gzip';
     Recursos: VETORIAL),
    (Chave: 'msvg'; Rotulo: 'MSVG'; Grupo: G_VETORIAL;
     Observacao: 'SVG pelo renderizador interno do ImageMagick';
     Recursos: VETORIAL),

    { ---------- Cinema e HDR ---------- }
    (Chave: 'exr'; Rotulo: 'OpenEXR'; Grupo: G_CINEMA;
     Observacao: 'Float linear, com varios compactadores';
     Recursos: HDR),
    (Chave: 'dpx'; Rotulo: 'DPX'; Grupo: G_CINEMA;
     Observacao: 'SMPTE 268M, o formato das cameras de cinema';
     Recursos: HDR),
    (Chave: 'cin'; Rotulo: 'Cineon'; Grupo: G_CINEMA;
     Observacao: 'Kodak Cineon, antes do DPX';
     Recursos: HDR),
    (Chave: 'fl32'; Rotulo: 'FL32'; Grupo: G_CINEMA;
     Observacao: 'Float de ponto flutuante da FilmLight';
     Recursos: HDR),
    (Chave: 'hdr'; Rotulo: 'Radiance'; Grupo: G_CINEMA;
     Observacao: 'HDR RGBE, de alto valor dinamico em texto';
     Recursos: [rfRedimensionar, rfAlpha, rfTransparencia, rfLinear]),

    { ---------- Texturas e 3D ---------- }
    (Chave: 'dds'; Rotulo: 'DDS'; Grupo: G_TEXTURA;
     Observacao: 'DirectDraw Surface, com compressao DXT1, DXT5 ou none';
     Recursos: [rfCompressao, rfRedimensionar, rfAlpha, rfTransparencia]),
    (Chave: 'dxt1'; Rotulo: 'DXT1'; Grupo: G_TEXTURA;
     Observacao: 'DDS comprimido com DXT1, sem alpha';
     Recursos: [rfCompressao, rfRedimensionar]),
    (Chave: 'dxt5'; Rotulo: 'DXT5'; Grupo: G_TEXTURA;
     Observacao: 'DDS comprimido com DXT5, com alpha';
     Recursos: [rfCompressao, rfRedimensionar, rfAlpha]),
    (Chave: 'sf3'; Rotulo: 'SF3'; Grupo: G_TEXTURA;
     Observacao: 'Simple File Format Family, feita para ser lida por codigo';
     Recursos: SO_REDIM),
    (Chave: 'vips'; Rotulo: 'VIPS'; Grupo: G_TEXTURA;
     Observacao: 'Formato da biblioteca VIPS, de processamento rapido';
     Recursos: SO_REDIM),
    (Chave: 'mat'; Rotulo: 'MATLAB'; Grupo: G_TEXTURA;
     Observacao: 'Nivel 5 do MATLAB, com variaveis e metadados';
     Recursos: SO_REDIM),

    { ---------- Cientifico ---------- }
    (Chave: 'fits'; Rotulo: 'FITS'; Grupo: G_CIENTIF;
     Observacao: 'Transporte de dados astronomicos, ponto flutuante';
     Recursos: [rfRedimensionar, rfLinear]),
    (Chave: 'fts'; Rotulo: 'FITS'; Grupo: G_CIENTIF;
     Observacao: 'Nome alternativo do FITS';
     Recursos: [rfRedimensionar, rfLinear]),
    (Chave: 'pfm'; Rotulo: 'PFM'; Grupo: G_CIENTIF;
     Observacao: 'Float portatil, usado em topografia';
     Recursos: BRUTO),
    (Chave: 'phm'; Rotulo: 'PHM'; Grupo: G_CIENTIF;
     Observacao: 'Float de meia precisao, 16 bits';
     Recursos: BRUTO),
    (Chave: 'pam'; Rotulo: 'PAM'; Grupo: G_CIENTIF;
     Observacao: 'Bitmap 2D com alpha e canais extras';
     Recursos: REDIM_ALFA),
    (Chave: 'pnm'; Rotulo: 'PNM'; Grupo: G_CIENTIF;
     Observacao: 'Escolhe sozinho entre PBM, PGM e PPM';
     Recursos: REDIM_ALFA),
    (Chave: 'pgm'; Rotulo: 'PGM'; Grupo: G_CIENTIF;
     Observacao: 'Mapa de tons de cinza portatil';
     Recursos: [rfRedimensionar, rfLinear]),
    (Chave: 'ppm'; Rotulo: 'PPM'; Grupo: G_CIENTIF;
     Observacao: 'Mapa de cores portatil, RGB simples';
     Recursos: REDIM_ALFA),
    (Chave: 'pbm'; Rotulo: 'PBM'; Grupo: G_CIENTIF;
     Observacao: 'Bitmap preto e branco, 1 bit por pixel';
     Recursos: SO_REDIM),

    { ---------- Fax ---------- }
    (Chave: 'fax'; Rotulo: 'FAX'; Grupo: G_FAX;
     Observacao: 'Group 3; a largura e fixa em 1728 pontos';
     Recursos: SO_REDIM),
    (Chave: 'g3'; Rotulo: 'G3'; Grupo: G_FAX;
     Observacao: 'Fax Group 3';
     Recursos: SO_REDIM),
    (Chave: 'g4'; Rotulo: 'G4'; Grupo: G_FAX;
     Observacao: 'Fax Group 4, sem compressao de linha morta';
     Recursos: SO_REDIM),
    (Chave: 'group4'; Rotulo: 'CCITT G4'; Grupo: G_FAX;
     Observacao: 'CCITT G4 dentro de TIFF, so preto e branco';
     Recursos: SO_REDIM),

    { ---------- Amostras brutas ---------- }
    (Chave: 'rgb'; Rotulo: 'RGB bruto'; Grupo: G_BRUTO;
     Observacao: 'Pixels crus, sem cabecalho; precisa de -size na leitura';
     Recursos: BRUTO),
    (Chave: 'rgba'; Rotulo: 'RGBA bruto'; Grupo: G_BRUTO;
     Observacao: 'Pixels crus RGB com alpha';
     Recursos: BRUTO),
    (Chave: 'rgbo'; Rotulo: 'RGBO bruto'; Grupo: G_BRUTO;
     Observacao: 'Pixels crus RGB com opacidade';
     Recursos: BRUTO),
    (Chave: 'bgr'; Rotulo: 'BGR bruto'; Grupo: G_BRUTO;
     Observacao: 'Pixels crus na ordem azul, verde, vermelho';
     Recursos: BRUTO),
    (Chave: 'bgra'; Rotulo: 'BGRA bruto'; Grupo: G_BRUTO;
     Observacao: 'Pixels crus BGR com alpha';
     Recursos: BRUTO),
    (Chave: 'bgro'; Rotulo: 'BGRO bruto'; Grupo: G_BRUTO;
     Observacao: 'Pixels crus BGR com opacidade';
     Recursos: BRUTO),
    (Chave: 'cmyk'; Rotulo: 'CMYK bruto'; Grupo: G_BRUTO;
     Observacao: 'Tinta quase pronta para impressao';
     Recursos: BRUTO),
    (Chave: 'cmyka'; Rotulo: 'CMYKA bruto'; Grupo: G_BRUTO;
     Observacao: 'CMYK com alpha';
     Recursos: BRUTO),
    (Chave: 'gray'; Rotulo: 'GRAY bruto'; Grupo: G_BRUTO;
     Observacao: 'Um canal por pixel, sem cor';
     Recursos: BRUTO),
    (Chave: 'graya'; Rotulo: 'GRAYA bruto'; Grupo: G_BRUTO;
     Observacao: 'Cinza com alpha';
     Recursos: BRUTO),
    (Chave: 'ycbcr'; Rotulo: 'YCbCr bruto'; Grupo: G_BRUTO;
     Observacao: 'Espaco de video, usado em transmissao';
     Recursos: BRUTO),
    (Chave: 'ycbcra'; Rotulo: 'YCbCrA bruto'; Grupo: G_BRUTO;
     Observacao: 'Espaco de video com alpha';
     Recursos: BRUTO),
    (Chave: 'yuv'; Rotulo: 'YUV bruto'; Grupo: G_BRUTO;
     Observacao: 'CCIR 601, com subamostragem 4:2:2';
     Recursos: BRUTO),
    (Chave: 'uyvy'; Rotulo: 'UYVY bruto'; Grupo: G_BRUTO;
     Observacao: 'YUV intercalado de 16 bits por pixel';
     Recursos: BRUTO),
    (Chave: 'pal'; Rotulo: 'PAL'; Grupo: G_BRUTO;
     Observacao: 'UYVY de 16 bits, para video';
     Recursos: BRUTO),
    (Chave: 'mono'; Rotulo: 'MONO'; Grupo: G_BRUTO;
     Observacao: 'Um bit por pixel, o menor formato que existe';
     Recursos: BRUTO),
    (Chave: 'map'; Rotulo: 'MAP'; Grupo: G_BRUTO;
     Observacao: 'Indices de cor e tabela de paleta';
     Recursos: BRUTO),

    { ---------- Texto ---------- }
    (Chave: 'txt'; Rotulo: 'TXT'; Grupo: G_TEXTO;
     Observacao: 'Cada pixel vira um numero em texto';
     Recursos: SO_REDIM),
    (Chave: 'ftxt'; Rotulo: 'FTXT'; Grupo: G_TEXTO;
     Observacao: 'Multispectral em texto formatado, com nome dos canais';
     Recursos: SO_REDIM),
    (Chave: 'brf'; Rotulo: 'BRF'; Grupo: G_TEXTO;
     Observacao: 'Braille ASCII de 6 pontos';
     Recursos: SO_REDIM),
    (Chave: 'isobrl'; Rotulo: 'ISOBRL'; Grupo: G_TEXTO;
     Observacao: 'Braille ISO/TR 11548 de 8 pontos';
     Recursos: SO_REDIM),
    (Chave: 'isobrl6'; Rotulo: 'ISOBRL6'; Grupo: G_TEXTO;
     Observacao: 'Braille ISO/TR 11548 de 6 pontos';
     Recursos: SO_REDIM),
    (Chave: 'ubrl'; Rotulo: 'UBRL'; Grupo: G_TEXTO;
     Observacao: 'Braille em Unicode, 8 pontos';
     Recursos: SO_REDIM),
    (Chave: 'ubrl6'; Rotulo: 'UBRL6'; Grupo: G_TEXTO;
     Observacao: 'Braille em Unicode, 6 pontos';
     Recursos: SO_REDIM),

    { ---------- Legado ---------- }
    (Chave: 'art'; Rotulo: 'ART'; Grupo: G_LEGADO;
     Observacao: 'Clip art do Mac e do 1st Publisher';
     Recursos: REDIM_ALFA),
    (Chave: 'avs'; Rotulo: 'AVS'; Grupo: G_LEGADO;
     Observacao: 'Formato de imagem do AVS';
     Recursos: REDIM_ALFA),
    (Chave: 'sixel'; Rotulo: 'SIXEL'; Grupo: G_LEGADO;
     Observacao: 'SIXEL dos terminais DEC, dos anos 80';
     Recursos: SO_REDIM),
    (Chave: 'six'; Rotulo: 'SIX'; Grupo: G_LEGADO;
     Observacao: 'Nome curto do SIXEL';
     Recursos: SO_REDIM),
    (Chave: 'xbm'; Rotulo: 'XBM'; Grupo: G_LEGADO;
     Observacao: 'Bitmap do X Window, so preto e branco e em texto C';
     Recursos: SO_REDIM),
    (Chave: 'xpm'; Rotulo: 'XPM'; Grupo: G_LEGADO;
     Observacao: 'Pixmap do X Window, em texto, com alpha opcional';
     Recursos: REDIM_ALFA),
    (Chave: 'picon'; Rotulo: 'PICON'; Grupo: G_LEGADO;
     Observacao: 'Icone pessoal, do NeXT ao Mac';
     Recursos: REDIM_ALFA),
    (Chave: 'pcd'; Rotulo: 'Photo CD'; Grupo: G_LEGADO;
     Observacao: 'Photo CD; a escrita para no tamanho 768x512';
     Recursos: SO_REDIM),
    (Chave: 'pcds'; Rotulo: 'Photo CD sRGB'; Grupo: G_LEGADO;
     Observacao: 'Photo CD com as tabelas de cor do sRGB';
     Recursos: SO_REDIM),
    (Chave: 'wpg'; Rotulo: 'WPG'; Grupo: G_LEGADO;
     Observacao: 'WordPerfect Graphics, muito antigo';
     Recursos: SO_REDIM),
    (Chave: 'pict'; Rotulo: 'PICT'; Grupo: G_LEGADO;
     Observacao: 'QuickDraw do Macintosh, com alpha';
     Recursos: REDIM_ALFA),
    (Chave: 'pct'; Rotulo: 'PCT'; Grupo: G_LEGADO;
     Observacao: 'PICT do Macintosh, em arquivo separado';
     Recursos: REDIM_ALFA),
    (Chave: 'cal'; Rotulo: 'CAL'; Grupo: G_LEGADO;
     Observacao: 'CALS tipo 1, para plantas tecnicas';
     Recursos: SO_REDIM),
    (Chave: 'cals'; Rotulo: 'CALS'; Grupo: G_LEGADO;
     Observacao: 'CALS tipo 1, com o nome completo do padrao';
     Recursos: SO_REDIM),
    (Chave: 'otb'; Rotulo: 'OTB'; Grupo: G_LEGADO;
     Observacao: 'On-the-air bitmap, da transmissao de TV';
     Recursos: SO_REDIM),
    (Chave: 'rgf'; Rotulo: 'RGF'; Grupo: G_LEGADO;
     Observacao: 'LEGO Mindstorms EV3, so preto e branco';
     Recursos: SO_REDIM),
    (Chave: 'aai'; Rotulo: 'AAI'; Grupo: G_LEGADO;
     Observacao: 'AAI Dune, formato CAD antigo';
     Recursos: REDIM_ALFA),
    (Chave: 'palm'; Rotulo: 'Palm'; Grupo: G_LEGADO;
     Observacao: 'Pixmap do Palm OS, dos primeiros pocket PC';
     Recursos: REDIM_ALFA),
    (Chave: 'pdb'; Rotulo: 'PDB'; Grupo: G_LEGADO;
     Observacao: 'Banco de imagens do Palm OS';
     Recursos: SO_REDIM),
    (Chave: 'vicar'; Rotulo: 'VICAR'; Grupo: G_LEGADO;
     Observacao: 'Raster da NASA, usado em missao espacial';
     Recursos: SO_REDIM),
    (Chave: 'hrz'; Rotulo: 'HRZ'; Grupo: G_LEGADO;
     Observacao: 'Slow Scan TV, 256 por 240 em tons de cinza';
     Recursos: SO_REDIM),
    (Chave: 'wbmp'; Rotulo: 'WBMP'; Grupo: G_LEGADO;
     Observacao: 'Bitmap sem fio dos telefones antigos';
     Recursos: SO_REDIM)
  );

  { Extensoes de entrada reconhecidas como imagem que NAO fazem sentido
    como destino. Raw de camera entra por aqui porque depende de delegate
    para ler, e o resto cobre apelidos comuns de formatos que o catalogo
    nao lista. }
  ENTRADAS: array[0..18] of string = (
    'jfif', 'jif', 'jpz', 'jpx', 'jpf', 'tpic', 'cin', 'rs', 'sgi', 'sfw',
    'xwd', 'dcm', 'dic', 'otb', 'psb', 'ras', 'vicar', 'emf', 'wmf');

  { Raw de camera: aparece muito em material de edicao e precisa entrar
    na fila, mesmo que o ImageMagick depende de delegate para ler.

    'jpt' entra aqui e nao no catalogo de saida: o codigo JPEG 2000 le o
    arquivo normalmente, so a gravacao e que esta quebrada. }
  ENTRADAS_EXTRA: array[0..12] of string = (
    'cr2', 'cr3', 'crw', 'nef', 'arw', 'dng', 'orf', 'rw2', 'srw', 'raf',
    'pef', 'raw', 'jpt');

var
  { Cache da consulta ao ImageMagick instalado. Vazio significa "ainda nao
    consultou", e nesse caso nenhum formato e marcado como indisponivel. }
  FDisponiveis: TStringList = nil;
  FConsultado: Boolean = False;

function NormalizarChave(const A: string): string;
var
  i: Integer;
begin
  { Aceita as tres formas que aparecem no projeto: a chave crua do
    catalogo ('png'), uma extensao com ponto ('.PNG') e um caminho
    completo ('C:\pasta\FOTO.PNG'). Sem isso, uma consulta por 'jpeg'
    voltaria vazia e cairia no primeiro formato da lista por engano. }
  Result := ExtractFileName(LowerCase(Trim(A)));
  i := Pos('.', Result);
  if i > 0 then
    Result := Copy(Result, i + 1, Length(Result) - i);
  Result := Trim(Result);
end;

function ExtensaoDoArquivo(const AArquivo: string): string;
var
  C: string;
begin
  { Para arquivo a extensao e obrigatoria: um caminho sem ponto nao tem
    extensao e portanto nao identifica formato nenhum. }
  Result := '';
  C := ExtractFileName(LowerCase(Trim(AArquivo)));
  if Pos('.', C) = 0 then
    Exit;
  Result := NormalizarChave(C);
end;

{ O FPC nao tem conjunto de string, entao a busca de uma familia e feita
  sobre uma lista separada por barras. As barras nas pontas evitam que
  'jpe' case com 'jpeg'. }
function EstaNaLista(const AChave, ALista: string): Boolean;
begin
  Result := Pos('|' + AChave + '|', '|' + ALista + '|') > 0;
end;

{ Pertence a familia JPEG, que compartilha os mesmos parametros. }
function EhFamiliaJPEG(const AChave: string): Boolean;
begin
  Result := EstaNaLista(AChave, 'jpeg|jpg|jpe|pjpe|pjpeg|jps');
end;

{ Pertence a familia PNG, que divide as mesmas opcoes de compactacao. }
function EhFamiliaPNG(const AChave: string): Boolean;
begin
  Result := (AChave = 'png') or (Copy(AChave, 1, 4) = 'png0') or
            (Copy(AChave, 1, 4) = 'png2') or (Copy(AChave, 1, 4) = 'png3') or
            (Copy(AChave, 1, 4) = 'png4') or (Copy(AChave, 1, 4) = 'png6') or
            (Copy(AChave, 1, 4) = 'png8') or (AChave = 'apng') or
            (AChave = 'mng') or (AChave = 'jng');
end;

function EhFamiliaTIFF(const AChave: string): Boolean;
begin
  Result := EstaNaLista(AChave, 'tiff|tif|tiff64|ptif');
end;

function EhFamiliaJP2(const AChave: string): Boolean;
begin
  Result := EstaNaLista(AChave, 'jp2|jpf|jpx|jpm|jpt|j2k|j2c');
end;

function EhFamiliaIcone(const AChave: string): Boolean;
begin
  Result := EstaNaLista(AChave, 'ico|cur|icon');
end;

function IndiceNoCatalogo(const AChave: string): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := Low(CATALOGO) to High(CATALOGO) do
    if CATALOGO[i].Chave = AChave then
      Exit(i);
end;

{ Separa a primeira e a segunda palavra de uma linha. Devolve False quando
  a linha nao tem duas palavras. }
function SepararPrimeiraPalavra(const ALinha: string;
  out APrimeira, AResto: string): Boolean;
var
  i, N: Integer;
begin
  APrimeira := '';
  AResto := '';
  i := 1;
  N := Length(ALinha);
  while (i <= N) and (ALinha[i] <= ' ') do
    Inc(i);
  while (i <= N) and (ALinha[i] > ' ') do
  begin
    APrimeira := APrimeira + ALinha[i];
    Inc(i);
  end;
  if APrimeira = '' then
    Exit(False);
  while (i <= N) and (ALinha[i] <= ' ') do
    Inc(i);
  AResto := Copy(ALinha, i, N - i + 1);
  Result := AResto <> '';
end;

{ O modo do 'magick -list format' tem tres caracteres: leitura, escrita e
  multiplas imagens. Por exemplo 'rw+', 'rw-', 'r--' e '-w+'. }
function EhModoFormato(const A: string): Boolean;
begin
  Result := (Length(A) = 3) and
            ((A[1] = 'r') or (A[1] = 'R') or (A[1] = '-')) and
            ((A[2] = 'w') or (A[2] = 'W') or (A[2] = '-')) and
            ((A[3] = '+') or (A[3] = '-'));
end;

class function TGerenciadorFormatos.Todas: TStrings;
var
  i: Integer;
begin
  Result := TStringList.Create;
  for i := Low(CATALOGO) to High(CATALOGO) do
    Result.Add(CATALOGO[i].Chave);
end;

class procedure TGerenciadorFormatos.PreencherCombo(ACombo: TStrings);
var
  i: Integer;
begin
  ACombo.Clear;
  for i := Low(CATALOGO) to High(CATALOGO) do
    ACombo.Add(CATALOGO[i].Rotulo);
end;

class function TGerenciadorFormatos.CabecalhoDeGrupo(
  const AGrupo: string): string;
begin
  Result := '--- ' + AGrupo + ' ---';
end;

class procedure TGerenciadorFormatos.PreencherComboAgrupado(
  AItems, AChaves: TStrings);
var
  i: Integer;
  GrupoAtual, Sufixo: string;
begin
  AItems.Clear;
  AChaves.Clear;
  GrupoAtual := '';
  for i := Low(CATALOGO) to High(CATALOGO) do
  begin
    if CATALOGO[i].Grupo <> GrupoAtual then
    begin
      GrupoAtual := CATALOGO[i].Grupo;
      AItems.Add(CabecalhoDeGrupo(GrupoAtual));
      AChaves.Add('');
    end;
    Sufixo := '';
    if Disponivel(CATALOGO[i].Chave) = dfIndisponivel then
      Sufixo := '  (sem suporte)';
    AItems.Add(CATALOGO[i].Rotulo + Sufixo);
    AChaves.Add(CATALOGO[i].Chave);
  end;
end;

class function TGerenciadorFormatos.Info(const AChave: string): TFormatoImagem;
var
  i: Integer;
begin
  i := IndiceNoCatalogo(NormalizarChave(AChave));
  if i >= 0 then
    Exit(CATALOGO[i]);
  { Chave desconhecida nao e erro: devolve o primeiro formato, que e o
    mais seguro, e o aviso fica por conta da interface. }
  Result := CATALOGO[Low(CATALOGO)];
end;

class function TGerenciadorFormatos.Existe(const AChave: string): Boolean;
begin
  Result := IndiceNoCatalogo(NormalizarChave(AChave)) >= 0;
end;

class function TGerenciadorFormatos.Suporta(const AChave: string;
  ARecurso: TRecursoFormato): Boolean;
begin
  Result := ARecurso in Info(AChave).Recursos;
end;

class function TGerenciadorFormatos.RotuloDe(const AChave: string): string;
begin
  Result := Info(AChave).Rotulo;
end;

class function TGerenciadorFormatos.ObservacaoDe(
  const AChave: string): string;
begin
  Result := Info(AChave).Observacao;
end;

class function TGerenciadorFormatos.GrupoDe(const AChave: string): string;
begin
  Result := Info(AChave).Grupo;
end;

class function TGerenciadorFormatos.ChaveNormalizada(
  const AExtensao: string): string;
begin
  Result := NormalizarChave(AExtensao);
end;

class function TGerenciadorFormatos.ChaveDe(const ATexto: string): string;
var
  i: Integer;
  C: string;
begin
  { Primeiro a chave, que e o que vem do arquivo de configuracao. Depois o
    rotulo, que e o que aparece na interface e muda de TRADUCAO para
    TRADUCAO: comparar so os rotulos quebraria ao traduzir a interface. }
  C := NormalizarChave(ATexto);
  if Existe(C) then
    Exit(C);
  for i := Low(CATALOGO) to High(CATALOGO) do
    if CATALOGO[i].Rotulo = Trim(ATexto) then
      Exit(CATALOGO[i].Chave);
  Result := '';
end;

class function TGerenciadorFormatos.EntradaSuportada(
  const AChave: string): Boolean;
var
  G: string;
begin
  { Texto e amostra bruta nao servem de entrada: um .txt nao e uma imagem,
    e um .rgb sem -size e so um monte de bytes. Os dois ainda aparecem na
    lista de saida, que e onde eles fazem sentido. }
  G := LowerCase(GrupoDe(AChave));
  Result := (G <> LowerCase(G_TEXTO)) and (G <> LowerCase(G_BRUTO));
end;

class function TGerenciadorFormatos.EhEntradaDeImagem(
  const AArquivo: string): Boolean;
var
  i: Integer;
  C: string;
begin
  C := ExtensaoDoArquivo(AArquivo);
  Result := False;
  if C = '' then
    Exit;
  if Existe(C) and EntradaSuportada(C) then
    Exit(True);
  for i := Low(ENTRADAS) to High(ENTRADAS) do
    if ENTRADAS[i] = C then
      Exit(True);
  for i := Low(ENTRADAS_EXTRA) to High(ENTRADAS_EXTRA) do
    if ENTRADAS_EXTRA[i] = C then
      Exit(True);
  { Um formato que o ImageMagick instalado le mas que nao esta no catalogo
    continua sendo uma entrada valida. So vale quando a consulta ja
    aconteceu; sem ela, a lista acima e a unica fonte. }
  Result := (FDisponiveis <> nil) and (FDisponiveis.IndexOf(C) >= 0);
end;

class function TGerenciadorFormatos.ExtensaoDe(const AChave: string): string;
begin
  Result := NormalizarChave(AChave);
  if not Existe(Result) then
    Result := CATALOGO[Low(CATALOGO)].Chave;
end;

class function TGerenciadorFormatos.PrefixoDe(const AChave: string): string;
begin
  { Exemplo: 'jp2'. O prefixo nao substitui a extensao do arquivo, os dois
    vao juntos: o prefixo diz ao ImageMagick qual codificador usar e o
    nome mantem o arquivo reconhecivel por qualquer outro programa. }
  Result := NormalizarChave(AChave) + ':';
end;

class function TGerenciadorFormatos.AtualizarDisponibilidade: Boolean;
var
  Exe, Saida: string;
  Args: TStringList;
  Codigo: Integer;
  i, Ini: Integer;
  Linha, Tag, Modo, Palma, Resto: string;
begin
  Result := False;
  if FDisponiveis = nil then
    FDisponiveis := TStringList.Create
  else
    FDisponiveis.Clear;
  FDisponiveis.Sorted := True;
  FDisponiveis.Duplicates := dupIgnore;

  Exe := TGerenciadorDependencias.Caminho(depImageMagick);
  if Exe = '' then
  begin
    FConsultado := True;
    Exit(False);
  end;

  { A leitura vai por CapturarSaida, que drena o pipe enquanto o processo
    corre. Ler so depois do termino nao funciona aqui: o 'magick -list
    format' escreve quase 19 KB, o buffer do pipe do Windows tem 4 KB, e o
    processo filho trava escrevendo o resto enquanto o programa espera por
    ele. O resultado era uma lista de formatos truncada no meio, com PNG,
    JPEG e TIFF marcados como inexistentes. }
  Args := TStringList.Create;
  try
    Args.Add('-list');
    Args.Add('format');
    if not TGerenciadorProcessos.CapturarSaida(Exe, Args, 8000,
      Saida, Codigo) then
    begin
      FConsultado := True;
      Exit(False);
    end;
  finally
    Args.Free;
  end;

  { Cada linha tem formato:
        3FR  DNG       r--   Hasselblad CFV/H3D39II Raw Format
    O nome do formato e a primeira palavra, o asterisco de "nativo" fica
    grudado nela, e o modo vem em seguida. A coluna do modulo as vezes esta
    vazia, entao o modo e procurado em vez de assumed numa posicao fixa.

      O terceiro caractere do modo e o de multiplas imagens: 'rw+' e 'rw-'
      gravam os dois, e o sinal de menos so diz que o arquivo guarda uma
      imagem por vez. Exigir o '+' descartaria PNG, JPEG, BMP e boa parte
      dos formatos mais usados. }
  Saida := StringReplace(Saida, #13, #10, [rfReplaceAll]);
  i := 1;
  while i <= Length(Saida) do
  begin
    Ini := Pos(#10, Copy(Saida, i, Length(Saida) - i + 1));
    if Ini = 0 then
    begin
      Linha := Copy(Saida, i, Length(Saida) - i + 1);
      i := Length(Saida) + 1;
    end
    else
    begin
      Linha := Copy(Saida, i, Ini - 1);
      Inc(i, Ini);
    end;
    if not SepararPrimeiraPalavra(Linha, Tag, Palma) then
      Continue;
    { O asterisco marca os formatos nativos do proprio ImageMagick e nao
      faz parte do nome. }
    while (Tag <> '') and (Tag[Length(Tag)] = '*') do
      Delete(Tag, Length(Tag), 1);
    Tag := LowerCase(Tag);
    if (Tag = '') or (Tag[1] = '-') then
      Continue;
    Modo := '';
    while Palma <> '' do
    begin
      if not SepararPrimeiraPalavra(Palma, Modo, Resto) then
        Break;
      Palma := Resto;
      if EhModoFormato(Modo) then
      begin
        if Pos('w', LowerCase(Modo)) > 0 then
          FDisponiveis.Add(Tag);
        Break;
      end;
    end;
  end;

  FConsultado := True;
  Result := FDisponiveis.Count > 0;
end;

class function TGerenciadorFormatos.Disponivel(
  const AChave: string): TDisponibilidadeFormato;
var
  C: string;
begin
  if not FConsultado then
    Exit(dfDesconhecido);
  if not Existe(AChave) then
    Exit(dfDesconhecido);
  C := LowerCase(NormalizarChave(AChave));
  if FDisponiveis.IndexOf(C) >= 0 then
    Exit(dfDisponivel)
  else
    Exit(dfIndisponivel);
end;

class function TGerenciadorFormatos.OpcoesPadrao: TOpcoesConversao;
begin
  Result.Qualidade        := -1;
  Result.Compressao       := -1;
  Result.Redimensionar    := False;
  Result.Largura          := 0;
  Result.Altura           := 0;
  Result.ManterProporcao  := True;
  Result.AplicarAlpha     := True;
  Result.CorFundo         := clWhite;
  Result.ReduzirCores     := 0;
  Result.RemoverMetadados := False;
  Result.Progressivo      := False;
  Result.SemPerda         := False;
end;

class function TGerenciadorFormatos.CopiarOpcoes(
  const AOpcoes: TOpcoesConversao): TOpcoesConversao;
begin
  Result := AOpcoes;
end;

class function TGerenciadorFormatos.ArgumentosConversao(
  const AExtensaoDestino: string;
  const AOpcoes: TOpcoesConversao): TStringList;
var
  F: TFormatoImagem;
  Chave: string;
  CorHex: string;
begin
  Chave := NormalizarChave(AExtensaoDestino);
  F := Info(Chave);
  Result := TStringList.Create;

  { -write null: substitui a entrada em vez de empilhar resultados. Sem
    isso, converter a mesma imagem duas vezes geraria arquivos
    foto.png-0.png-1... no lugar de um unico resultado. }
  Result.Add('-write');
  Result.Add('null:');

  { Qualidade }
  if rfQualidade in F.Recursos then
  begin
    if AOpcoes.SemPerda and (rfPerdaTotal in F.Recursos) then
    begin
      if EhFamiliaPNG(Chave) then
      begin
        Result.Add('-define');
        Result.Add('png:compression-level=9');
      end
      else if Chave = 'webp' then
      begin
        Result.Add('-define');
        Result.Add('webp:lossless=true');
      end
      else if Chave = 'jxl' then
      begin
        Result.Add('-define');
        Result.Add('jxl:lossless=true');
      end
      else if (Chave = 'avif') or (Chave = 'heic') then
      begin
        { O codificador HEIC e o mesmo para AVIF e HEIC: a slowest speed e
          o que mais aproxima do modo sem perda. }
        Result.Add('-define');
        Result.Add('heic:speed=0');
      end
      else if Chave = 'farbfeld' then
        { farbfeld e sempre sem perda: nao ha argumento a enviar. }
      else if (Chave = 'ff') then
        ;
    end
    else if AOpcoes.Qualidade >= 0 then
    begin
      Result.Add('-quality');
      Result.Add(IntToStr(AOpcoes.Qualidade));
    end;
  end;

  { Compressao tem escala propria em cada formato. PNG e TIFF usam
    parametros diferentes de qualidade, entao nunca compartilham a flag. }
  if (rfCompressao in F.Recursos) and (AOpcoes.Compressao >= 0) then
  begin
    if EhFamiliaPNG(Chave) then
    begin
      Result.Add('-define');
      Result.Add('png:compression-level=' + IntToStr(AOpcoes.Compressao));
      Result.Add('-define');
      Result.Add('png:compression-filter=5');
    end
    else if EhFamiliaTIFF(Chave) then
    begin
      Result.Add('-compress');
      if AOpcoes.Compressao >= 6 then Result.Add('Zip')
      else if AOpcoes.Compressao >= 3 then Result.Add('LZW')
      else Result.Add('None');
    end
    else if (Chave = 'psd') or (Chave = 'psb') then
    begin
      Result.Add('-compress');
      if AOpcoes.Compressao >= 6 then Result.Add('Zip')
      else Result.Add('RLE');
    end
    else if (Chave = 'exr') or (Chave = 'dpx') or (Chave = 'cin') or
            (Chave = 'fl32') then
    begin
      { So o EXR tem compactadores proprios; DPX e Cineon usam a mesma
        sintaxe de compressao. }
      if Chave = 'exr' then
      begin
        Result.Add('-define');
        Result.Add('exr:compression-type=' +
          EXR_COMPRESSAO[AOpcoes.Compressao]);
      end;
    end
    else if Chave = 'svg' then
    begin
      { O nome correto da opcao e svg:parse-huge. A forma antiga,
        svg:xml-parse-huge, e ignorada pelo ImageMagick. }
      Result.Add('-define');
      Result.Add('svg:parse-huge=true');
    end
    else if (Chave = 'dds') or (Chave = 'dxt1') or (Chave = 'dxt5') then
    begin
      Result.Add('-define');
      if Chave = 'dxt1' then Result.Add('dds:compression=dxt1')
      else if Chave = 'dxt5' then Result.Add('dds:compression=dxt5')
      else if AOpcoes.Compressao = 0 then Result.Add('dds:compression=none')
      else Result.Add('dds:compression=dxt5');
    end;
  end;

  { Paleta }
  if (rfCores in F.Recursos) and (AOpcoes.ReduzirCores > 0) then
  begin
    Result.Add('-colors');
    Result.Add(IntToStr(AOpcoes.ReduzirCores));
  end;
  if (Chave = 'gif') or (Chave = 'gif87') then
  begin
    Result.Add('-layers');
    Result.Add('Optimize');
  end;

  { Progressivo e exclusivo do JPEG. Enviar em outro formato seria erro,
    por isso a marca rfProgressivo e o que habilita este bloco. }
  if (rfProgressivo in F.Recursos) and AOpcoes.Progressivo then
  begin
    Result.Add('-interlace');
    Result.Add('Plane');
  end;

  { JPEG com subamostragem 4:2:0 e o que reproduz igual em qualquer
    leitor; sem isso alguns editores mostram serrilhado. }
  if EhFamiliaJPEG(Chave) then
  begin
    Result.Add('-sampling-factor');
    Result.Add('4:2:0');
  end;

  { ICO guarda varios tamanhos no mesmo arquivo, entao a opcao de tamanho
    vira uma lista, nao uma dimensao unica. }
  if EhFamiliaIcone(Chave) then
  begin
    Result.Add('-define');
    Result.Add('icon:auto-resize=256,128,64,48,32,16');
  end;

  { PNM tem versao binaria e ASCII; o padrao ja e binario, entao so a
    opcao de compactacao muda o resultado. }
  if AExtensaoDestino <> '' then
    if (Chave = 'pnm') or (Chave = 'pgm') or (Chave = 'ppm') or
       (Chave = 'pbm') or (Chave = 'pam') then
      if AOpcoes.Compressao = 0 then
      begin
        Result.Add('-compress');
        Result.Add('none');
      end;

  { Alpha. JPEG e BMP nao tem canal alfa, entao nada e enviado e a
    interface mostra o controle como inativo.

    A ordem importa: primeiro a cor de fundo, depois remove o canal, e por
    ultimo desliga o alfa. Inverter esses passos, ou usar -flatten depois
    de remover o alfa, deixa a imagem com o fundo errado. }
  if (rfAlpha in F.Recursos) or (rfTransparencia in F.Recursos) then
    if not AOpcoes.AplicarAlpha then
    begin
      CorHex := IntToHex(Red(AOpcoes.CorFundo), 2) +
                IntToHex(Green(AOpcoes.CorFundo), 2) +
                IntToHex(Blue(AOpcoes.CorFundo), 2);
      Result.Add('-background');
      Result.Add('#' + CorHex);
      Result.Add('-alpha');
      Result.Add('remove');
      Result.Add('-alpha');
      Result.Add('off');
    end;

  { Redimensionamento }
  if AOpcoes.Redimensionar and (rfRedimensionar in F.Recursos) and
     ((AOpcoes.Largura > 0) or (AOpcoes.Altura > 0)) then
  begin
    Result.Add('-resize');
    { '>' impede que a imagem seja ampliada alem do pedido e preserva o
      aspecto; '!' forcaria exatamente LxH, deformando. }
    if AOpcoes.ManterProporcao then
      Result.Add(Format('%dx%d>', [AOpcoes.Largura, AOpcoes.Altura]))
    else
      Result.Add(Format('%dx%d!', [AOpcoes.Largura, AOpcoes.Altura]));
  end;

  { O fundo so entra quando a transparencia e removida de um formato que
    aceita alpha. Fora desse caso seria um argumento solto. }
  if AOpcoes.RemoverMetadados then
    Result.Add('-strip');

  { EXR precisa de ponto flutuante explicito, senao a saida vira meio
    tom e a composicao perde precisao. O mesmo serve para FITS e PFM. }
  if (Chave = 'exr') or (Chave = 'fl32') or (Chave = 'pfm') or
     (Chave = 'phm') or (Chave = 'fits') or (Chave = 'fts') then
  begin
    Result.Add('-define');
    Result.Add('quantum:format=floating-point');
  end;
end;

end.
