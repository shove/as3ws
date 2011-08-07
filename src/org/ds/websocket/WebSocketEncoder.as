package org.ds.websocket
{
	import com.hurlant.util.der.Integer;
	
	import flash.utils.ByteArray;
	
	import org.ds.logging.Logger;

	public class WebSocketEncoder
	{

		public static function encode(message:String):ByteArray {
			var data:ByteArray = new ByteArray();
			data.writeUTFBytes(message);
			data.position = 0;
			
			var buffer:ByteArray = new ByteArray();
			buffer.writeByte(0x80 | WebSocketOps.TEXT_FRAME);
			
			if(data.length > 125) {
				if(data.length < 65536) {
					buffer.writeByte(126 | 0x80);
					buffer.writeShort(data.length);
				} else {
					Logger.log("Message to large!");
					return null;
				}
			} else {
				buffer.writeByte(data.length | 0x80);
			}
			
			var key:uint = Math.floor(Math.random() * uint.MAX_VALUE);
			
			buffer.writeUnsignedInt(key);
			for(var i:uint = 0; i < data.length;i++) {
				data[i] = (data[i] ^ (key >>> ((3 - (i % 4)) * 8)));
			}
			buffer.writeBytes(data);
			buffer.position = 0;
			
			return buffer;
		}
	}
}