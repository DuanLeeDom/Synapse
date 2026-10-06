unit uImageProcRunner;

{ uImageProcRunner

  Executa a fila de imagens.

  Cada item vira uma invocacao do ImageMagick, montada por
  TGerenciadorFormatos.ArgumentosConversao e lancada por
  TProcessoGerenciado. Nenhum comando e escrito na mao aqui: o runner so
  cuida de ordem, progresso, cancelamento e erro, que sao as quatro coisas
  que a fila precisa e que nao pertencem a nenhuma ferramenta.

  Tres regras dao o comportamento esperado de um lote:

    1. Um item que falha nao interrompe os outros. O erro fica registrado
       no item e o laco segue para o proximo, que e o que se espera de um
       processamento em lote.

    2. O cancelamento vale para o lote todo. Ele encerra o item em
       andamento pela arvore de processos e nao comeca o seguinte, em vez
       de deixar metade da fila processada sem explicacao.

    3. Nada de shell. Os argumentos vao direto para o processo, o que
       elimina a fragilidade de aspas e faz o ImageMagick aparecer como
       filho direto do aplicativo. }

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, uDependencias, uProcessos, uImageFormats,
  uImageProcQueue;

type
  { TConversorImagens
    Percorre a fila uma vez, convertendo o que estiver pendente. }
  TConversorImagens = class
  private
    FFila        : TFilaImagens;
    FExecutando  : Boolean;
    FItemAtual   : TItemImagem;
    FProcesso    : TProcessoGerenciado;
    FNotificado  : Boolean;
    FLog         : TStrings;
    FSaida       : TStringList;

    { Rastreamento do progresso. O ImageMagick com -monitor imprime
      uma linha por passo, e o percentual e o da etapa atual: leitura,
      depois gravacao. Mostrar esse numero cru faria a barra do item andar
      para tras, de 96% da leitura para 0% da gravacao. As duas etapas
      recebem faixas fixas de 0 a 49 e de 50 a 99 para que a barra avance
      sempre, e so chegue a 100 quando o item termina de verdade. }
  FEtapa       : string;
  FEtapasVistas: Integer;
  FUltimoProgresso: Integer;

    function ConverterItem(AItem: TItemImagem): Boolean;
    function PastaDeDestino(AItem: TItemImagem): string;
    function NomeDeDestino(AItem: TItemImagem): string;
    function MontarArgumentos(AItem: TItemImagem;
      const ADestino: string): TStringList;
    function EtapaDoTexto(const ATexto: string): string;
    function ExtrairProgresso(const ATexto: string): Integer;
    procedure RegistrarSaida(const ATexto: string);
    function ResumirErro: string;
    procedure Anotar(const ALinha: string);
  public
    constructor Create(const AFila: TFilaImagens);
    destructor Destroy; override;

    { Processa todos os itens pendentes, na ordem da lista. Devolve True
      quando nenhum item terminou em erro. }
    function Executar: Boolean;

    { Encerra o item em andamento. Pode ser chamado de outro laco, por
      exemplo do botao de cancelar ou do tratador de fechar janela. }
    procedure Cancelar;

    property Executando: Boolean read FExecutando;
    property ItemAtual  : TItemImagem read FItemAtual;
    { Log da execucao, uma linha por evento. O progresso nao entra aqui:
      sao milhares de linhas que esconderiam justamente a mensagem de erro
      que o usuario precisa ler. }
    property Log        : TStrings read FLog;
  end;

implementation

{ Tamanho do arquivo em bytes. FileSize existe no Delphi para string, mas
  neste compilador so existe a variante de arquivo de texto, entao a
  medicao e feita abrindo e seeking, que funciona igual em qualquer
  plataforma. }
function TamanhoDoArquivo(const AArquivo: string): Int64;
var
  H: THandle;
begin
  Result := -1;
  H := FileOpen(AArquivo, fmOpenRead or fmShareDenyWrite);
  if H = THandle(-1) then
    Exit;
  try
    Result := FileSeek(H, Int64(0), fsFromEnd);
  finally
    FileClose(H);
  end;
end;

{ TConversorImagens }

constructor TConversorImagens.Create(const AFila: TFilaImagens);
begin
  inherited Create;
  if AFila = nil then
    FFila := TFilaImagens.Unica
  else
    FFila := AFila;
  FLog := TStringList.Create;
  FSaida := TStringList.Create;
end;

destructor TConversorImagens.Destroy;
begin
  { Um conversor destruido no meio do processamento nao pode deixar o
    ImageMagick daquele item rodando: e a ultima chance de encerrar a
    arvore antes de perder a referencia. }
  if FProcesso <> nil then
  begin
    FProcesso.EncerrarArvore;
    FProcesso.Free;
    FProcesso := nil;
  end;
  FLog.Free;
  FSaida.Free;
  inherited Destroy;
end;

procedure TConversorImagens.Anotar(const ALinha: string);
begin
  if ALinha = '' then
    Exit;
  FLog.Add(FormatDateTime('hh:nn:ss', Now) + '  ' + ALinha);
end;

procedure TConversorImagens.RegistrarSaida(const ATexto: string);
var
  i, Ini: Integer;
  Linha: string;
begin
  { Guarda so o que NAO e progresso. O -monitor despeja uma linha por
    passo de leitura e de gravacao, e guardar tudo encheria a memoria de
    um lote grande e soterraria a mensagem de erro, que e a unica parte
    dessa saida que interessa ao usuario. }
  Ini := 1;
  for i := 1 to Length(ATexto) + 1 do
    if (i = Length(ATexto) + 1) or (ATexto[i] = #10) or (ATexto[i] = #13) then
    begin
      if i > Ini then
      begin
        Linha := Trim(Copy(ATexto, Ini, i - Ini));
        if (Linha <> '') and (Pos('% complete', Linha) = 0) then
        begin
          FSaida.Add(Linha);
          { Janela deslizante: em arquivo grande o ImageMagick pode emitir
            centenas de avisos, e o que explica a falha e sempre o fim. }
          while FSaida.Count > 60 do
            FSaida.Delete(0);
        end;
      end;
      Ini := i + 1;
    end;
end;

function TConversorImagens.EtapaDoTexto(const ATexto: string): string;
var
  P: Integer;
begin
  { As linhas de progresso comecam com "load image[...]", "save image...",
    "encode image..." e afins. O nome da operacao e o que separa as
    etapas, e nao o percentual. }
  Result := '';
  P := Pos('[', ATexto);
  if P = 0 then
    Exit;
  P := Pos('image', LowerCase(ATexto));
  if P = 0 then
    Exit;
  Result := Trim(Copy(ATexto, 1, P + 4));
end;

function TConversorImagens.PastaDeDestino(
  AItem: TItemImagem): string;
begin
  Result := FFila.PastaDeDestino(AItem);
end;

function TConversorImagens.NomeDeDestino(AItem: TItemImagem): string;
begin
  Result := ChangeFileExt(AItem.Nome,
    '.' + TGerenciadorFormatos.ExtensaoDe(AItem.FormatoDestino));
end;

function TConversorImagens.MontarArgumentos(AItem: TItemImagem;
  const ADestino: string): TStringList;
var
  Opcoes: TOpcoesConversao;
  Gerados: TStringList;
  i: Integer;
begin
  Result := TStringList.Create;

  { A ordem e o que faz o ImageMagick funcionar: primeiro o arquivo de
    entrada, depois os operadores, e o destino so por ultimo. Um destino
    no meio da lista seria lido como se fosse outra entrada e o comando
    falharia com "no decode delegate". }
  Result.Add(AItem.Arquivo);

  Opcoes := AItem.Opcoes;

  Gerados := TGerenciadorFormatos.ArgumentosConversao(
    AItem.FormatoDestino, Opcoes);
  try
    for i := 0 to Gerados.Count - 1 do
      Result.Add(Gerados[i]);
  finally
    Gerados.Free;
  end;

  { -monitor faz a ferramenta escrever "N de T, P% complete" na saida de
    erro, que e o que permite mostrar progresso real em vez de uma
    animacao falsa. }
  Result.Add('-monitor');
  Result.Add(ADestino);
end;

function TConversorImagens.ExtrairProgresso(const ATexto: string): Integer;
var
  P, Ini, Fim: Integer;
  Fracao: string;
  Etapa: string;
  Bruto: Integer;
  Valor: Integer;
begin
  { Formato emitido pelo -monitor do ImageMagick:
        load image[C:\x.tif]: 120 of 480, 25% complete

    A busca e feita de tras para frente porque o buffer pode trazer varias
    linhas e interessa o percentual mais recente. }
  Result := -1;
  Fim := Pos('% complete', ATexto);
  if Fim = 0 then
    Exit;

  P := LastDelimiter(',;', Copy(ATexto, 1, Fim));
  if P = 0 then
    P := Fim - 1;

  Ini := P;
  while (Ini > 1) and (ATexto[Ini - 1] in ['0'..'9']) do
    Dec(Ini);

  Fracao := Copy(ATexto, Ini, P - Ini + 1);
  if Fracao = '' then
    Exit;
  Bruto := StrToIntDef(Fracao, -1);
  if Bruto < 0 then
    Exit;

  { Traducao do percentual da etapa para a barra do item. Cada etapa nova
    sobe um degrau, o que impede a barra de voltar de 96 para 0 quando o
    ImageMagick passa da leitura para a gravacao. }
  Etapa := EtapaDoTexto(ATexto);
  if (Etapa <> '') and (Etapa <> FEtapa) then
  begin
    FEtapa := Etapa;
    Inc(FEtapasVistas);
  end;

  case FEtapasVistas of
    0, 1: Valor := Bruto div 2;
    2:     Valor := 50 + Bruto div 2;
  else
    { Terceira etapa em diante fica na cauda: nao ha como saber quantas
      ainda virao, e melhor travar perto do fim do que inventar. }
    Valor := 99;
  end;

  if Valor < FUltimoProgresso then
    Valor := FUltimoProgresso;
  FUltimoProgresso := Valor;
  Result := Valor;
end;

function TConversorImagens.ResumirErro: string;
var
  i, P: Integer;
  Linha: string;
begin
  { A saida de erro do ImageMagick costuma vir precedida de linhas de uso
    e de versao. O que interessa e a ultima linha de verdade, e nao a
    parede de texto. }
  Result := '';
  if FSaida = nil then
    Exit;
  for i := FSaida.Count - 1 downto 0 do
  begin
    Linha := Trim(FSaida[i]);
    if (Linha = '') or (Pos('Usage:', Linha) > 0) then
      Continue;

    { Linha so com referencia interna, sem mensagem alguma. Isso acontece
      quando o relatorio quebra em duas linhas. }
    if (Pos('@', Linha) = 1) or (Pos('error/', LowerCase(Linha)) = 1) or
      (Pos('.c/', Linha) = 1) then
      Continue;

    { O ImageMagick anexa a origem no fim da propria mensagem:
        improper image header `x.png' @ error/png.c/ReadPNGImage/3956
      Cortar no "@" preserva a parte que o usuario entende e descarta o
      caminho de codigo, que so serve para quem vai depurar o proprio
      ImageMagick. }
    P := Pos(' @ ', Linha);
    if P > 0 then
      Linha := Trim(Copy(Linha, 1, P - 1));

    if Linha = '' then
      Continue;

    Result := Linha;
    Break;
  end;

  { O prefixo e o nome do executavel, repetido no comeco da linha. }
  while Pos('magick', LowerCase(Result)) = 1 do
    Result := Trim(Copy(Result, Pos(':', Result) + 1));
  Result := Trim(Result);
end;

function TConversorImagens.ConverterItem(AItem: TItemImagem): Boolean;
var
  Pasta, Destino, DestinoMagick, Exe: string;
  Args: TStringList;
  Trecho: string;
  Codigo: Integer;
  Progresso: Integer;
begin
  Result := False;
  FItemAtual := AItem;

  Pasta := PastaDeDestino(AItem);
  if Pasta = '' then
  begin
    AItem.Status := isiErro;
    AItem.Mensagem := 'sem pasta de destino';
    AItem.DetalheErro := 'Nenhuma pasta de destino definida.';
    Anotar(AItem.Nome + ': sem pasta de destino');
    Exit;
  end;

  { Criar a pasta aqui, e nao no item, porque o destino pode ter sido
    apagado entre a inclusao e a execucao, e uma pasta que sumiu nao pode
    derrubar o lote inteiro. }
  if not DirectoryExists(Pasta) then
    if not ForceDirectories(Pasta) then
    begin
      AItem.Status := isiErro;
      AItem.Mensagem := 'pasta de destino inacessivel';
      AItem.DetalheErro := 'Nao foi possivel criar a pasta: ' + Pasta;
      Anotar(AItem.Nome + ': nao foi possivel criar ' + Pasta);
      Exit;
    end;

  Destino := IncludeTrailingPathDelimiter(Pasta) + NomeDeDestino(AItem);

  { O prefixo de formato antes do caminho e o que permite gravar nos
    formatos cujo nome de arquivo nao identifica o codificador, como 'jpt'
    ou 'j2c'. Sem ele o ImageMagick tenta adivinhar pela extensao e falha
    em boa parte dos formatos esotericicos. }
  DestinoMagick := TGerenciadorFormatos.PrefixoDe(AItem.FormatoDestino) +
    Destino;

  { A consulta ao ImageMagick instalado acontece uma vez, na abertura da
    tela. Quando ela diz que o formato nao existe nesta instalacao, o erro
    aqui e claro; sem esta guarda o usuario veria apenas a mensagem
    generica de "no decode delegate" mais adiante. }
  if TGerenciadorFormatos.Disponivel(AItem.FormatoDestino) = dfIndisponivel then
  begin
    AItem.Status := isiErro;
    AItem.Mensagem := 'formato sem suporte';
    AItem.DetalheErro := 'A instalacao do ImageMagick usada por este programa ' +
      'nao consegue gravar ' + TGerenciadorFormatos.RotuloDe(
      AItem.FormatoDestino) + '. Escolha outro formato de destino.';
    Anotar(AItem.Nome + ': formato sem suporte -> ' + AItem.FormatoDestino);
    Exit;
  end;

  Exe := TGerenciadorDependencias.Caminho(depImageMagick);
  if Exe = '' then
  begin
    AItem.Status := isiErro;
    AItem.Mensagem := 'ImageMagick nao encontrado';
    AItem.DetalheErro :=
      'ImageMagick nao foi encontrado. Coloque o executavel em tools\' +
      'imagemagick\ ou aponte o caminho em synapse.ini, na secao ' +
      '[dependencies].';
    Anotar(AItem.Nome + ': ImageMagick nao encontrado');
    Exit;
  end;

  Args := MontarArgumentos(AItem, DestinoMagick);
  FProcesso := TProcessoGerenciado.Create;
  try
    { FSaida e reiniciada por item porque e dela que se extrai a mensagem de
    erro daquele item. FLog nao: e o historico do lote e precisa
    acumular. }
    FSaida.Clear;
    FEtapa := '';
    FEtapasVistas := 0;
    FUltimoProgresso := 0;
    Anotar(Format('%s -> %s', [AItem.Arquivo, Destino]));

    if not FProcesso.Iniciar(Exe, Args, nil, True) then
    begin
      AItem.Status := isiErro;
      AItem.Mensagem := 'nao foi possivel iniciar';
      AItem.DetalheErro := 'O ImageMagick nao pode ser executado: ' + Exe;
      Anotar(AItem.Nome + ': falha ao iniciar o processo');
      Exit;
    end;

    AItem.Progresso := 0;
    AItem.Mensagem := 'Convertendo';

    { Aguarda o fim lendo o progresso no mesmo laco. separateDoLaco nao
      serviria: a leitura do pipe e o que impede o travamento descrito em
      TGerenciadorProcessos.CapturarSaida. }
    Progresso := 0;
    while FProcesso.Ativo do
    begin
      if FProcesso.LerDisponivel(Trecho) > 0 then
      begin
        RegistrarSaida(Trecho);
        Progresso := ExtrairProgresso(Trecho);
        if Progresso >= 0 then
          AItem.Progresso := Progresso;
      end;

      if FFila.Cancelado then
      begin
        FProcesso.Encerrar(encForcar);
        Break;
      end;

      Sleep(10);
    end;

    { Depois que o processo acaba ainda sobra texto no pipe, e a ultima
      linha e justamente a que importa: a mensagem de erro. Ler apenas
      enquanto o processo esta ativo perderia justamente essa linha. }
    Trecho := FProcesso.LerTudo;
    if Trecho <> '' then
    begin
      RegistrarSaida(Trecho);
      Progresso := ExtrairProgresso(Trecho);
      if Progresso >= 0 then
        AItem.Progresso := Progresso;
    end;

    Codigo := FProcesso.CodigoSaida;

    if FFila.Cancelado then
    begin
      AItem.Status := isiCancelado;
      AItem.Mensagem := 'Cancelado';
      AItem.DetalheErro := '';
      Anotar(AItem.Nome + ': cancelado');
      Exit;
    end;

    if (Codigo <> 0) or (not FileExists(Destino)) then
    begin
      AItem.Status := isiErro;
      AItem.Mensagem := 'Erro';
      AItem.DetalheErro := ResumirErro;
      if AItem.DetalheErro = '' then
        AItem.DetalheErro := Format('O ImageMagick terminou com codigo %d ' +
          'e nao produziu o arquivo.', [Codigo]);
      Anotar(AItem.Nome + ': erro -> ' + AItem.DetalheErro);
      Exit;
    end;

    { Um arquivo de tamanho zero e sintoma de conversao interrompida no
      meio. O codigo de saida as vezes vem de zero nesse caso, entao o
      tamanho e a unica conferencia confiavel. }
    if TamanhoDoArquivo(Destino) = 0 then
    begin
      AItem.Status := isiErro;
      AItem.Mensagem := 'Erro';
      AItem.DetalheErro := 'O arquivo gerado ficou vazio.';
      Anotar(AItem.Nome + ': arquivo de saida vazio');
      Exit;
    end;

    AItem.Status := isiConcluido;
    AItem.Progresso := 100;
    AItem.Mensagem := Destino;
    AItem.DetalheErro := '';
    AItem.AtribuirMiniatura(TThumbnailServiceImagem.DoArquivo(
      Destino, LARGURA_THUMB_IMAGEM, ALTURA_THUMB_IMAGEM));
    Anotar(AItem.Nome + ': concluido');
    Result := True;
  finally
    FProcesso.Free;
    FProcesso := nil;
    FItemAtual := nil;
  end;
end;

function TConversorImagens.Executar: Boolean;
var
  i: Integer;
  Item: TItemImagem;
begin
  Result := True;
  if FExecutando then
    Exit;
  if FFila.QtItens = 0 then
    Exit;

  FExecutando := True;
  FFila.Processando := True;
  FFila.Cancelado := False;
  FLog.Clear;
  Anotar(Format('Inicio: %d item(ns)', [FFila.QtPendentes]));

  try
    { A lista e percorrida por indice e nao com "proximo pendente" porque
      remover ou mover itens durante o laco mudaria a ordem de forma
      imprevisivel. O laco snapshot o que existe e decide o que pular. }
    for i := 0 to FFila.QtItens - 1 do
    begin
      Item := FFila.Item(i);
      if Item = nil then
        Continue;
      if Item.Status <> isiAguardando then
        Continue;

      if FFila.Cancelado then
      begin
        Item.Status := isiCancelado;
        Item.Mensagem := 'Cancelado';
        Continue;
      end;

      { Um erro em um item nao interrompe os demais. Este e o ponto que
        separa um lote util de um lote que para no primeiro problema. }
      if not ConverterItem(Item) then
        Result := False;
    end;

    Anotar(Format('Fim: %d concluido(s), %d erro(s), %d cancelado(s)',
      [FFila.QtConcluidos, FFila.QtComErro,
       FFila.QtItens - FFila.QtConcluidos - FFila.QtComErro]));
  finally
    FExecutando := False;
    FFila.Processando := False;
  end;
end;

procedure TConversorImagens.Cancelar;
begin
  { Sinaliza o lote e, se houver, derruba o processo do item atual. O laco
    de execucao ve a flag e para de pegar o proximo item. }
  FFila.Cancelado := True;
  if FProcesso <> nil then
    FProcesso.EncerrarArvore;
end;

end.