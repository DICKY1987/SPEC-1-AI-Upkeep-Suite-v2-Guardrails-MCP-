package guardrails.changeplan

import future.keywords.every

# ChangePlan policies ensure that AI-generated plans adhere to the
# repository's quality guardrails before patches are applied.

default allow := false

allow {
  not deny[_]
}

deny[msg] {
  not input.summary
  msg := "ChangePlan must include a summary."
}

deny[msg] {
  is_string(input.summary)
  not string_length_ok(input.summary, 12)
  msg := "ChangePlan summary is too short; provide meaningful context."
}

deny[msg] {
  not input.changes
  msg := "ChangePlan must declare at least one change entry."
}

deny[msg] {
  not is_array(input.changes)
  msg := "ChangePlan.changes must be an array."
}

deny[msg] {
  change := input.changes[_]
  not is_object(change)
  msg := "Each change entry must be an object."
}

deny[msg] {
  change := input.changes[index]
  not change.path
  msg := sprintf("Change entry %v is missing the path property.", [index])
}

deny[msg] {
  change := input.changes[index]
  not is_string(change.path)
  msg := sprintf("Change entry %v has a non-string path.", [index])
}

deny[msg] {
  change := input.changes[index]
  path := lower(change.path)
  invalid_path(path)
  msg := sprintf("Change entry %v targets an invalid path '%s'.", [index, change.path])
}

deny[msg] {
  change := input.changes[index]
  not change.description
  msg := sprintf("Change entry %v is missing the description property.", [index])
}

deny[msg] {
  change := input.changes[index]
  not is_string(change.description)
  msg := sprintf("Change entry %v has a non-string description.", [index])
}

deny[msg] {
  change := input.changes[index]
  is_string(change.description)
  not string_length_ok(change.description, 12)
  msg := sprintf("Change entry %v description must explain the rationale.", [index])
}

deny[msg] {
  change := input.changes[index]
  is_code_path(change.path)
  not has_valid_tests(change)
  msg := sprintf("Code change '%s' must declare the tests it impacts.", [change.path])
}

deny[msg] {
  not input.validation
  msg := "ChangePlan must include a validation summary."
}

deny[msg] {
  not is_object(input.validation)
  msg := "ChangePlan.validation must be an object."
}

deny[msg] {
  flag := required_validation_flags[_]
  not truthy_flag(flag)
  msg := sprintf("Validation flag '%s' must be true.", [flag])
}

deny[msg] {
  flag := optional_validation_flags[_]
  flag in input.validation
  not boolean_flag(flag)
  msg := sprintf("Validation flag '%s' must be boolean when provided.", [flag])
}

# --- helper functions -----------------------------------------------------

required_validation_flags := ["format", "lint", "test"]
optional_validation_flags := ["sast", "policy", "secrets"]

code_extensions := [
  ".ps1",
  ".psm1",
  ".psd1",
  ".py",
  ".ts",
  ".tsx",
  ".js",
  ".jsx"
]

whitespace_chars := " \t\n\r"

invalid_path(path) {
  startswith(path, "/")
}

invalid_path(path) {
  contains(path, "..")
}

invalid_path(path) {
  contains(path, "\\")
}

invalid_path(path) {
  re_match("(?i)^tests?/", path)
  not contains(path, ".")
}

is_code_path(path) {
  ext := code_extensions[_]
  endswith(lower(path), ext)
}

has_valid_tests(change) {
  change.tests
  is_array(change.tests)
  every t in change.tests {
    is_string(t)
    count(trimmed(t)) > 0
  }
}

truthy_flag(name) {
  value := input.validation[name]
  value == true
}

boolean_flag(name) {
  value := input.validation[name]
  value == true
}

boolean_flag(name) {
  value := input.validation[name]
  value == false
}

string_length_ok(text, min) {
  count(trimmed(text)) >= min
}

trimmed(text) = result {
  result := trim(text, whitespace_chars)
}

