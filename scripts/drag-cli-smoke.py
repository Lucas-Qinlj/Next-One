#!/usr/bin/env python3
"""Real CLI process checks for drag/drop endpoints; uses temporary data only."""
import json
import os
import subprocess
import tempfile
from pathlib import Path

cli = Path(__file__).resolve().parents[1] / '.build/debug/todo'
with tempfile.TemporaryDirectory(prefix='todo-drag-') as directory:
    env = dict(os.environ, TODO_AI_HOME=directory)
    def run(*args, error=None):
        p = subprocess.run([str(cli), *args], env=env, text=True, capture_output=True)
        result = json.loads(p.stderr if p.returncode else p.stdout)
        if error:
            assert p.returncode and result['error']['code'] == error, result
            return
        assert p.returncode == 0, result
        return result['data']
    def task(tid): return run('get', tid)['task']
    a = run('add', '--project', 'unclassified', '--title', 'A')['task']['id']
    b = run('add', '--project', 'unclassified', '--title', 'B')['task']['id']
    result = run('place', b, '--expected-revision', '1', '--anchor', a, '--anchor-revision', '1', '--placement', 'before')
    assert result['ordered_ids'] == [b, a]
    assert [x['id'] for x in run('list')['tasks']] == [b, a]
    project = run('group', a, '--expected-revision', str(task(a)['revision']), '--target', b,
                  '--target-revision', str(task(b)['revision']), '--name', 'Group')['project']
    assert project['paths'] == []
    assert task(a)['project_id'] == task(b)['project_id'] == project['id']
    run('context', '--cwd', directory, error='project_unmatched')
    run('project', 'bind', '--project', project['id'], '--expected-revision', '1', '--path', directory)
    assert run('context', '--cwd', directory)['project']['id'] == project['id']
    empty = run('project', 'create', '--name', 'Empty')['project']['id']
    c = run('add', '--project', 'unclassified', '--title', 'C')['task']['id']
    d = run('add', '--project', 'unclassified', '--title', 'D')['task']['id']
    run('group', c, '--expected-revision', '1', '--target', d, '--target-revision', '1', '--project', project['id'], error='invalid_field')
    assert 'project_id' not in task(c)
    run('group', c, '--expected-revision', '1', '--target', d, '--target-revision', '1', '--project', empty)
    run('place', c, '--expected-revision', str(task(c)['revision']), '--project', 'unclassified', '--parent', 'root', '--placement', 'end')
    assert 'project_id' not in task(c)
    board = run('board', 'list')
    run('board', 'place', '--key', 'p:' + empty, '--expected-revision', '1',
        '--expected-board-revision', str(board['board_revision']), '--anchor', 'p:' + project['id'], '--placement', 'before')
    board = run('board', 'list')
    assert board['ordered_keys'][0] == 'p:' + empty
    run('board', 'place', '--key', 't:' + c, '--expected-revision', str(task(c)['revision']),
        '--expected-board-revision', str(board['board_revision']), '--anchor', 'p:' + project['id'], '--placement', 'before')
    assert run('board', 'list')['ordered_keys'] == ['p:' + empty, 't:' + c, 'p:' + project['id']]
print('PASS: real CLI ordering, persistent reads, atomic grouping, empty-project validation, deferred directory binding, unclassified move')
