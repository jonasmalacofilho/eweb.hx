/*
 * Improved Web apis.
 *
 * Fixes and extends neko.Web.
 *
 * Based on and licensed as the original neko.Web.
 * Copyright (C)2005-2016 Haxe Foundation
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */
package eweb;

import neko.Web in W;

@:forwardStatics
@:access(neko.Web)
abstract Web(W) from W {
#if neko
	static var date_get_tz = neko.Lib.load("std","date_get_tz", 0);
	static function getTimezoneDelta():Float return 1e3*date_get_tz();
#end
	/**
		Returns all GET and POST parameters.
	**/
	public static function getAllParams()
	{
		var p = W._get_params();
		var h = new Map<String, Array<String>>();
		var k = "";
		while( p != null ) {
			untyped k.__s = p[0];
			if (!h.exists(k)) h.set(k, []);
			h.get(k).push(new String(p[1]));
			p = untyped p[2];
		}
		return h;
	}

	/**
		Returns all Cookies sent by the client, including multiple values for any given key.

		Modifying the hashtable will not modify the cookie, use setCookie or addCookie instead.
	**/
	public static function getAllCookies() {
		var p = W._get_cookies();
		var h = new Map<String, Array<String>>();
		var k = "";
		while( p != null ) {
			untyped k.__s = p[0];
			if (!h.exists(k)) h.set(k, []);
			h.get(k).push(new String(p[1]));
			p = untyped p[2];
		}
		return h;
	}

	/**
		Set a Cookie value in the HTTP headers. Same remark as setHeader.

		Fixed in regards to hosts running on timezones differents than GMT.
	**/
	public static function setCookie( key : String, value : String, ?expire: Date, ?domain: String, ?path: String, ?secure: Bool, ?httpOnly: Bool ) {
		var buf = new StringBuf();
		buf.add(value);
		expire = DateTools.delta(expire, -getTimezoneDelta());
		if( expire != null ) W.addPair(buf, "expires=", DateTools.format(expire, "%a, %d-%b-%Y %H:%M:%S GMT"));
		W.addPair(buf, "domain=", domain);
		W.addPair(buf, "path=", path);
		if( secure ) W.addPair(buf, "secure", "");
		if( httpOnly ) W.addPair(buf, "HttpOnly", "");
		var v = buf.toString();
		W._set_cookie(untyped key.__s, untyped v.__s);
	}

	public static function getLocalReferer():Null<String>
	{
		var r = W.getClientHeader("Referer");
		if (r == null) return null;
		if (r.indexOf("#") >= 0) r = r.substr(0, r.indexOf("#"));  // shouldn't fragments anyways
		var h = W.getClientHeader("Host");
		var p = r.indexOf(h);
		if (p == -1) {
			if (r == "about:blank") return null;
			return r;
		}
		return r.substr(p + h.length);
	}

#if (tora && experimental)
	public static var fromManagedCache(default,null) = false;
	static var execute(default,null) = null;
	static var finalizers = [];

	public static function runAndCache(f:Void->Void)
	{
		if (execute != null)
			throw "tora-cache: fatal: already initialized";
		if (!neko.Web.isTora)
			throw "tora-cache: fatal: not available, not running on Tora";

		var module = neko.vm.Module.local();
		var path = '${module.name}.n';
		var mtime = sys.FileSystem.stat(path).mtime.getTime();

		traceCache('tora-cache: fresh load of ${module.name} @ ${Date.fromTime(mtime)}');
		var current = {
			inUse : new neko.vm.Mutex(),
			module : module,
			mtime : mtime,
			finalize : function () for (f in finalizers) f()
		};

		execute = function () {
			current.inUse.acquire();
			if (fromManagedCache)
				traceCache('tora-cache: running from cache (${module.name} @ ${Date.fromTime(mtime)})');
			try {
				f();
				current.inUse.release();
			} catch (e:Dynamic) {
				current.inUse.release();
				neko.Lib.rethrow(e);
			}
		};
		W.cacheModule(execute);

		var share = new ToraShare<ToraCacheInfos>("tora-cache", function () return []);
		var cache = share.get(true);
		
		// gc: decide what to collect, but leave the actual cleanup to after the
		// lock on `cache` has been released
		var keep = [], gc = [];
		for (i in cache) {
			if (i.module != module && i.mtime < mtime && i.module.name == module.name && i.inUse.tryAcquire()) {
				gc.push(i);
				i.inUse.release();
			} else {
				keep.push(i);
			}
		}

		keep.push(current);
		share.set(keep);

		if (gc.length > 0) {
			traceCache('tora-cache: dispatching thread for garbage collection');
			neko.vm.Thread.create(function () {
				for (i in gc) {
					traceCache('tora-cache: garbage collecting ${i.module.name} @ ${Date.fromTime(i.mtime)}');
					try {
						i.finalize();
					} catch (e:Dynamic) {
						traceCache('tora-cache: warning: exception thrown in finalizer; probable leak');
					}
				}
				traceCache('tora-cache: garbage collection done');
			});
		}

		execute();
		fromManagedCache = true;
	}

	public static function addModuleFinalizer(finalize:Void->Void)
	{
		finalizers.push(finalize);
	}

	public dynamic static function traceCache(msg:Dynamic, ?pos:haxe.PosInfos) {}
#end
}

#if (tora && experimental)
typedef ToraCacheInfos = Array<{ inUse:neko.vm.Mutex, module:neko.vm.Module, mtime:Float, finalize:Void->Void }>;

/*
	Simplified version of tora.Share, loosing Persist.
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
class ToraShare<T> {

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
#end

