package guardrails.delivery

import future.keywords.every

default allow := false

allow {
  required := {"code", "tests", "docs"}
  provided := {item | item := input.components[_]}
  every need in required {
    need in provided
  }
}
