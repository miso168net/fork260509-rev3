---
type: community
cohesion: 0.33
members: 6
---

# records to csv()

**Cohesion:** 0.33 - loosely connected
**Members:** 6 nodes

## Members
- [[csv_escape_field()]] - code - rust-api/server/src/handler/system_manage.rs
- [[push_csv_line()]] - code - rust-api/server/src/handler/system_manage.rs
- [[records_to_csv()]] - code - rust-api/server/src/handler/system_manage.rs
- [[records_to_csv_bom_once_and_stable_header()]] - code - rust-api/server/src/handler/system_manage.rs
- [[records_to_csv_payload_json_cell_no_field_misalign()]] - code - rust-api/server/src/handler/system_manage.rs
- [[records_to_csv_zero_rows_header_only()]] - code - rust-api/server/src/handler/system_manage.rs

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/records_to_csv
SORT file.name ASC
```

## Connections to other communities
- 6 edges to [[_COMMUNITY_system manage.rs]]
- 3 edges to [[_COMMUNITY_get access log()]]

## Top bridge nodes
- [[records_to_csv()]] - degree 9, connects to 2 communities
- [[csv_escape_field()]] - degree 2, connects to 1 community
- [[push_csv_line()]] - degree 2, connects to 1 community
- [[records_to_csv_bom_once_and_stable_header()]] - degree 2, connects to 1 community
- [[records_to_csv_payload_json_cell_no_field_misalign()]] - degree 2, connects to 1 community