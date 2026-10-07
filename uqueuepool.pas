unit uQueuePool;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, SyncObjs;

type
  { TPoolTask
    Trabalho unitário entregue aos trabalhadores do pool. O worker chama
    Executar dentro da própria thread; a thread da interface é quem
    lê os resultados (RetirarConcluidos) e decide o que fazer com eles.
    Os campos de resultado são escritos pelo worker e lidos pela
    interface, nunca ao mesmo tempo — o que desobriga de travas extras. }
  TPoolTask = class
  public
    procedure Executar; virtual; abstract;
  end;

  { TQueuePool

    Pool de threads com fila FIFO e concorrência limitada. As tarefas
    entram por Enfileirar (qualquer thread) e saem concluídas por
    RetirarConcluidos, normalmente chamada de um timer da interface.

    O desenho evita de propósito TThread.Synchronize: como os resultados
    ficam acumulados numa lista protegida por trava, o teardown (Parar ou
    Destroy) nunca depende do message loop da interface — condição que,
    com Synchronize, criaria o deadlock clássico de parar os workers
    justamente a partir da thread em que eles aguardam entrega. }
  TQueuePool = class
  private
    type
      TPoolThread = class(TThread)
      private
        FDono: TQueuePool;
      protected
        procedure Execute; override;
      public
        constructor Create(ADono: TQueuePool);
      end;
  private
    FFila      : TThreadList;  { de TPoolTask, na ordem de chegada }
    FConclu    : TThreadList;  { de TPoolTask prontos, aguardando retirada }
    FEvento    : TEvent;
    FParando   : Boolean;
    FLimite    : Integer;
    FSequencia : Int64;
    FThreads   : TList;        { de TPoolThread }
    function RetirarPendente: TPoolTask;
    procedure AdicionarConcluida(ATarefa: TPoolTask);
  public
    constructor Create(ALimite: Integer);
    destructor Destroy; override;

    { Põe uma tarefa no fim da fila. Depois de Parar/Destroy não aceita
      mais trabalho: a tarefa é libertada na hora. }
    procedure Enfileirar(ATarefa: TPoolTask);

    { Move as tarefas concluídas para ALista. Quem chama passa a ser o
      dono delas. Devolve quantas foram movidas. }
    function RetirarConcluidos(ALista: TList): Integer;

    { Encerra o pool para sempre: nenhuma thread volta a pegar trabalho,
      a fila pendente é esvaziada e os trabalhadores são juntados. Pode
      ser chamado da thread da interface sem risco de deadlock. }
    procedure Parar;

    { Sufixo único para arquivos temporários criados pelas tarefas. }
    function NovoIdentificador: string;

    function Pendentes: Integer;
    property Limite: Integer read FLimite;
  end;

implementation

{ TQueuePool }

constructor TQueuePool.TPoolThread.Create(ADono: TQueuePool);
begin
  inherited Create(False);
  FDono := ADono;
  FreeOnTerminate := False;
end;

procedure TQueuePool.TPoolThread.Execute;
var
  Tarefa: TPoolTask;
begin
  { Loop clássico de consumidor: tira a próxima, executa, deposita o
    resultado. Sem FEvento o thread giraria em barriga até receber
    trabalho; com ele, dorme 250 ms de cada vez enquanto a fila está
    vazia, o que também limita o atraso de acordar para no máximo isso. }
  while not Terminated do
  begin
    Tarefa := FDono.RetirarPendente;
    if Tarefa = nil then
    begin
      if FDono.FEvento.WaitFor(250) = wrTimeout then
        Continue;
      if Terminated or FDono.FParando then
        Break;
      Continue;
    end;

    try
      Tarefa.Executar;
    except
      { Falha isolada de uma tarefa não derruba o pool nem os irmãos. }
    end;

    FDono.AdicionarConcluida(Tarefa);
  end;
end;

constructor TQueuePool.Create(ALimite: Integer);
var
  i: Integer;
begin
  inherited Create;
  if ALimite < 1 then
    ALimite := 1;
  FLimite    := ALimite;
  FParando   := False;
  FSequencia := 0;
  FFila      := TThreadList.Create;
  FConclu    := TThreadList.Create;
  FEvento    := TEvent.Create(nil, True, False, '');
  FThreads   := TList.Create;
  for i := 1 to ALimite do
    FThreads.Add(TPoolThread.Create(Self));
end;

destructor TQueuePool.Destroy;
var
  i: Integer;
  L: TList;
begin
  if not FParando then
  begin
    L := FFila.LockList;
    try
      FParando := True;
      for i := 0 to L.Count - 1 do
        TPoolTask(L[i]).Free;
      L.Clear;
    finally
      FFila.UnlockList;
    end;
  end;

  FEvento.SetEvent;
  for i := 0 to FThreads.Count - 1 do
  begin
    TPoolThread(FThreads[i]).Terminate;
    TPoolThread(FThreads[i]).WaitFor;
    TPoolThread(FThreads[i]).Free;
  end;
  FThreads.Free;

  L := FConclu.LockList;
  try
    for i := 0 to L.Count - 1 do
      TPoolTask(L[i]).Free;
    L.Clear;
  finally
    FConclu.UnlockList;
  end;

  FFila.Free;
  FConclu.Free;
  FEvento.Free;
  inherited Destroy;
end;

function TQueuePool.RetirarPendente: TPoolTask;
var
  L: TList;
begin
  Result := nil;
  L := FFila.LockList;
  try
    { FParando é checado dentro da mesma trava usada por Parar para
      esvaziar a fila: depois de Parar nenhum worker volta a pegar
      tarefa. }
    if (not FParando) and (L.Count > 0) then
    begin
      Result := TPoolTask(L[0]);
      L.Delete(0);
    end;
  finally
    FFila.UnlockList;
  end;
end;

procedure TQueuePool.AdicionarConcluida(ATarefa: TPoolTask);
var
  L: TList;
begin
  L := FConclu.LockList;
  try
    L.Add(ATarefa);
  finally
    FConclu.UnlockList;
  end;
end;

procedure TQueuePool.Enfileirar(ATarefa: TPoolTask);
var
  L: TList;
begin
  if ATarefa = nil then
    Exit;
  L := FFila.LockList;
  try
    if FParando then
    begin
      ATarefa.Free;
      Exit;
    end;
    L.Add(ATarefa);
  finally
    FFila.UnlockList;
  end;
  FEvento.SetEvent;
end;

function TQueuePool.RetirarConcluidos(ALista: TList): Integer;
var
  L: TList;
begin
  Result := 0;
  if ALista = nil then
    Exit;
  L := FConclu.LockList;
  try
    if L.Count > 0 then
    begin
      ALista.AddList(L);
      Result := L.Count;
      L.Clear;
    end;
  finally
    FConclu.UnlockList;
  end;
end;

procedure TQueuePool.Parar;
var
  i: Integer;
  L: TList;
begin
  if FParando then
    Exit;

  L := FFila.LockList;
  try
    FParando := True;
    for i := 0 to L.Count - 1 do
      TPoolTask(L[i]).Free;
    L.Clear;
  finally
    FFila.UnlockList;
  end;

  FEvento.SetEvent;
  for i := 0 to FThreads.Count - 1 do
  begin
    TPoolThread(FThreads[i]).WaitFor;
    TPoolThread(FThreads[i]).Free;
  end;
  FThreads.Clear;
end;

function TQueuePool.NovoIdentificador: string;
var
  L: TList;
begin
  L := FFila.LockList;
  try
    Inc(FSequencia);
    Result := IntToHex(FSequencia, 8);
  finally
    FFila.UnlockList;
  end;
end;

function TQueuePool.Pendentes: Integer;
var
  L: TList;
begin
  L := FFila.LockList;
  try
    Result := L.Count;
  finally
    FFila.UnlockList;
  end;
end;

end.