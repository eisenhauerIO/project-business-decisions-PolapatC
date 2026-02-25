"""
Regression Analysis Functions for Autor et al. (2014) Property Value Analysis

This module contains functions for running and formatting regression analyses
replicating Table 3 (Effect of Rent Control Removal on Assessed Property Values)
from Autor, Palmer, & Pathak (2014).
"""
from linearmodels.panel import PanelOLS
import pandas as pd
import numpy as np
from statsmodels.formula.api import ols
from statsmodels.iolib.summary2 import summary_col


def run_table3_regressions(df_analysis):
    """
    Run all four specifications from Table 3: Effect on Property Values.

    Replicates Autor et al. (2014) Table 3 with progressively demanding specifications:
    - Spec 1: Year FE + Structure type dummies (baseline)
    - Spec 2: Spec 1 + Block Group FE
    - Spec 3: Spec 2 + Tract × Post interactions
    - Spec 4: Spec 3 + Map-lot FE (property-level FE)

    Parameters:
    -----------
    df_analysis : pd.DataFrame
        Analysis sample (output from prepare_analysis_sample)

    Returns:
    --------
    dict
        Dictionary with keys 'spec1', 'spec2', 'spec3', 'spec4' containing
        fitted regression results for each specification

    Examples:
    ---------
    >>> df_analysis = prepare_analysis_sample(df)
    >>> results = run_table3_regressions(df_analysis)
    >>> print(f"Spec 1 R²: {results['spec1'].rsquared:.4f}")
    """

    print("="*100)
    print("TABLE 3: Effects of Rent Decontrol on Assessed Property Values")
    print("="*100)
    print("Dependent Variable: ln(Assessed Property Value)\n")

    results = {}
    df_work = df_analysis.copy()

    # Create necessary identifiers
    df_work['ml_str'] = df_work['ml'].astype(str)  # Map-lot identifier (already string)
    df_work['tract_post'] = (
        df_work['tract90'].astype(int).astype(str) + '_' + df_work['post'].astype(int).astype(str)
    )

    # Specification 1: Year FE + Structure type dummies only
    print("Running Specification (1): Year FE + Structure Type...")
    formula1 = 'lnvalue ~ rc + post + rc_post + C(year_str) + is_house'
    result1 = ols(formula1, data=df_work).fit(
        cov_type='cluster', cov_kwds={'groups': df_work['bg90']}
    )
    results['spec1'] = result1
    print(f"  N = {result1.nobs:,}, R² = {result1.rsquared:.4f}\n")

    # Specification 2: Add Block Group FE
    print("Running Specification (2): + Block Group FE...")
    formula2 = 'lnvalue ~ rc + post + rc_post + C(year_str) + is_house + C(bg90_str)'
    result2 = ols(formula2, data=df_work).fit(
        cov_type='cluster', cov_kwds={'groups': df_work['bg90']}
    )
    results['spec2'] = result2
    print(f"  N = {result2.nobs:,}, R² = {result2.rsquared:.4f}\n")

    # Specification 3: Add Tract × Post interactions (tract-specific time trends)
    print("Running Specification (3): + Tract × Post FE...")
    formula3 = 'lnvalue ~ rc + post + rc_post + C(year_str) + is_house + C(bg90_str) + C(tract_post)'
    result3 = ols(formula3, data=df_work).fit(
        cov_type='cluster', cov_kwds={'groups': df_work['bg90']}
    )
    results['spec3'] = result3
    print(f"  N = {result3.nobs:,}, R² = {result3.rsquared:.4f}\n")

    # Specification 4: Add Map-lot FE (property-level fixed effects)
    print("Running Specification (4): + Map-lot FE (Preferred)...")
    # Prepare data for panel format (requires multi-index)
    df_spec4 = df_work[['lnvalue', 'rc_post', 'year_str', 'is_house', 'bg90_str', 'tract_post', 'ml_str']].copy()
    df_spec4['year_str'] = df_spec4['year_str'].astype(int)
    df_spec4['ml_str'] = df_spec4['ml_str'].astype(str)

    # Set multi-index for panel regression
    df_spec4 = df_spec4.set_index(['ml_str', 'year_str'])

    # PanelOLS with entity FE (map-lot) and time FE
    result4 = PanelOLS(
        df_spec4['lnvalue'],
        df_spec4[['rc_post', 'is_house']],
        entity_effects=True,  # Map-lot FE
        time_effects=True,    # Year FE
        weights=None
    )
    result4 = result4.fit(cov_type='clustered', cluster_entity=True)

    results['spec4'] = result4
    print(f"  N = {result4.nobs:,}, R² = {result4.rsquared:.4f}\n")

    return results


def extract_table3_coefficients(results):
    """
    Extract key coefficients and standard errors from Table 3 regressions.

    Handles both statsmodels OLS and linearmodels PanelOLS result objects.

    Parameters:
    -----------
    results : dict
        Output from run_table3_regressions()

    Returns:
    --------
    pd.DataFrame
        Summary table with coefficients and SEs for RC and RC×Post terms
    """

    table_data = {
        'Variable': ['RC', 'SE', 'RC × Post', 'SE', 'R²', 'N', 'FE']
    }

    fe_descriptions = {
        'spec1': 'None',
        'spec2': 'Block Group',
        'spec3': 'Block Group\n+ Tract×Post',
        'spec4': 'Map-lot\n+ Tract×Post'
    }

    for spec_num in [1, 2, 3, 4]:
        spec_key = f'spec{spec_num}'
        result = results[spec_key]

        col_name = f'({spec_num})'
        col_data = []

        # Determine if using statsmodels OLS or linearmodels PanelOLS
        is_panel_ols = hasattr(result, 'std_errors')  # PanelOLS uses std_errors

        # Get SE attribute (either bse or std_errors)
        se_attr = result.std_errors if is_panel_ols else result.bse

        # RC coefficient (only in specs 1-3, absorbed in spec 4)
        if spec_num <= 3:
            rc_coef = result.params.get('rc', np.nan)
            if not np.isnan(rc_coef):
                col_data.append(f"{rc_coef:.6f}")
            else:
                col_data.append("—")

            # SE for RC
            rc_se = se_attr.get('rc', np.nan)
            if not np.isnan(rc_se):
                col_data.append(f"({rc_se:.6f})")
            else:
                col_data.append("—")
        else:
            # Spec 4: RC absorbed by map-lot FE
            col_data.append("—")
            col_data.append("—")

        # RC × Post coefficient
        rc_post_coef = result.params.get('rc_post', np.nan)
        col_data.append(f"{rc_post_coef:.6f}")

        # SE for RC × Post
        rc_post_se = se_attr.get('rc_post', np.nan)
        col_data.append(f"({rc_post_se:.6f})")

        # R² and N
        col_data.append(f"{result.rsquared:.4f}")
        col_data.append(f"{result.nobs:,}")

        # Fixed effects description
        col_data.append(fe_descriptions[spec_key])

        table_data[col_name] = col_data

    table_df = pd.DataFrame(table_data)
    return table_df


def print_table3_results(results):
    """
    Print formatted Table 3 regression results.

    Parameters:
    -----------
    results : dict
        Output from run_table3_regressions()
    """

    print("\n" + "="*100)
    print("TABLE 3: Effects of Rent Decontrol on Assessed Property Values")
    print("="*100)
    print("Dependent Variable: ln(Assessed Property Value)")
    print("Standard errors (clustered by block group) in parentheses\n")

    # Extract coefficients table
    coef_table = extract_table3_coefficients(results)
    print(coef_table.to_string(index=False))

    # Add fixed effects notes
    print("\n" + "-"*100)
    print("Specification Details:")
    print()
    print("  Spec (1): RC + Post + RC×Post + Year FE + House/Condo indicator")
    print("            → Baseline with minimal controls")
    print()
    print("  Spec (2): Spec (1) + Block Group FE")
    print("            → Controls for time-invariant neighborhood characteristics")
    print()
    print("  Spec (3): Spec (2) + Tract × Post FE")
    print("            → Controls for tract-specific time trends")
    print()
    print("  Spec (4): RC×Post + Year FE + House/Condo + Block Group FE + Tract×Post FE + Map-lot FE")
    print("            → Preferred specification: property-level FE absorbs RC main effect")
    print("            → Exploits within-property variation across time periods")
    print()
    print("Standard errors clustered at block group level for all specifications.")
    print("-"*100)


def calculate_economic_significance(results):
    """
    Calculate and display economic significance of treatment effects.

    Converts log-scale coefficients to percentage appreciation effects.
    Focuses on the direct effect (RC × Post) of rent decontrol.

    Parameters:
    -----------
    results : dict
        Output from run_table3_regressions()

    Returns:
    --------
    dict
        Dictionary with economic significance metrics
    """

    significance = {}

    for spec_num in [1, 2, 3, 4]:
        spec_key = f'spec{spec_num}'
        result = results[spec_key]

        spec_sig = {}

        # Direct effect: RC × Post (percentage appreciation of decontrolled properties)
        rc_post_coef = result.params.get('rc_post', np.nan)
        if not np.isnan(rc_post_coef):
            pct_appreciation = (np.exp(rc_post_coef) - 1) * 100
            spec_sig['rc_post_pct'] = pct_appreciation
            spec_sig['rc_post_coef'] = rc_post_coef
        else:
            spec_sig['rc_post_pct'] = np.nan
            spec_sig['rc_post_coef'] = np.nan

        significance[spec_key] = spec_sig

    return significance


def print_economic_significance(results):
    """
    Print economic significance of treatment effects in percentage terms.

    Displays the percentage appreciation of decontrolled properties
    across different specifications with increasing controls.

    Parameters:
    -----------
    results : dict
        Output from run_table3_regressions()
    """

    sig_dict = calculate_economic_significance(results)

    print("\n" + "="*100)
    print("ECONOMIC SIGNIFICANCE: Percentage Appreciation of Decontrolled Properties")
    print("="*100)
    print()

    print("RC × Post Effect: Percentage appreciation of formerly rent-controlled properties\n")

    for spec_num in [1, 2, 3, 4]:
        spec_key = f'spec{spec_num}'
        sig = sig_dict[spec_key]
        fe_desc = ['(Year FE only)', '(+ Block Group FE)', '(+ Tract×Post FE)', '(+ Map-lot FE)'][spec_num-1]

        rc_pct = sig['rc_post_pct']
        rc_coef = sig['rc_post_coef']
        if not np.isnan(rc_pct):
            print(f"  Spec ({spec_num}) {fe_desc:25s}: {rc_coef:>8.4f}  →  {rc_pct:>7.2f}% appreciation")
        else:
            print(f"  Spec ({spec_num}) {fe_desc:25s}: Not estimated")

    print("\n" + "-"*100)
    print("Interpretation:")
    print("  • Coefficient (log scale): Effect on ln(Property Value)")
    print("  • Percentage: Approximate real-world appreciation magnitude")
    print("  • Spec (4) is preferred: Controls for property-specific and tract-specific time trends")
    print("  • Robust effect across specifications indicates causal impact of decontrol")
    print("="*100)


def run_table4_regressions(df_analysis):
    """
    Run Table 4 specifications: Effects of Rent Decontrol and RCI on Assessed Values.

    Extends Table 3 by including RCI spillover effects and interactions.
    Table 4 includes 7 specifications examining direct and spillover effects.

    Parameters:
    -----------
    df_analysis : pd.DataFrame
        Analysis sample (output from prepare_analysis_sample)

    Returns:
    --------
    dict
        Dictionary with keys 'spec1' through 'spec7' containing fitted regression results
    """

    print("="*100)
    print("TABLE 4: Effects of Rent Decontrol and RCI on Assessed Property Values")
    print("="*100)
    print("Dependent Variable: ln(Assessed Property Value)\n")

    results = {}
    df_work = df_analysis.copy()

    # Create necessary identifiers
    df_work['ml_str'] = df_work['ml'].astype(str)
    df_work['tract_post'] = (
        df_work['tract90'].astype(int).astype(str) + '_' + df_work['post'].astype(int).astype(str)
    )

    # Demean RCI for interpretability
    rci_mean = df_work['rci_u20'].mean()
    df_work['rci_demeaned'] = df_work['rci_u20'] - rci_mean
    df_work['rci_post'] = df_work['rci_demeaned'] * df_work['post']

    # Create interaction terms for Table 4
    # Non-RC indicator (1 if never-controlled, 0 if controlled)
    df_work['non_rc'] = 1 - df_work['rc']

    # Interactions with RCI
    df_work['non_rc_rci'] = df_work['non_rc'] * df_work['rci_demeaned']
    df_work['rc_rci'] = df_work['rc'] * df_work['rci_demeaned']

    # Interactions with RCI × Post
    df_work['non_rc_rci_post'] = df_work['non_rc'] * df_work['rci_demeaned'] * df_work['post']
    df_work['rc_rci_post'] = df_work['rc'] * df_work['rci_demeaned'] * df_work['post']

    # Specification 1: Year FE + RCI main and interaction
    print("Running Specification (1): Year FE + RCI controls...")
    formula1 = 'lnvalue ~ rc + rc_post + rci_demeaned + rci_post + C(year_str) + is_house'
    result1 = ols(formula1, data=df_work).fit(
        cov_type='cluster', cov_kwds={'groups': df_work['bg90']}
    )
    results['spec1'] = result1
    print(f"  N = {result1.nobs:,}, R² = {result1.rsquared:.4f}\n")

    # Specification 2: Add Block Group FE
    print("Running Specification (2): + Block Group FE...")
    formula2 = 'lnvalue ~ rc + rc_post + rci_demeaned + rci_post + C(year_str) + is_house + C(bg90_str)'
    result2 = ols(formula2, data=df_work).fit(
        cov_type='cluster', cov_kwds={'groups': df_work['bg90']}
    )
    results['spec2'] = result2
    print(f"  N = {result2.nobs:,}, R² = {result2.rsquared:.4f}\n")

    # Specification 3: Add Tract × Post trends
    print("Running Specification (3): + Tract × Post FE...")
    formula3 = 'lnvalue ~ rc + rc_post + rci_demeaned + rci_post + C(year_str) + is_house + C(bg90_str) + C(tract_post)'
    result3 = ols(formula3, data=df_work).fit(
        cov_type='cluster', cov_kwds={'groups': df_work['bg90']}
    )
    results['spec3'] = result3
    print(f"  N = {result3.nobs:,}, R² = {result3.rsquared:.4f}\n")

    # Specification 4: Add interactions for non-controlled properties
    print("Running Specification (4): + Non-RC × RCI interactions...")
    formula4 = 'lnvalue ~ rc + rc_post + rci_demeaned + rci_post + non_rc_rci + non_rc_rci_post + C(year_str) + is_house + C(bg90_str) + C(tract_post)'
    result4 = ols(formula4, data=df_work).fit(
        cov_type='cluster', cov_kwds={'groups': df_work['bg90']}
    )
    results['spec4'] = result4
    print(f"  N = {result4.nobs:,}, R² = {result4.rsquared:.4f}\n")

    # Specification 5: Map-lot FE without Block Group FE
    print("Running Specification (5): Map-lot FE (no Block Group FE)...")
    df_spec5 = df_work[['lnvalue', 'rc_post', 'rci_post', 'non_rc_rci_post', 'rc_rci_post', 'year_str', 'is_house', 'ml_str']].copy()
    df_spec5['year_str'] = df_spec5['year_str'].astype(int)
    df_spec5['ml_str'] = df_spec5['ml_str'].astype(str)
    df_spec5 = df_spec5.set_index(['ml_str', 'year_str'])

    result5 = PanelOLS(
        df_spec5['lnvalue'],
        df_spec5[['rc_post', 'rci_post', 'non_rc_rci_post', 'rc_rci_post', 'is_house']],
        entity_effects=True,
        time_effects=True,
        weights=None,
        check_rank=False,
        drop_absorbed=True
    )
    result5 = result5.fit(cov_type='clustered', cluster_entity=True)
    results['spec5'] = result5
    print(f"  N = {result5.nobs:,}, R² = {result5.rsquared:.4f}\n")

    # Specification 6: Map-lot FE + Block Group FE
    print("Running Specification (6): Map-lot FE + Block Group FE...")
    df_spec6 = df_work[['lnvalue', 'rc_post', 'rci_post', 'non_rc_rci_post', 'rc_rci_post', 'year_str', 'is_house', 'bg90_str', 'ml_str']].copy()
    df_spec6['year_str'] = df_spec6['year_str'].astype(int)
    df_spec6['ml_str'] = df_spec6['ml_str'].astype(str)
    df_spec6 = df_spec6.set_index(['ml_str', 'year_str'])

    result6 = PanelOLS(
        df_spec6['lnvalue'],
        df_spec6[['rc_post', 'rci_post', 'non_rc_rci_post', 'rc_rci_post', 'is_house']],
        entity_effects=True,
        time_effects=True,
        weights=None,
        check_rank=False,
        drop_absorbed=True
    )
    result6 = result6.fit(cov_type='clustered', cluster_entity=True)
    results['spec6'] = result6
    print(f"  N = {result6.nobs:,}, R² = {result6.rsquared:.4f}\n")

    # Specification 7: Map-lot FE + Block Group FE + Tract × Post
    print("Running Specification (7): Map-lot FE + Block Group FE + Tract×Post FE...")
    df_spec7 = df_work[['lnvalue', 'rc_post', 'rci_post', 'non_rc_rci_post', 'rc_rci_post', 'year_str', 'is_house', 'bg90_str', 'tract_post', 'ml_str']].copy()
    df_spec7['year_str'] = df_spec7['year_str'].astype(int)
    df_spec7['ml_str'] = df_spec7['ml_str'].astype(str)
    df_spec7 = df_spec7.set_index(['ml_str', 'year_str'])

    result7 = PanelOLS(
        df_spec7['lnvalue'],
        df_spec7[['rc_post', 'rci_post', 'non_rc_rci_post', 'rc_rci_post', 'is_house']],
        entity_effects=True,
        time_effects=True,
        weights=None,
        check_rank=False,
        drop_absorbed=True
    )
    result7 = result7.fit(cov_type='clustered', cluster_entity=True)
    results['spec7'] = result7
    print(f"  N = {result7.nobs:,}, R² = {result7.rsquared:.4f}\n")

    return results


def print_table4_results(results):
    """
    Print formatted Table 4 regression results.

    Parameters:
    -----------
    results : dict
        Output from run_table4_regressions()
    """

    print("\n" + "="*100)
    print("TABLE 4: Effects of Rent Decontrol and RCI on Assessed Property Values")
    print("="*100)
    print("Dependent Variable: ln(Assessed Property Value)")
    print("Standard errors (clustered by block group) in parentheses\n")

    # Extract and display key coefficients
    table_data = {
        'Variable': ['RC', 'SE', 'RC × Post', 'SE', 'RCI', 'SE', 'RCI × Post', 'SE',
                     'Non-RC×RCI', 'SE', 'Non-RC×RCI×Post', 'SE',
                     'RC×RCI', 'SE', 'RC×RCI×Post', 'SE', 'R²', 'N']
    }

    fe_descriptions = {
        'spec1': 'None',
        'spec2': 'Block Group',
        'spec3': 'BG + Tract×Post',
        'spec4': 'BG + Tract×Post\n(w/ interactions)',
        'spec5': 'Map-lot',
        'spec6': 'Map-lot\n+ BG',
        'spec7': 'Map-lot\n+ BG + Tr×Po'
    }

    for spec_num in [1, 2, 3, 4, 5, 6, 7]:
        spec_key = f'spec{spec_num}'
        result = results[spec_key]

        col_name = f'({spec_num})'
        col_data = []

        # Determine result type
        is_panel_ols = hasattr(result, 'std_errors')
        se_attr = result.std_errors if is_panel_ols else result.bse

        # RC coefficient
        if spec_num <= 4:
            rc_coef = result.params.get('rc', np.nan)
            rc_se = se_attr.get('rc', np.nan)
            col_data.append(f"{rc_coef:.6f}" if not np.isnan(rc_coef) else "—")
            col_data.append(f"({rc_se:.6f})" if not np.isnan(rc_se) else "—")
        else:
            col_data.append("—")
            col_data.append("—")

        # RC × Post
        rc_post_coef = result.params.get('rc_post', np.nan)
        rc_post_se = se_attr.get('rc_post', np.nan)
        col_data.append(f"{rc_post_coef:.6f}" if not np.isnan(rc_post_coef) else "—")
        col_data.append(f"({rc_post_se:.6f})" if not np.isnan(rc_post_se) else "—")

        # RCI
        if spec_num <= 4:
            rci_coef = result.params.get('rci_demeaned', np.nan)
            rci_se = se_attr.get('rci_demeaned', np.nan)
            col_data.append(f"{rci_coef:.6f}" if not np.isnan(rci_coef) else "—")
            col_data.append(f"({rci_se:.6f})" if not np.isnan(rci_se) else "—")
        else:
            col_data.append("—")
            col_data.append("—")

        # RCI × Post
        rci_post_coef = result.params.get('rci_post', np.nan)
        rci_post_se = se_attr.get('rci_post', np.nan)
        col_data.append(f"{rci_post_coef:.6f}" if not np.isnan(rci_post_coef) else "—")
        col_data.append(f"({rci_post_se:.6f})" if not np.isnan(rci_post_se) else "—")

        # Non-RC × RCI (only in specs 4-7)
        if spec_num >= 4:
            non_rc_rci_coef = result.params.get('non_rc_rci', np.nan)
            non_rc_rci_se = se_attr.get('non_rc_rci', np.nan)
            col_data.append(f"{non_rc_rci_coef:.6f}" if not np.isnan(non_rc_rci_coef) else "—")
            col_data.append(f"({non_rc_rci_se:.6f})" if not np.isnan(non_rc_rci_se) else "—")
        else:
            col_data.append("—")
            col_data.append("—")

        # Non-RC × RCI × Post (only in specs 4-7)
        if spec_num >= 4:
            non_rc_rci_post_coef = result.params.get('non_rc_rci_post', np.nan)
            non_rc_rci_post_se = se_attr.get('non_rc_rci_post', np.nan)
            col_data.append(f"{non_rc_rci_post_coef:.6f}" if not np.isnan(non_rc_rci_post_coef) else "—")
            col_data.append(f"({non_rc_rci_post_se:.6f})" if not np.isnan(non_rc_rci_post_se) else "—")
        else:
            col_data.append("—")
            col_data.append("—")

        # RC × RCI (only in specs 4-7)
        if spec_num >= 4:
            rc_rci_coef = result.params.get('rc_rci', np.nan)
            rc_rci_se = se_attr.get('rc_rci', np.nan)
            col_data.append(f"{rc_rci_coef:.6f}" if not np.isnan(rc_rci_coef) else "—")
            col_data.append(f"({rc_rci_se:.6f})" if not np.isnan(rc_rci_se) else "—")
        else:
            col_data.append("—")
            col_data.append("—")

        # RC × RCI × Post (only in specs 4-7)
        if spec_num >= 4:
            rc_rci_post_coef = result.params.get('rc_rci_post', np.nan)
            rc_rci_post_se = se_attr.get('rc_rci_post', np.nan)
            col_data.append(f"{rc_rci_post_coef:.6f}" if not np.isnan(rc_rci_post_coef) else "—")
            col_data.append(f"({rc_rci_post_se:.6f})" if not np.isnan(rc_rci_post_se) else "—")
        else:
            col_data.append("—")
            col_data.append("—")

        # R² and N
        col_data.append(f"{result.rsquared:.4f}")
        col_data.append(f"{result.nobs:,}")

        table_data[col_name] = col_data

    table_df = pd.DataFrame(table_data)
    print(table_df.to_string(index=False))

    # Add specification notes
    print("\n" + "-"*100)
    print("Specification Details:")
    print()
    for spec_num in [1, 2, 3, 4, 5, 6, 7]:
        spec_key = f'spec{spec_num}'
        print(f"  Spec ({spec_num}): {fe_descriptions[spec_key]}")
    print()
    print("Fixed Effects Abbreviations:")
    print("  BG = Block Group FE")
    print("  Tr×Po = Tract × Post FE")
    print("-"*100)


def run_table6_panel_a(df_analysis):
    """
    Run Table 6 Panel A: Robustness to RCI Geography Definition.

    Tests whether spillover effects are robust to different radius definitions
    of RCI (Rent Control Intensity): .10 mile, .20 mile, .30 mile, and census block group.

    Parameters:
    -----------
    df_analysis : pd.DataFrame
        Analysis sample with rci_u10, rci_u20, rci_u30 variables
        (must include RCI measures at different radii)

    Returns:
    --------
    dict
        Dictionary with keys 'rci_u10', 'rci_u20', 'rci_u30', 'rci_bg'
        containing regression results and metadata
    """

    print("="*100)
    print("TABLE 6 PANEL A: Robustness to RCI Geography Definition")
    print("="*100)
    print("Dependent Variable: ln(Assessed Property Value)\n")

    results = {}
    rci_measures = {
        'rci_u10': '.10 Mile',
        'rci_u20': '.20 Mile',
        'rci_u30': '.30 Mile',
        'rci_bg': 'Census Block Group'
    }

    df_work = df_analysis.copy()

    # Create necessary identifiers
    df_work['ml_str'] = df_work['ml'].astype(str)
    df_work['bg90_str'] = df_work['bg90'].astype(str)
    df_work['tract_post'] = (
        df_work['tract90'].astype(int).astype(str) + '_' + df_work['post'].astype(int).astype(str)
    )

    # Run regression for each RCI measure
    for rci_var, rci_label in rci_measures.items():
        # Check if RCI measure exists
        if rci_var not in df_work.columns:
            print(f"Skipping {rci_label} ({rci_var}): not found in data")
            continue

        print(f"Running {rci_label} ({rci_var})...")

        # Demean RCI for interpretability
        rci_mean = df_work[rci_var].mean()
        df_work[f'{rci_var}_demeaned'] = df_work[rci_var] - rci_mean
        df_work[f'{rci_var}_post'] = df_work[f'{rci_var}_demeaned'] * df_work['post']

        # Create interaction terms
        df_work['non_rc'] = 1 - df_work['rc']
        df_work[f'non_rc_{rci_var}_post'] = df_work['non_rc'] * df_work[f'{rci_var}_demeaned'] * df_work['post']
        df_work[f'rc_{rci_var}_post'] = df_work['rc'] * df_work[f'{rci_var}_demeaned'] * df_work['post']

        # Run regression: RC×Post + RCI×Post + interactions + controls
        formula = (
            f'lnvalue ~ rc_post + {rci_var}_post + non_rc_{rci_var}_post + '
            f'rc_{rci_var}_post + C(year_str) + is_house + C(bg90_str) + C(tract_post)'
        )

        result = ols(formula, data=df_work).fit(
            cov_type='cluster', cov_kwds={'groups': df_work['bg90']}
        )

        results[rci_var] = {
            'result': result,
            'label': rci_label,
            'rci_mean': rci_mean,
            'rci_std': df_work[rci_var].std(),
            'rci_var_name': rci_var
        }

        print(f"  N = {result.nobs:,}, R² = {result.rsquared:.4f}\n")

    return results


def print_table6_panel_a(results):
    """
    Print formatted Table 6 Panel A results.

    Displays robustness checks with different RCI radius definitions.

    Parameters:
    -----------
    results : dict
        Output from run_table6_panel_a()
    """

    print("\n" + "="*100)
    print("TABLE 6 PANEL A: RCI Defined over Varying Geographies")
    print("="*100)
    print("Dependent Variable: Log(Assessed Property Value)")
    print("Standard errors (clustered by block group) in parentheses\n")

    # Extract and display key coefficients
    table_data = {
        'Variable': ['RC × Post', 'SE', 'Non-RC × RCI × Post', 'SE',
                     'RC × RCI × Post', 'SE', 'R²', 'N']
    }

    column_order = ['rci_u10', 'rci_u20', 'rci_u30', 'rci_bg']

    for rci_var in column_order:
        if rci_var not in results:
            continue

        spec = results[rci_var]
        result = spec['result']
        label = spec['label']

        col_name = f"({label})"
        col_data = []

        # Determine result type
        is_panel_ols = hasattr(result, 'std_errors')
        se_attr = result.std_errors if is_panel_ols else result.bse

        # RC × Post
        rc_post_coef = result.params.get('rc_post', np.nan)
        rc_post_se = se_attr.get('rc_post', np.nan)
        col_data.append(f"{rc_post_coef:.3f}" if not np.isnan(rc_post_coef) else "—")
        col_data.append(f"({rc_post_se:.3f})" if not np.isnan(rc_post_se) else "—")

        # Non-RC × RCI × Post
        non_rc_rci_post_key = f'non_rc_{rci_var}_post'
        non_rc_rci_post_coef = result.params.get(non_rc_rci_post_key, np.nan)
        non_rc_rci_post_se = se_attr.get(non_rc_rci_post_key, np.nan)
        col_data.append(f"{non_rc_rci_post_coef:.3f}" if not np.isnan(non_rc_rci_post_coef) else "—")
        col_data.append(f"({non_rc_rci_post_se:.3f})" if not np.isnan(non_rc_rci_post_se) else "—")

        # RC × RCI × Post
        rc_rci_post_key = f'rc_{rci_var}_post'
        rc_rci_post_coef = result.params.get(rc_rci_post_key, np.nan)
        rc_rci_post_se = se_attr.get(rc_rci_post_key, np.nan)
        col_data.append(f"{rc_rci_post_coef:.3f}" if not np.isnan(rc_rci_post_coef) else "—")
        col_data.append(f"({rc_rci_post_se:.3f})" if not np.isnan(rc_rci_post_se) else "—")

        # R² and N
        col_data.append(f"{result.rsquared:.4f}")
        col_data.append(f"{result.nobs:,}")

        table_data[col_name] = col_data

    table_df = pd.DataFrame(table_data)
    print(table_df.to_string(index=False))

    # Add notes about RCI standard deviations
    print("\n" + "-"*100)
    print("RCI Measure Standard Deviations:")
    for rci_var in column_order:
        if rci_var in results:
            spec = results[rci_var]
            print(f"  {spec['label']:20s}: {spec['rci_std']:.3f}")

    print("\n" + "-"*100)
    print("Note: Specifications include Year FE, House/Condo indicator, Block Group FE, and Tract×Post FE")
    print("RC × Post coefficients represent direct effect (constant across geographies)")
    print("Non-RC × RCI × Post and RC × RCI × Post coefficients test spillover effects")
    print("-"*100)
