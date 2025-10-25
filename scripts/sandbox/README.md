# Sandbox Script Placeholder

Phase 0 requires the sandbox directory to be present so that the dedicated stream can add platform-specific isolation scripts (`
sandbox_linux.sh`, `sandbox_windows.ps1`, `New-EphemeralWorkspace.ps1`, `Remove-EphemeralWorkspace.ps1`) without further reorg
anization. Keeping the directory tracked now ensures later automation does not need to create it dynamically.

> Related plan references: *Development Order - Parallel Streams Strategy*, Stream E "Sandbox System".
