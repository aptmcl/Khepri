// KhepriChannel.cpp — Binary protocol over FSocket

#include "KhepriChannel.h"
#include "KhepriModule.h"

FKhepriChannel::FKhepriChannel()
  : CurrentParentIndex(-1)
  , CurrentMaterialIndex(-1)
  , Socket(nullptr)
  , ReadPos(0)
  , bInFrame(false)
{
}

FKhepriChannel::~FKhepriChannel()
{
}

void FKhepriChannel::SetSocket(FSocket* InSocket)
{
  Socket = InSocket;
}

bool FKhepriChannel::IsConnected() const
{
  return Socket != nullptr && Socket->GetConnectionState() == SCS_Connected;
}

// =============================================================================
// Network-level raw I/O (always goes to socket)
// =============================================================================

bool FKhepriChannel::NetRecvBytes(uint8* Data, int32 Count)
{
  int32 TotalRead = 0;
  while (TotalRead < Count)
  {
    // Wait for data before calling Recv — Unreal sockets may be non-blocking,
    // so Recv can return 0 bytes if called before data arrives.
    if (!Socket->Wait(ESocketWaitConditions::WaitForRead, FTimespan::FromSeconds(30.0)))
    {
      return false; // Timeout or error
    }
    int32 BytesRead = 0;
    if (!Socket->Recv(Data + TotalRead, Count - TotalRead, BytesRead))
    {
      return false;
    }
    if (BytesRead <= 0)
    {
      return false;
    }
    TotalRead += BytesRead;
  }
  return true;
}

bool FKhepriChannel::NetSendBytes(const uint8* Data, int32 Count)
{
  int32 TotalSent = 0;
  while (TotalSent < Count)
  {
    int32 BytesSent = 0;
    if (!Socket->Send(Data + TotalSent, Count - TotalSent, BytesSent))
    {
      return false;
    }
    if (BytesSent <= 0)
    {
      return false;
    }
    TotalSent += BytesSent;
  }
  return true;
}

// =============================================================================
// Framing — reads/writes go through memory buffers when a frame is active
// =============================================================================

bool FKhepriChannel::RecvBytes(uint8* Data, int32 Count)
{
  if (bInFrame)
  {
    if (ReadPos + Count > ReadBuffer.Num())
    {
      return false;
    }
    FMemory::Memcpy(Data, ReadBuffer.GetData() + ReadPos, Count);
    ReadPos += Count;
    return true;
  }
  return NetRecvBytes(Data, Count);
}

bool FKhepriChannel::SendBytes(const uint8* Data, int32 Count)
{
  if (bInFrame)
  {
    WriteBuffer.Append(Data, Count);
    return true;
  }
  return NetSendBytes(Data, Count);
}

bool FKhepriChannel::BeginFrame()
{
  // Read the Int32 frame length from the network
  int32 FrameLen = 0;
  if (!NetRecvBytes(reinterpret_cast<uint8*>(&FrameLen), sizeof(int32)))
  {
    UE_LOG(LogKhepri, Log, TEXT("Khepri: BeginFrame — failed to read frame length (connection closed?)"));
    return false;
  }
  if (FrameLen <= 0)
  {
    UE_LOG(LogKhepri, Warning, TEXT("Khepri: BeginFrame — invalid frame length: %d"), FrameLen);
    return false;
  }

  // Read the frame payload into the read buffer
  ReadBuffer.SetNumUninitialized(FrameLen);
  if (!NetRecvBytes(ReadBuffer.GetData(), FrameLen))
  {
    UE_LOG(LogKhepri, Warning, TEXT("Khepri: BeginFrame — failed to read frame payload (%d bytes)"), FrameLen);
    return false;
  }
  ReadPos = 0;

  // Reset the write buffer for the response
  WriteBuffer.Reset();
  bInFrame = true;
  return true;
}

void FKhepriChannel::EndFrame()
{
  // Write the response as a length-prefixed frame
  int32 ResponseLen = WriteBuffer.Num();
  NetSendBytes(reinterpret_cast<const uint8*>(&ResponseLen), sizeof(int32));
  if (ResponseLen > 0)
  {
    NetSendBytes(WriteBuffer.GetData(), ResponseLen);
  }
  bInFrame = false;
}

// =============================================================================
// Primitive reads (little-endian, matching Julia)
// =============================================================================

uint8 FKhepriChannel::ReadByte()
{
  uint8 Value = 0;
  RecvBytes(&Value, 1);
  return Value;
}

bool FKhepriChannel::ReadBool()
{
  uint8 Value = ReadByte();
  return Value == 1;
}

int32 FKhepriChannel::ReadInt32()
{
  int32 Value = 0;
  RecvBytes(reinterpret_cast<uint8*>(&Value), sizeof(int32));
  return Value;
}

int64 FKhepriChannel::ReadInt64()
{
  int64 Value = 0;
  RecvBytes(reinterpret_cast<uint8*>(&Value), sizeof(int64));
  return Value;
}

float FKhepriChannel::ReadFloat()
{
  float Value = 0.0f;
  RecvBytes(reinterpret_cast<uint8*>(&Value), sizeof(float));
  return Value;
}

double FKhepriChannel::ReadDouble()
{
  double Value = 0.0;
  RecvBytes(reinterpret_cast<uint8*>(&Value), sizeof(double));
  return Value;
}

FString FKhepriChannel::ReadString()
{
  // .NET 7-bit variable-length encoding for string length
  int32 Length = 0;
  int32 Shift = 0;
  uint8 Byte;
  do
  {
    RecvBytes(&Byte, 1);
    Length |= (Byte & 0x7F) << Shift;
    Shift += 7;
  } while (Byte & 0x80);

  if (Length == 0)
  {
    return FString();
  }

  TArray<uint8> Buffer;
  Buffer.SetNumUninitialized(Length);
  RecvBytes(Buffer.GetData(), Length);

  // Convert UTF-8 to FString
  FUTF8ToTCHAR Converter(reinterpret_cast<const ANSICHAR*>(Buffer.GetData()), Length);
  return FString(Converter.Length(), Converter.Get());
}

// =============================================================================
// Primitive writes
// =============================================================================

void FKhepriChannel::WriteByte(uint8 Value)
{
  SendBytes(&Value, 1);
}

void FKhepriChannel::WriteBool(bool Value)
{
  WriteByte(Value ? 1 : 2);
}

void FKhepriChannel::WriteInt32(int32 Value)
{
  SendBytes(reinterpret_cast<const uint8*>(&Value), sizeof(int32));
}

void FKhepriChannel::WriteInt64(int64 Value)
{
  SendBytes(reinterpret_cast<const uint8*>(&Value), sizeof(int64));
}

void FKhepriChannel::WriteFloat(float Value)
{
  SendBytes(reinterpret_cast<const uint8*>(&Value), sizeof(float));
}

void FKhepriChannel::WriteDouble(double Value)
{
  SendBytes(reinterpret_cast<const uint8*>(&Value), sizeof(double));
}

void FKhepriChannel::WriteString(const FString& Value)
{
  // Convert to UTF-8
  FTCHARToUTF8 Converter(*Value);
  int32 Length = Converter.Length();

  // .NET 7-bit variable-length encoding
  uint32 ULength = static_cast<uint32>(Length);
  do
  {
    uint8 Byte = ULength & 0x7F;
    ULength >>= 7;
    if (ULength > 0)
    {
      Byte |= 0x80;
    }
    SendBytes(&Byte, 1);
  } while (ULength > 0);

  if (Length > 0)
  {
    SendBytes(reinterpret_cast<const uint8*>(Converter.Get()), Length);
  }
}

// =============================================================================
// UE type reads/writes
// =============================================================================

FVector FKhepriChannel::ReadFVector()
{
  float X = ReadFloat();
  float Y = ReadFloat();
  float Z = ReadFloat();
  return FVector(X, Y, Z);
}

FLinearColor FKhepriChannel::ReadFLinearColor()
{
  float R = ReadFloat();
  float G = ReadFloat();
  float B = ReadFloat();
  return FLinearColor(R, G, B, 1.0f);
}

void FKhepriChannel::WriteFVector(const FVector& Value)
{
  WriteFloat(static_cast<float>(Value.X));
  WriteFloat(static_cast<float>(Value.Y));
  WriteFloat(static_cast<float>(Value.Z));
}

void FKhepriChannel::WriteFLinearColor(const FLinearColor& Value)
{
  WriteFloat(Value.R);
  WriteFloat(Value.G);
  WriteFloat(Value.B);
}

// =============================================================================
// Convenience array reads
// =============================================================================

TArray<FVector> FKhepriChannel::ReadFVectorArray()
{
  return ReadArray<FVector>([this]() { return ReadFVector(); });
}

TArray<int32> FKhepriChannel::ReadInt32Array()
{
  return ReadArray<int32>([this]() { return ReadInt32(); });
}

TArray<TArray<FVector>> FKhepriChannel::ReadFVectorArrayArray()
{
  return ReadArray<TArray<FVector>>([this]() { return ReadFVectorArray(); });
}

TArray<TArray<int32>> FKhepriChannel::ReadInt32ArrayArray()
{
  return ReadArray<TArray<int32>>([this]() { return ReadInt32Array(); });
}

// =============================================================================
// Object registries
// =============================================================================

int32 FKhepriChannel::RegisterActor(AActor* Actor)
{
  int32 Index = ActorRegistry.Add(Actor);
  return Index;
}

AActor* FKhepriChannel::GetActor(int32 Index) const
{
  if (ActorRegistry.IsValidIndex(Index))
  {
    return ActorRegistry[Index];
  }
  UE_LOG(LogKhepri, Warning, TEXT("Khepri: Invalid actor index %d (registry size %d)"), Index, ActorRegistry.Num());
  return nullptr;
}

int32 FKhepriChannel::RegisterMaterial(UMaterialInterface* Material)
{
  int32 Index = MaterialRegistry.Add(Material);
  return Index;
}

UMaterialInterface* FKhepriChannel::GetMaterial(int32 Index) const
{
  if (MaterialRegistry.IsValidIndex(Index))
  {
    return MaterialRegistry[Index];
  }
  UE_LOG(LogKhepri, Warning, TEXT("Khepri: Invalid material index %d"), Index);
  return nullptr;
}

int32 FKhepriChannel::RegisterMesh(UStaticMesh* Mesh)
{
  int32 Index = MeshRegistry.Add(Mesh);
  return Index;
}

UStaticMesh* FKhepriChannel::GetMesh(int32 Index) const
{
  if (MeshRegistry.IsValidIndex(Index))
  {
    return MeshRegistry[Index];
  }
  UE_LOG(LogKhepri, Warning, TEXT("Khepri: Invalid mesh index %d"), Index);
  return nullptr;
}

// =============================================================================
// Cleanup
// =============================================================================

void FKhepriChannel::ClearRegistries()
{
  ClearActors();

  // Release GC roots for dynamic materials before clearing
  for (UMaterialInterface* Material : MaterialRegistry)
  {
    if (Material && Material->IsValidLowLevel() && Material->IsRooted())
    {
      Material->RemoveFromRoot();
    }
  }
  MaterialRegistry.Empty();

  MeshRegistry.Empty();
  ParentIndices.Empty();
  CurrentParentIndex = -1;
  CurrentMaterialIndex = -1;
}

void FKhepriChannel::ClearActors()
{
  ActorRegistry.Empty();
}

void FKhepriChannel::ClearShapeActors()
{
  for (int32 i = 0; i < ActorRegistry.Num(); ++i)
  {
    AActor* Actor = ActorRegistry[i];
    if (Actor && !Actor->IsUnreachable() && IsValid(Actor))
    {
      Actor->Destroy();
    }
  }
  ActorRegistry.Empty();
  ParentIndices.Empty();
  CurrentParentIndex = -1;
}
