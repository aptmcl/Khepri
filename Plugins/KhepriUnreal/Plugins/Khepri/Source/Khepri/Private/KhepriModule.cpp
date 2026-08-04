// KhepriModule.cpp — Plugin module lifecycle

#include "KhepriModule.h"
#include "KhepriServer.h"
#include "KhepriPrimitives.h"

DEFINE_LOG_CATEGORY(LogKhepri);

#define LOCTEXT_NAMESPACE "FKhepriModule"

void FKhepriModule::StartupModule()
{
  UE_LOG(LogKhepri, Log, TEXT("Khepri: Starting plugin module"));

  Server = MakeUnique<FKhepriServer>();
  KhepriPrimitives::RegisterAllOperations(*Server);
  Server->StartServer();

  UE_LOG(LogKhepri, Log, TEXT("Khepri: Server started on port 11010"));
}

void FKhepriModule::ShutdownModule()
{
  UE_LOG(LogKhepri, Log, TEXT("Khepri: Shutting down plugin module"));

  if (Server)
  {
    Server->StopServer();
    Server.Reset();
  }
}

#undef LOCTEXT_NAMESPACE

IMPLEMENT_MODULE(FKhepriModule, Khepri)
