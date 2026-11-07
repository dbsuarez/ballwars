"""Run every ordinary Flutter test in small sequential processes on Windows.

Each batch releases its compiler/test resources before the next starts. Raw JSON
logs and a machine-readable inventory/result manifest are kept under build/.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--flutter', required=True)
    parser.add_argument('--batch-size', type=int, default=16)
    args = parser.parse_args()
    if args.batch_size < 1:
        parser.error('--batch-size must be positive')
    root = Path(__file__).resolve().parents[1]
    files = sorted(root.joinpath('test').rglob('*_test.dart'))
    if not files:
        raise SystemExit('No test files found; refusing an empty success')
    output = root / 'build' / 'regression-batches'
    output.mkdir(parents=True, exist_ok=True)
    manifest = {'files': [str(f.relative_to(root)).replace('\\', '/') for f in files],
                'source_hashes': {str(f.relative_to(root)).replace('\\', '/'): hashlib.sha256(f.read_bytes()).hexdigest() for f in files},
                'batch_size': args.batch_size, 'batches': [], 'complete': False}
    env = os.environ.copy()
    temp = root / 'build' / 'tool-temp'
    temp.mkdir(parents=True, exist_ok=True)
    env.update(TEMP=str(temp), TMP=str(temp))
    for start in range(0, len(files), args.batch_size):
        batch = files[start:start + args.batch_size]
        number = len(manifest['batches']) + 1
        log = output / f'batch-{number:02}.jsonl'
        command = [args.flutter, 'test', '--no-pub', '--concurrency=1', '--reporter=json',
                   *[str(f.relative_to(root)) for f in batch]]
        print(f'Batch {number}: {len(batch)} files', flush=True)
        began = time.monotonic()
        for file in batch:
            manifest['source_hashes'][str(file.relative_to(root)).replace('\\', '/')] = hashlib.sha256(file.read_bytes()).hexdigest()
        with log.open('w', encoding='utf-8') as stream:
            run = subprocess.run(command, cwd=root, env=env, stdout=stream, stderr=subprocess.STDOUT)
        counts = {'passed': 0, 'skipped': 0, 'failed': 0}
        for line in log.read_text(encoding='utf-8', errors='replace').splitlines():
            try:
                event = json.loads(line)
            except ValueError:
                continue
            if event.get('type') == 'testDone' and not event.get('hidden', False):
                key = 'skipped' if event.get('skipped') else 'passed' if event.get('result') == 'success' else 'failed'
                counts[key] += 1
        manifest['batches'].append({'number': number, 'files': command[5:],
                                    'exit_code': run.returncode, **counts,
                                    'seconds': round(time.monotonic() - began, 2), 'log': str(log.relative_to(root))})
        (output / 'results.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
        print(f'Batch {number}: exit {run.returncode}, {counts}', flush=True)
    manifest['complete'] = True
    executed = [f.replace('\\', '/') for batch in manifest['batches'] for f in batch['files']]
    manifest['inventory_matches'] = sorted(executed) == manifest['files']
    manifest['sources_unchanged_after_execution'] = all(
        hashlib.sha256((root / name).read_bytes()).hexdigest() == sha
        for name, sha in manifest['source_hashes'].items())
    manifest['success'] = (all(b['exit_code'] == 0 for b in manifest['batches'])
                           and manifest['inventory_matches']
                           and manifest['sources_unchanged_after_execution'])
    manifest['totals'] = {key: sum(b[key] for b in manifest['batches']) for key in counts}
    (output / 'results.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(manifest['totals']), flush=True)
    return 0 if manifest['success'] else 1


if __name__ == '__main__':
    sys.exit(main())
