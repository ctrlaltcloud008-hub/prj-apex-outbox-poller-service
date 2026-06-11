package checkpoint

import (
	"context"
	"fmt"
	"time"

	"cloud.google.com/go/spanner"
	spannerutil "github.com/ctrlaltcloud008-hub/prj-apex-core-modules/pkg/spanner"
	"google.golang.org/api/iterator"
)

const (
	StateActive   = "ACTIVE"
	StateFinished = "FINISHED"
)

type PartitionCheckpoint struct {
	PartitionToken        string
	Watermark             time.Time
	State                 string
	ParentPartitionTokens []string
}

// ReadActiveCheckpoints returns all partitions in ACTIVE state.
func ReadActiveCheckpoints(ctx context.Context, client *spanner.Client) ([]PartitionCheckpoint, error) {
	stmt := spanner.Statement{
		SQL: `SELECT partition_token, watermark, state, parent_partition_tokens
		      FROM outbox_relay_checkpoints
		      WHERE state = @state`,
		Params: map[string]any{"state": StateActive},
	}

	iter := client.Single().Query(ctx, stmt)
	defer iter.Stop()

	var checkpoints []PartitionCheckpoint
	for {
		row, err := iter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			return nil, fmt.Errorf("query active checkpoints: %w", err)
		}

		var cp PartitionCheckpoint
		if err := row.Columns(
			&cp.PartitionToken,
			&cp.Watermark,
			&cp.State,
			&cp.ParentPartitionTokens,
		); err != nil {
			return nil, fmt.Errorf("read checkpoint row: %w", err)
		}
		checkpoints = append(checkpoints, cp)
	}

	return checkpoints, nil
}

// UpsertCheckpoint writes or updates a partition checkpoint.
func UpsertCheckpoint(ctx context.Context, client *spanner.Client, cp PartitionCheckpoint) error {
	_, err := spannerutil.RunRW(ctx, client, func(ctx context.Context, txn *spanner.ReadWriteTransaction) error {
		m := spanner.InsertOrUpdate("outbox_relay_checkpoints",
			[]string{"partition_token", "watermark", "state", "parent_partition_tokens", "created_at", "updated_at"},
			[]any{
				cp.PartitionToken,
				cp.Watermark,
				cp.State,
				cp.ParentPartitionTokens,
				spanner.CommitTimestamp,
				spanner.CommitTimestamp,
			},
		)
		return txn.BufferWrite([]*spanner.Mutation{m})
	})
	if err != nil {
		return fmt.Errorf("upsert checkpoint for token %q: %w", cp.PartitionToken, err)
	}
	return nil
}

// MarkPartitionFinished transitions a partition to FINISHED state.
func MarkPartitionFinished(ctx context.Context, client *spanner.Client, token string) error {
	_, err := spannerutil.RunRW(ctx, client, func(ctx context.Context, txn *spanner.ReadWriteTransaction) error {
		m := spanner.Update("outbox_relay_checkpoints",
			[]string{"partition_token", "state", "updated_at"},
			[]any{token, StateFinished, spanner.CommitTimestamp},
		)
		return txn.BufferWrite([]*spanner.Mutation{m})
	})
	if err != nil {
		return fmt.Errorf("mark partition finished for token %q: %w", token, err)
	}
	return nil
}
