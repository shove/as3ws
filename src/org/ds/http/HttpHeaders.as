package org.ds.http
{
	import flash.utils.ByteArray;
	
	public class HttpHeaders
	{
		private static const Pattern:RegExp = /^(\S+):\s+(.+)$/;
		
		private var status:String;
		private var headers:Object = {};
		
		public function HttpHeaders(encoded:ByteArray=null) {
			if(encoded) {
				parse(encoded.readUTFBytes(encoded.length));
			}
		}
		
		private function parse(encoded:String):void {
			var entries:Array = encoded.split(/\r\n/);
			status = entries[0];
			for(var i:int = 1;i < entries.length;i++) {
				if(Pattern.test(entries[i])) {
					var kvp:Array = entries[i].match(/^(\S+):\s+(.+)$/);
					headers[kvp[1]] = kvp[2];
				}
			}
		}
		
		public function existsAs(header:String, value:String):Boolean {
			return exists(header) && headers[header] == value;
		}
		
		public function exists(header:String):Boolean {
			return headers.hasOwnProperty(header);
		}
	}
}