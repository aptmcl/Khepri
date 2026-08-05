// KhepriServer.cpp — TCP listener thread for Khepri protocol

#include "KhepriServer.h"
#include "KhepriPrimitives.h"
#include "KhepriModule.h"
#include "Async/Async.h"
#include "Common/TcpSocketBuilder.h"
#include "Editor.h"
#include "Engine/Selection.h"
#include <stdexcept>

FKhepriServer::FKhepriServer()
  : Thread(nullptr)
  , bStopping(false)
  , bRunning(false)
  , ListenerSocket(nullptr)
  , GameThreadDone(nullptr)
{
  GameThreadDone = FPlatformProcess::GetSynchEventFromPool(false);
}

FKhepriServer::~FKhepriServer()
{
  StopServer();
  if (GameThreadDone)
  {
    FPlatformProcess::ReturnSynchEventToPool(GameThreadDone);
    GameThreadDone = nullptr;
  }
}

bool FKhepriServer::Init()
{
  return true;
}

uint32 FKhepriServer::Run()
{
  bRunning = true;

  while (!bStopping)
  {
    // Create listener socket
    ListenerSocket = FTcpSocketBuilder(TEXT("KhepriListener"))
      .AsReusable()
      .BoundToPort(Port)
      .Listening(1)
      .Build();

    if (!ListenerSocket)
    {
      UE_LOG(LogKhepri, Error, TEXT("Khepri: Failed to create listener socket on port %d"), Port);
      FPlatformProcess::Sleep(1.0f);
      continue;
    }

    UE_LOG(LogKhepri, Log, TEXT("Khepri: Listening on port %d"), Port);

    // Accept connections loop
    while (!bStopping)
    {
      bool bHasPendingConnection = false;
      if (ListenerSocket->HasPendingConnection(bHasPendingConnection) && bHasPendingConnection)
      {
        FSocket* ClientSocket = ListenerSocket->Accept(TEXT("KhepriClient"));
        if (ClientSocket)
        {
          UE_LOG(LogKhepri, Log, TEXT("Khepri: Client connected"));
          HandleConnection(ClientSocket);
          UE_LOG(LogKhepri, Log, TEXT("Khepri: Client disconnected"));

          ClientSocket->Close();
          ISocketSubsystem::Get(PLATFORM_SOCKETSUBSYSTEM)->DestroySocket(ClientSocket);
        }
      }
      else
      {
        FPlatformProcess::Sleep(0.1f);
      }
    }

    // Cleanup listener
    if (ListenerSocket)
    {
      ListenerSocket->Close();
      ISocketSubsystem::Get(PLATFORM_SOCKETSUBSYSTEM)->DestroySocket(ListenerSocket);
      ListenerSocket = nullptr;
    }
  }

  bRunning = false;
  return 0;
}

void FKhepriServer::Stop()
{
  bStopping = true;
}

void FKhepriServer::StartServer()
{
  Thread = FRunnableThread::Create(this, TEXT("KhepriServer"), 0, TPri_BelowNormal);
}

void FKhepriServer::StopServer()
{
  bStopping = true;

  if (ListenerSocket)
  {
    ListenerSocket->Close();
  }

  if (Thread)
  {
    Thread->WaitForCompletion();
    delete Thread;
    Thread = nullptr;
  }
}

void FKhepriServer::RegisterOperation(const FString& Name, const FString& Canonical,
                                      TFunction<void(FKhepriChannel&)> Handler)
{
  int32 Index = OperationHandlers.Add(Handler);
  OperationCanonicals.Add(Canonical);
  OperationNameToIndex.Add(Name, Index);
}

// ProvideOperation (opcode 0): Julia sends the method name and the canonical
// signature it expects; we answer the assigned opcode, or NOTOK on an unknown
// name or a canonical mismatch. Both the socket-thread path and the mid-batch
// game-thread path dispatch HERE — the logic used to be duplicated inline in
// both, which is exactly how a validation fix could reach one path and miss
// the other. The mismatch message mirrors the C# side (RMIFy.RMIFor) so
// signature drift reads the same on every backend.
void FKhepriServer::HandleProvideOperation()
{
  FString OpName = Channel.ReadString();
  FString ExpectedCanonical = Channel.ReadString();
  int32* FoundIndex = OperationNameToIndex.Find(OpName);
  if (!FoundIndex)
  {
    UE_LOG(LogKhepri, Warning, TEXT("Khepri: Unknown operation '%s'"), *OpName);
    Channel.WriteByte(1);
    Channel.WriteString(FString::Printf(TEXT("Method '%s' not found in Unreal primitives"), *OpName));
  }
  else if (!OperationCanonicals[*FoundIndex].IsEmpty() &&
           OperationCanonicals[*FoundIndex] != ExpectedCanonical)
  {
    UE_LOG(LogKhepri, Warning, TEXT("Khepri: Signature mismatch for '%s': Julia expects %s but Unreal has %s"),
           *OpName, *ExpectedCanonical, *OperationCanonicals[*FoundIndex]);
    Channel.WriteByte(1);
    Channel.WriteString(FString::Printf(TEXT("Signature mismatch for '%s': Julia expects %s but Unreal has %s"),
                                        *OpName, *ExpectedCanonical, *OperationCanonicals[*FoundIndex]));
  }
  else
  {
    // Success: write OK prefix + new opcode (1-based: index + 1)
    Channel.WriteByte(0);
    Channel.WriteInt32(*FoundIndex + 1);
  }
  Channel.EndFrame();
}

void FKhepriServer::HandleConnection(FSocket* ClientSocket)
{
  // Ensure blocking mode so NetRecvBytes can read complete frames
  // without returning prematurely with 0 bytes on partial data.
  ClientSocket->SetNonBlocking(false);
  ClientSocket->SetNoDelay(true);

  Channel.SetSocket(ClientSocket);
  Channel.ClearRegistries();

  try
  {
    ProcessCommands(ClientSocket);
    UE_LOG(LogKhepri, Log, TEXT("Khepri: ProcessCommands ended normally (connection closed by client)"));
  }
  catch (const std::exception& e)
  {
    UE_LOG(LogKhepri, Error, TEXT("Khepri: ProcessCommands exception: %s"), ANSI_TO_TCHAR(e.what()));
  }
  catch (...)
  {
    UE_LOG(LogKhepri, Error, TEXT("Khepri: ProcessCommands unknown exception"));
  }

  // Log socket state at disconnect
  if (ClientSocket)
  {
    ESocketConnectionState State = ClientSocket->GetConnectionState();
    UE_LOG(LogKhepri, Log, TEXT("Khepri: Socket state at disconnect: %d"), (int32)State);
  }

  Channel.SetSocket(nullptr);
}

void FKhepriServer::ProcessCommands(FSocket* ClientSocket)
{
  // Operation 0 is ProvideOperation (the bootstrap mechanism).
  // Runtime-registered operations start at index 1.
  // The operations list stores only runtime handlers; opcode N>0 maps to index N-1.

  while (!bStopping)
  {
    // Wait for data with a short timeout to allow checking bStopping
    if (!ClientSocket->Wait(ESocketWaitConditions::WaitForRead, FTimespan::FromSeconds(0.5)))
    {
      continue;
    }

    // Read a length-prefixed frame; the opcode is inside the frame payload.
    // Returns false on connection close or error.
    if (!Channel.BeginFrame())
    {
      UE_LOG(LogKhepri, Log, TEXT("Khepri: BeginFrame returned false — connection closed or read error"));
      break;
    }

    int32 Opcode = Channel.ReadInt32();

    if (Opcode == 0)
    {
      HandleProvideOperation();
    }
    else if (Opcode > 0)
    {
      // Batch-execute operations on game thread.
      // After each operation, probe the socket for more data (20ms timeout).
      // If another frame arrives within the window, execute it immediately
      // without yielding back to the socket thread — same pattern as AutoCAD/Revit.
      GameThreadDone->Reset();

      AsyncTask(ENamedThreads::GameThread, [this, Opcode, ClientSocket]()
      {
        int32 Op = Opcode;
        while (!bStopping)
        {
          if (Op == 0)
          {
            // ProvideOperation arrived mid-batch
            HandleProvideOperation();
          }
          else if (Op > 0)
          {
            int32 HandlerIndex = Op - 1;
            if (OperationHandlers.IsValidIndex(HandlerIndex))
            {
              try
              {
                Channel.WriteByte(0);
                OperationHandlers[HandlerIndex](Channel);
              }
              catch (const std::exception& e)
              {
                UE_LOG(LogKhepri, Error, TEXT("Khepri: opcode %d threw exception: %s"), HandlerIndex, ANSI_TO_TCHAR(e.what()));
                // The handler may have written part of its reply after the 0x00 OK
                // prefix; shipping that would make Julia decode garbage as success.
                // Discard the partial payload and ship a NOTOK error frame instead
                // (the CSG-stub pattern; mirrors C# RMIFy's error serialization).
                Channel.ResetResponse();
                Channel.WriteByte(1);
                Channel.WriteString(FString::Printf(TEXT("Unreal exception in opcode %d: %s"), Op, ANSI_TO_TCHAR(e.what())));
                Channel.EndFrame();
                break;
              }
              catch (...)
              {
                UE_LOG(LogKhepri, Error, TEXT("Khepri: opcode %d threw unknown exception"), HandlerIndex);
                Channel.ResetResponse();
                Channel.WriteByte(1);
                Channel.WriteString(FString::Printf(TEXT("Unreal unknown exception in opcode %d"), Op));
                Channel.EndFrame();
                break;
              }
            }
            else
            {
              UE_LOG(LogKhepri, Error, TEXT("Khepri: Invalid operation index %d"), HandlerIndex);
              Channel.WriteByte(1);
              Channel.WriteString(FString::Printf(TEXT("Invalid operation index %d"), HandlerIndex));
            }
            Channel.EndFrame();
          }
          else
          {
            UE_LOG(LogKhepri, Error, TEXT("Khepri: Invalid opcode %d in batch"), Op);
            // An empty response frame would make Julia's prefix read hit EOF;
            // ship a proper NOTOK so the client sees a BackendError instead.
            Channel.WriteByte(1);
            Channel.WriteString(FString::Printf(TEXT("Invalid opcode %d"), Op));
            Channel.EndFrame();
            break;
          }

          // Probe socket for more data (20ms timeout)
          if (!ClientSocket->Wait(ESocketWaitConditions::WaitForRead,
                                   FTimespan::FromMilliseconds(20)))
            break;  // No more data — exit batch

          // Read next frame on game thread (socket thread is blocked)
          if (!Channel.BeginFrame())
            break;
          Op = Channel.ReadInt32();
        }
        GameThreadDone->Trigger();
      });

      GameThreadDone->Wait();

      // If a deferred selection was started, poll until the editor selection changes
      if (KhepriPrimitives::bSelectionPending)
      {
        UE_LOG(LogKhepri, Log, TEXT("Khepri: Waiting for user selection..."));
        while (!bStopping && KhepriPrimitives::bSelectionPending)
        {
          FPlatformProcess::Sleep(0.1f);

          // Check editor selection on game thread
          GameThreadDone->Reset();
          AsyncTask(ENamedThreads::GameThread, [this]()
          {
            if (!GEditor || !KhepriPrimitives::bSelectionPending)
            {
              GameThreadDone->Trigger();
              return;
            }

            USelection* Selection = GEditor->GetSelectedActors();
            if (Selection && Selection->Num() > 0)
            {
              // User selected something — write the deferred response
              TArray<int32> SelectedIds;
              const auto& Registry = Channel.GetActorRegistry();
              for (int32 i = 0; i < Selection->Num(); i++)
              {
                AActor* SelActor = Cast<AActor>(Selection->GetSelectedObject(i));
                if (!SelActor) continue;
                int32 Idx = Registry.IndexOfByKey(SelActor);
                if (Idx != INDEX_NONE)
                  SelectedIds.Add(Idx);
              }

              // Write length-prefixed int array (no framing — raw deferred data).
              // Outside a frame, WriteInt32 sends directly to the socket.
              Channel.WriteInt32(SelectedIds.Num());
              for (int32 Id : SelectedIds)
                Channel.WriteInt32(Id);

              KhepriPrimitives::bSelectionPending = false;

              if (!KhepriPrimitives::bSelectMany)
              {
                GEditor->SelectNone(true, true, false);
              }
            }
            GameThreadDone->Trigger();
          });
          GameThreadDone->Wait();
        }
      }
    }
    else
    {
      UE_LOG(LogKhepri, Error, TEXT("Khepri: Invalid opcode %d"), Opcode);
      // See the batch-path twin: an empty frame starves Julia's prefix read.
      Channel.WriteByte(1);
      Channel.WriteString(FString::Printf(TEXT("Invalid opcode %d"), Opcode));
      Channel.EndFrame();
    }
  }
}
