"""Read-only deployment/schema probes. Never authenticates or changes server data.

Run from the repository root. JSON output deliberately excludes keys and rows.
Column visibility does not establish that RLS policies/triggers are installed.
"""
import hashlib
import json
from pathlib import Path
import re
import urllib.error
import urllib.request
from datetime import datetime, timezone


def main():
    config = Path('lib/core/config/supabase_config.dart').read_text()
    base = re.search(r"url = '([^']+)'", config)[1]
    public_key = re.search(r"publishableKey = '([^']+)'", config)[1]
    report = {'checked_at': datetime.now(timezone.utc).isoformat(), 'checks': {}}

    def check(name, url, headers=None, local=None):
        try:
            request = urllib.request.Request(url, headers=headers or {})
            with urllib.request.urlopen(request, timeout=25) as response:
                data = response.read()
                result = {'status': response.status, 'bytes': len(data)}
                if local:
                    result['sha256'] = hashlib.sha256(data).hexdigest()
                    result['matches_local'] = data == Path(local).read_bytes()
                if name == 'web_version':
                    result['version'] = json.loads(data)
                report['checks'][name] = result
        except urllib.error.HTTPError as error:
            report['checks'][name] = {'status': error.code}
        except (OSError, ValueError) as error:
            report['checks'][name] = {'error': type(error).__name__}

    web = 'https://dbsuarez.github.io/ballwars/'
    for name, path in [('web_entry', 'index.html'), ('web_version', 'version.json'),
                       ('web_bundle', 'main.dart.js'),
                       ('web_material_icons', 'assets/fonts/MaterialIcons-Regular.otf')]:
        check(name, web + path, {'Cache-Control': 'no-cache'}, 'build/web/' + path)
    for name, table, fields in [
        ('settings_columns', 'app_settings', 'id,updated_at,skill_library,ball_appearance'),
        ('replay_document_column', 'replays', 'id,replay_payload'),
        ('sprite_atlases_columns', 'sprite_atlases', 'id,manifest,sheet_path'),
        ('sprite_revisions_columns', 'sprite_atlas_revisions', 'atlas_id,revision_id,manifest'),
        ('ball_gender_column', 'group_balls', 'id,gender'),
    ]:
        check(name, f'{base}/rest/v1/{table}?select={fields}&limit=0', {'apikey': public_key})
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
