// KhepriChannel.h — Binary protocol over FSocket
// Handles all type serialization for Khepri ↔ Unreal communication.
// Little-endian wire format matching Julia's native byte order.

#pragma once

#include "CoreMinimal.h"
#include "Networking.h"

class FKhepriChannel
{
public:
  FKhepriChannel();
  ~FKhepriChannel();

  void SetSocket(FSocket* InSocket);
  bool IsConnected() const;

  // --- Framing ---
  // Reads a length-prefixed frame from the network into a memory buffer, then
  // redirects reads to the buffer and writes to a response buffer. EndFrame
  // flushes the response as a length-prefixed frame back to the network.
  bool BeginFrame();
  void EndFrame();

  // --- Primitive reads ---
  uint8 ReadByte();
  bool ReadBool();
  int32 ReadInt32();
  int64 ReadInt64();
  float ReadFloat();
  double ReadDouble();
  FString ReadString();  // .NET 7-bit variable-length prefix

  // --- Primitive writes ---
  void WriteByte(uint8 Value);
  void WriteBool(bool Value);
  void WriteInt32(int32 Value);
  void WriteInt64(int64 Value);
  void WriteFloat(float Value);
  void WriteDouble(double Value);
  void WriteString(const FString& Value);

  // --- UE type reads ---
  FVector ReadFVector();       // 3 floats
  FLinearColor ReadFLinearColor(); // 3 floats (RGB, A=1)

  // --- UE type writes ---
  void WriteFVector(const FVector& Value);
  void WriteFLinearColor(const FLinearColor& Value);

  // --- Array reads ---
  template<typename T>
  TArray<T> ReadArray(TFunction<T()> ReadElement)
  {
    int32 Count = ReadInt32();
    TArray<T> Result;
    Result.Reserve(Count);
    for (int32 i = 0; i < Count; ++i)
    {
      Result.Add(ReadElement());
    }
    return Result;
  }

  // Convenience: read array of FVector
  TArray<FVector> ReadFVectorArray();
  // Convenience: read array of int32
  TArray<int32> ReadInt32Array();
  // Convenience: read array of arrays of FVector
  TArray<TArray<FVector>> ReadFVectorArrayArray();
  // Convenience: read array of arrays of int32
  TArray<TArray<int32>> ReadInt32ArrayArray();

  // --- Array writes ---
  template<typename T>
  void WriteArray(const TArray<T>& Array, TFunction<void(const T&)> WriteElement)
  {
    WriteInt32(Array.Num());
    for (const T& Element : Array)
    {
      WriteElement(Element);
    }
  }

  // --- Object registries ---
  // Actors
  int32 RegisterActor(AActor* Actor);
  AActor* GetActor(int32 Index) const;
  // Materials
  int32 RegisterMaterial(UMaterialInterface* Material);
  UMaterialInterface* GetMaterial(int32 Index) const;
  // Static meshes
  int32 RegisterMesh(UStaticMesh* Mesh);
  UStaticMesh* GetMesh(int32 Index) const;

  // --- State ---
  int32 CurrentParentIndex;
  int32 CurrentMaterialIndex;
  bool bCreateCollision = true;

  // --- Cleanup ---
  void ClearRegistries();
  void ClearActors();
  void ClearShapeActors();

  // --- Parent tracking ---
  TSet<int32> ParentIndices;

  // --- Registry access ---
  const TArray<AActor*>& GetActorRegistry() const { return ActorRegistry; }

private:
  FSocket* Socket;

  // Raw I/O — reads/writes go through the frame buffers when a frame is active
  bool RecvBytes(uint8* Data, int32 Count);
  bool SendBytes(const uint8* Data, int32 Count);

  // Framing state
  TArray<uint8> ReadBuffer;
  int32 ReadPos;
  TArray<uint8> WriteBuffer;
  bool bInFrame;

  // Network-level raw I/O (bypasses framing)
  bool NetRecvBytes(uint8* Data, int32 Count);
  bool NetSendBytes(const uint8* Data, int32 Count);

  // Registries
  TArray<AActor*> ActorRegistry;
  TArray<UMaterialInterface*> MaterialRegistry;
  TArray<UStaticMesh*> MeshRegistry;
};
