package guardrails.delivery

# Validates that AI-produced delivery bundles include the required artifacts
# for code review and automated validation.

default allow := false

allow {
  not deny[_]
}

deny[msg] {
  not input.components
  msg := "Delivery bundle must list the components it contains."
}

deny[msg] {
  not is_array(input.components)
  msg := "Delivery bundle components must be an array of strings."
}

deny[msg] {
  missing := required_components[_]
  not component_present(missing)
  msg := sprintf("Delivery bundle is missing the required '%s' component.", [missing])
}

deny[msg] {
  component := input.components[_]
  not is_string(component)
  msg := "All delivery bundle components must be strings."
}

deny[msg] {
  not input.metadata
  msg := "Delivery bundle metadata block is required."
}

deny[msg] {
  not is_object(input.metadata)
  msg := "Delivery bundle metadata must be an object."
}

deny[msg] {
  reviewers := input.metadata.reviewers
  not is_array(reviewers)
  msg := "Delivery bundle metadata.reviewers must be an array."
}

deny[msg] {
  reviewers := input.metadata.reviewers
  is_array(reviewers)
  count(reviewers) == 0
  msg := "Delivery bundle must identify at least one reviewer."
}

deny[msg] {
  reviewers := input.metadata.reviewers
  is_array(reviewers)
  some reviewer
  reviewer := reviewers[_]
  not is_string(reviewer)
  msg := "Each reviewer entry must be a string."
}

deny[msg] {
  not input.metadata.ticket
  msg := "Delivery bundle metadata.ticket is required for traceability."
}

deny[msg] {
  ticket := input.metadata.ticket
  not re_match("^[A-Z][A-Z0-9]+-[0-9]+$", ticket)
  msg := "Delivery bundle ticket must match organizational ticket format (e.g. ABC-123)."
}

# --- helper utilities -----------------------------------------------------

required_components := ["code", "tests", "docs"]

component_present(name) {
  component := input.components[_]
  lower(component) == lower(name)
}

