"""
Data Preparation Functions for Autor et al. (2014) Housing Market Analysis

This module contains functions for preparing the assess-panel data for
regression analysis of rent control effects on property values.
"""

import pandas as pd
import numpy as np


def prepare_analysis_sample(df):
    """
    Create analysis sample from raw assess-panel data with required filtering and variables.

    Applies sample restrictions and creates analysis variables needed for
    difference-in-differences regression analysis of rent control effects.

    Parameters:
    -----------
    df : pd.DataFrame
        Raw assess-panel data (e.g., from read_stata())

    Returns:
    --------
    pd.DataFrame
        Analysis-ready dataframe with sample restrictions applied and
        all analysis variables created

    Sample Restrictions Applied:
    - Positive assessed values (value > 0)
    - Residential properties only (house == 1 OR condo == 1)
    - Non-missing rent control intensity (rci_u20.notna())
    - Non-missing year values (year.notna())

    Variables Created:
    - lnvalue: Natural log of assessed value
    - post: Post-treatment indicator (1 if year >= 2002)
    - rc_post: RC × Post interaction
    - rci_post: RCI × Post interaction
    - is_house: House indicator (1 if house, 0 if condo)
    - period: Period label ('Pre (1994)' or 'Post (2002-04)')
    - year_str: Year as string (for categorical variables in formulas)
    - bg90_str: Block group as string (for categorical variables in formulas)
    - tract90_str: Census tract as string (for categorical variables in formulas)
    - year_int: Year as integer

    Examples:
    ---------
    >>> df = pd.read_stata("assess-panel-1994-2001-2004.dta")
    >>> df_analysis = prepare_analysis_sample(df)
    >>> print(f"Sample size: {len(df_analysis):,}")
    """

    # Apply sample restrictions
    df_clean = df[
        (df['value'] > 0) &
        ((df['house'] == 1) | (df['condo'] == 1)) &
        (df['rci_u20'].notna()) &
        (df['year'].notna())
    ].copy()

    # Create outcome variable: log assessed value
    df_clean['lnvalue'] = np.log(df_clean['value'])

    # Create treatment indicators
    df_clean['post'] = (df_clean['year'] >= 2002).astype(int)
    df_clean['rc_post'] = df_clean['rc'] * df_clean['post']
    df_clean['rci_post'] = df_clean['rci_u20'] * df_clean['post']

    # Create property type indicator
    df_clean['is_house'] = (df_clean['house'] == 1).astype(int)

    # Create period indicator
    df_clean['period'] = df_clean['year'].apply(
        lambda x: 'Pre (1994)' if x == 1994 else 'Post (2002-04)'
    )

    # Create categorical versions for fixed effects (needed for statsmodels formula interface)
    df_clean['year_str'] = df_clean['year'].astype(int).astype(str)
    df_clean['bg90_str'] = df_clean['bg90'].astype(int).astype(str)
    df_clean['tract90_str'] = df_clean['tract90'].astype(int).astype(str)
    df_clean['year_int'] = df_clean['year'].astype(int)

    return df_clean


def print_sample_summary(df_analysis):
    """
    Print summary of analysis sample.

    Displays key summary statistics about the prepared analysis sample including
    total observations, breakdown by year, rent control status, and property type.

    Parameters:
    -----------
    df_analysis : pd.DataFrame
        Analysis sample (output from prepare_analysis_sample())

    Returns:
    --------
    None (prints to console)

    Examples:
    ---------
    >>> df_analysis = prepare_analysis_sample(df)
    >>> print_sample_summary(df_analysis)
    """

    print("Analysis Sample Summary:")
    print(f"  Total observations: {len(df_analysis):,}")
    print(f"\n  By year:")
    for year in sorted(df_analysis['year_int'].unique()):
        count = (df_analysis['year_int'] == year).sum()
        print(f"    {int(year)}: {count:,}")
    print(f"\n  By RC status:")
    print(f"    RC=0 (never-controlled): {(df_analysis['rc'] == 0).sum():,}")
    print(f"    RC=1 (controlled): {(df_analysis['rc'] == 1).sum():,}")
    print(f"\n  By property type:")
    print(f"    Houses: {(df_analysis['is_house'] == 1).sum():,}")
    print(f"    Condos: {(df_analysis['is_house'] == 0).sum():,}")


def create_summary_statistics(df_data, print_output=True):
    """
    Generate comprehensive summary statistics by RC status and period.

    Creates a summary table showing descriptive statistics (N, median value, mean value,
    mean RCI, and property type composition) broken down by rent control status and
    time period.

    Parameters:
    -----------
    df_data : pd.DataFrame
        Analysis sample (output from prepare_analysis_sample())
    print_output : bool, default True
        If True, prints formatted table to console. If False, only returns DataFrame.

    Returns:
    --------
    pd.DataFrame
        Summary statistics table with rows for each RC status × period combination

    Examples:
    ---------
    >>> df_analysis = prepare_analysis_sample(df)
    >>> summary_table = create_summary_statistics(df_analysis)
    >>> summary_table_silent = create_summary_statistics(df_analysis, print_output=False)
    """

    summary_stats = []
    for rc_status in [0, 1]:
        rc_label = "Never-Controlled (RC=0)" if rc_status == 0 else "Controlled (RC=1)"
        for period in ['Pre (1994)', 'Post (2002-04)']:
            subset = df_data[(df_data['rc'] == rc_status) & (df_data['period'] == period)]
            if len(subset) > 0:
                stats = {
                    'RC Status': rc_label,
                    'Period': period,
                    'N': len(subset),
                    'Median Value ($)': subset['value'].median(),
                    'Mean Value ($)': subset['value'].mean(),
                    'Mean RCI': subset['rci_u20'].mean(),
                    'Houses (%)': (subset['is_house'] == 1).sum() / len(subset) * 100
                }
                summary_stats.append(stats)

    summary_df = pd.DataFrame(summary_stats)

    if print_output:
        print("="*80)
        print("TABLE: Summary Statistics by Rent Control Status and Period")
        print("="*80)
        print(summary_df.to_string(index=False))

    return summary_df


def calculate_appreciation(df_data, print_output=True):
    """
    Calculate property appreciation from pre to post-treatment period.

    Computes median property value appreciation for never-controlled (RC=0)
    and controlled (RC=1) properties between the pre-treatment (1994) and
    post-treatment (2002-2004) periods.

    Parameters:
    -----------
    df_data : pd.DataFrame
        Analysis sample (output from prepare_analysis_sample())
    print_output : bool, default True
        If True, prints results to console. If False, only returns dictionary.

    Returns:
    --------
    dict
        Dictionary with appreciation data:
        - 'Never-Controlled': {'pre': pre_value, 'post': post_value, 'pct_change': pct}
        - 'Controlled': {'pre': pre_value, 'post': post_value, 'pct_change': pct}

    Examples:
    ---------
    >>> df_analysis = prepare_analysis_sample(df)
    >>> appreciation = calculate_appreciation(df_analysis)
    >>> appreciation_silent = calculate_appreciation(df_analysis, print_output=False)
    """

    appreciation = {}

    for rc_status in [0, 1]:
        rc_label = "Never-Controlled" if rc_status == 0 else "Controlled"

        pre_val = df_data[
            (df_data['rc'] == rc_status) &
            (df_data['period'] == 'Pre (1994)')
        ]['value'].median()

        post_val = df_data[
            (df_data['rc'] == rc_status) &
            (df_data['period'] == 'Post (2002-04)')
        ]['value'].median()

        pct_change = ((post_val - pre_val) / pre_val) * 100 if pre_val > 0 else np.nan

        appreciation[rc_label] = {
            'pre': pre_val,
            'post': post_val,
            'pct_change': pct_change
        }

    if print_output:
        print("\n" + "="*80)
        print("Appreciation from Pre to Post Period:")
        print("="*80)
        for rc_label, values in appreciation.items():
            print(f"{rc_label:25} Median: ${values['pre']:>12,.0f} -> ${values['post']:>12,.0f} ({values['pct_change']:>6.1f}%)")

    return appreciation


def get_sample_statistics(df_analysis):
    """
    Get sample statistics as a dictionary (non-printing version).

    Useful for logging or comparing multiple samples without console output.

    Parameters:
    -----------
    df_analysis : pd.DataFrame
        Analysis sample (output from prepare_analysis_sample())

    Returns:
    --------
    dict
        Dictionary containing sample statistics:
        - 'total_obs': Total observations
        - 'by_year': Dict with counts by year
        - 'rc_never': Count of never-controlled properties
        - 'rc_controlled': Count of controlled properties
        - 'houses': Count of houses
        - 'condos': Count of condos

    Examples:
    ---------
    >>> df_analysis = prepare_analysis_sample(df)
    >>> stats = get_sample_statistics(df_analysis)
    >>> print(f"Total observations: {stats['total_obs']:,}")
    """

    stats = {
        'total_obs': len(df_analysis),
        'by_year': dict(df_analysis['year_int'].value_counts().sort_index()),
        'rc_never': int((df_analysis['rc'] == 0).sum()),
        'rc_controlled': int((df_analysis['rc'] == 1).sum()),
        'houses': int((df_analysis['is_house'] == 1).sum()),
        'condos': int((df_analysis['is_house'] == 0).sum())
    }

    return stats
