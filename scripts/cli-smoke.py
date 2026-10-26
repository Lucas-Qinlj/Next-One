#!/usr/bin/env python3
"""Real CLI subprocess checks; only a fresh disposable directory is used."""
import concurrent.futures, json, os, pathlib, subprocess, tempfile
ROOT = pathlib.Path(__file__).resolve().parent.parent
CLI = ROOT / '.build/debug/todo'
with tempfile.TemporaryDirectory(prefix='todo-cli-') as tmp:
    env = dict(os.environ, NEXT_ONE_HOME=tmp)
    def run(*args, error=None):
        p = subprocess.run([str(CLI), *args], env=env, text=True, capture_output=True)
        value = json.loads(p.stderr if p.returncode else p.stdout)
        if error:
            assert p.returncode != 0 and value['error']['code'] == error, (args, p.stderr)
            return value
        assert p.returncode == 0 and value['ok'], (args, p.stderr)
        return value['data']
    project = run('project', 'bind', '--path', str(ROOT))['project']['id']
    assert run('context', '--cwd', str(ROOT))['project']['id'] == project
    run('context', '--cwd', str(ROOT) + '-other', error='project_unmatched')
    run('add', '--title', 'ambiguous', error='project_unmatched')
    args = ('add', '--project', project, '--title', 'CLI真实任务', '--source', 'codex', '--request-key', 'same-request')
    a = run(*args)['task']; assert run(*args)['task']['id'] == a['id']
    description = pathlib.Path(tmp) / 'description.txt'; description.write_text('多行\n保留 $HOME `literal` $(literal) 内容', encoding='utf8')
    updated = run('update', a['id'], '--description-file', str(description), '--status', 'in_progress', '--expected-revision', '1')['task']
    assert updated['description'] == description.read_text()
    run('update', a['id'], '--status', 'done', '--expected-revision', '1', error='revision_conflict')
    run('update', a['id'], '--mystery', 'x', '--expected-revision', '2', error='invalid_field')
    def race(title):
        p = subprocess.run([str(CLI), 'update', a['id'], '--title', title, '--expected-revision', '2'], env=env, capture_output=True, text=True)
        return p.returncode
    with concurrent.futures.ThreadPoolExecutor() as pool: codes = list(pool.map(race, ['writer-one', 'writer-two']))
    assert sorted(codes) == [0, 1], codes
    child = run('add', '--parent', a['id'], '--title', 'child')['task']
    run('complete', a['id'], '--expected-revision', '3', error='cascade_required')
    run('complete', a['id'], '--expected-revision', '3', '--cascade')
    assert run('get', child['id'])['task']['status'] == 'done'
    assert run('get', a['id'])['task']['description'] == description.read_text()
    print('PASS: CLI JSON, real process persistence, paths, partial updates, idempotency, concurrent revision conflict, cascade rollback, shell-literal description')
