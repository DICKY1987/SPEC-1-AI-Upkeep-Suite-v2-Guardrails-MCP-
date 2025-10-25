package guardrails.changeplan

import future.keywords.every

default allow := false

allow {
  input.summary != ""
  every change in input.changes {
    change.path != ""
    change.description != ""
  }
}
