using System;
using UnityEngine;

namespace KhepriUnity {
    /// <summary>
    /// Interface for network communication channel.
    /// Abstracts the serialization layer for testing and alternative implementations.
    /// </summary>
    public interface INetworkChannel : IDisposable {
        /// <summary>
        /// Indicates whether the channel is currently connected.
        /// </summary>
        bool IsConnected { get; }

        /// <summary>
        /// Read a 32-bit integer from the channel.
        /// </summary>
        int ReadInt32();

        /// <summary>
        /// Write a 32-bit integer to the channel.
        /// </summary>
        void WriteInt32(int value);

        /// <summary>
        /// Read a single-precision float from the channel.
        /// </summary>
        float ReadSingle();

        /// <summary>
        /// Write a single-precision float to the channel.
        /// </summary>
        void WriteSingle(float value);

        /// <summary>
        /// Read a string from the channel.
        /// </summary>
        string ReadString();

        /// <summary>
        /// Write a string to the channel.
        /// </summary>
        void WriteString(string value);

        /// <summary>
        /// Read a Vector3 from the channel.
        /// </summary>
        Vector3 ReadVector3();

        /// <summary>
        /// Write a Vector3 to the channel.
        /// </summary>
        void WriteVector3(Vector3 value);

        /// <summary>
        /// Read a Color from the channel.
        /// </summary>
        Color ReadColor();

        /// <summary>
        /// Write a Color to the channel.
        /// </summary>
        void WriteColor(Color value);

        /// <summary>
        /// Read a boolean from the channel.
        /// </summary>
        bool ReadBoolean();

        /// <summary>
        /// Write a boolean to the channel.
        /// </summary>
        void WriteBoolean(bool value);

        /// <summary>
        /// Flush any buffered data to the underlying stream.
        /// </summary>
        void Flush();

        /// <summary>
        /// Event fired when an error occurs on the channel.
        /// </summary>
        event Action<Exception> OnError;
    }
}
