﻿using UnityEngine;
using System.Collections;
using System.IO;
using System.Text;
using System;
using LuaInterface;

namespace GameLogic
{
    public class ByteBuffer
    {
        MemoryStream stream = null;
        BinaryWriter writer = null;
        BinaryReader reader = null;

        public ByteBuffer()
        {
            stream = new MemoryStream();
            writer = new BinaryWriter(stream);
        }

        public ByteBuffer(byte[] data)
        {
            if (data != null)
            {
                stream = new MemoryStream(data);
                reader = new BinaryReader(stream);
            }
            else
            {
                stream = new MemoryStream();
                writer = new BinaryWriter(stream);
            }
        }

        public void Close()
        {
            if (writer != null) writer.Close();
            if (reader != null) reader.Close();

            stream.Close();
            writer = null;
            reader = null;
            stream = null;
        }

        public void WriteByte(byte v)
        {
            writer.Write(v);
        }

        public void WriteInt(int v)
        {
            writer.Write(v);
        }

        public void WriteIntToByte(int content)
        {
            writer.Write((sbyte)((content >> 24) & 0xff));
            writer.Write((sbyte)((content >> 16) & 0xff));
            writer.Write((sbyte)((content >> 8) & 0xff));
            writer.Write((sbyte)((content) & 0xff));
        }

        public void WriteShort(ushort v)
        {
            writer.Write(v);
        }

        public void WriteLong(long v)
        {
            writer.Write(v);
        }

        public void WriteFloat(float v)
        {
            byte[] temp = BitConverter.GetBytes(v);
            Array.Reverse(temp);
            writer.Write(BitConverter.ToSingle(temp, 0));
        }

        public void WriteDouble(double v)
        {
            byte[] temp = BitConverter.GetBytes(v);
            Array.Reverse(temp);
            writer.Write(BitConverter.ToDouble(temp, 0));
        }

        public void WriteString(string v)
        {
            byte[] bytes = Encoding.UTF8.GetBytes(v);
            writer.Write((ushort)bytes.Length);
            writer.Write(bytes);
        }

        public void WriteBytes(byte[] v)
        {
            writer.Write(v.Length);
            writer.Write(v);
        }

        public void WriteBuffer(LuaByteBuffer strBuffer)
        {
            writer.Write(strBuffer.buffer);
        }

        public byte ReadByte()
        {
            return reader.ReadByte();
        }

        public int ReadInt()
        {
            return reader.ReadInt32();
        }

        public int ReadIntToByte()
        {
            byte[] temp = BitConverter.GetBytes(reader.ReadInt32());
            Array.Reverse(temp);
            return BitConverter.ToInt32(temp, 0);
        }

        public ushort ReadShort()
        {
            return reader.ReadUInt16();
        }

        public long ReadLong()
        {
            return reader.ReadInt64();
        }

        public float ReadFloat()
        {
            byte[] temp = BitConverter.GetBytes(reader.ReadSingle());
            Array.Reverse(temp);
            return BitConverter.ToSingle(temp, 0);
        }

        public double ReadDouble()
        {
            byte[] temp = BitConverter.GetBytes(reader.ReadDouble());
            Array.Reverse(temp);
            return BitConverter.ToDouble(temp, 0);
        }

        public string ReadString()
        {
            ushort len = ReadShort();
            byte[] buffer = new byte[len];
            buffer = reader.ReadBytes(len);
            return Encoding.UTF8.GetString(buffer);
        }

        public byte[] ReadBytes()
        {
            int len = ReadInt();
            return reader.ReadBytes(len);
        }

        public LuaByteBuffer ReadBuffer()
        {
            byte[] bytes = ReadBytes();
            return new LuaByteBuffer(bytes);
        }

        public LuaByteBuffer DataByte()
        {
            byte[] bytes = reader.ReadBytes((int)(stream.Length - stream.Position));
            return new LuaByteBuffer(bytes);
        }

        public byte[] ToBytes()
        {
            writer.Flush();
            return stream.ToArray();
        }

        public void Flush()
        {
            writer.Flush();
        }
    }
}