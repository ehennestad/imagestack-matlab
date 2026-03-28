# Multiresolution Design

## Decision

Use a wrapper type: `imagestack.views.MultiResolutionStack`.

## Why this direction

- keeps multiresolution behavior outside the core `ImageStack` storage wrapper
- works with existing stacks instead of creating a special-case subclass
- lines up with explicit read parameters like `Scale` and `ROI`

## First-pass scope

- pyramid state lives in the wrapper as lazy cached levels
- reads are explicit: `getFrameSet(frameInd, 'Scale', scale, 'ROI', roi)`
- `Scale` is currently limited to `1` or reciprocal integer factors such as `0.5`
- `ROI` is explicit input, not mutable stack state
- spatial downsampling uses deterministic strided subsampling for now

## Deferred work

- higher quality interpolation
- native pyramid backends
- write-through behavior
- tighter integration with viewer display pipelines
