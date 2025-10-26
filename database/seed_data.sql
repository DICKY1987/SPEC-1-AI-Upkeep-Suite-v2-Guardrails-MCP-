BEGIN TRANSACTION;

-- Seed access groups if they do not already exist
INSERT INTO access_groups (name, description)
SELECT 'reader', 'Read-only access to audit artifacts and historical reports'
WHERE NOT EXISTS (
    SELECT 1
    FROM access_groups
    WHERE name = 'reader'
);

INSERT INTO access_groups (name, description)
SELECT 'contributor', 'Standard contribution rights with ability to trigger validations'
WHERE NOT EXISTS (
    SELECT 1
    FROM access_groups
    WHERE name = 'contributor'
);

INSERT INTO access_groups (name, description)
SELECT 'maintainer', 'Full maintenance privileges including guardrail updates'
WHERE NOT EXISTS (
    SELECT 1
    FROM access_groups
    WHERE name = 'maintainer'
);

-- Seed tool catalog
INSERT INTO tools (name, description)
SELECT 'psscriptanalyzer', 'PowerShell analyzer enforcing coding and security guardrails'
WHERE NOT EXISTS (
    SELECT 1
    FROM tools
    WHERE name = 'psscriptanalyzer'
);

INSERT INTO tools (name, description)
SELECT 'pester', 'PowerShell testing framework for deterministic validation'
WHERE NOT EXISTS (
    SELECT 1
    FROM tools
    WHERE name = 'pester'
);

INSERT INTO tools (name, description)
SELECT 'ruff', 'Python linter and formatter for quick feedback'
WHERE NOT EXISTS (
    SELECT 1
    FROM tools
    WHERE name = 'ruff'
);

INSERT INTO tools (name, description)
SELECT 'black', 'Python opinionated formatter run in check mode'
WHERE NOT EXISTS (
    SELECT 1
    FROM tools
    WHERE name = 'black'
);

INSERT INTO tools (name, description)
SELECT 'mypy', 'Python static type checker for strict mode enforcement'
WHERE NOT EXISTS (
    SELECT 1
    FROM tools
    WHERE name = 'mypy'
);

INSERT INTO tools (name, description)
SELECT 'pytest', 'Python unit test runner with coverage reporting'
WHERE NOT EXISTS (
    SELECT 1
    FROM tools
    WHERE name = 'pytest'
);

INSERT INTO tools (name, description)
SELECT 'semgrep', 'Semgrep-based SAST scanning configuration'
WHERE NOT EXISTS (
    SELECT 1
    FROM tools
    WHERE name = 'semgrep'
);

INSERT INTO tools (name, description)
SELECT 'gitleaks', 'Secret scanning to prevent credential exfiltration'
WHERE NOT EXISTS (
    SELECT 1
    FROM tools
    WHERE name = 'gitleaks'
);

INSERT INTO tools (name, description)
SELECT 'conftest', 'OPA/Conftest policy validation harness'
WHERE NOT EXISTS (
    SELECT 1
    FROM tools
    WHERE name = 'conftest'
);

-- Map groups to their permitted tools using an explicit matrix to avoid duplicate rows
WITH mappings AS (
    SELECT 'reader' AS group_name, 'psscriptanalyzer' AS tool_name UNION ALL
    SELECT 'reader', 'ruff' UNION ALL
    SELECT 'reader', 'semgrep' UNION ALL
    SELECT 'contributor', 'psscriptanalyzer' UNION ALL
    SELECT 'contributor', 'pester' UNION ALL
    SELECT 'contributor', 'ruff' UNION ALL
    SELECT 'contributor', 'black' UNION ALL
    SELECT 'contributor', 'mypy' UNION ALL
    SELECT 'contributor', 'pytest' UNION ALL
    SELECT 'contributor', 'semgrep' UNION ALL
    SELECT 'contributor', 'gitleaks' UNION ALL
    SELECT 'contributor', 'conftest' UNION ALL
    SELECT 'maintainer', 'psscriptanalyzer' UNION ALL
    SELECT 'maintainer', 'pester' UNION ALL
    SELECT 'maintainer', 'ruff' UNION ALL
    SELECT 'maintainer', 'black' UNION ALL
    SELECT 'maintainer', 'mypy' UNION ALL
    SELECT 'maintainer', 'pytest' UNION ALL
    SELECT 'maintainer', 'semgrep' UNION ALL
    SELECT 'maintainer', 'gitleaks' UNION ALL
    SELECT 'maintainer', 'conftest'
)
INSERT INTO group_tools (group_id, tool_id)
SELECT g.id, t.id
FROM mappings AS map
JOIN access_groups AS g ON g.name = map.group_name
JOIN tools AS t ON t.name = map.tool_name
WHERE NOT EXISTS (
    SELECT 1
    FROM group_tools gt
    WHERE gt.group_id = g.id
      AND gt.tool_id = t.id
);

COMMIT;
