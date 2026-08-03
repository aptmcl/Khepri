// KhepriModule.h — Plugin module lifecycle
// Creates FKhepriServer on startup, stops on shutdown.
// Editor module type (loaded in editor only).

#pragma once

#include "CoreMinimal.h"
#include "Modules/ModuleManager.h"

DECLARE_LOG_CATEGORY_EXTERN(LogKhepri, Log, All);

class FKhepriServer;

class FKhepriModule : public IModuleInterface
{
public:
  virtual void StartupModule() override;
  virtual void ShutdownModule() override;

private:
  TUniquePtr<FKhepriServer> Server;
};
