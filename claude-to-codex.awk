# Portable awk conversion for the scalar frontmatter used in .claude-base.
# Reject unsupported YAML rather than emitting a misleading Codex configuration.
function fail(message) {
    print FILENAME ":" NR ": " message > "/dev/stderr"
    failed = 1
    exit 1
}
function scalar(value, quote) {
    sub(/^[ \t]+/, "", value)
    sub(/[ \t]+$/, "", value)
    if (value ~ /^[|>\[\{&*!]/) fail("only plain or quoted single-line YAML scalars are supported")
    quote = substr(value, 1, 1)
    if (quote == "\047" || quote == "\042") {
        if (substr(value, length(value), 1) != quote) fail("unclosed quoted scalar")
        value = substr(value, 2, length(value) - 2)
        if (quote == "\047") gsub(/\047\047/, "\047", value)
        else if (value ~ /\\/) fail("escaped YAML double-quoted scalars are unsupported; use a plain or single-quoted scalar")
    } else sub(/[ \t]+#.*/, "", value)
    return value
}
function adapt(line) {
    gsub(/`CLAUDE.md` \/ `\.claude\/CLAUDE.md`/, "`AGENTS.md`", line)
    gsub(/\.claude\/CLAUDE.md/, "AGENTS.md", line)
    gsub(/CLAUDE.md/, "AGENTS.md", line)
    gsub(/\.claude\/agents\//, ".codex/agents/", line)
    gsub(/\.claude\/plans\//, ".codex/plans/", line)
    gsub(/\.claude\/skills\//, ".agents/skills/", line)
    gsub(/Claude Code/, "Codex", line)
    gsub(/Agent tool/, "available Codex subagent tools", line)
    gsub(/Agent call/, "subagent spawn", line)
    gsub(/frontmatter/, "TOML configuration", line)
    gsub(/`opus` \(pinned\)|`sonnet` \(pinned\)|`haiku` \(pinned\)/, "agent configuration or inherited session model", line)
    gsub(/an Opus planner/, "a planner", line)
    gsub(/Opus planner/, "planner", line)
    if (line ~ /Workers cannot spawn other workers/) return "The **main thread is the orchestrator**. Keep worker delegation in the main thread; workers report back to their caller."
    if (line ~ /Model tiers are pinned/) return "Use model settings from each agent TOML file when configured; otherwise inherit the session model."
    if (line ~ /The expensive model plans and verifies/) return "Use optional model mappings to choose an available model for each role."
    if (line ~ /mentally check before finalizing/) return "- After editing, run the relevant type-check or build command when available and report the result; distinguish unverified work."
    if (line == "$ARGUMENTS") return "Use any comment numbers or scope supplied in the user request."
    gsub(/\$ARGUMENTS/, "the arguments supplied in the user request", line)
    return line
}
function toml(value, result, i, c) {
    result = "\042"
    for (i = 1; i <= length(value); i++) {
        c = substr(value, i, 1)
        if (c == "\\") result = result "\\\\"
        else if (c == "\042") result = result "\\\042"
        else if (c == "\n") result = result "\\n"
        else if (c == "\t") result = result "\\t"
        else if (c ~ /[[:cntrl:]]/) fail("unsupported control character")
        else result = result c
    }
    return result "\042"
}
{ sub(/\r$/, "") }
NR == 1 && (mode == "agent" || mode == "skill") {
    if ($0 != "---") fail("expected YAML frontmatter")
    in_frontmatter = 1
    next
}
NR == 1 && mode == "command" && $0 == "---" { in_frontmatter = 1; next }
in_frontmatter && $0 == "---" { in_frontmatter = 0; closed = 1; next }
in_frontmatter {
    if ($0 ~ /^[ \t]*(#.*)?$/) next
    if ($0 !~ /^[a-zA-Z_-]+:/) fail("unsupported YAML frontmatter syntax")
    key = $0; sub(/:.*/, "", key)
    value = $0; sub(/^[^:]+:/, "", value)
    if (seen[key]++) fail("duplicate frontmatter key: " key)
    value = scalar(value)
    if (key == "name") name = value
    else if (key == "description") description = value
    else if (key == "model") model = value
    else if (key == "tools" || key == "disallowedTools" || key == "permissionMode" || key == "maxTurns" || (mode == "command" && (key == "allowed-tools" || key == "argument-hint" || key == "disable-model-invocation"))) {
        print FILENAME ": ignoring Claude-only field " key " (no direct Codex equivalent)" > "/dev/stderr"
    } else fail("unsupported frontmatter field: " key)
    next
}
{ body = body adapt($0) "\n" }
END {
    if (failed) exit 1
    if (mode == "resource") { printf "%s", body; exit }
    if (mode == "command") {
        if (in_frontmatter) fail("unclosed command frontmatter")
        name = command_name
        if (description == "") description = "Use when the user requests the /" name " workflow imported from Claude."
    } else if (!closed) fail("unclosed YAML frontmatter")
    if (name !~ /^[a-zA-Z0-9_-]+$/) fail("name must contain only letters, numbers, underscores, or hyphens")
    if (description == "" || body == "") fail("name, description, and instructions are required")
    description = adapt(description)
    if (mode != "agent") {
        print "---"
        print "name: " name
        gsub(/\047/, "\047\047", description)
        print "description: \047" description "\047"
        print "---"
        print "<!-- generated by .claude-base/claude-to-codex.sh - do not edit -->"
        print ""
        print "Read applicable AGENTS.md guidance and use only tools available in the current Codex session."
        if (name == "superpower") print "Use custom agents from .codex/agents/*.toml when the runtime supports named agent selection. Otherwise include the matching developer_instructions in the spawn task and use supported explicit model overrides. Use the available tools for spawning, follow-ups, and waits; if delegation is unavailable, perform the role in the main thread and state that limitation."
        print ""
        printf "%s", body
        exit
    }
        print "# generated by .claude-base/claude-to-codex.sh - do not edit"
        print "name = " toml(name)
        print "description = " toml(description)
        mapped = ""
        if (model == "opus") mapped = ENVIRON["CODEX_MODEL_OPUS"]
        else if (model == "sonnet") mapped = ENVIRON["CODEX_MODEL_SONNET"]
        else if (model == "haiku") mapped = ENVIRON["CODEX_MODEL_HAIKU"]
        else if (model != "" && model != "inherit") fail("unmapped Claude model: " model)
        if (mapped != "") {
            print "model = " toml(mapped)
            if (ENVIRON["CODEX_REASONING_EFFORT"] != "") print "model_reasoning_effort = " toml(ENVIRON["CODEX_REASONING_EFFORT"])
        }
        print "developer_instructions = " toml("Read and follow applicable AGENTS.md guidance before starting. Use only tools actually available in this Codex session.\n\n" body)
}
