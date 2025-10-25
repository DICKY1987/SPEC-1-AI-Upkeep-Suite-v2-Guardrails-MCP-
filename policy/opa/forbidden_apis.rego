package guardrails.forbidden

default allow := true

deny[msg] {
  api := lower(input.api)
  api == "invoke-expression"
  msg := "Invoke-Expression is forbidden"
}

deny[msg] {
  api := lower(input.api)
  api == "eval"
  msg := "Eval is forbidden"
}
