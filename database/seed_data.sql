INSERT INTO access_groups (name, description) VALUES
  ('reader', 'Read-only access'),
  ('contributor', 'Standard contributor access'),
  ('maintainer', 'Full maintainer access');

INSERT INTO tools (name, description) VALUES
  ('psscriptanalyzer', 'PowerShell analyzer'),
  ('pester', 'PowerShell tests'),
  ('ruff', 'Python linter'),
  ('black', 'Python formatter'),
  ('mypy', 'Python type checker'),
  ('pytest', 'Python tests'),
  ('semgrep', 'SAST scanning'),
  ('gitleaks', 'Secret scanning'),
  ('conftest', 'OPA policy runner');
