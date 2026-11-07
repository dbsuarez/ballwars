"""Verify the 001-029 manual baseline from schema_inventory.sql metadata.

Usage: python tools/supabase/verify_inventory.py raw-cli-json report.json
This only reads local files; it never executes SQL or marks history as applied.
"""
from datetime import datetime, timedelta, timezone
import hashlib
import json
from pathlib import Path
import re
import sys


def normalized(sql):
    return re.sub(r'\s+', '', re.sub(r'--[^\n]*', '', sql)).lower()


def main():
    root = Path(__file__).resolve().parents[2]
    source = Path(sys.argv[1])
    raw = source.read_bytes()
    data = json.loads(raw.decode('utf-16' if raw[:2] == b'\xff\xfe' else 'utf-8-sig'))
    inventory = data['rows'][0]['inventory']
    columns = {(c['table_name'], c['column_name']): c for c in inventory['columns']}
    tables = {t['name']: t for t in inventory['tables']}
    constraints = {c['name']: c['definition'] for c in inventory['constraints']}
    indexes = {i['indexname'] for i in inventory['indexes']}
    policies = {p['policyname']: p for p in inventory['policies']}
    functions = {f['name']: f for f in inventory['functions']}
    triggers = {t['name']: t for t in inventory['triggers']}
    buckets = {b['id']: b for b in inventory['buckets']}
    required_columns = {
        '001': {'ball_groups': 'id owner name is_public created_at', 'group_balls': 'id group_id owner name image_path image_style color position created_at'},
        '002': {'admins': 'user_id', 'app_settings': 'id headline theme updated_at'},
        '003': {'replays': 'id seed speed effects balls created_at', 'app_settings': 'watermark_enabled watermark_text'},
        '004': {'saved_groups': 'user_id group_id created_at'},
        '005': {'app_settings': 'music'}, '006': {'app_settings': 'slow_motion_lines slow_motion_before_win'},
        '007': {'replays': 'creator'}, '008': {'replays': 'size', 'ball_groups': 'pack_id submitted_at'},
        '009': {'app_settings': 'menu_music'}, '010': {'replays': 'question'},
        '011': {'app_settings': 'power_ups', 'replays': 'tuning'},
        '012': {'app_settings': 'ball_glow_enabled'}, '013': {'app_settings': 'blood_color'},
        '014': {'app_settings': 'arena_title arena_subtitle'}, '015': {'app_settings': 'minimum_arena_scale'},
        '016': {'app_settings': 'skill_library'}, '017': {'app_settings': 'arena_decoration'},
        '018': {'app_settings': 'projectile_render_mode explosion_render_mode freeze_render_mode'},
        '019': {'app_settings': 'ball_glow_width'}, '020': {'replays': 'replay_payload'},
        '022': {'group_balls': 'gender'},
        '023': {'sprite_atlases': 'id name sheet_path manifest updated_at'},
        '024': {'sprite_atlas_revisions': 'atlas_id revision_id name sheet_path manifest updated_at'},
        '025': {'app_settings': 'ball_appearance'}, '028': {'app_settings': 'export_watermark_text'},
        '029': {'app_settings': 'arena_catalog'},
    }
    required_constraints = {
        '001': 'ball_groups_pkey ball_groups_owner_fkey ball_groups_name_check group_balls_pkey group_balls_group_id_fkey group_balls_owner_fkey group_balls_name_check group_balls_check group_balls_image_style_check group_balls_color_check',
        '002': 'admins_pkey admins_user_id_fkey app_settings_pkey app_settings_id_check app_settings_headline_check app_settings_theme_check',
        '003': 'replays_pkey replays_id_check replays_speed_check replays_balls_check app_settings_watermark_text_check',
        '004': 'saved_groups_pkey saved_groups_user_id_fkey saved_groups_group_id_fkey',
        '005': 'app_settings_music_check', '006': 'app_settings_slow_motion_lines_check app_settings_slow_motion_before_win_check',
        '007': 'replays_creator_fkey', '008': 'replays_size_check ball_groups_pack_id_check',
        '009': 'app_settings_menu_music_check', '010': 'replays_question_check',
        '011': 'app_settings_power_ups_check replays_tuning_check', '013': 'app_settings_blood_color_check',
        '014': 'app_settings_arena_title_check app_settings_arena_subtitle_check',
        '015': 'app_settings_minimum_arena_scale_check', '017': 'app_settings_arena_decoration_check',
        '018': 'app_settings_projectile_render_mode_check app_settings_explosion_render_mode_check app_settings_freeze_render_mode_check',
        '019': 'app_settings_ball_glow_width_check', '020': 'replays_payload_check replays_balls_check',
        '021': 'replays_tuning_check', '022': 'group_balls_gender_check',
        '023': 'sprite_atlases_pkey sprite_atlases_name_check sprite_atlases_sheet_path_check sprite_atlases_manifest_check sprite_atlases_sheet_path_key',
        '024': 'sprite_atlas_revisions_pkey sprite_atlas_revisions_sheet_path_key',
        '025': 'app_settings_ball_appearance_check', '029': 'arena_catalog_size',
    }
    files = sorted((root / 'supabase/migrations').glob('*.sql'))
    versions = [f.name.split('_')[0] for f in files]
    if len(set(versions)) != len(versions):
        raise SystemExit('Duplicate migration versions: resolve before verification')
    results = []
    for file in files:
        version = file.name.split('_')[0]
        sql = file.read_text(encoding='utf-8-sig')
        checks = []
        def check(label, passed):
            checks.append({'check': label, 'passed': bool(passed)})
        for table, names in required_columns.get(version, {}).items():
            check(f'{table} RLS enabled', tables.get(table, {}).get('rls'))
            for column in names.split():
                check(f'{table}.{column} present', (table, column) in columns)
        for name in required_constraints.get(version, '').split():
            check(f'constraint {name}', name in constraints)
        for name in re.findall(r'create\s+(?:unique\s+)?index\s+(?:if\s+not\s+exists\s+)?(\w+)', sql, re.I):
            check(f'index {name}', name in indexes)
        for name in re.findall(r'create\s+policy\s+"([^"]+)"', sql, re.I):
            check(f'policy {name}', name in policies)
        for name in re.findall(r'create\s+trigger\s+(\w+)', sql, re.I):
            check(f'enabled trigger {name}', triggers.get(name, {}).get('enabled') == 'O')
        for match in re.finditer(r'create\s+or\s+replace\s+function\s+public\.(\w+).*?\bas\s+(\$\w*\$)(.*?)\2', sql, re.I | re.S):
            name, _, body = match.groups()
            remote = functions.get(name, {})
            actual = re.search(r'\bas\s+(\$\w*\$)(.*?)\1', remote.get('definition', ''), re.I | re.S)
            check(f'function {name} exact normalized body', actual is not None and normalized(body) == normalized(actual[2]))
            check(f'function {name} SECURITY DEFINER', remote.get('security_definer'))
        if version == '001':
            bucket = buckets.get('ball-images', {})
            check('ball-images public 512 KiB raster bucket', bucket.get('public') and bucket.get('file_size_limit') == 524288 and set(bucket.get('allowed_mime_types', [])) == {'image/png', 'image/jpeg', 'image/webp'})
        if version == '002':
            check('singleton settings row exists', inventory['settings_row_present'])
            check('admins has no API policies', not any(p['tablename'] == 'admins' for p in policies.values()))
        if version in ('003', '007'):
            policy = policies.get('replays insert', {})
            check('latest replay insert policy requires authenticated creator', policy.get('roles') == ['authenticated'] and 'auth.uid()' in str(policy.get('with_check')))
        if version == '013':
            column = columns.get(('app_settings', 'blood_color'), {})
            check('blood_color bigint NOT NULL default ARGB red', column.get('data_type') == 'bigint' and column.get('is_nullable') == 'NO' and '4292416811' in str(column.get('column_default')))
        if version == '020':
            check('full replay document constraint', all(s in constraints.get('replays_payload_check', '') for s in ['ballwars-replay', '1048576', 'query', 'format', 'version']))
            check('expanded balls payload limit', '524288' in constraints.get('replays_balls_check', ''))
        if version in ('011', '021'):
            rule = constraints.get('replays_tuning_check', '')
            check('corrected tuning regex and 2000 character bound', '[A-Za-z0-9_-]+$' in rule and '2000' in rule and '{1,2000}' not in rule)
        if version == '023':
            bucket = buckets.get('sprite-sheets', {})
            check('sprite-sheets public 4 MiB PNG/WebP bucket', bucket.get('public') and bucket.get('file_size_limit') == 4194304 and set(bucket.get('allowed_mime_types', [])) == {'image/png', 'image/webp'})
            check('sprite manifest grants', all(g['allowed'] for g in inventory['grants'] if g['table'] == 'sprite_atlases' and (g['privilege'] == 'SELECT' or g['role'] == 'authenticated')))
        if version == '024':
            check('sprite revisions complete for current library', inventory['unarchived_sprite_count'] == 0)
            check('sprite revisions read-only to API roles', all(g['allowed'] == (g['privilege'] == 'SELECT') for g in inventory['grants'] if g['table'] == 'sprite_atlas_revisions'))
            check('revision storage retention is restrictive', policies.get('Retain revision sheets', {}).get('permissive') == 'RESTRICTIVE')
        if not checks:
            raise SystemExit(f'No verification criteria for {file.name}')
        result = {'version': version, 'file': file.name, 'sha256': hashlib.sha256(file.read_bytes()).hexdigest(), 'verified': all(c['passed'] for c in checks), 'checks': checks}
        results.append(result)
        print(version, 'PASS' if result['verified'] else 'FAIL', ', '.join(c['check'] for c in checks if not c['passed']))
    report = {'project_ref': 'ehepdokwjmudssgkxoij', 'verified_on': datetime.now(timezone(timedelta(hours=8))).date().isoformat(), 'metadata_snapshot_sha256': hashlib.sha256(raw).hexdigest(), 'all_verified': all(r['verified'] for r in results), 'migrations': results}
    Path(sys.argv[2]).write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    return 0 if report['all_verified'] else 1


if __name__ == '__main__':
    sys.exit(main())
