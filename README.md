[![Review Assignment Due Date](https://classroom.github.com/assets/deadline-readme-button-22041afd0340ce965d47ae6ef1cefeee28c7c493a6346c4f15d667ab976d596c.svg)](https://classroom.github.com/a/g5Rk6CRe)
[![Run Notebook](https://github.com/eisenhauerIO/projects-businss-decisions/actions/workflows/run-notebook.yml/badge.svg)](https://github.com/eisenhauerIO/projects-businss-decisions/actions/workflows/run-notebook.yml)
[![Ruff](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/astral-sh/ruff/main/assets/badge/v2.json)](https://github.com/astral-sh/ruff)

## Replication of Autor, D. H., Palmer, C. J., & Pathak, P. A. (2014)

### Housing Market Spillovers: Evidence from the End of Rent Control in Cambridge, Massachusetts

This project replicates the results from the following paper:

* Autor, D. H., Palmer, C. J., & Pathak, P. A. (2014). [Housing Market Spillovers: Evidence from the End of Rent Control in Cambridge, Massachusetts](https://doi.org/10.1086/675536). *Journal of Political Economy*, 122(3), 661–717.

**Project by:** [Polapat Chartphanich](https://github.com/PolapatC), Winter 2026

### Project Overview

This notebook examines the capitalization effect in the housing market following the elimination of rent control in Cambridge, Massachusetts. In November 1994, Massachusetts voters passed a statewide ballot initiative that repealed rent control, which had capped housing rents at roughly 40% below market value and restricted unit sizes in rent-controlled buildings.

#### Key Research Questions

1. **Direct Effects:** How much did property values appreciate for units that were directly decontrolled?
2. **Spillover Effects:** Did properties in high-rent-control-intensity neighborhoods also appreciate, even if they were never directly controlled?
3. **Mechanisms:** What explains the spillover effects—neighborhood improvements, resident sorting, or both?

### Key Findings

- **Direct Effects:** Formerly rent-controlled units appreciated by 21–26% relative to never-controlled properties
- **Spillover Effects:** Properties in high-rent-control-intensity neighborhoods (75th percentile) gained ~13% more in value than those in low-intensity areas (25th percentile)
- **Interpretation:** Rent control created allocative inefficiency; its removal improved market efficiency and generated neighborhood-wide benefits

### Methodology

- **Identification Strategy:** Difference-in-Differences (DiD) with spatial intensity variation
- **Treatment Variables:**
  - RC (Rent Control): Binary indicator of property's rent-control status in 1994
  - RCI (Rent Control Intensity): Fraction of residential units within 0.20-mile radius subject to rent control
- **Data:** Universe of assessed values and transaction prices in Cambridge, MA (1994–2004)
- **Sample:** ~51,000 observations across 15,475 residential properties (houses and condominiums)

### Notebook Structure

1. **Introduction:** Overview of rent control dynamics and research questions
2. **Theoretical Background:** Equilibrium housing market model with spillover mechanisms
3. **Identification:** Causal inference strategy and parallel trends assumption
4. **Empirical Strategy:** Regression specifications and estimation approach
5. **Data Replication:** Summary statistics and visualization
6. **Results:** Main difference-in-differences estimates with robustness checks

### Data Source

The analysis uses the `assess-panel-1994-2001-2004.dta` dataset provided by the original authors, containing pre-processed property-level data across three time periods (1994, 2002, 2004).

---

*For transparency, all sections marked as "extensions" represent independent contributions and deviations from the original paper's methodology.*
