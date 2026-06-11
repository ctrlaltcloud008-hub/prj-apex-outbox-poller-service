package relay

import (
	"time"

	"cloud.google.com/go/spanner"
)

// ChangeRecord is the top-level row returned by a Change Stream query.
// Each row column is ARRAY<STRUCT<...>> so we decode into a slice.
type ChangeRecord struct {
	DataChangeRecords      []*DataChangeRecord     `spanner:"data_change_record"`
	HeartbeatRecords       []*HeartbeatRecord      `spanner:"heartbeat_record"`
	ChildPartitionsRecords []*ChildPartitionsRecord `spanner:"child_partitions_record"`
}

// DataChangeRecord carries one or more row mutations for a committed transaction.
// Fields must match the Spanner change stream schema exactly in declaration order
// because the client decodes nested structs positionally.
type DataChangeRecord struct {
	CommitTimestamp                        time.Time    `spanner:"commit_timestamp"`
	RecordSequence                         string       `spanner:"record_sequence"`
	ServerTransactionID                    string       `spanner:"server_transaction_id"`
	IsLastRecordInTransactionInPartition   bool         `spanner:"is_last_record_in_transaction_in_partition"`
	TableName                              string       `spanner:"table_name"`
	ColumnTypes                            []*ColumnType `spanner:"column_types"`
	Mods                                   []*Mod        `spanner:"mods"`
	ModType                                string       `spanner:"mod_type"`
	ValueCaptureType                       string       `spanner:"value_capture_type"`
	NumberOfRecordsInTransaction           int64        `spanner:"number_of_records_in_transaction"`
	NumberOfPartitionsInTransaction        int64        `spanner:"number_of_partitions_in_transaction"`
	TransactionTag                         string       `spanner:"transaction_tag"`
	IsSystemTransaction                    bool         `spanner:"is_system_transaction"`
}

// ColumnType describes a column tracked by the change stream.
type ColumnType struct {
	Name            string           `spanner:"name"`
	Type            spanner.NullJSON `spanner:"type"`
	IsPrimaryKey    bool             `spanner:"is_primary_key"`
	OrdinalPosition int64            `spanner:"ordinal_position"`
}

// Mod holds the key and new/old column values for one modified row.
type Mod struct {
	Keys      spanner.NullJSON `spanner:"keys"`
	NewValues spanner.NullJSON `spanner:"new_values"`
	OldValues spanner.NullJSON `spanner:"old_values"`
}

// HeartbeatRecord is emitted periodically when no data changes occur,
// allowing the consumer to advance its watermark.
type HeartbeatRecord struct {
	Timestamp time.Time `spanner:"timestamp"`
}

// ChildPartitionsRecord signals that this partition has split into one or more
// child partitions. The consumer must spawn goroutines for each child.
type ChildPartitionsRecord struct {
	StartTimestamp  time.Time        `spanner:"start_timestamp"`
	RecordSequence  string           `spanner:"record_sequence"`
	ChildPartitions []*ChildPartition `spanner:"child_partitions"`
}

// ChildPartition describes a new partition spawned from a split.
type ChildPartition struct {
	Token                 string   `spanner:"token"`
	ParentPartitionTokens []string `spanner:"parent_partition_tokens"`
}
