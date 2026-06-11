package spanner

import (
	"context"
	"fmt"
	"time"

	"cloud.google.com/go/spanner"
	spannerutil "github.com/ctrlaltcloud008-hub/prj-apex-core-modules/pkg/spanner"
)

func MarkOutboxEntriesPublished(ctx context.Context, client *spanner.Client, entryIDs []string) error {
	if len(entryIDs) == 0 {
		return nil
	}

	publishedAt := time.Now().UTC()

	_, err := spannerutil.RunRW(ctx, client, func(ctx context.Context, txn *spanner.ReadWriteTransaction) error {
		mutations := make([]*spanner.Mutation, 0, len(entryIDs))
		for _, entryID := range entryIDs {
			mutations = append(mutations, spanner.Update("outbox",
				[]string{"entry_id", "status", "published_at"},
				[]any{entryID, "PUBLISHED", publishedAt},
			))
		}

		if err := txn.BufferWrite(mutations); err != nil {
			return fmt.Errorf("buffer outbox publish updates: %w", err)
		}

		return nil
	})
	if err != nil {
		return fmt.Errorf("mark outbox entries published: %w", err)
	}

	return nil
}
