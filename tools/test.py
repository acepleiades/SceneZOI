"""Run the SceneZOI framework checks using ModKit's Lua runtime."""
import argparse
import json
import ctypes
import os
import subprocess
import sys
from pathlib import Path
from pack_sources import load_pack

parser = argparse.ArgumentParser()
parser.add_argument('--modkit-root', type=Path, required=True)
parser.add_argument('--content-root',type=Path,help='Optional external author repository integration checks')
args = parser.parse_args()
repo = Path(__file__).resolve().parents[1]
os.chdir(repo)
lib = ctypes.CDLL(str(args.modkit_root / 'inZOIModKit/Binaries/Win64/Lua.dll'))
lib.luaL_newstate.restype = ctypes.c_void_p
lib.luaL_openlibs.argtypes = [ctypes.c_void_p]
lib.luaL_loadstring.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
lib.lua_pcallk.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_longlong, ctypes.c_void_p]
lib.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
lib.lua_tolstring.restype = ctypes.c_char_p
lib.lua_close.argtypes = [ctypes.c_void_p]

folders=[repo/'tests']
if args.content_root:
    args.content_root=args.content_root.resolve()
    folders.append(args.content_root/'tests')
env=os.environ.copy();env['SCENEZOI_REPO']=str(repo)
pack_roots=[repo/'packs']+([args.content_root/'packs']if args.content_root else [])
source_packs={}
for pack_root in pack_roots:
    for path in sorted(pack_root.glob('*.json')):
        pack=load_pack(path);source_packs[pack['id']]=pack
prefix=('TEST_SCENE_PACKS='+json.dumps(json.dumps(source_packs,ensure_ascii=False),ensure_ascii=False)+'\n').encode('utf-8')
for folder in folders:
    for filename in sorted(folder.glob('*.lua')):
        state = lib.luaL_newstate()
        lib.luaL_openlibs(state)
        # Keep intentional injected-failure diagnostics from overwhelming routine test output.
        source = b'''local output=print
print=function(first,...) if not tostring(first):match("^%[SceneZOI%]") then output(first,...) end end
''' + prefix + ((('TEST_CONTENT_ROOT='+json.dumps(args.content_root.as_posix(),ensure_ascii=False)+'\n').encode('utf-8'))if args.content_root else b'') + filename.read_bytes()
        status = lib.luaL_loadstring(state, source)
        if status == 0:
            status = lib.lua_pcallk(state, 0, -1, 0, 0, None)
        if status:
            message = lib.lua_tolstring(state, -1, None).decode()
            lib.lua_close(state)
            raise RuntimeError(f'{filename.name}: {message}')
        lib.lua_close(state)
        print('PASS', filename.relative_to(repo)if filename.is_relative_to(repo)else filename, flush=True)
subprocess.run([sys.executable,'tests/catalog.py'],check=True)
subprocess.run([sys.executable,'tests/scene_metadata.py'],check=True)
subprocess.run([sys.executable,'tests/addon_annotations.py'],check=True)
subprocess.run([sys.executable,'tests/assetless_package.py'],check=True)
if args.content_root:subprocess.run([sys.executable,str(args.content_root/'tests/catalog.py')],check=True,env=env)
for filename in ['tests/controls.cjs', 'tests/demo-entry.cjs', 'tests/voices.cjs', 'tests/tasks.cjs', 'tests/panel-state.cjs','tests/save-guard.cjs','tests/addon-bridge.cjs']:
    subprocess.run(['node', filename], check=True)
print('All SceneZOI framework checks passed.')
