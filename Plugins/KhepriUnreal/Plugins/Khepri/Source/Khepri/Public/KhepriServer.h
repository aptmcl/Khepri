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

  // Register an operation handler
  void RegisterOperation(const FString& Name, TFunction<void(FKhepriChannel&)> Handler);

private:
  // Dispatch protocol
  void HandleConnection(FSocket* ClientSocket);
  void ProcessCommands(FSocket* ClientSocket);

  // Thread management
  FRunnableThread* Thread;
  TAtomic<bool> bStopping;
  TAtomic<bool> bRunning;

  // Server socket
  FSocket* ListenerSocket;
  static constexpr int32 Port = 11010;

  // Operation dispatch
  TMap<FString, int32> OperationNameToIndex;
  TArray<TFunction<void(FKhepriChannel&)>> OperationHandlers;

  // Channel for current connection
  FKhepriChannel Channel;

  // Game thread synchronization
  FEvent* GameThreadDone;
};
