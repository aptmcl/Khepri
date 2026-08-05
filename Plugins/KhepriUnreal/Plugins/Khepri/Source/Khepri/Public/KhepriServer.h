// KhepriServer.h — TCP listener thread for Khepri protocol
// FRunnable subclass that listens on port 11010 for Julia connections.
// Uses the standard Khepri length-prefixed framing protocol:
//   Each message is Int32 length + payload. Inside the payload:
//   opcode==0 → ProvideOperation: register by name, return assigned opcode
//   opcode>0  → execute handler, response prefixed with 0x00 (OK) or 0x01 (NOTOK)

#pragma once

#include "CoreMinimal.h"
#include "HAL/Runnable.h"
#include "KhepriChannel.h"

class FKhepriServer : public FRunnable
{
public:
  FKhepriServer();
  virtual ~FKhepriServer() override;

  // FRunnable interface
  virtual bool Init() override;
  virtual uint32 Run() override;
  virtual void Stop() override;

  // Start/stop the server thread
  void StartServer();
  void StopServer();

  bool IsRunning() const { return bRunning; }

  // Register an operation handler. Canonical is the signature string the Julia
  // side computes for this operation (canonical_signature in KhepriBase's
  // Primitives.jl — e.g. "AActor(FVector,Single,UMaterial)"); ProvideOperation
  // validates Julia's expectation against it so protocol drift surfaces as a
  // clean NOTOK at registration time instead of decoding garbage arguments.
  // Pass an empty string only for operations with no Julia-side declaration.
  void RegisterOperation(const FString& Name, const FString& Canonical,
                         TFunction<void(FKhepriChannel&)> Handler);

private:
  // Dispatch protocol
  void HandleConnection(FSocket* ClientSocket);
  void ProcessCommands(FSocket* ClientSocket);
  void HandleProvideOperation();

  // Thread management
  FRunnableThread* Thread;
  TAtomic<bool> bStopping;
  TAtomic<bool> bRunning;

  // Server socket
  FSocket* ListenerSocket;
  static constexpr int32 Port = 11010;

  // Operation dispatch. OperationCanonicals is index-parallel to
  // OperationHandlers (empty string = no Julia-side declaration to validate).
  TMap<FString, int32> OperationNameToIndex;
  TArray<TFunction<void(FKhepriChannel&)>> OperationHandlers;
  TArray<FString> OperationCanonicals;

  // Channel for current connection
  FKhepriChannel Channel;

  // Game thread synchronization
  FEvent* GameThreadDone;
};
