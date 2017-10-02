package eweb._impl;

typedef ToraCacheInfos = Array<{ inUse:neko.vm.Mutex, module:neko.vm.Module, mtime:Float, finalize:Void->Void }>;

