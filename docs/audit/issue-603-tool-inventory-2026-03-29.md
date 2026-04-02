# Issue #603 - Tool Inventory Report

Generated: 2026-03-29 00:13:35

## Scope

- Registry handlers (`case 'roosync_*'` + `export_config`)
- RooSync metadata list (`roosyncTools` in `roosync/index.ts`)
- Audit test inventory (`ALL_MCP_TOOLS` in `mcp-tools-audit.test.ts`)

## Summary

- Registry roosync/export handlers: 40
- Exposed roosync metadata entries: 24
- ALL_MCP_TOOLS entries: 68
- Registry handlers missing in ALL_MCP_TOOLS: 6
- Test roosync entries missing in registry handlers: 6

## Registry Handlers

- roosync_apply_config
- roosync_apply_decision
- roosync_approve_decision
- roosync_attachments
- roosync_baseline
- roosync_cleanup_messages
- roosync_collect_config
- roosync_compare_config
- roosync_config
- roosync_dashboard
- roosync_decision
- roosync_decision_info
- roosync_delete_attachment
- roosync_diagnose
- roosync_export_baseline
- roosync_get_attachment
- roosync_get_decision_details
- roosync_get_machine_inventory
- roosync_get_status
- roosync_heartbeat
- roosync_indexing
- roosync_init
- roosync_inventory
- roosync_list_attachments
- roosync_list_diffs
- roosync_machines
- roosync_manage
- roosync_manage_baseline
- roosync_mcp_management
- roosync_publish_config
- roosync_read
- roosync_refresh_dashboard
- roosync_reject_decision
- roosync_rollback_decision
- roosync_search
- roosync_send
- roosync_storage_management
- roosync_sync_event
- roosync_update_baseline
- roosync_update_dashboard

## Exposed RooSync Metadata Entries

- attachmentsToolMetadata
- baselineToolMetadata
- cleanupToolMetadata
- compareConfigToolMetadata
- configToolMetadata
- dashboardToolMetadata
- diagnoseToolMetadata
- getAttachmentToolMetadata
- getStatusToolMetadata
- heartbeatToolMetadata
- initToolMetadata
- inventoryToolMetadata
- listAttachmentsToolMetadata
- listDiffsToolMetadata
- machinesToolMetadata
- manageToolMetadata
- mcpManagementToolMetadata
- readToolMetadata
- refreshDashboardToolMetadata
- roosyncDecisionInfoToolMetadata
- roosyncDecisionToolMetadata
- sendToolMetadata
- storageManagementToolMetadata
- updateDashboardToolMetadata

## Registry Handlers Missing In ALL_MCP_TOOLS

- roosync_attachments
- roosync_dashboard
- roosync_delete_attachment
- roosync_get_attachment
- roosync_list_attachments
- roosync_manage_baseline

## Test RooSync Entries Missing In Registry

- roosync_archive_message
- roosync_get_message
- roosync_read_inbox
- roosync_reply_message
- roosync_send_message
- roosync_summarize
