package guardrails.forbidden

# Evaluates API usage collected during static analysis runs. Any entry in
# ``input.calls`` that matches the deny list will cause the policy to fail.

default allow := false

allow {
  not deny[_]
}

deny[msg] {
  not input.calls
  msg := "Policy input must include the 'calls' array."
}

deny[msg] {
  input.calls
  not is_array(input.calls)
  msg := "Policy input 'calls' must be an array of call records."
}

# Canonical list of APIs that are blocked in the automation environment.
blocked_apis := {
  "invoke-expression": "Invoke-Expression is forbidden. Use Invoke-Command -ScriptBlock instead.",
  "invokecommand": "InvokeCommand is forbidden outside vetted wrappers.",
  "eval": "Python eval() is disabled due to arbitrary code execution risk.",
  "exec": "Python exec() is disabled due to arbitrary code execution risk.",
  "system": "Direct system() calls are blocked; use subprocess without shell mode.",
}

# Optional allow list for specific files or tools. Each entry is expected to be
# an object with ``api`` and ``path`` patterns. When provided, the matching call
# is skipped.
exception(call) {
  exception := input.exceptions[_]
  lower(exception.api) == lower(call.api)
  glob.match(exception.path, ["/"], call.path)
}

# Flag any call that uses a forbidden API without an explicit exception.
deny[msg] {
  call := input.calls[_]
  api := lower(call.api)
  message := blocked_apis[api]
  not exception(call)
  location := format_location(call)
  msg := sprintf("%s %s", [message, location])
}

# Require the scanning tool to provide structured metadata for traceability.
deny[msg] {
  call := input.calls[index]
  not call.path
  msg := sprintf("Forbidden API record at index %v is missing the source path.", [index])
}

deny[msg] {
  call := input.calls[index]
  not call.line
  msg := sprintf("Forbidden API record at index %v is missing the line number.", [index])
}

format_location(call) = result {
  result := sprintf("(found in %s:%v)", [call.path, call.line])
}

