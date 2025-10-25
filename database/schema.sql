CREATE TABLE access_groups (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT NOT NULL
);

CREATE TABLE tools (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT NOT NULL
);

CREATE TABLE group_tools (
    group_id INTEGER NOT NULL REFERENCES access_groups(id),
    tool_id INTEGER NOT NULL REFERENCES tools(id),
    PRIMARY KEY (group_id, tool_id)
);

CREATE TABLE ledger (
    id INTEGER PRIMARY KEY,
    timestamp TEXT NOT NULL,
    result TEXT NOT NULL,
    payload TEXT NOT NULL
);
