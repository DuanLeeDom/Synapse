unit uProcessos;

{ uProcessos

  Execucao e ciclo de vida das ferramentas externas.

  Este e o unico lugar do projeto que cria processos externos. As duas
  garantias que ele da sao:

  1) Execucao direta. O executavel e lanzado pelo proprio aplicativo, sem
     cmd.exe no meio. Isso faz o Synapse aparecer como pai direto do
     processo filho, o que e o que o Gerenciador de Tarefas mostra na
     coluna de PPID, e elimina a fragilidade de montar comando em texto
     com aspas.

  2) Ciclo de vida preso ao aplicativo, via Job Object do Windows. Todos os
     processos sao colocados num job do proprio aplicativo com a flag
     JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE. E o kernel quem garante o
     encerraento: quando o Synapse fecha, seja normalmente, por erro ou
     por Terminate, todos os filhos morrem junto. Nao existe caminho em que
     um ffmpeg continue rodando sem o aplicativo.

  Isso e o maximo que o Windows permite. Um executavel de outro programa
  nao pode virar parte do mesmo processo: so DLLs sao carregadas no espaco
  de enderecamento do chamador. Job Object e o mecanismo previsto para
  agrupar processos sob um dono, e e o que agrupa Synapse, ffmpeg e o
  ffmpeg que o yt-dlp cria ao juntar faixas.

  Cancelar um item especifico NAO usa taskkill /IM por nome: mataria o
  ffmpeg de outros programas e de outros usuarios da maquina. Em vez disso
  a arvore e percorrida a partir do PID, que pertence a este item. }

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Process, Windows;

type
  { Como encerrar um processo em andamento. }
  TModoEncerramento = (encEncerrarSuave, encForcar);

  { Rotina sem parametros chamada para repintar durante uma espera. }
  TProcBombeio = procedure;

  { TProcessoGerenciado

    Um processo externo sob controle do aplicativo. }
  TProcessoGerenciado = class
  private
    FProcesso : TProcess;
    FExe      : string;
    FArgs     : TStringList;
    FCancelado: Boolean;
    FNoJob    : Boolean;
    procedure EscreverEntrada(const ATexto: string);
  public
    constructor Create;
    destructor Destroy; override;

    { Inicia o processo. ARedirecionar captura stdout e stderr juntos, que
      e o que o log e o progresso leem; sem isso o processo apenas roda ate
      o fim. AEntrada, se preenchida, e escrita em stdin, que e como o
      ffmpeg recebe comandos. }
    function Iniciar(const AExe: string; const AArgs: TStringList;
                     const AEntrada: TStrings;
                     ARedirecionar: Boolean = True): Boolean;

    { Le o que ja saiu do processo sem travar. Devolve quantos bytes leu;
      devolve 0 quando nao ha mais nada. }
    function LerDisponivel(out ATexto: string): Integer;

    { Le a saida inteira quando o processo ja terminou. So deve ser usada
      depois que a espera terminou: enquanto o processo roda, a leitura
      competiria com LerDisponivel e perderia bytes. }
    function LerTudo: string;

    { Espera o processo terminar. AMaxMs e o limite em milissegundos, com
      zero esperando para sempre. ABombeia faz o laco passar as mensagens
      pendentes, o que e obrigatorio quando a espera acontece na thread da
      interface: sem isso a janela travaria ate o processo acabar.

      Devolve True quando o processo saiu dentro do tempo, e False em caso
      de estouro de prazo. }
    function Aguardar(AMaxMs: Integer; ABombeia: Boolean = True): Boolean;

    { encEncerrarSuave escreve 'q' no stdin: o ffmpeg entende isso como
      "finalize o arquivo atual e saia", o que evita deixar saida
      truncada. So depois de esperar ele passa a terminating. }
    procedure Encerrar(AModo: TModoEncerramento = encEncerrarSuave);
    procedure EncerrarArvore;

    function Ativo: Boolean;
    function PID: Integer;
    function CodigoSaida: Integer;
    function Cancelado: Boolean;
    function HandleProcesso: THandle;
    function EstaNoJob: Boolean;
    property Executavel: string read FExe;
    property Argumentos: TStringList read FArgs;
  end;

  { TGerenciadorProcessos

    Dono do Job Object do aplicativo. }
  TGerenciadorProcessos = class
  public
    { Cria o job do aplicativo, uma unica vez. }
    class function JobDoAplicativo: THandle;
    class function JobAtivo: Boolean;

    { Coloca um processo recem-criado no job. Chamar antes de retomar um
      processo suspenso e o que elimina a janela de corrida: sem isso o
      processo pode comecar a rodar e criar filhos antes de estar no job,
      e esses filhos escapariam. }
    class function Vincular(AProcessoHandle: THandle): Boolean;
    class function EstaVinculado(AProcessoHandle: THandle): Boolean;

    { Quantos processos estao vivos agora no job. }
    class function TotalNoJob: Integer;

    { Diagnostico: PID de um processo, quem o criou e se ainda está vivo.
      Usado pela interface para mostrar a vinculação e pelos testes. }
class function PPID(APid: Integer): Integer;
class function Vivo(APid: Integer): Boolean;
class function NomeDoProcesso(APid: Integer): string;
class function ListaPidsDoJob: TStringList;

    { Encerra apenas a arvore que nasceu deste PID, filhos primeiro. E o
      que o botao de cancelar usa quando o processo foi criado fora de
      TProcessoGerenciado: matar por nome de imagem derrubaria o ffmpeg de
      qualquer outro programa da maquina. }
    class procedure EncerrarArvorePorPid(APai: DWORD);

    { Executa uma ferramenta e devolve o que ela respondeu. E o caminho de
      leitura de versao e de qualquer outra saida curta; Conversao por
      item tem o proprio runner porque precisa de progresso item a item. }
    class function CapturarSaida(const AExe: string; const AArgs: TStrings;
      ATimeoutMs: Integer; out ASaida: string;
      out ACodigo: Integer): Boolean;

    { Encerra tudo que sobrou. Usado na saida do aplicativo; em operacao
      normal quem encerra e o proprio item, para nao matar Conversao A
      por causa de Conversao B. }
    class procedure EncerrarTodos;
    class procedure LiberarJob;
  end;

{ Registra a rotina que bombeia as mensagens da interface durante uma
  espera. Esta unit nao usa Forms de proposito: ela precisa poder ser
  ligada em programa de console, onde nao existe widgetset e um Form
  abortaria a execucao. A camada de interface registra aqui o
  Application.ProcessMessages e, fora do aplicativo a espera apenas
  dorme. }
procedure uProcessosDefinirBombearMensagens(const AProc: TProcBombeio);

implementation

{ Este unit nao depende de uDependencias de proposito. E o contrario que
  vale: a captura de saida usada para ler a versao de uma ferramenta e
  implementada aqui, e uDependencias a consome. Manter a dependencia nesse
  sentido deixa aCaptura de saida sem o deadlock descrito em
  CapturarSaida. }

{ ------------------------------------------------------------------------ }
{ API do Windows                                                            }
{ ------------------------------------------------------------------------ }

{$IFDEF WINDOWS}

{ O RTL do FPC nao declara Job Object nem Toolhelp. Sao Win32 estavel e
  exportada por kernel32, entao declaram-se aqui. Sem isso o agrupamento de
  processos - que e o que amarra as ferramentas ao aplicativo - teria de
  ser feito por contagem de processos e nomes de executavel, exatamente o
  metodo frágil que o projeto usava antes. }
const
  JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = $00002000;
  JOB_OBJECT_EXTENDED_LIMIT_INFORMATION_CLASS = 9;
  JOB_OBJECT_BASIC_ACCOUNTING_INFORMATION_CLASS = 1;
  JOB_OBJECT_BASIC_PROCESS_ID_LIST_CLASS = 3;
  TH32CS_SNAPPROCESS = $00000002;

type
  { A Toolhelp so exporta as variantes W: Process32FirstA e Process32NextA
    nao existem em nenhuma versao do Windows, e tentar importa-las causa
    STATUS_ENTRYPOINT_NOT_FOUND na carga do executavel. Por isso a
    estrutura usa WideChar.

    Atencao a th32DefaultHeapID: em PROCESSENTRY32 ele e ULONG_PTR, ou
    seja, 8 bytes em 64 bits. Declarar como DWORD desloca todos os campos
    seguintes em quatro bytes, e o efeito aparece de forma enganosa: o
    processo e encontrado, mas o PPID lido sai errado - o que faria a
    encerramento de arvore mirar no processo errado. }
  TProcessEntry32 = record
    dwSize              : DWORD;
    cntUsage            : DWORD;
    th32ProcessID       : DWORD;
    th32DefaultHeapID   : ULONG_PTR;
    th32ModuleID        : DWORD;
    cntThreads          : DWORD;
    th32ParentProcessID : DWORD;
    pcPriClassBase      : LongInt;
    dwFlags             : DWORD;
    szExeFile           : array[0..MAX_PATH - 1] of WideChar;
  end;

  { Lista de PIDs que o proprio job mantem. }
  TJobObjectBasicProcessIdList = record
    NumberOfAssignedProcesses: DWORD;
    NumberOfProcessIdsInList : DWORD;
    ProcessIdList            : array[0..0] of ULONG_PTR;
  end;

  TArrayDeIds = array[0..0] of ULONG_PTR;
  PArrayDeIds = ^TArrayDeIds;
  PJobObjectBasicProcessIdList = ^TJobObjectBasicProcessIdList;

function CreateJobObjectW(lpJobAttributes: Pointer;
  lpName: PWideChar): THandle; stdcall;
  external 'kernel32.dll' name 'CreateJobObjectW';
function AssignProcessToJobObject(hJob, hProcess: THandle): BOOL; stdcall;
  external 'kernel32.dll' name 'AssignProcessToJobObject';
function SetInformationJobObject(hJob: THandle;
  JobObjectInformationClass: DWORD; lpJobObjectInformation: Pointer;
  cbJobObjectInformationLength: DWORD): BOOL; stdcall;
  external 'kernel32.dll' name 'SetInformationJobObject';
function QueryInformationJobObject(hJob: THandle;
  JobObjectInformationClass: DWORD; lpJobObjectInformation: Pointer;
  cbJobObjectInformationLength: DWORD; lpReturnLength: PDWORD): BOOL; stdcall;
  external 'kernel32.dll' name 'QueryInformationJobObject';
function TerminateJobObject(hJob: THandle; uExitCode: UINT): BOOL; stdcall;
  external 'kernel32.dll' name 'TerminateJobObject';
function IsProcessInJob(hProcess, hJob: THandle;
  var pResult: LongBool): LongBool; stdcall;
  external 'kernel32.dll' name 'IsProcessInJob';

function CreateToolhelp32Snapshot(dwFlags, th32ProcessID: DWORD): THandle; stdcall;
  external 'kernel32.dll' name 'CreateToolhelp32Snapshot';
function Process32First(hSnapshot: THandle;
  var lppe: TProcessEntry32): LongBool; stdcall;
  external 'kernel32.dll' name 'Process32FirstW';
function Process32Next(hSnapshot: THandle;
  var lppe: TProcessEntry32): LongBool; stdcall;
  external 'kernel32.dll' name 'Process32NextW';

type
  TJobObjectBasicLimitInformation = record
    PerProcessUserTimeLimit : Int64;
    PerJobUserTimeLimit     : Int64;
    LimitFlags              : DWORD;
    MinimumWorkingSetSize   : SIZE_T;
    MaximumWorkingSetSize   : SIZE_T;
    ActiveProcessLimit      : DWORD;
    Affinity                : ULONG_PTR;
    PriorityClass           : DWORD;
    SchedulingClass         : DWORD;
  end;

  TIoCounters = record
    ReadOperationCount  : UInt64;
    WriteOperationCount : UInt64;
    OtherOperationCount : UInt64;
    ReadTransferCount   : UInt64;
    WriteTransferCount  : UInt64;
    OtherTransferCount  : UInt64;
  end;

  TJobObjectExtendedLimitInformation = record
    BasicLimitInformation : TJobObjectBasicLimitInformation;
    IoInfo                : TIoCounters;
    ProcessMemoryLimit    : SIZE_T;
    JobMemoryLimit        : SIZE_T;
    PeakProcessMemoryUsed : SIZE_T;
    PeakJobMemoryUsed     : SIZE_T;
  end;

  TJobObjectBasicAccountingInformation = record
    TotalUserTime            : Int64;
    TotalKernelTime          : Int64;
    ThisPeriodTotalUserTime  : Int64;
    ThisPeriodTotalKernelTime: Int64;
    TotalPageFaultCount      : DWORD;
    TotalProcesses           : DWORD;
    ActiveProcesses          : DWORD;
    TotalTerminatedProcesses : DWORD;
  end;
{$ENDIF}

var
  GJob : THandle = 0;
  GBombearMensagens : TProcBombeio = nil;

procedure uProcessosDefinirBombearMensagens(const AProc: TProcBombeio);
begin
  GBombearMensagens := AProc;
end;

function ObterJob: THandle;
var
  {$IFDEF WINDOWS}
  Info: TJobObjectExtendedLimitInformation;
  {$ENDIF}
begin
{$IFDEF WINDOWS}
  Result := GJob;
  if Result = 0 then
  begin
    GJob := CreateJobObjectW(nil, nil);
    if GJob <> 0 then
    begin
      { A flag e o que importa: o SO encerra o job quando o ultimo handle
        fecha. Como este handle vive no processo do Synapse, qualquer
        saida do aplicativo - normal, erro ou Terminate - mata a arvore
        inteira. E garantia do kernel, nao do nosso codigo. }
      FillChar(Info, SizeOf(Info), 0);
      Info.BasicLimitInformation.LimitFlags :=
        JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
      SetInformationJobObject(GJob,
        JOB_OBJECT_EXTENDED_LIMIT_INFORMATION_CLASS, @Info, SizeOf(Info));
    end;
    { O handle precisa voltar em Result: quem chama reavalia o job a cada
      operacao, e devolver o valor antigo faria o aplicativo achar que o
      job nunca foi criado. }
    Result := GJob;
  end;
{$ELSE}
  { Fora do Windows nao ha Job Object. O processo filho e encerrado
    individualmente; a garantia de "morrer junto com o aplicativo" nao
    existe fora do Windows e o codigo nao finge que existe. }
  Result := 0;
{$ENDIF}
end;

{ ------------------------------------------------------------------------ }
{ Encerramento de arvore por PID                                              }
{ ------------------------------------------------------------------------ }

{$IFDEF WINDOWS}
type
  TPids = array of DWORD;

{ Junta os filhos diretos de APai. O snapshot do Toolhelp e estatico, entao
  a lista precisa ser montada antes de comecar a matar: enquanto se percorre
  a arvore, novos filhos podem nascer e ficariam de fora. }
function FilhosDiretos(APai: DWORD): TPids;
var
  Snapshot: THandle;
  Info: TProcessEntry32;
begin
  Result := nil;
  Snapshot := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if Snapshot = INVALID_HANDLE_VALUE then
    Exit;
  try
    Info.dwSize := SizeOf(Info);
    if Process32First(Snapshot, Info) then
    begin
      repeat
        if Info.th32ParentProcessID = APai then
        begin
          SetLength(Result, Length(Result) + 1);
          Result[High(Result)] := Info.th32ProcessID;
        end;
        Info.dwSize := SizeOf(Info);
      until not Process32Next(Snapshot, Info);
    end;
  finally
    CloseHandle(Snapshot);
  end;
end;

{ Mata apenas a arvore que nasceu deste PID. Substitui o antigo
  taskkill /F /IM ffmpeg.exe, que encerrava o ffmpeg de qualquer programa da
  maquina, inclusive de outros usuarios. }
procedure EncerrarArvorePorPidInterno(APai: DWORD);
var
  Filhos: TPids;
  i: Integer;
  H: THandle;
begin
  if APai = 0 then
    Exit;

  Filhos := FilhosDiretos(APai);

  { Profundidade primeiro: os filhos sao encerrados antes do pai. }
  for i := 0 to Length(Filhos) - 1 do
    EncerrarArvorePorPidInterno(Filhos[i]);

  H := OpenProcess(PROCESS_TERMINATE, False, APai);
  if H <> 0 then
  begin
    try
      TerminateProcess(H, 1);
    finally
      CloseHandle(H);
    end;
  end;
end;
{$ENDIF}

{ ------------------------------------------------------------------------ }
{ TGerenciadorProcessos                                                     }
{ ------------------------------------------------------------------------ }

class function TGerenciadorProcessos.JobDoAplicativo: THandle;
begin
  Result := ObterJob;
end;

class function TGerenciadorProcessos.JobAtivo: Boolean;
begin
{$IFDEF WINDOWS}
  Result := ObterJob <> 0;
{$ELSE}
  Result := False;
{$ENDIF}
end;

class function TGerenciadorProcessos.Vincular(AProcessoHandle: THandle): Boolean;
begin
{$IFDEF WINDOWS}
  Result := AssignProcessToJobObject(ObterJob, AProcessoHandle);
{$ELSE}
  Result := False;
{$ENDIF}
end;

class function TGerenciadorProcessos.EstaVinculado(AProcessoHandle: THandle): Boolean;
var
  {$IFDEF WINDOWS}
  Dentro: LongBool;
  {$ENDIF}
begin
{$IFDEF WINDOWS}
  { IsProcessInJob responde o que o SO realmente registrou, em vez de
    confiar na memoria do aplicativo sobre o que ele fez. }
  Dentro := False;
  Result := IsProcessInJob(AProcessoHandle, ObterJob, Dentro) and Dentro;
{$ELSE}
  Result := False;
{$ENDIF}
end;

class function TGerenciadorProcessos.TotalNoJob: Integer;
var
  {$IFDEF WINDOWS}
  Info: TJobObjectBasicAccountingInformation;
  Tam: DWORD;
  {$ENDIF}
begin
  Result := 0;
{$IFDEF WINDOWS}
  Tam := SizeOf(Info);
  if QueryInformationJobObject(ObterJob,
      JOB_OBJECT_BASIC_ACCOUNTING_INFORMATION_CLASS, @Info, Tam, nil) then
    Result := Integer(Info.ActiveProcesses);
{$ENDIF}
end;

class function TGerenciadorProcessos.PPID(APid: Integer): Integer;
var
  {$IFDEF WINDOWS}
  Snapshot: THandle;
  Info: TProcessEntry32;
  {$ENDIF}
begin
  Result := 0;
{$IFDEF WINDOWS}
  Snapshot := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if Snapshot = INVALID_HANDLE_VALUE then
    Exit;
  try
    Info.dwSize := SizeOf(Info);
    if Process32First(Snapshot, Info) then
    begin
      repeat
        if Info.th32ProcessID = DWORD(APid) then
        begin
          Result := Integer(Info.th32ParentProcessID);
          Break;
        end;
        Info.dwSize := SizeOf(Info);
      until not Process32Next(Snapshot, Info);
    end;
  finally
    CloseHandle(Snapshot);
  end;
{$ENDIF}
end;

class function TGerenciadorProcessos.Vivo(APid: Integer): Boolean;
var
  {$IFDEF WINDOWS}
  H: THandle;
  {$ENDIF}
begin
  Result := False;
{$IFDEF WINDOWS}
  if APid = 0 then
    Exit;
  H := OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, DWORD(APid));
  if H <> 0 then
  begin
    Result := WaitForSingleObject(H, 0) = WAIT_TIMEOUT;
    CloseHandle(H);
  end;
{$ENDIF}
end;

class function TGerenciadorProcessos.NomeDoProcesso(APid: Integer): string;
var
  {$IFDEF WINDOWS}
  Snapshot: THandle;
  Info: TProcessEntry32;
 Achou: Boolean;
  {$ENDIF}
begin
  Result := '';
{$IFDEF WINDOWS}
  Snapshot := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if Snapshot = INVALID_HANDLE_VALUE then
    Exit;
  try
    Info.dwSize := SizeOf(Info);
    Achou := False;
    if Process32First(Snapshot, Info) then
    begin
      repeat
        if Info.th32ProcessID = DWORD(APid) then
        begin
          Result := String(Info.szExeFile);
          Achou := True;
          Break;
        end;
        Info.dwSize := SizeOf(Info);
      until not Process32Next(Snapshot, Info);
    end;
    if not Achou then
      Result := '(encerrado)';
  finally
    CloseHandle(Snapshot);
  end;
{$ENDIF}
end;

class function TGerenciadorProcessos.ListaPidsDoJob: TStringList;
var
  {$IFDEF WINDOWS}
  Tam: DWORD;
  TamLista: DWORD;
  Ptr: PByte;
  Lista: PJobObjectBasicProcessIdList;
  PIds: PArrayDeIds;
  i: Integer;
  {$ENDIF}
begin
  Result := TStringList.Create;
{$IFDEF WINDOWS}
  { O job nao tem tamanho maximo de PIDs, entao o buffer e alocado com
    folga. Se a consulta falhar por falta de espaco, a lista volta vazia
    em vez de inventar um numero. }
  Tam := 8 + 4096 * SizeOf(ULONG_PTR);
  GetMem(Ptr, Tam);
  try
    TamLista := Tam;
    if not QueryInformationJobObject(ObterJob,
         JOB_OBJECT_BASIC_PROCESS_ID_LIST_CLASS, Ptr, TamLista, nil) then
      Exit;

    Lista := PJobObjectBasicProcessIdList(Ptr);
    PIds := @Lista^.ProcessIdList;
    for i := 0 to Integer(Lista^.NumberOfProcessIdsInList) - 1 do
      Result.Add(IntToStr(Integer(PIds^[i])));
  finally
    FreeMem(Ptr);
  end;
{$ENDIF}
end;

class function TGerenciadorProcessos.CapturarSaida(const AExe: string;
  const AArgs: TStrings; ATimeoutMs: Integer; out ASaida: string;
  out ACodigo: Integer): Boolean;
var
  i: Integer;
  Proc: TProcessoGerenciado;
  Args: TStringList;
  Trecho: string;
begin
  ASaida := '';
  ACodigo := -1;
  Result := False;
  if AExe = '' then
    Exit;

  Args := TStringList.Create;
  Proc := TProcessoGerenciado.Create;
  try
    for i := 0 to AArgs.Count - 1 do
      Args.Add(AArgs[i]);

    if not Proc.Iniciar(AExe, Args, nil, True) then
      Exit;

    { Nada de poWaitOnExit aqui. Quando o processo escreve em um pipe, o
      SO para o processo assim que o buffer enche; se o aplicativo espera
      a saida do processo antes de drainar o pipe, os dois ficam esperando
      um pelo outro e o programa trava para sempre. Por isso a espera
      aqui bombeia o pipe enquanto o processo corre, que e o que
      LerDisponivel existe para fazer.

      Este era um travamento real: `ffmpeg -version` escreve mais que o
      buffer do pipe e o Diagnostico do aplicativo ficava parado nele. }
    while Proc.Ativo do
    begin
      { LerDisponivel substitui a string recebida pelo que achou no buffer,
        entao e preciso acumular em outro lugar. Atribuir direto a ASaida
        fazia cada volta do laco descartar tudo que ja tinha sido lido, e o
        resultado dependia de quantas vezes o processo escrevia. }
      if Proc.LerDisponivel(Trecho) > 0 then
        ASaida := ASaida + Trecho;
      Sleep(5);
      Dec(ATimeoutMs);
      if ATimeoutMs <= 0 then
        break;
    end;
    ASaida := Trim(ASaida + Proc.LerTudo);
    ACodigo := Proc.CodigoSaida;
    Result := not Proc.Ativo;
  finally
    Proc.Free;
    Args.Free;
  end;
end;

class procedure TGerenciadorProcessos.EncerrarTodos;
begin
{$IFDEF WINDOWS}
  if GJob <> 0 then
    TerminateJobObject(GJob, 1);
{$ENDIF}
end;

class procedure TGerenciadorProcessos.LiberarJob;
begin
{$IFDEF WINDOWS}
  if GJob <> 0 then
  begin
    { Fechar o handle dispara KILL_ON_JOB_CLOSE, o que encerra qualquer
      processo remanescente sem depender de chamarmos um a um. }
    CloseHandle(GJob);
    GJob := 0;
  end;
{$ENDIF}
end;

class procedure TGerenciadorProcessos.EncerrarArvorePorPid(APai: DWORD);
begin
{$IFDEF WINDOWS}
  EncerrarArvorePorPidInterno(APai);
{$ENDIF}
end;

{ ------------------------------------------------------------------------ }
{ TProcessoGerenciado                                                       }
{ ------------------------------------------------------------------------ }

constructor TProcessoGerenciado.Create;
begin
  inherited Create;
  FProcesso  := TProcess.Create(nil);
  FArgs      := TStringList.Create;
  FCancelado := False;
  FNoJob     := False;
end;

destructor TProcessoGerenciado.Destroy;
begin
  { Um processo esquecido ainda ativo seria o caso classico de orfao. Como
    o job resolve isso no nivel do SO, aqui basta garantir o encerramento
    antes de soltar a referencia. }
  if Ativo then
    Encerrar(encForcar);
  FArgs.Free;
  FProcesso.Free;
  inherited Destroy;
end;

procedure TProcessoGerenciado.EscreverEntrada(const ATexto: string);
begin
  if (ATexto = '') or not Assigned(FProcesso) then
    Exit;
  try
    FProcesso.Input.Write(ATexto[1], Length(ATexto));
  except
    { Processo encerrado: nao ha mais stdin. Nao e erro. }
  end;
end;

function TProcessoGerenciado.Iniciar(const AExe: string;
  const AArgs: TStringList; const AEntrada: TStrings;
  ARedirecionar: Boolean): Boolean;
var
  i: Integer;
begin
  Result := False;
  if AExe = '' then
    Exit;

  FExe := AExe;
  FArgs.Clear;
  for i := 0 to AArgs.Count - 1 do
    FArgs.Add(AArgs[i]);

  FProcesso.Executable := AExe;
  for i := 0 to AArgs.Count - 1 do
    FProcesso.Parameters.Add(AArgs[i]);

  if ARedirecionar then
    FProcesso.Options := [poUsePipes, poStderrToOutPut, poNoConsole,
                          poRunSuspended]
  else
    { poWaitOnExit e propositalmente ausente: ele faz Execute devolver
      apenas quando o processo ja terminou, o que travaria a interface
      durante toda a conversao. Quem quiser esperar usa Aguardar, que
      bombeteia as mensagens e por isso mantem a janela viva. }
    FProcesso.Options := [poNoConsole];

  try
    FProcesso.Execute;
  except
    FExe := '';
    Exit;
  end;

  { Entra no job ainda suspenso e so depois roda. }
  FNoJob := not TGerenciadorProcessos.Vincular(FProcesso.ProcessHandle);

  if ARedirecionar then
    try
      FProcesso.Resume;
    except
      { Se a suspensao nao tiver sido aplicada, o processo ja roda e
        chamar Resume aqui seria um erro sem importancia. }
    end;

  if AEntrada <> nil then
    for i := 0 to AEntrada.Count - 1 do
      EscreverEntrada(AEntrada[i] + LineEnding);

  Result := True;
end;

function TProcessoGerenciado.LerDisponivel(out ATexto: string): Integer;
var
  Disponivel: Integer;
  Buf: array[0..8191] of Char;
begin
  ATexto := '';
  Result := 0;
  if not Assigned(FProcesso) then
    Exit;
  try
    if FProcesso.Output = nil then
      Exit;
    Disponivel := FProcesso.Output.NumBytesAvailable;
    if Disponivel <= 0 then
      Exit;
    if Disponivel > SizeOf(Buf) then
      Disponivel := SizeOf(Buf);
    Result := FProcesso.Output.Read(Buf, Disponivel);
    if Result > 0 then
      SetString(ATexto, PChar(@Buf[0]), Result);
  except
    Result := 0;
  end;
end;

function TProcessoGerenciado.Aguardar(AMaxMs: Integer;
  ABombeia: Boolean): Boolean;
var
  Inicio: QWord;
  Decorrido: Integer;
begin
  Inicio := GetTickCount64;
  repeat
    if not Ativo then
      Exit(True);
    { Espera curta e frappe entre uma checagem e outra. Esperar o processo
      inteiro antes de olhar Running deixaria a interface congelada; o
      Sleep pequeno mantem o laco barato e ainda repinta. }
    Sleep(10);
    if ABombeia and Assigned(GBombearMensagens) then
      GBombearMensagens;
    if AMaxMs <= 0 then
      Continue;
    Decorrido := Integer(GetTickCount64 - Inicio);
    if Decorrido >= AMaxMs then
      Exit(not Ativo);
  until False;
end;

function TProcessoGerenciado.LerTudo: string;
var
  Buf: array[0..8191] of Char;
  N: Integer;
  Trecho: string;
begin
  { Uma TStringList guardaria cada linha duplicada em memoria, e o aviso de
    erro do ImageMagick pode ter dezenas de linhas; a concatenacao direta
    e o caminho mais barato. }
  Result := '';
  if not Assigned(FProcesso) then
    Exit;
  try
    if FProcesso.Output = nil then
      Exit;
    repeat
      N := FProcesso.Output.Read(Buf, SizeOf(Buf));
      if N > 0 then
      begin
        SetString(Trecho, PChar(@Buf[0]), N);
        Result := Result + Trecho;
      end;
    until N <= 0;
  except
    { Processo encerrado: o pipe pode dar erro ao ser lido. O que ja foi
      lido continua valendo. }
  end;
end;

procedure TProcessoGerenciado.Encerrar(AModo: TModoEncerramento);
var
  Tentativas: Integer;
begin
  FCancelado := True;
  if not Ativo then
    Exit;

  if AModo = encEncerrarSuave then
  begin
    { O ffmpeg trata 'q' como "termine o arquivo atual e saia", o que
      preserva a saida valida. O yt-dlp tambem respeita o cancelamento
      gracioso. }
    EscreverEntrada('q');

    { Espera curta pelo termino voluntario antes de partir para o bruto.
      O laco fica sem ProcessMessages de proposito: quem chama estarotina e
      um laco que ja bombeia a fila de mensagens, e um segundo repaint
      dentro da espera so causaria tremida. }
    Tentativas := 0;
    while Ativo and (Tentativas < 40) do
    begin
      Sleep(50);
      Inc(Tentativas);
    end;
    if not Ativo then
      Exit;
  end;

  EncerrarArvore;
end;

procedure TProcessoGerenciado.EncerrarArvore;
begin
  if not Ativo then
    Exit;
  { Primeiro os filhos deste PID, depois ele. }
{$IFDEF WINDOWS}
  EncerrarArvorePorPidInterno(DWORD(PID));
{$ENDIF}
  try
    FProcesso.Terminate(1);
  except
  end;
end;

function TProcessoGerenciado.Ativo: Boolean;
begin
  Result := False;
  if not Assigned(FProcesso) then
    Exit;
  try
    Result := FProcesso.Running;
  except
    Result := False;
  end;
end;

function TProcessoGerenciado.PID: Integer;
begin
  Result := 0;
  if not Assigned(FProcesso) then
    Exit;
  Result := FProcesso.ProcessID;
end;

function TProcessoGerenciado.CodigoSaida: Integer;
begin
  Result := -1;
  if not Assigned(FProcesso) then
    Exit;
  try
    Result := FProcesso.ExitCode;
  except
    Result := -1;
  end;
end;

function TProcessoGerenciado.Cancelado: Boolean;
begin
  Result := FCancelado;
end;

function TProcessoGerenciado.HandleProcesso: THandle;
begin
  Result := 0;
  if not Assigned(FProcesso) then
    Exit;
  Result := FProcesso.ProcessHandle;
end;

function TProcessoGerenciado.EstaNoJob: Boolean;
begin
  Result := TGerenciadorProcessos.EstaVinculado(HandleProcesso);
end;

end.