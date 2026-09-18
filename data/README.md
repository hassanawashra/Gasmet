# Input data

Keep raw Gasmet files in `data/raw_gasmet/` and the analysis workbook in this folder. These files are ignored by Git to prevent accidental publication.

Expected workbook sheets:

- `metadata`: field and flux data described in the main README.
- `rainfall`: `Date` and `rainfall_mm`.

Expected goFlux auxiliary-file columns:

`UniqueID`, `start.time`, `Area`, `Vtot`, `Tcham`, and `Pcham`.