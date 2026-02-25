# Synthetic Sales Data for Housing Market Research

## Overview

This folder contains Python scripts and synthetic datasets that replicate the Warren Group and Equifax transaction data used in:

**Autor, D., Palmer, C., & Pathak, P. (2013).** "Housing Market Spillovers: Evidence from the End of Rent Control in Cambridge Massachusetts." *Journal of Political Economy*, 121(3), 465-505.

## Files

### Python Scripts

**do_data.py** (19 KB)
- Main synthetic data generation script
- Implements the exact cleaning methodology from Autor et al. (2013)
- Generates realistic Cambridge housing market data
- Can be customized for different time periods or property mixes

**gis_data.py** (9 KB)
- Merges GIS shapefiles with property assessor data
- Creates analysis-ready geographic datasets
- Exports GeoJSON and CSV formats

**dta_data.py** (3 KB)
- Helper script for DTA file processing
- Manages panel data structures

### Synthetic Datasets

**synthetic_transactions_raw.csv** (499 KB)
- 3,500 transactions before cleaning
- Original variables from Warren Group data
- Contains properties that will be flagged as non-arms-length

**synthetic_transactions_flagged.csv** (679 KB)
- Same data with 9 cleaning flag columns
- Shows the decision logic for data removal
- 7 types of flagged non-arms-length transactions:
  - `flag_norooms`: Zero total rooms
  - `flag_nosqft`: Zero square footage
  - `flag_zeroprice`: Zero or missing price
  - `flag_deed`: Foreclosure or land court deeds
  - `flag_duplicate`: Identical duplicate transactions
  - `flag_share`: Same person on both sides of transaction
  - `flag_family`: Same last name on both sides

**synthetic_transactions_clean.csv** (550 KB)
- 2,213 analysis-ready transactions (36.8% removal rate)
- Flagged transactions removed
- Includes computed variables for analysis
- Ready to merge with GIS and assessment panel data

## Data Characteristics

### Coverage
- **Time period:** 1992-2000 (covers 1995 rent control repeal)
- **Geography:** Cambridge, Massachusetts
- **Transactions:** 2,213 clean sales

### Variables Available

#### Transaction Data
- `address`: Property address
- `ML`: Map-Lot identifier (parcel code)
- `price`: Sale price in dollars
- `sale_date`: Transaction date
- `year`: Year of sale
- `buyer1`, `buyer2`: Buyer names
- `seller1`, `seller2`: Seller names
- `mortgage`: Mortgage amount

#### Property Characteristics
- `usecode`: Massachusetts use classification code
- `use_description`: Property type description
- `sqft`: Square footage
- `bedrooms`: Number of bedrooms
- `bathrooms`: Number of bathrooms
- `lotsize`: Lot size in square feet
- `yearbuilt`: Construction year

#### Analysis Variables
- `lprice`: Natural log of price (for hedonic models)
- `post_rc_repeal`: 1 if post-1995, 0 if pre-1995
- `sing_fam`, `twofam`, `apt`: Property type indicators
- `lotsize_nonapt`: Lot size for non-apartments
- `add_group`: Address group for panel analysis
- `block90`: Census block identifier

## Usage

### Basic Python Usage

```python
import pandas as pd

# Load clean dataset
df = pd.read_csv('synthetic_transactions_clean.csv')

# Simple hedonic model
from sklearn.linear_model import LinearRegression
X = df[['sqft', 'bedrooms', 'bathrooms', 'yearbuilt']]
y = df['lprice']
model = LinearRegression()
model.fit(X, y)

# Event study
pre_repeal = df[df['post_rc_repeal'] == 0]['price'].mean()
post_repeal = df[df['post_rc_repeal'] == 1]['price'].mean()
effect = post_repeal - pre_repeal
```

### Customizing the Data Generator

```python
from do_data import CambridgeSyntheticData

# Generate with different parameters
generator = CambridgeSyntheticData(n_transactions=5000, seed=123)
df_raw = generator.generate_transactions()
df_flagged = generator.apply_cleaning_flags(df_raw)
df_clean = generator.create_clean_dataset(df_flagged)
```

## Methodological Accuracy

The synthetic data generator implements the exact cleaning procedures from the original paper:

1. **Flags non-arms-length transactions** using 7 criteria
2. **Parses ML codes** from property identifiers
3. **Handles missing values** by property type
4. **Creates property dummies** (single family, two-family, etc.)
5. **Generates temporal variables** for event studies
6. **Produces analysis variables** (log price, lot size adjustments)

## Data Quality Metrics

| Metric | Value |
|--------|-------|
| Original transactions | 3,500 |
| Clean transactions | 2,213 |
| Removal rate | 36.8% |
| Properties (unique addresses) | 1,750+ |
| Years covered | 1992-2000 |
| Missing yearbuilt | 4.9% |
| Price range | $1,000 - $3,160,551 |
| Average price | $238,196 |

## Research Applications

### Event Study Analysis
Analyze the effect of the 1995 rent control repeal on:
- Property values
- Transaction volumes
- Residential tenure
- Spillover effects on neighboring properties

### Hedonic Price Models
Estimate housing price determinants:
- Structure: bedrooms, bathrooms, square footage, year built
- Location: property type, neighborhood
- Time effects: pre/post-1995 dummy

### Panel Analysis
Track property movement and ownership changes:
- Address group identifier enables panel structure
- Temporal variation: 1992-2000
- Can merge with census data for neighborhood characteristics

## Data Transparency

The synthetic data generation is fully documented and reproducible:
- Fixed random seed for consistent results
- Clear flagging criteria matching original paper
- Comments explaining each cleaning decision
- Property characteristics vary by realistic distributions

## Limitations

This is **synthetic data** created for research purposes:
- Not actual transaction data
- Used to demonstrate methodology
- Results will differ from actual Cambridge housing market
- Provides proof-of-concept without licensing costs

## Citation

If you use these synthetic datasets in your research, please cite:

Autor, D., Palmer, C., & Pathak, P. (2013). Housing Market Spillovers: Evidence from the End of Rent Control in Cambridge Massachusetts. *Journal of Political Economy*, 121(3), 465-505.

And acknowledge the synthetic data generation:

*Synthetic transaction data generated using methodology from Autor et al. (2013) for research and educational purposes.*

## Further Reading

- **Original Paper:** [JPE Article](https://www.journals.uchicago.edu/doi/10.1086/670394)
- **Data Appendix:** Details on original Warren Group and Equifax data
- **Cambridge Property Database:** Available online for property verification

## Questions?

Refer to:
- `do_data.py` documentation (docstrings and comments)
- Original paper's Data Appendix
- The `do/sales-data-clean.do` Stata code in the parent directory

---

**Created:** February 2026
**Format:** Python 3.11+ with pandas
**License:** Research use only
