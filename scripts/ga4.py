#!/usr/bin/env python3
"""
Read Google Analytics 4 for a Heart environment, to verify what the app actually reported.

The app's analytics taxonomy (docs/2026-09-24.analytics.md) is only half testable on the device:
a unit test proves an event is built correctly and a forced debug run proves it leaves the
phone, but neither says it arrived. This asks GA4.

`--env` selects a Google service-account key, read from the environment's secrets bucket through
its AWS profile — the same place and the same layout as the deploy workflows' secrets, one bucket
per AWS account with the same key in each. Nothing about the machine's own Google credentials is
touched: no `gcloud auth application-default login`, which would overwrite a shared ADC file that
other projects here rely on.

The key's service account needs read access on the GA4 property itself — Analytics admin ->
Property Access Management -> Viewer. That is not GCP IAM, so no project-level role grants it,
and the Analytics Data API has to be enabled on the project.

Run:
  scripts/ga4.py --env dev properties          # what this key can see, with property ids
  scripts/ga4.py --env dev realtime            # event counts, last 30 minutes
  scripts/ga4.py --env dev events --days 7     # event counts over a date range
  scripts/ga4.py --env prod events --days 1 --property 123456789

The property is resolved automatically when the key can see exactly one; pass --property when
it sees several. Authentication is the JWT-bearer exchange, stdlib only and no dependency to
install — the same flow as `store_listing.py`'s `play_token()`, against a different scope.
"""

import argparse
import base64
import json
import os
import ssl
import subprocess
import sys
import time
import urllib.error
import urllib.request
from functools import cache

# Analytics to read the reports; Firebase to ask whether the project is linked to a property at
# all, which is the first thing to know when a report comes back empty.
SCOPES = (
    'https://www.googleapis.com/auth/analytics.readonly',
    'https://www.googleapis.com/auth/analytics.edit',
    'https://www.googleapis.com/auth/firebase.readonly',
)
ADMIN_API = 'https://analyticsadmin.googleapis.com/v1beta'
DATA_API = 'https://analyticsdata.googleapis.com/v1beta'
FIREBASE_API = 'https://firebase.googleapis.com/v1beta1'

# Each environment's AWS profile and the secrets bucket it reaches. The GCP project is not
# named here: it is in the key file, and stating it twice invites the two to disagree.
ENVIRONMENTS = {
    'dev': ('heart-dev', '583168578067-ca-central-1-static'),
    'prod': ('heart-prod', '922419543441-ca-central-1-static'),
}

# The same object in both buckets — the account the profile reaches is what makes it dev or prod,
# exactly as `secrets/firebase/google-services.json` works in the deploy workflows.
KEY_OBJECT = 'secrets/firebase/gcp-sa-key.json'

# The python.org build ships no CA bundle, so urllib cannot verify either API.
# macOS keeps one here; fall back to whatever the interpreter was built with.
_CA = '/etc/ssl/cert.pem'
SSL_CONTEXT = ssl.create_default_context(cafile=_CA if os.path.exists(_CA) else None)

# The taxonomy's parameters, as GA4 has to be told about them. Mirrors the constants in
# `shared/heart_state/lib/src/analytics.dart` — anything added there needs a row here, or it is
# collected and never reportable, which looks exactly like the app not sending it.
#
# Strings are dimensions and numbers are metrics; the split follows what `Analytics` encodes, so
# a bool flag is a dimension because it ships as 'true'/'false'. GA4 allows 50 of each.
EVENT_DIMENSIONS = {
    'provider': 'Auth provider',
    'arrival': 'Account arrival',
    'from_anonymous': 'From anonymous session',
    'reason': 'Failure reason',
    'placement': 'Prompt placement',
    'ok': 'Succeeded',
    'source': 'Source',
    'pinned_notes': 'Pinned notes applied',
    'had_content': 'Had content',
    'field': 'Edited field',
    'format': 'Export format',
    'filed': 'Filed into a folder',
    'granted': 'Permission granted',
}

# User properties are user-scoped dimensions; GA4 draws no other distinction.
USER_DIMENSIONS = {
    'account_state': 'Account state',
    'auth_provider': 'Auth provider (user)',
    'form_factor': 'Form factor',
    'workouts_bucket': 'Workouts bucket',
    'templates_bucket': 'Templates bucket',
}

METRICS = {
    'rows': 'Replay rows',
    'uploaded': 'Replay uploaded',
    'existing': 'Replay already there',
    'skipped': 'Replay skipped',
    'duration_ms': 'Duration (ms)',
    'exercise_count': 'Exercises',
    'set_count': 'Sets',
    'duration_min': 'Duration (min)',
    'unticked_sets': 'Unticked sets',
    'pages': 'Backfill pages',
    'unmatched': 'Unmatched exercises',
    'created_custom': 'Custom exercises created',
}


@cache
def service_account_key(environment: str) -> dict:
    """The environment's Google service-account key, read from its secrets bucket.

    Streamed to stdout rather than downloaded: nothing here should leave a Google private key
    sitting in the working tree. The one thing that needs a file is `openssl`, which gets a 0600
    temp file for the length of a single signature.
    """
    profile, bucket = ENVIRONMENTS[environment]
    fetched = subprocess.run(
        ['aws', '--profile', profile, 's3', 'cp', f's3://{bucket}/{KEY_OBJECT}', '-'],
        capture_output=True,
        check=False,
    )
    if fetched.returncode != 0:
        sys.exit(
            f'ga4: could not read s3://{bucket}/{KEY_OBJECT} with AWS profile {profile}\n'
            f'{fetched.stderr.decode().strip()}'
        )
    return json.loads(fetched.stdout)


def _b64(data: str | bytes) -> str:
    if isinstance(data, str):
        data = data.encode()
    return base64.urlsafe_b64encode(data).rstrip(b'=').decode()


def _sign(pem_path: str, payload: str) -> bytes:
    signed = subprocess.run(
        ['openssl', 'dgst', '-sha256', '-sign', pem_path],
        input=payload.encode(),
        capture_output=True,
        check=True,
    )
    return signed.stdout


def access_token(environment: str) -> str:
    """Exchanges the environment's service-account key for a token scoped to [SCOPES].

    The private key is written to a 0600 temp file because `openssl dgst -sign` reads a path,
    not a stream, and removed in a `finally` so a failed signature does not leave a key on disk.
    """
    key = service_account_key(environment)
    pem = f'/tmp/.heart_ga4_{environment}.pem'
    with open(os.open(pem, os.O_CREAT | os.O_WRONLY | os.O_TRUNC, 0o600), 'w') as f:
        f.write(key['private_key'])
    try:
        now = int(time.time())
        head = _b64(json.dumps({'alg': 'RS256', 'typ': 'JWT'}))
        body = _b64(
            json.dumps(
                {
                    'iss': key['client_email'],
                    'scope': ' '.join(SCOPES),
                    'aud': 'https://oauth2.googleapis.com/token',
                    'iat': now,
                    'exp': now + 3500,
                }
            )
        )
        assertion = f'{head}.{body}.{_b64(_sign(pem, f"{head}.{body}"))}'
    finally:
        os.unlink(pem)

    status, payload = _http(
        'POST',
        'https://oauth2.googleapis.com/token',
        body=f'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion={assertion}',
        content_type='application/x-www-form-urlencoded',
    )
    if status != 200:
        sys.exit(f'ga4: token exchange failed ({status}): {payload}')
    return json.loads(payload)['access_token']


def _http(
    method: str,
    url: str,
    body: dict | str | None = None,
    token: str | None = None,
    content_type: str = 'application/json',
) -> tuple[int, str]:
    data = body.encode() if isinstance(body, str) else json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(url, data=data, method=method)
    request.add_header('Content-Type', content_type)
    if token:
        request.add_header('Authorization', f'Bearer {token}')
    try:
        with urllib.request.urlopen(request, context=SSL_CONTEXT) as response:
            return response.status, response.read().decode()
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()


def _call(method: str, url: str, token: str, body: dict | None = None) -> dict:
    for attempt in range(3):
        status, payload = _http(method, url, body=body, token=token)
        # The admin API returns a transient 503 often enough to be worth riding out — but only
        # on a read. A create that succeeded and lost its response would come back as a
        # duplicate, and a write's recovery is re-running the command, which by then sends only
        # what is still missing.
        if status < 500 or method != 'GET' or attempt == 2:
            break
        time.sleep(1 + attempt)

    if status != 200:
        # 403 here is nearly always the property grant rather than the token: the scope is
        # right or the exchange would have failed, so say which one to go and check. Reads want
        # Viewer on the property, writes — registering a dimension — want Editor.
        grant = 'Editor' if method == 'POST' else 'Viewer'
        hint = f' — is the service account an Analytics {grant} on this property?' if status == 403 else ''
        sys.exit(f'ga4: {method} {url} failed ({status}){hint}\n{payload}')
    return json.loads(payload) if payload else {}


def analytics_link(token: str, environment: str) -> tuple[str, str] | None:
    """The GA4 property this environment's Firebase project reports as linked, if any.

    Distinct from what [properties] returns, and the two disagree in both directions: a project
    can be linked to a property this key cannot read, and a key can read properties belonging to
    no Firebase project at all. Unlinked is the interesting one — the app's events go nowhere.
    """
    project = service_account_key(environment)['project_id']
    status, payload = _http('GET', f'{FIREBASE_API}/projects/{project}/analyticsDetails', token=token)
    if status == 404:
        return None
    if status != 200:
        sys.exit(f'ga4: could not read the analytics link for {project} ({status})\n{payload}')
    linked = json.loads(payload).get('analyticsProperty') or {}
    return (linked['id'], linked.get('displayName', '?')) if linked.get('id') else None


def properties(token: str) -> list[tuple[str, str, str]]:
    """Every GA4 property this key can read, as (id, display name, owning account).

    The account comes along because it is what a *new* property needs: linking a Firebase
    project to Analytics creates the property inside an account, named by id.
    """
    summaries = _call('GET', f'{ADMIN_API}/accountSummaries', token).get('accountSummaries') or []
    return [
        (
            summary['property'].split('/')[-1],
            summary.get('displayName', '?'),
            account.get('account', '?'),
        )
        for account in summaries
        for summary in account.get('propertySummaries') or []
    ]


def resolve_property(token: str, environment: str, requested: str | None) -> str:
    """Which property to read for [environment].

    Firebase's own link is the answer whenever there is one: it is what the app reports into, by
    definition. Falling back to "the only property this key can see" would be a guess, and one
    key can easily see several — this account holds six.
    """
    if requested:
        return requested
    if linked := analytics_link(token, environment):
        return linked[0]

    found = properties(token)
    if len(found) == 1:
        return found[0][0]
    if not found:
        sys.exit('ga4: this key can see no GA4 property — grant it Viewer in Analytics admin')
    listed = '\n'.join(f'  {id}  {name}' for id, name, _ in found)
    sys.exit(f'ga4: no property linked to this project, and several visible — pass --property:\n{listed}')


def _registered(token: str, property_id: str, kind: str) -> set[str]:
    """The parameter names already registered on the property, for `customDimensions` or
    `customMetrics`.

    Archived definitions do not come back from these lists and their parameter name stays taken,
    so a create can still fail on a name this says is missing. That is rare enough to report
    rather than pre-empt.
    """
    names: set[str] = set()
    token_param = ''
    while True:
        page = _call('GET', f'{ADMIN_API}/properties/{property_id}/{kind}{token_param}', token)
        names.update(entry['parameterName'] for entry in page.get(kind) or [])
        cursor = page.get('nextPageToken')
        if not cursor:
            return names
        token_param = f'?pageToken={cursor}'


def register(token: str, property_id: str, apply: bool) -> int:
    """Reports which of the taxonomy's parameters the property is missing, and creates them
    when [apply].

    Idempotent by construction: what exists is read first and only the difference is sent, so a
    re-run after a taxonomy change adds the new rows and leaves the rest alone.
    """
    wanted = [
        ('customDimensions', EVENT_DIMENSIONS, {'scope': 'EVENT'}),
        ('customDimensions', USER_DIMENSIONS, {'scope': 'USER'}),
        ('customMetrics', METRICS, {'scope': 'EVENT', 'measurementUnit': 'STANDARD'}),
    ]

    missing: list[tuple[str, str, str, dict]] = []
    for kind, table, extra in wanted:
        have = _registered(token, property_id, kind)
        for parameter, label in table.items():
            if parameter not in have:
                missing.append((kind, parameter, label, extra))

    if not missing:
        print(f'property {property_id}: every parameter in the taxonomy is registered')
        return 0

    for kind, parameter, label, extra in missing:
        scope = extra['scope'].lower()
        what = 'metric' if kind == 'customMetrics' else f'{scope} dimension'
        print(f'{"creating" if apply else "missing"}: {parameter} ({what}) — {label}')
        if apply:
            _call(
                'POST',
                f'{ADMIN_API}/properties/{property_id}/{kind}',
                token,
                {'parameterName': parameter, 'displayName': label} | extra,
            )

    if apply:
        print(f'\nregistered {len(missing)} on property {property_id}')
        return 0

    print(f'\n{len(missing)} missing on property {property_id}; re-run with --apply to create them')
    return 1


def event_counts(token: str, property_id: str, days: int | None) -> list[tuple[str, int]]:
    """Event name -> count, from the realtime API when [days] is None and the report API otherwise.

    The two are different endpoints on purpose. Realtime covers roughly the last 30 minutes and
    is what a run a moment ago shows up in; the report API is complete but lags, so a freshly
    sent event is genuinely absent from it for a while and that absence means nothing.
    """
    if days is None:
        url = f'{DATA_API}/properties/{property_id}:runRealtimeReport'
        body: dict = {'dimensions': [{'name': 'eventName'}], 'metrics': [{'name': 'eventCount'}]}
    else:
        url = f'{DATA_API}/properties/{property_id}:runReport'
        body = {
            'dimensions': [{'name': 'eventName'}],
            'metrics': [{'name': 'eventCount'}],
            'dateRanges': [{'startDate': f'{days}daysAgo', 'endDate': 'today'}],
        }

    rows = _call('POST', url, token, body).get('rows') or []
    counts = [(row['dimensionValues'][0]['value'], int(row['metricValues'][0]['value'])) for row in rows]
    return sorted(counts, key=lambda row: (-row[1], row[0]))


def report(counts: list[tuple[str, int]], window: str) -> int:
    if not counts:
        print(f'no events in {window}')
        return 0
    width = max(len(name) for name, _ in counts)
    for name, count in counts:
        print(f'{name.ljust(width)}  {count}')
    print(f'\n{len(counts)} event names, {sum(count for _, count in counts)} events in {window}')
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--env', required=True, choices=tuple(ENVIRONMENTS), help='which environment to read')
    parser.add_argument('--property', help='GA4 property id; defaults to the one Firebase reports as linked')
    parser.add_argument(
        'command',
        choices=('properties', 'realtime', 'events', 'dimensions'),
        help='what to ask for',
    )
    parser.add_argument('--days', type=int, default=7, help='date-range size for `events` (default: 7)')
    parser.add_argument('--apply', action='store_true', help='for `dimensions`: create what is missing')
    args = parser.parse_args()

    token = access_token(args.env)

    if args.command == 'properties':
        project = service_account_key(args.env)['project_id']
        match analytics_link(token, args.env):
            case (id, name):
                print(f'{project}: linked to property {id} ({name})\n')
            case None:
                # Everything downstream is moot: with no property behind the project, the SDK
                # uploads into nothing and no amount of instrumenting the app changes that.
                print(f'{project}: NO Google Analytics property linked — events go nowhere\n')

        found = properties(token)
        width = max((len(name) for _, name, _ in found), default=0)
        for id, name, account in found:
            print(f'{id}  {name.ljust(width)}  {account}')
        if not found:
            print('this key can read no property — grant it Viewer in Analytics admin')
        return 0 if found else 1

    property_id = resolve_property(token, args.env, args.property)
    if args.command == 'dimensions':
        return register(token, property_id, args.apply)
    if args.command == 'realtime':
        return report(event_counts(token, property_id, None), 'the last 30 minutes')
    return report(event_counts(token, property_id, args.days), f'the last {args.days} days')


if __name__ == '__main__':
    sys.exit(main())
