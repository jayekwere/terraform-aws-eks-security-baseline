#!/usr/bin/env python3
"""Fail on mutable Actions, write permissions, or unsafe PR execution contexts."""
from pathlib import Path
import re
import yaml

for path in Path('.github/workflows').glob('*.yml'):
    text=path.read_text()
    conf=yaml.safe_load(text)
    assert 'pull_request_target' not in text and 'secrets.' not in text
    assert conf.get('permissions') == {'contents':'read'}, path
    for job in conf['jobs'].values():
        assert 'permissions' not in job or job['permissions']=={'contents':'read'}, path
        for step in job.get('steps',[]):
            if 'uses' in step:
                assert re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+@[a-f0-9]{40}',step['uses']),step['uses']
                if step['uses'].startswith('actions/checkout@'):
                    assert step.get('with',{}).get('persist-credentials') is False
    assert '${{ github.event.pull_request' not in text
print('PASS: Actions pinned; contents:read only; checkout credentials disabled; no privileged PR trigger')
