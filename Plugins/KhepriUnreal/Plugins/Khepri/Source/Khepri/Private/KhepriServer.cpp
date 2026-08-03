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

void FKhepriServer::RegisterOperation(const FString& Name, TFunction<void(FKhepriChannel&)> Handler)
{
  int32 Index = OperationHandlers.Add(Handler);
  OperationNameToIndex.Add(Name, Index);
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
      // ProvideOperation: Julia sends method name + canonical signature.
      // We read both but ignore the canonical (no reflection in C++).
      FString OpName = Channel.ReadString();
      FString Canonical = Channel.ReadString(); // consumed but not validated

      int32* FoundIndex = OperationNameToIndex.Find(OpName);
      if (FoundIndex)
      {
        // Success: write OK prefix + new opcode (1-based: index + 1)
        Channel.WriteByte(0);
        Channel.WriteInt32(*FoundIndex + 1);
      }
      else
      {
        // Failure: write NOTOK prefix + error message
        UE_LOG(LogKhepri, Warning, TEXT("Khepri: Unknown operation '%s'"), *OpName);
        Channel.WriteByte(1);
        Channel.WriteString(FString::Printf(TEXT("Method '%s' not found in Unreal primitives"), *OpName));
      }
      Channel.EndFrame();
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
            FString OpName = Channel.ReadString();
            FString Canonical = Channel.ReadString();
            int32* FoundIndex = OperationNameToIndex.Find(OpName);
            if (FoundIndex)
            {
              Channel.WriteByte(0);
              Channel.WriteInt32(*FoundIndex + 1);
            }
            else
            {
              UE_LOG(LogKhepri, Warning, TEXT("Khepri: Unknown operation '%s'"), *OpName);
              Channel.WriteByte(1);
              Channel.WriteString(FString::Printf(TEXT("Method '%s' not found in Unreal primitives"), *OpName));
            }
            Channel.EndFrame();
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
                Channel.EndFrame();
                break;
              }
              catch (...)
              {
                UE_LOG(LogKhepri, Error, TEXT("Khepri: opcode %d threw unknown exception"), HandlerIndex);
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
      Channel.EndFrame();
    }
  }
}
