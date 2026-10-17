# Structured CLI output — M0003 authority

`--json` is an optional **valueless switch** for `status` and `history` only. Text-mode defaults remain intact. JSON emits exactly one UTF-8 object plus newline on stdout, without progress lines. Errors emit no JSON/stdout, use stderr and nonzero exit codes (usage 2; operation 1). `--source` and `--package` together are rejected, not silently ignored. Paths are relative, `/`-separated, ordinally sorted; object keys are camelCase; `schemaVersion` is integer 1. Arrays always present. JSON is a stable CLI interchange surface distinct from package manifest v1. Do not overhaul help-text wording (M0004 scope).

## `status --json`

Managed workspace clean/dirty:
```json
{"schemaVersion":1,"kind":"workspace","package":{"id":"sample.data","version":"1.0.0"},"clean":false,"changes":{"added":["new.bin"],"modified":["nested/data.txt"],"deleted":[]}}
```
`package.version` is the baseline version. For clean state, `clean:true` and all empty arrays.

Successful `status --package file.nupkg --json`:
```json
{"schemaVersion":1,"kind":"package","package":{"id":"sample.data","version":"1.0.0"},"valid":true,"fileCount":2}
```
Invalid package fails instead of emitting successful `{valid:false}`.

## `history --json`

Works with workspace or explicit package; includes full chronological recorded history, preserving optional absent message:
```json
{"schemaVersion":1,"package":{"id":"sample.data","version":"1.1.0"},"history":[{"version":"1.0.0","previousVersion":null,"changes":{"added":["nested/data.txt"],"modified":[],"deleted":[]}},{"version":"1.1.0","previousVersion":"1.0.0","message":"Refresh","changes":{"added":[],"modified":["nested/data.txt"],"deleted":[]}}]}
```

Validate through the actually installed .NET tool with external JSON parsing; assert shape/types, both source forms, absent/present message, errors/streams and text-mode retention.
