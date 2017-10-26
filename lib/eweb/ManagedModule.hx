package eweb;

import neko.Web in W;
import eweb._impl.*;

class ManagedModule {
	public static var cacheAvailable(default,null) = #if tora Web.isTora #else false #end;
	public static var cacheEnabled(get,never):Bool;
		static inline function get_cacheEnabled() return execute != null;
	public static var runningFromCache(default,null) = false;

	static var execute(default,null) = null;
	static var finalizers = [];

	public static function runAndCache(f:Void->Void)
	{
#if tora
		if (!cacheAvailable)
			throw "ERROR: not available, not running on Tora";
		if (cacheEnabled || execute != null)
			throw "ERROR: already initialized";

		var module = neko.vm.Module.local();
		var path = '${module.name}.n';
		var mtime = sys.FileSystem.stat(path).mtime.getTime();

		log('fresh load of ${module.name} @ ${Date.fromTime(mtime)}');
		var current = {
			inUse : new neko.vm.Mutex(),
			module : module,
			mtime : mtime,
			finalize : callFinalizers
		};

		execute = function () {
			current.inUse.acquire();
			if (runningFromCache)
				log('running from cache (${module.name} @ ${Date.fromTime(mtime)})');
			try {
				f();
				current.inUse.release();
			} catch (e:Dynamic) {
				current.inUse.release();
				neko.Lib.rethrow(e);
			}
		};
		W.cacheModule(execute);

		var share = new ToraRawShare<ToraModuleInfos>("tora-cache", function () return []);
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
			for (i in gc) {
				log('garbage collecting ${i.module.name} @ ${Date.fromTime(i.mtime)}');
				i.finalize();
			}
			log('garbage collection done');
		}

		execute();
		runningFromCache = true;
#else
			throw "ERROR: not available, not compiled with -lib tora";
#end
	}

	public static function uncache()
	{
#if tora
		if (cacheAvailable && cacheEnabled) {
			W.cacheModule(null);
			execute = null;

			var share = new ToraRawShare<ToraModuleInfos>("tora-cache", function () return []);
			var cache = share.get(true);
			var infos = Lambda.find(cache, function (i) return Reflect.compareMethods(i.finalize, callFinalizers));
			if (infos == null)
				throw "ERROR: something went wrong here";
			cache.remove(infos);
			share.set(cache);
		}
#else
			throw "ERROR: not available, not compiled with -lib tora";
#end
	}

	public static function addModuleFinalizer(finalize:Void->Void, ?name:String)
	{
		finalizers.push({ f:finalize, name:name });
	}

	public static function callFinalizers()
	{
		for (i in finalizers) {
			var name = i.name != null ? ${i.name} : 'unnamed';
			log('executing finalizer: $name');
			try
				i.f()
			catch (e:Dynamic)
				log('ERROR thrown during finalizer, probable leak ($name): $e');
		}
	}

	public dynamic static function log(msg:Dynamic, ?pos:haxe.PosInfos) {}
}

