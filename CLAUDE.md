# CLAUDE.md

## Code navigation
Use the Dart MCP LSP (`ToolSearch` → `select:mcp__dart__lsp`) for symbol/type
resolution instead of grep: `resolveWorkspaceSymbol` to find a definition,
`hover`/`signatureHelp` for types and signatures (positions are zero-based).
No `references` command exists — for "find usages", fall back to grep.