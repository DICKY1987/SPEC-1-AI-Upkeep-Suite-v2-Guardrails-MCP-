# File Naming Convention

All files processed by the router must follow the structure:

```
PROJECT-AREA-SUBFOLDER__name__timestamp__version__ulid__sha8.ext
```

- `PROJECT` identifies the codebase (e.g., SPEC-1).
- `AREA` and `SUBFOLDER` align with repository directories.
- `name` describes the payload succinctly.
- `timestamp` is an ISO 8601 string without separators.
- `version` increments for repeated deliveries.
- `ulid` provides global uniqueness.
- `sha8` is the first eight characters of the related commit SHA.
