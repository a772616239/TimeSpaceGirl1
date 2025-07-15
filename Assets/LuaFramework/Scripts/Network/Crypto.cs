using System;
using System.Security.Cryptography;

namespace GameLogic
{
    class Encryptor
    {
        public void Init(byte[] key)
        {
            m_service = new TripleDESCryptoServiceProvider { KeySize = 24 * 8, Padding = System.Security.Cryptography.PaddingMode.PKCS7 };
            m_service.Key = key;
            m_service.Mode = CipherMode.ECB;
            m_Encrypt = m_service.CreateEncryptor();
            m_Decrypt = m_service.CreateDecryptor();
            m_OriginalBuff = new byte[64 * 1024];
            m_bValid = true;
        }
        public void Init(string sKey)
        {
            Init(System.Text.Encoding.UTF8.GetBytes(sKey));
        }
        private int FixEncryDataBlock(byte[] data, int nDataLen)
        {
            int nSize = (nDataLen / 8 + 1) * 8;
            System.Buffer.BlockCopy(data, 0, m_OriginalBuff, 0, nDataLen);
            for (int i = nDataLen; i < nSize; ++i)
            {
                m_OriginalBuff[i] = (byte)(nSize - nDataLen);
            }
            return nSize;
        }
        public byte[] Encode(byte[] szData)
        {
            int nDataLen = szData.Length;
            int nFixLen = FixEncryDataBlock(szData, nDataLen);
            byte[] szOut = new byte[nFixLen];
            m_Encrypt.TransformBlock(m_OriginalBuff, 0, nFixLen, szOut, 0);
            return szOut;
        }
        public byte[] Decode(byte[] szData)
        {
            return m_Decrypt.TransformFinalBlock(szData, 0, szData.Length);
        }
        public bool IsValid()
        {
            return m_bValid;
        }
        public void SetValid(bool bValid)
        {
            m_bValid = bValid;
        }
        private TripleDESCryptoServiceProvider m_service;
        private ICryptoTransform m_Encrypt;
        private ICryptoTransform m_Decrypt;
        private byte[] m_OriginalBuff;
        private bool m_bValid = false;
    }

    class Crypto : GameLogic.ICrypto
    {
        public void Init(string key)
        {
            encryptor.Init(key);
        }

        public override byte[] Encode(byte[] data)
        {
            if (data != null && data.Length > 0)
            {
                byte[] compressed = Ionic.Zlib.ZlibStream.CompressBuffer(data);
                return encryptor.Encode(compressed);
            }
            return data;
        }

        public override byte[] Decode(byte[] data)
        {
            if (data != null && data.Length > 0)
            {
                byte[] decoded = encryptor.Decode(data);
                return Ionic.Zlib.ZlibStream.UncompressBuffer(decoded);
            }
            return data;
        }

        private Encryptor encryptor = new Encryptor();
    }

    class TEA
    {
        public static int[] KEY = new int[]{//加密解密所用的KEY
            0x789f5645, unchecked((int)0xf68bd5a4),
            unchecked((int)0x81963ffa), 0x458fac58
    };
        private static int TIMES = 32;


        public static int byteToInt(byte[] content, int offset)
        {
            int result = (int)(content[offset + 3]) | (int)(content[offset + 2]) << 8 |
                    (int)(content[offset + 1]) << 16 | (int)content[offset] << 24;
            return result;
        }

        public static short byteToShort(byte[] content, int offset)
        {
            int result = (int)(content[offset + 1]) | (int)(content[offset]) << 8;
            return (short)result;
        }
        public static void intToByte(byte[] bys, int offset, int content)
        {
            bys[offset + 3] = (byte)(content & 0xff);
            bys[offset + 2] = (byte)((content >> 8) & 0xff);
            bys[offset + 1] = (byte)((content >> 16) & 0xff);
            bys[offset] = (byte)((content >> 24) & 0xff);
        }

        //加密
        public static byte[] encrypt(byte[] content, int offset, int[] key)
        {
            unchecked
            {
                //times为加密轮数
                int delta = (int)0x9e3779b9; //这是算法标准给的值
                int a = key[0], b = key[1], c = key[2], d = key[3];
                for (int m = offset; m < content.Length; m += 8)
                {
                    int y = byteToInt(content, m), z = byteToInt(content, m + 4), sum = 0, i;
                    for (i = 0; i < TIMES; i++)
                    {
                        sum += delta;
                        y += ((z << 4) + a) ^ (z + sum) ^ ((z >> 5) + b);
                        z += ((y << 4) + c) ^ (y + sum) ^ ((y >> 5) + d);
                    }
                    intToByte(content, m, y);
                    intToByte(content, m + 4, z);
                }
                return content;
            }
        }

        public static void shortToByte(byte[] bys, int offset, int content)
        {
            bys[offset + 1] = (byte)(content & 0xff);
            bys[offset] = (byte)((content >> 8) & 0xff);
        }

        public static byte[] encrypt2(byte[] content, int[] key)
        {
            //8字节对齐，并加上数据长度
            int totalLength = (content.Length + 7) / 8 * 8 + 2;
            byte[] bys = new byte[totalLength];
            Array.Copy(content, 0, bys, 2, content.Length);
            byte[] encryptContent = encrypt(bys, 2, key);
            shortToByte(encryptContent, 0, content.Length);
            return encryptContent;
        }

        //解密
        public static byte[] decrypt(byte[] encryptContent, int offset, int[] key)
        {
            unchecked
            {
                int delta = (int)0x9e3779b9; //这是算法标准给的值
                int a = key[0], b = key[1], c = key[2], d = key[3];
                for (int m = offset; m < encryptContent.Length; m += 8)
                {
                    int y = byteToInt(encryptContent, m), z = byteToInt(encryptContent, m + 4), sum = (int)0xC6EF3720, i;
                    for (i = 0; i < TIMES; i++)
                    {
                        z -= ((y << 4) + c) ^ (y + sum) ^ ((y >> 5) + d);
                        y -= ((z << 4) + a) ^ (z + sum) ^ ((z >> 5) + b);
                        sum -= delta;
                    }
                    intToByte(encryptContent, m, y);
                    intToByte(encryptContent, m + 4, z);
                }
                return encryptContent;
            }
        }
        //解密时，encryptContent只是待解密内容
        public static byte[] decrypt2(byte[] encryptContent, int len, int offset, int[] key)
        {
            byte[] decryptContent = decrypt(encryptContent, offset, key);
            if (len == decryptContent.Length)
            {
                return decryptContent;
            }
            Array.Resize<byte>(ref decryptContent, len);
            return decryptContent;
        }

        public byte[] Decode(byte[] data, int len)
        {
            return decrypt2(data, len, 0, KEY);
        }

        public byte[] Encode(byte[] message)
        {
            return encrypt2(message, KEY);
        }
    }

    class XXTEA : GameLogic.ICrypto
    {
        //加密解密所用的KEY
        public static uint[] Key = new uint[] {
            0x789f5645, 0xf68bd5a4,
            0x81963ffa, 0x458fac58
        };

        public override byte[] Encode(byte[] Data)
        {
            if (Data.Length == 0)
            {
                return Data;
            }
            if (Data.Length % 8 != 0)
            {
                byte[] newData = new byte[Data.Length % 8 + Data.Length];
                for (int i = 0; i < newData.Length; i++)
                {
                    newData[i] = i < Data.Length ? Data[i] : (byte)0;
                }
                Data = newData;
            }
            return ToByteArray(Encrypt(ToUInt32Array(Data, true), Key), false);
        }
        public override byte[] Decode(byte[] Data)
        {
            if (Data.Length == 0)
            {
                return Data;
            }
            return ToByteArray(Decrypt(ToUInt32Array(Data, false), Key), true);
        }

        private static uint[] Encrypt(uint[] v, uint[] k)
        {
            int n = v.Length - 1;
            if (n < 1)
            {
                return v;
            }
            if (k.Length < 4)
            {
                uint[] Key = new uint[4];
                k.CopyTo(Key, 0);
                k = Key;
            }
            uint delta = 3; //防止有人通过汇编指令搜索到该常数以至于猜出算法
            uint z = v[n], y = v[0], sum = 0, e;
            int p, q = 6 + 52 / (n + 1);
            delta *= 89; delta *= 523; delta *= 19009;
            while (q-- > 0)
            {
                sum = unchecked(sum + delta);
                e = sum >> 2 & 3;
                for (p = 0; p < n; p++)
                {
                    y = v[p + 1];
                    z = unchecked(v[p] += (z >> 5 ^ y << 2) + (y >> 3 ^ z << 4) ^ (sum ^ y) + (k[p & 3 ^ e] ^ z));
                }
                y = v[0];
                z = unchecked(v[n] += (z >> 5 ^ y << 2) + (y >> 3 ^ z << 4) ^ (sum ^ y) + (k[p & 3 ^ e] ^ z));
            }
            return v;
        }
        private static uint[] Decrypt(uint[] v, uint[] k)
        {
            int n = v.Length - 1;
            if (n < 1)
            {
                return v;
            }
            if (k.Length < 4)
            {
                uint[] Key = new uint[4];
                k.CopyTo(Key, 0);
                k = Key;
            }
            uint delta = 3; //防止有人通过汇编指令搜索到该常数以至于猜出算法
            uint z = v[n], y = v[0], sum, e;
            int p, q = 6 + 52 / (n + 1);
            delta *= 89; delta *= 523; delta *= 19009;
            sum = unchecked((uint)(q * delta));
            while (sum != 0)
            {
                e = sum >> 2 & 3;
                for (p = n; p > 0; p--)
                {
                    z = v[p - 1];
                    y = unchecked(v[p] -= (z >> 5 ^ y << 2) + (y >> 3 ^ z << 4) ^ (sum ^ y) + (k[p & 3 ^ e] ^ z));
                }
                z = v[n];
                y = unchecked(v[0] -= (z >> 5 ^ y << 2) + (y >> 3 ^ z << 4) ^ (sum ^ y) + (k[p & 3 ^ e] ^ z));
                sum = unchecked(sum - delta);
            }
            return v;
        }
        private static uint[] ToUInt32Array(byte[] Data, bool IncludeLength)
        {
            int n = ((Data.Length & 3) == 0) ? (Data.Length >> 2) : ((Data.Length >> 2) + 1);
            uint[] Result;
            if (IncludeLength)
            {
                Result = new uint[n + 1];
                Result[n] = (uint)Data.Length;
            }
            else
            {
                Result = new uint[n];
            }
            n = Data.Length;
            for (int i = 0; i < n; i++)
            {
                Result[i >> 2] |= (uint)Data[i] << ((i & 3) << 3);
            }
            return Result;
        }
        private static byte[] ToByteArray(uint[] Data, bool IncludeLength)
        {
            int n;
            if (IncludeLength)
            {
                n = (int)Data[Data.Length - 1];
            }
            else
            {
                n = Data.Length << 2;
            }
            byte[] Result = new byte[n];
            for (int i = 0; i < n; i++)
            {
                Result[i] = (byte)(Data[i >> 2] >> ((i & 3) << 3));
            }
            return Result;
        }
    }
}