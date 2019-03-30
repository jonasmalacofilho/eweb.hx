package eweb._impl;

#if (haxe_ver >= 4)
import sys.thread.Mutex;
#else
import neko.vm.Mutex;
#end

typedef ToraModuleInfos = Array<{ inUse:Mutex, module:neko.vm.Module, mtime:Float, finalize:Void->Void }>;

