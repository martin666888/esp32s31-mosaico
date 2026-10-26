set -euo pipefail
cd /userdata/esp32s31
exec > >(tee logs/prefetch-domestic.log) 2>&1
make -s -C sources/buildroot O=/userdata/esp32s31/output-mosaico show-info > checks/buildroot-packages.json
python3 - <<'PY'
import concurrent.futures
import hashlib
import json
import pathlib
import platform
import shutil
import subprocess
import urllib.parse

root = pathlib.Path('/userdata/esp32s31')
info = json.loads((root / 'checks/buildroot-packages.json').read_text())
hashes = {}
for tree in [root / 'sources/buildroot', root / 'mosaico-external']:
    for file in tree.rglob('*.hash'):
        for line in file.read_text(errors='replace').splitlines():
            values = line.split()
            if len(values) == 3 and values[0] in {'sha256', 'sha512', 'sha1', 'md5'}:
                hashes.setdefault(values[2], set()).add((values[0], values[1]))
local_archives = json.loads((root / 'archives.lock.json').read_text())
local_files = {pathlib.Path(value['file']).name: value for value in local_archives.values()}
pending = []
for name, package in info.items():
    for download in package.get('downloads', []):
        if any(uri.startswith('local+') for uri in download['uris']):
            continue
        source = download['source']
        if pathlib.PurePosixPath(source).name != source:
            raise RuntimeError('Unexpected source filename')
        subdir = download['uris'][0].rsplit('/', 1)[-1]
        pending.append((name, source, subdir, download['uris']))

def verify(path, name):
    expected = hashes.get(name, set())
    if not expected:
        signatures = {'.tar.xz': b'\xfd7zXZ\x00', '.tar.gz': b'\x1f\x8b', '.tar.bz2': b'BZh'}
        for suffix, signature in signatures.items():
            if name.endswith(suffix):
                with path.open('rb') as stream:
                    return stream.read(len(signature)) == signature
        return True
    for algorithm, value in expected:
        with path.open('rb') as stream:
            if hashlib.file_digest(stream, algorithm).hexdigest() == value:
                return True
    return False

def fetch(item):
    name, source, subdir, uris = item
    target = root / 'dl' / subdir / source
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        if not verify(target, source):
            raise RuntimeError('Cached source checksum mismatch: ' + source)
        return source, {'file': str(target), 'origin': 'existing-cache'}
    if source in local_files:
        value = local_files[source]
        shutil.copyfile(value['file'], target)
        if not verify(target, source):
            raise RuntimeError('Local BSP archive checksum mismatch')
        return source, {'file': str(target), 'origin': 'verified-official-bsp-cache'}
    candidates = [
        'https://mirrors.huaweicloud.com/buildroot/' + subdir + '/' + source,
        'https://mirrors.nju.edu.cn/buildroot/' + subdir + '/' + source,
    ]
    if source.startswith('Python-') and source.endswith('.tar.xz'):
        version = source.removeprefix('Python-').removesuffix('.tar.xz')
        candidates.insert(0, 'https://mirrors.huaweicloud.com/python/' + version + '/' + source)
    if source.startswith('rust-') and source.endswith('.tar.xz'):
        candidates.insert(0, 'https://mirrors.huaweicloud.com/rustup/dist/' + source)
    if source.startswith('riscv64-esp-linux-musl-'):
        for line in (root / 'output-mosaico/.config').read_text().splitlines():
            if line.startswith('BR2_TOOLCHAIN_EXTERNAL_URL='):
                url = line.split('=', 1)[1].strip('"').replace('$(HOSTARCH)', platform.machine())
                if urllib.parse.urlsplit(url).hostname == 'dl.espressif.cn':
                    candidates.insert(0, url)
    for uri in uris:
        url = uri.split('+')[-1]
        host = urllib.parse.urlsplit(url).hostname or ''
        if host.endswith('.cn') and url.startswith('https://'):
            candidates.append(url.rstrip('/') + '/' + source)
    for url in dict.fromkeys(candidates):
        temp = target.with_name(target.name + '.domestic-part')
        result = subprocess.run(['curl', '--noproxy', '*', '-fsSL', '--retry', '1', '--connect-timeout', '5', '--max-time', '900', '-o', str(temp), url], capture_output=True, text=True)
        if result.returncode == 0 and verify(temp, source):
            temp.rename(target)
            print('Cached', source, 'from', url, flush=True)
            return source, {'file': str(target), 'origin': url}
    raise RuntimeError('No verified domestic source available: ' + source)

results = {}
failures = []
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
    futures = {executor.submit(fetch, item): item[1] for item in pending}
    for future in concurrent.futures.as_completed(futures):
        try:
            name, value = future.result()
            results[name] = value
        except Exception as error:
            failures.append(str(error))
            print('SOURCE ERROR:', error, flush=True)
for name, value in results.items():
    with pathlib.Path(value['file']).open('rb') as stream:
        value['sha256'] = hashlib.file_digest(stream, 'sha256').hexdigest()
(root / 'domestic-downloads.lock.json').write_text(json.dumps(results, indent=2) + '\n')
if failures:
    raise SystemExit('\n'.join(failures))
print('All required source files are cached; domestic-only builds can proceed', flush=True)
PY
