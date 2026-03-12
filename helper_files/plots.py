"""
Visualization Functions for Autor et al. (2014) Housing Market Analysis

This module contains functions for creating publication-quality plots and visualizations
for the rent control property value analysis.
"""

import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
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
    Plot mean property value trends over time by RC status.

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
    """

    fig, ax = plt.subplots(figsize=figsize)

    colors = {0: 'steelblue', 1: 'coral'}
    labels = {0: 'Never-Controlled (RC=0)', 1: 'Controlled (RC=1)'}

    trend_data = df_analysis.groupby(['year_int', 'rc'])['value'].mean().reset_index()
    for rc_status in [0, 1]:
        subset = trend_data[trend_data['rc'] == rc_status]
        ax.plot(subset['year_int'], subset['value'] / 1000, marker='o',
                linewidth=2.5, markersize=8, label=labels[rc_status],
                color=colors[rc_status])

    ax.axvline(x=1995, color='red', linestyle='--', linewidth=1.5, alpha=0.7,
               label='Policy Change (1995)')
    ax.set_xlabel('Year', fontsize=11)
    ax.set_ylabel('Mean Assessed Value ($K)', fontsize=11)
    ax.set_title('Mean Property Value Trends by Rent Control Status',
                 fontsize=12, fontweight='bold')
    ax.legend(fontsize=10)
    ax.grid(alpha=0.3)

    plt.tight_layout()

    return fig


def plot_rc_intensity_trends(df_analysis, figsize=(12, 6)):
    """
    Plot mean property value trends by RCI exposure.

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
    """

    fig, ax = plt.subplots(figsize=figsize)

    # Split sample by median RCI
    median_rci = df_analysis['rci_u20'].median()
    df_copy = df_analysis.copy()
    df_copy['high_rci'] = (df_copy['rci_u20'] >= median_rci).astype(int)

    colors = {0: 'steelblue', 1: 'coral'}
    labels_map = {
        0: f'Low RCI (< {median_rci:.2f})',
        1: f'High RCI (≥ {median_rci:.2f})'
    }

    trend_data = df_copy.groupby(['year_int', 'high_rci'])['value'].mean().reset_index()
    for high_rci in [0, 1]:
        subset = trend_data[trend_data['high_rci'] == high_rci]
        ax.plot(subset['year_int'], subset['value'] / 1000, marker='o',
                linewidth=2.5, markersize=8, label=labels_map[high_rci],
                color=colors[high_rci])

    ax.axvline(x=1995, color='red', linestyle='--', linewidth=1.5, alpha=0.7,
               label='Policy Change (1995)')
    ax.set_xlabel('Year', fontsize=11)
    ax.set_ylabel('Mean Assessed Value ($K)', fontsize=11)
    ax.set_title('Mean Property Value Trends by Neighborhood RCI Exposure',
                 fontsize=12, fontweight='bold')
    ax.legend(fontsize=10)
    ax.grid(alpha=0.3)

    plt.tight_layout()

    return fig


def _get_coef_and_se(result, param_name):
    """Extract coefficient and SE from either statsmodels OLS or linearmodels PanelOLS."""
    is_panel = hasattr(result, 'std_errors')
    se_attr = result.std_errors if is_panel else result.bse
    coef = result.params.get(param_name, np.nan)
    se = se_attr.get(param_name, np.nan)
    return coef, se


def plot_table3_coefficients(results, figsize=(8, 5)):
    """
    Dot-and-whisker plot of the RC x Post coefficient across Table 3 specifications.

    Parameters
    ----------
    results : dict
        Output from run_table3_regressions() with keys 'spec1' .. 'spec4'.
    figsize : tuple, default (8, 5)
        Figure size.

    Returns
    -------
    matplotlib.figure.Figure
    """
    labels = [
        '(1) Year FE',
        '(2) + Block Group FE',
        '(3) + Tract×Post FE',
        '(4) + Map-lot FE'
    ]
    coefs, ses = [], []
    for i in range(1, 5):
        c, s = _get_coef_and_se(results[f'spec{i}'], 'rc_post')
        coefs.append(c)
        ses.append(s)

    fig, ax = plt.subplots(figsize=figsize)
    y_pos = np.arange(len(labels))

    ax.errorbar(coefs, y_pos, xerr=[1.96 * s for s in ses],
                fmt='o', color='steelblue', markersize=9, capsize=6,
                linewidth=2, capthick=1.5, zorder=3)
    ax.axvline(x=0, color='grey', linestyle='--', alpha=0.5)

    ax.set_yticks(y_pos)
    ax.set_yticklabels(labels, fontsize=10)
    ax.invert_yaxis()
    ax.set_xlabel('RC × Post Coefficient (95% CI)', fontsize=11)
    ax.set_title('Table 3: Stability of Direct Effect Across Specifications',
                 fontsize=12, fontweight='bold')
    ax.xaxis.set_major_formatter(mticker.FormatStrFormatter('%.2f'))
    ax.grid(alpha=0.3, axis='x')

    plt.tight_layout()
    return fig


def plot_table4_coefficients(results, figsize=(14, 6)):
    """
    Two-panel dot-and-whisker plot showing direct (RC x Post) and indirect
    (RCI x Post) effects across Table 4 specifications.

    Parameters
    ----------
    results : dict
        Output from run_table4_regressions() with keys 'spec1' .. 'spec7'.
    figsize : tuple, default (14, 6)
        Figure size.

    Returns
    -------
    matplotlib.figure.Figure
    """
    labels = [
        '(1) Year FE',
        '(2) + BG FE',
        '(3) + Tract×Post',
        '(4) + Interactions',
        '(5) Map-lot FE',
        '(6) + BG FE',
        '(7) + Tract×Post'
    ]

    rc_coefs, rc_ses = [], []
    rci_coefs, rci_ses = [], []
    for i in range(1, 8):
        c, s = _get_coef_and_se(results[f'spec{i}'], 'rc_post')
        rc_coefs.append(c)
        rc_ses.append(s)
        c, s = _get_coef_and_se(results[f'spec{i}'], 'rci_post')
        rci_coefs.append(c)
        rci_ses.append(s)

    fig, axes = plt.subplots(1, 2, figsize=figsize)
    y_pos = np.arange(len(labels))

    # Panel A: Direct effect
    axes[0].errorbar(rc_coefs, y_pos, xerr=[1.96 * s for s in rc_ses],
                     fmt='o', color='steelblue', markersize=9, capsize=6,
                     linewidth=2, capthick=1.5, zorder=3)
    axes[0].axvline(x=0, color='grey', linestyle='--', alpha=0.5)
    axes[0].set_yticks(y_pos)
    axes[0].set_yticklabels(labels, fontsize=10)
    axes[0].invert_yaxis()
    axes[0].set_xlabel('Coefficient (95% CI)', fontsize=11)
    axes[0].set_title('Direct Effect (RC × Post)', fontsize=12, fontweight='bold')
    axes[0].xaxis.set_major_formatter(mticker.FormatStrFormatter('%.2f'))
    axes[0].grid(alpha=0.3, axis='x')

    # Panel B: Indirect / spillover effect
    axes[1].errorbar(rci_coefs, y_pos, xerr=[1.96 * s for s in rci_ses],
                     fmt='o', color='coral', markersize=9, capsize=6,
                     linewidth=2, capthick=1.5, zorder=3)
    axes[1].axvline(x=0, color='grey', linestyle='--', alpha=0.5)
    axes[1].set_yticks(y_pos)
    axes[1].set_yticklabels(labels, fontsize=10)
    axes[1].invert_yaxis()
    axes[1].set_xlabel('Coefficient (95% CI)', fontsize=11)
    axes[1].set_title('Indirect Effect (RCI × Post)', fontsize=12, fontweight='bold')
    axes[1].xaxis.set_major_formatter(mticker.FormatStrFormatter('%.2f'))
    axes[1].grid(alpha=0.3, axis='x')

    fig.suptitle('Table 4: Direct and Indirect Effects Across Specifications',
                 fontsize=13, fontweight='bold', y=1.02)
    plt.tight_layout()
    return fig


def plot_bootstrap_distribution(boot_result, figsize=(10, 5)):
    """
    Histogram of bootstrapped RC x Post coefficients with CI bounds.

    Parameters
    ----------
    boot_result : dict
        Output from robust.bootstrap_did().
    figsize : tuple
        Figure size.

    Returns
    -------
    matplotlib.figure.Figure
    """
    fig, ax = plt.subplots(figsize=figsize)

    coefs = boot_result['bootstrap_coefs']
    point = boot_result['point_estimate']
    ci_lo = boot_result['ci_lower']
    ci_hi = boot_result['ci_upper']

    ax.hist(coefs, bins=40, color='steelblue', alpha=0.7, edgecolor='white',
            density=True, label='Bootstrap distribution')
    ax.axvline(point, color='red', linewidth=2, label=f'Point estimate ({point:.4f})')
    ax.axvline(ci_lo, color='orange', linestyle='--', linewidth=1.5,
               label=f'95% CI [{ci_lo:.4f}, {ci_hi:.4f}]')
    ax.axvline(ci_hi, color='orange', linestyle='--', linewidth=1.5)

    ax.set_xlabel('RC × Post Coefficient', fontsize=11)
    ax.set_ylabel('Density', fontsize=11)
    ax.set_title('Bootstrap Distribution of Direct Effect (RC × Post)',
                 fontsize=12, fontweight='bold')
    ax.legend(fontsize=10)
    ax.grid(alpha=0.3)

    plt.tight_layout()
    return fig


def plot_permutation_test(perm_result, figsize=(10, 5)):
    """
    Histogram of permuted coefficients with the actual estimate marked.

    Parameters
    ----------
    perm_result : dict
        Output from robust.permutation_test().
    figsize : tuple
        Figure size.

    Returns
    -------
    matplotlib.figure.Figure
    """
    fig, ax = plt.subplots(figsize=figsize)

    perm_coefs = perm_result['permuted_coefs']
    actual = perm_result['actual_coef']
    p_val = perm_result['p_value']

    ax.hist(perm_coefs, bins=40, color='grey', alpha=0.7, edgecolor='white',
            density=True, label='Null distribution (permuted)')
    ax.axvline(actual, color='red', linewidth=2.5,
               label=f'Actual estimate ({actual:.4f})')
    ax.axvline(-actual, color='red', linewidth=2.5, linestyle=':', alpha=0.5)

    ax.set_xlabel('RC × Post Coefficient', fontsize=11)
    ax.set_ylabel('Density', fontsize=11)
    ax.set_title(f'Permutation Test: Null Distribution (p = {p_val:.4f})',
                 fontsize=12, fontweight='bold')
    ax.legend(fontsize=10)
    ax.grid(alpha=0.3)

    plt.tight_layout()
    return fig


def plot_subsample_comparison(subsample_result, figsize=(8, 4)):
    """
    Dot-and-whisker comparison of RC x Post across subsamples.

    Parameters
    ----------
    subsample_result : dict
        Output from robust.subsample_analysis().
    figsize : tuple
        Figure size.

    Returns
    -------
    matplotlib.figure.Figure
    """
    fig, ax = plt.subplots(figsize=figsize)

    labels = ['Full Sample', 'Houses Only', 'Condos Only']
    keys = ['full', 'houses', 'condos']
    colors = ['steelblue', 'coral', 'seagreen']

    y_pos = np.arange(len(labels))

    for i, key in enumerate(keys):
        r = subsample_result[key]
        ax.errorbar(r['coef'], y_pos[i],
                    xerr=1.96 * r['se'],
                    fmt='o', color=colors[i], markersize=10,
                    capsize=7, linewidth=2, capthick=1.5, zorder=3)
        ax.annotate(f"n={r['n']:,}", (r['coef'], y_pos[i]),
                    textcoords="offset points", xytext=(0, 12),
                    ha='center', fontsize=9, color=colors[i])

    ax.axvline(x=0, color='grey', linestyle='--', alpha=0.5)
    ax.set_yticks(y_pos)
    ax.set_yticklabels(labels, fontsize=11)
    ax.invert_yaxis()
    ax.set_xlabel('RC × Post Coefficient (95% CI)', fontsize=11)
    ax.set_title('Direct Effect by Property Type',
                 fontsize=12, fontweight='bold')
    ax.xaxis.set_major_formatter(mticker.FormatStrFormatter('%.2f'))
    ax.grid(alpha=0.3, axis='x')

    plt.tight_layout()
    return fig


def plot_monte_carlo(mc_result, figsize=(10, 5)):
    """
    Histogram of DiD estimates across Monte Carlo replications.

    Shows the sampling distribution centered on the true effect,
    with summary statistics annotated.

    Parameters
    ----------
    mc_result : dict
        Output from simulation.run_monte_carlo().
    figsize : tuple
        Figure size.

    Returns
    -------
    matplotlib.figure.Figure
    """
    fig, ax = plt.subplots(figsize=figsize)

    tau = mc_result['true_effect']
    did = mc_result['did']
    summary = mc_result['summary']
    bias = summary['Bias'].values[0]
    rmse = summary['RMSE'].values[0]
    se = summary['Std Dev'].values[0]

    ax.hist(did, bins=50, color='steelblue', alpha=0.7, edgecolor='white',
            density=True, label='DiD estimates')

    ax.axvline(tau, color='red', linewidth=2.5,
               label=f'True effect ({tau:.2f})', zorder=5)
    ax.axvline(did.mean(), color='navy', linewidth=2, linestyle='--',
               label=f'Mean estimate ({did.mean():.4f})', zorder=5)

    # 95% interval of the sampling distribution
    ci_lo, ci_hi = np.percentile(did, [2.5, 97.5])
    ax.axvspan(ci_lo, ci_hi, alpha=0.12, color='steelblue',
               label=f'95% range [{ci_lo:.3f}, {ci_hi:.3f}]')

    # Annotate statistics
    stats_text = (f'Bias: {bias:+.4f}\n'
                  f'Std Dev: {se:.4f}\n'
                  f'RMSE: {rmse:.4f}\n'
                  f'N sims: {mc_result["n_simulations"]:,}')
    ax.text(0.97, 0.95, stats_text, transform=ax.transAxes,
            fontsize=10, verticalalignment='top', horizontalalignment='right',
            bbox=dict(boxstyle='round,pad=0.4', facecolor='white',
                      edgecolor='grey', alpha=0.9),
            fontfamily='monospace')

    ax.set_xlabel('Estimated RC × Post Coefficient', fontsize=11)
    ax.set_ylabel('Density', fontsize=11)
    ax.set_title('Monte Carlo: Sampling Distribution of DiD Estimator',
                 fontsize=12, fontweight='bold')
    ax.legend(fontsize=9, loc='upper left')
    ax.grid(alpha=0.3)

    plt.tight_layout()
    return fig
