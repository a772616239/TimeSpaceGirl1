using System;
using GameLogic;

namespace GameLogic
{

    /// <summary>
    ///		Message dispatcher interface.
    /// </summary>
    public abstract class ICrypto
    {
        /// <summary>
        ///		Encode interface.
        /// </summary>
        /// <param name="message">Mesage data.</param>
        /// <returns>Encoded message.</returns>
        public abstract byte[] Encode(byte[] message);

        /// <summary>
        ///		Decode interface.
        /// </summary>
        /// <param name="message">Mesage data.</param>
        /// <returns>Decoded message.</returns>
        public abstract byte[] Decode(byte[] data);
    }

    /// <summary>
    ///		Message dispatcher interface.
    /// </summary>
    public abstract class IDispatcher {

		/// <summary>
		///		Process message.
		/// </summary>
		/// <param name="data">Message data.</param>
		/// <return>Process result</return>
		public abstract bool Process(ByteBuffer data);
	}

	public class SimpleDispatcher : IDispatcher
    {
		public event Action<ByteBuffer> processor;

		public override bool Process(ByteBuffer data) {
			try {
				if (data != null && processor!=null)
                {
                    processor.Invoke(data);
				}
				return true;
			}
            catch (Exception e)
            {
				UnityEngine.Debug.LogErrorFormat("Failed to parse network message : {0}", e.Message);
				return false;
			}
		}
	}
}
