# Core State Flow

This note summarizes how the standalone ImageStack core is structured after
the initial migration from NANSEN.

## Layer Responsibilities

### `imagestack.ImageStack`

`ImageStack` is the user-facing front end.

It is responsible for:

- current channel and plane selection
- standard versus extended indexing behavior
- chunk-oriented reads
- projection helpers

It does **not** own the underlying storage format. It delegates reads and
writes to an `ImageStackData` backend.

### `imagestack.data.abstract.ImageStackData`

`ImageStackData` is the central state model for stack dimensions.

It owns:

- `DataSize`
- `DataType`
- `DataDimensionArrangement`
- `StackDimensionArrangement`

From those source properties it derives:

- `StackDimensionOrder`
- `StackSize`

Important rule:

- `DataSize` and `DataDimensionArrangement` are source-of-truth state
- `StackDimensionOrder` and `StackSize` are rebuilt derived state

This distinction is important because it keeps adapters simple and avoids
recursive setter behavior.

### `imagestack.data.VirtualArray`

`VirtualArray` extends `ImageStackData` for file-backed storage.

It adds:

- file path handling
- metadata persistence
- dynamic frame caching
- adapter contract hooks for file info, frame reads, and frame writes

Concrete adapters such as `Binary` and `TiffMultiPart` should focus on
format-specific details:

- how file info is discovered
- how frames are read
- how frames are written

## Dimension Model

The code uses letter-based dimension arrangements:

- `Y`
- `X`
- `C`
- `Z`
- `T`

Two arrangements matter:

- `DataDimensionArrangement`: how the backend stores the data
- `StackDimensionArrangement`: how the stack is presented to callers

`StackDimensionOrder` maps from data-space order to stack-space order.

## Rebuild Flow

The main derived-state rebuild path in `ImageStackData` is:

1. source state changes
2. stack arrangement is reconciled if needed
3. `rebuildDerivedDimensionState` runs
4. `rebuildStackDimensionOrder` recomputes the permutation
5. `rebuildStackSize` maps source sizes into stack order

The goal is to keep all stack-facing derived state rebuilds in one place.

## Reconciliation Rule

When the data arrangement changes, the stack arrangement is reconciled with
this rule:

1. keep the currently visible stack-order dimensions that still exist
2. append any newly available dimensions in canonical `YXCZT` order

This preserves user-facing ordering where possible while staying compatible
with the new source arrangement.

## Testing Strategy

The core state flow is covered from several angles:

- `TestImageStackData` exercises dimension defaults and transitions
- `TestImageStackApi` exercises front-end chunking and projections
- `TestVirtualArrayContract` verifies file-backed behavior through a mock adapter
- `TestBinary` and `TestTiffMultiPart` verify real adapters

When changing core dimension logic, start with these tests before touching
format-specific code.
