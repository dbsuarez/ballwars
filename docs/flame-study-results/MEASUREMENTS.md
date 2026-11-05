# Release measurements

2026-11-05. Values below are the mean of two run-level P95 measurements, in milliseconds. They are not pooled percentiles. Raw run results retain both samples. Headless browser pacing is not physical-display FPS.

## Phone

| Scene | Renderer | UI P95 | Raster P95 | Ticker pacing P95 |
| --- | --- | ---: | ---: | ---: |
| effects | painter | 11.42 | 13.28 | 25.02 |
| effects | bridge | 10.97 | 12.83 | 25.01 |
| effects | components | 16.46 | 13.86 | 33.28 |
| effects | sprites | 17.65 | 13.99 | 33.31 |
| changing | painter | 18.05 | 19.11 | 33.31 |
| changing | bridge | 14.18 | 17.38 | 16.81 |
| changing | components | 13.36 | 17.38 | 16.77 |
| changing | sprites | 13.46 | 17.49 | 16.77 |

## Browser

| Scene | Renderer | UI P95 | Raster P95 | Ticker pacing P95 |
| --- | --- | ---: | ---: | ---: |
| effects | painter | 5.40 | 0.15 | 7.15 |
| effects | bridge | 4.40 | 0.10 | 7.05 |
| effects | components | 4.25 | 0.10 | 7.10 |
| effects | sprites | 4.45 | 0.10 | 7.10 |
| changing | painter | 5.10 | 0.10 | 7.05 |
| changing | bridge | 5.35 | 0.10 | 7.15 |
| changing | components | 5.20 | 0.10 | 7.15 |
| changing | sprites | 5.25 | 0.15 | 7.05 |

## Memory and startup limits

Phone PSS observations range from 143.0 to 182.1 MiB across 18 samples. Cache warming and GC vary across these samples; this does not attribute memory savings to one engine.

Asset-preload duration is shared across renderers within a process. Separate cold-launch comparisons and visible-browser acceptance remain unverified.
