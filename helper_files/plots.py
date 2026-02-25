"""
Visualization Functions for Autor et al. (2014) Housing Market Analysis

This module contains functions for creating publication-quality plots and visualizations
for the rent control property value analysis.
"""

import matplotlib.pyplot as plt
import numpy as np


def plot_distributions(df_analysis, figsize=(14, 5)):
    """
    Create distribution visualizations for RCI and property values.

    Generates a two-panel figure showing:
    1. RCI distribution by rent control status (never-controlled vs controlled)
    2. Log property value distribution by time period (pre vs post-treatment)

    Parameters:
    -----------
    df_analysis : pd.DataFrame
        Analysis sample (output from prepare_analysis_sample)
    figsize : tuple, default (14, 5)
        Figure size as (width, height) in inches

    Returns:
    --------
    matplotlib.figure.Figure
        Figure object containing both subplots

    Examples:
    ---------
    >>> df_analysis = prepare_analysis_sample(df)
    >>> fig = plot_distributions(df_analysis)
    >>> plt.show()

    >>> # Customize figure size
    >>> fig = plot_distributions(df_analysis, figsize=(16, 6))
    >>> plt.savefig('distributions.png', dpi=300, bbox_inches='tight')
    """

    fig, axes = plt.subplots(1, 2, figsize=figsize)

    # Panel 1: RCI distribution by RC status
    ax = axes[0]
    rc0_rci = df_analysis[df_analysis['rc'] == 0]['rci_u20']
    rc1_rci = df_analysis[df_analysis['rc'] == 1]['rci_u20']

    ax.hist(rc0_rci, bins=30, alpha=0.6, label='Never-Controlled (RC=0)',
            color='steelblue', density=True)
    ax.hist(rc1_rci, bins=30, alpha=0.6, label='Controlled (RC=1)',
            color='coral', density=True)
    ax.set_xlabel('Rent Control Intensity (0.20 mile radius)', fontsize=11)
    ax.set_ylabel('Density', fontsize=11)
    ax.set_title('Distribution of RCI by Rent Control Status', fontsize=12, fontweight='bold')
    ax.legend()
    ax.grid(alpha=0.3)

    # Panel 2: Log value distribution by period
    ax = axes[1]
    ax.hist(df_analysis[df_analysis['period'] == 'Pre (1994)']['lnvalue'],
            bins=40, alpha=0.6, label='1994 (Pre-treatment)', color='steelblue', density=True)
    ax.hist(df_analysis[df_analysis['period'] == 'Post (2002-04)']['lnvalue'],
            bins=40, alpha=0.6, label='2002-2004 (Post-treatment)', color='coral', density=True)
    ax.set_xlabel('Log(Assessed Value)', fontsize=11)
    ax.set_ylabel('Density', fontsize=11)
    ax.set_title('Distribution of Property Values Over Time', fontsize=12, fontweight='bold')
    ax.legend()
    ax.grid(alpha=0.3)

    plt.tight_layout()

    return fig


def plot_value_trends(df_analysis, figsize=(12, 6)):
    """
    Plot property value trends over time by RC status.

    Shows mean log(value) for each year, separated by rent control status.
    Useful for assessing parallel trends assumption in difference-in-differences.

    Parameters:
    -----------
    df_analysis : pd.DataFrame
        Analysis sample (output from prepare_analysis_sample)
    figsize : tuple, default (12, 6)
        Figure size as (width, height) in inches

    Returns:
    --------
    matplotlib.figure.Figure
        Figure object with trend plot

    Examples:
    ---------
    >>> df_analysis = prepare_analysis_sample(df)
    >>> fig = plot_value_trends(df_analysis)
    >>> plt.show()
    """

    fig, ax = plt.subplots(figsize=figsize)

    # Calculate mean log value by year and RC status
    trend_data = df_analysis.groupby(['year_int', 'rc'])['lnvalue'].mean().reset_index()

    for rc_status in [0, 1]:
        subset = trend_data[trend_data['rc'] == rc_status]
        label = 'Never-Controlled (RC=0)' if rc_status == 0 else 'Controlled (RC=1)'
        color = 'steelblue' if rc_status == 0 else 'coral'

        ax.plot(subset['year_int'], subset['lnvalue'], marker='o', linewidth=2.5,
                markersize=8, label=label, color=color)

    # Add treatment timing line
    ax.axvline(x=1995, color='red', linestyle='--', linewidth=1.5, alpha=0.7,
               label='Policy Change (1995)')

    ax.set_xlabel('Year', fontsize=11)
    ax.set_ylabel('Mean Log(Assessed Value)', fontsize=11)
    ax.set_title('Property Value Trends by Rent Control Status', fontsize=12, fontweight='bold')
    ax.legend(fontsize=10)
    ax.grid(alpha=0.3)

    plt.tight_layout()

    return fig


def plot_rc_intensity_trends(df_analysis, figsize=(12, 6)):
    """
    Plot property value trends by RCI exposure.

    Shows mean log(value) over time, separated by high vs low RCI neighborhood exposure.
    Demonstrates spillover effects from rent control removal.

    Parameters:
    -----------
    df_analysis : pd.DataFrame
        Analysis sample (output from prepare_analysis_sample)
    figsize : tuple, default (12, 6)
        Figure size as (width, height) in inches

    Returns:
    --------
    matplotlib.figure.Figure
        Figure object with RCI trend plot

    Examples:
    ---------
    >>> df_analysis = prepare_analysis_sample(df)
    >>> fig = plot_rc_intensity_trends(df_analysis)
    >>> plt.show()
    """

    fig, ax = plt.subplots(figsize=figsize)

    # Split sample by median RCI
    median_rci = df_analysis['rci_u20'].median()

    # Calculate mean log value by year and RCI exposure
    df_analysis_copy = df_analysis.copy()
    df_analysis_copy['high_rci'] = (df_analysis_copy['rci_u20'] >= median_rci).astype(int)

    trend_data = df_analysis_copy.groupby(['year_int', 'high_rci'])['lnvalue'].mean().reset_index()

    for high_rci in [0, 1]:
        subset = trend_data[trend_data['high_rci'] == high_rci]
        label = f'Low RCI (< {median_rci:.2f})' if high_rci == 0 else f'High RCI (≥ {median_rci:.2f})'
        color = 'steelblue' if high_rci == 0 else 'coral'

        ax.plot(subset['year_int'], subset['lnvalue'], marker='o', linewidth=2.5,
                markersize=8, label=label, color=color)

    # Add treatment timing line
    ax.axvline(x=1995, color='red', linestyle='--', linewidth=1.5, alpha=0.7,
               label='Policy Change (1995)')

    ax.set_xlabel('Year', fontsize=11)
    ax.set_ylabel('Mean Log(Assessed Value)', fontsize=11)
    ax.set_title('Property Value Trends by Neighborhood RCI Exposure', fontsize=12, fontweight='bold')
    ax.legend(fontsize=10)
    ax.grid(alpha=0.3)

    plt.tight_layout()

    return fig
