#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
python3 - "$PWD" <<'PY'
import base64,hashlib,json,pathlib,shlex,sys
root=pathlib.Path(sys.argv[1])
manifest=json.loads((root/'BrowserExtension/manifest.json').read_text())
key=base64.b64decode(manifest['key'])
extension=''.join(chr(97+int(char,16)) for char in hashlib.sha256(key).hexdigest()[:32])
base=pathlib.Path.home()/'Library/Application Support/OpenAudio'
base.mkdir(parents=True,exist_ok=True)
host=base/'browser-host'
host.write_text('#!/bin/sh\nexec '+shlex.quote(str(root/'dist/OpenAudio.app/Contents/MacOS/OpenAudio'))+' --native-host "$@"\n')
host.chmod(0o700)
registration={'name':'com.dhrvrm.openaudio','description':'OpenAudio browser tab control','path':str(host),'type':'stdio','allowed_origins':['chrome-extension://'+extension+'/']}
for browser in ['Arc/User Data','Google/Chrome']:
    folder=pathlib.Path.home()/'Library/Application Support'/browser/'NativeMessagingHosts'
    folder.mkdir(parents=True,exist_ok=True)
    (folder/'com.dhrvrm.openaudio.json').write_text(json.dumps(registration,indent=2)+'\n')
print('Registered browser bridge for extension '+extension)
print('Load unpacked extension: '+str(root/'BrowserExtension'))
PY
