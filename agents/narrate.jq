# Renders a Claude Code event stream as readable narration: the main agent's
# text verbatim, its tool calls as one-liners, and background tasks (subagents,
# backgrounded shells) as one start line and one finish line each. Subagents'
# own events are skipped — eight code-review angles each reading the same diff
# is noise here; the raw stream keeps them. Works on both a session .jsonl
# (what `watch` tails out of a container; subagent events carry isSidechain)
# and `-p --output-format stream-json` (what `host-agent` pipes through;
# subagent events carry parent_tool_use_id). The trailing `result` clause only
# ever matches the latter, and only when the run ends in an error.
def short: tostring | gsub("\n"; " ") | .[0:140];

if .type == "assistant" and .parent_tool_use_id == null and .isSidechain != true then
  (.message.content[]? |
    if .type == "text" then .text + "\n"
    elif .type == "tool_use" then
      "  → " + .name + "  " +
      ((.input.description // .input.command // .input.file_path // .input.prompt
        // .input.skill // "") | short) + "\n"
    else empty end)
elif .type == "system" and .subtype == "task_started" then
  "  ⇢ " + ((.description // "") | short) + "\n"
elif .type == "system" and .subtype == "task_notification" then
  "  ⇠ " + ((.summary // .description // "") | short)
    + (if .status and .status != "completed" then "  (" + .status + ")" else "" end) + "\n"
elif .type == "result" and .subtype != "success" then
  "\n✗ " + .subtype + "\n"
else empty end
