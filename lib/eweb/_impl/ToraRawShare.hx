package eweb._impl;

/*
	Simplified version of tora.Share, losing persistence.
	Based on and licensed as the original Tora.
	Copyright (C) 2008-2016 Haxe Foundation

	This library is free software; you can redistribute it and/or
	modify it under the terms of the GNU Lesser General Public
	License as published by the Free Software Foundation; either
	version 2.1 of the License, or (at your option) any later version.

	This library is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
	Lesser General Public License for more details.

	You should have received a copy of the GNU Lesser General Public
	License along with this library; if not, write to the Free Software
	Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
*/
class ToraRawShare<T> {

	var s : Dynamic;
	public var name(default,null) : String;

	public function new( name : String, ?makeData : Void -> T ) {
		init();
		if( makeData == null ) makeData = function() return null;
		this.name = name;
		s = share_init(untyped name.__s, makeData);
	}

	public function get( lock : Bool ) : T {
		var v = share_get(s,lock);
		return v;
	}

	public function set( data : T ) {
		share_set(s,data);
	}

	public function commit() {
		share_commit(s);
	}

	public function free() {
		share_free(s);
	}

	public static function commitAll() {
		init();
		share_commit_all();
	}

	static function init() {
		if( share_init != null ) return;
		share_init = neko.Lib.load(tora.Api.lib,"share_init",2);
		share_get = neko.Lib.load(tora.Api.lib,"share_get",2);
		share_set = neko.Lib.load(tora.Api.lib,"share_set",2);
		share_commit = neko.Lib.load(tora.Api.lib,"share_commit",1);
		share_free = neko.Lib.load(tora.Api.lib,"share_free",1);
		share_commit_all = neko.Lib.load(tora.Api.lib,"share_commit_all",0);
	}

	static var share_init = null;
	static var share_get;
	static var share_set;
	static var share_commit;
	static var share_free;
	static var share_commit_all;

}

