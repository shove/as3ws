package org.ds.websocket
{
	public class WebSocketOps
	{
		public static const CONTINUATION:uint = 0x0;
		public static const TEXT_FRAME:uint = 0x1;
		public static const BINARY_FRAME:uint = 0x2;
		public static const CLOSE:uint = 0x8;
		public static const PING:uint = 0x9;
		public static const PONG:uint = 0xA;
	}
}