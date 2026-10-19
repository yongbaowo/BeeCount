#!/usr/bin/env python3
"""Prepare a separate iOS identity; dry-run unless --apply is supplied."""
import argparse
import re
from pathlib import Path

ORIGINAL_ID = 'com.tntlikely.beecount'


def prepare(root: Path, bundle_id: str, team_id: str | None) -> dict[Path, str]:
    changes = {}
    development_team = team_id if team_id else '""'
    candidates = list((root / 'ios').rglob('*')) + [
        root / 'lib/main.dart',
        root / 'packages/flutter_cloud_sync_icloud/ios/Classes/ICloudManager.swift',
    ]
    allowed = {'.pbxproj', '.plist', '.entitlements', '.xcconfig', '.swift', '.strings', '.dart'}
    for path in candidates:
        if not path.is_file() or path.suffix not in allowed:
            continue
        # Never rewrite generated third-party dependencies or build output.
        if {'Pods', '.symlinks', 'build'} & set(path.relative_to(root).parts):
            continue
        before = path.read_text()
        after = before.replace(ORIGINAL_ID, bundle_id)
        after = after.replace('com.example.beecount.RunnerTests', bundle_id + '.RunnerTests')
        after = re.sub(r'DEVELOPMENT_TEAM = [A-Z0-9]+;',
                       f'DEVELOPMENT_TEAM = {development_team};', after)
        if path.suffix == '.xcconfig':
            after = re.sub(r'^APP_DISPLAY_NAME=.*$', 'APP_DISPLAY_NAME=蜜蜂记账·个人',
                           after, flags=re.MULTILINE)
        if path.suffix == '.strings':
            display_name = ('蜜蜂记账·个人' if path.parent.name == 'zh-Hans.lproj'
                            else '蜜蜂記帳·個人' if path.parent.name == 'zh-Hant.lproj'
                            else 'BeeCount Personal')
            after = re.sub(r'("?CFBundle(?:DisplayName|Name)"?\s*=\s*)"[^"]*"',
                           lambda match: match.group(1) + '"' + display_name + '"', after)
        if after != before:
            changes[path] = after
    return changes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bundle-id', required=True, help='Your own reverse-DNS app ID')
    parser.add_argument('--team-id', help='Your Apple development team ID; omit for unsigned builds')
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z][A-Za-z0-9-]*(?:\.[A-Za-z0-9-]+){2,}', args.bundle_id):
        parser.error('Invalid bundle ID')
    if args.bundle_id.startswith(ORIGINAL_ID):
        parser.error('Choose your own bundle ID, rather than the upstream author’s ID')
    if args.team_id is not None and not re.fullmatch(r'[A-Z0-9]{10}', args.team_id):
        parser.error('Team ID must contain 10 uppercase letters/digits')
    root = Path(__file__).resolve().parents[1]
    changes = prepare(root, args.bundle_id, args.team_id)
    for path, content in changes.items():
        print(('Updating ' if args.apply else 'Would update ') + str(path.relative_to(root)))
        if args.apply:
            path.write_text(content)
    print(f'{len(changes)} files. ' + ('Applied.' if args.apply else 'Dry run; no files changed.'))


if __name__ == '__main__':
    main()
