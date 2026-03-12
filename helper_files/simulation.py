"""
Monte Carlo Simulation for Validating the DiD Estimator

Simulates a housing market that mirrors the Autor et al. (2014) setting:
- Properties with non-random rent control assignment (selection bias)
- Two periods (pre/post decontrol) with a known true treatment effect
- Shows the DiD estimator is unbiased for the true effect across replications
"""

import numpy as np
import pandas as pd


def _simulate_one_dataset(n_properties, true_direct_effect, true_indirect_effect,
                          selection_strength, rng):
    """
    Generate one synthetic housing market dataset.

    Parameters
    ----------
    n_properties : int
        Number of unique properties.
    true_direct_effect : float
        True RC x Post coefficient (log points).
    true_indirect_effect : float
        True RCI x Post coefficient (log points).
    selection_strength : float
        How strongly RC assignment correlates with property characteristics.
    rng : np.random.Generator
        Random number generator.

    Returns
    -------
    pd.DataFrame
        Panel data with 2 * n_properties rows (pre and post for each property).
    """
    # Property characteristics
    is_condo = rng.binomial(1, 0.5, size=n_properties).astype(float)
    n_neighborhoods = max(20, n_properties // 50)
    neighborhood = rng.integers(0, n_neighborhoods, size=n_properties)

    # Neighborhood fixed effect (some neighborhoods are "better")
    neigh_fe = rng.normal(0, 0.3, size=n_neighborhoods)

    # RC assignment: NOT random — condos in dense neighborhoods more likely controlled
    neigh_density = rng.uniform(0, 1, size=n_neighborhoods)
    rc_propensity = (selection_strength * is_condo +
                     selection_strength * neigh_density[neighborhood] +
                     rng.normal(0, 0.5, size=n_properties))
    rc_prob = 1 / (1 + np.exp(-rc_propensity))
    rc = rng.binomial(1, rc_prob).astype(float)

    # RCI: fraction of RC properties in each neighborhood
    neigh_rc_sum = np.bincount(neighborhood, weights=rc, minlength=n_neighborhoods)
    neigh_count = np.bincount(neighborhood, minlength=n_neighborhoods).astype(float)
    neigh_count = np.maximum(neigh_count, 1)
    rci = (neigh_rc_sum / neigh_count)[neighborhood]

    # Baseline property value (log): condos worth less, RC properties worth less
    alpha_i = (12.0
               + 0.4 * (1 - is_condo)           # houses worth more
               + neigh_fe[neighborhood]           # neighborhood quality
               - 0.5 * rc                         # RC discount (pre-treatment gap)
               + rng.normal(0, 0.3, size=n_properties))

    # Time effect (general appreciation)
    delta_post = 0.8  # ~120% appreciation for all properties

    # Build panel: 2 periods per property
    n_obs = n_properties * 2
    prop_idx = np.tile(np.arange(n_properties), 2)
    post = np.array([0] * n_properties + [1] * n_properties, dtype=float)

    # Outcome
    lnvalue = (alpha_i[prop_idx]
               + delta_post * post
               + true_direct_effect * rc[prop_idx] * post
               + true_indirect_effect * rci[prop_idx] * post
               + rng.normal(0, 0.2, size=n_obs))

    df = pd.DataFrame({
        'property_id': prop_idx,
        'post': post,
        'rc': rc[prop_idx],
        'rci': rci[prop_idx],
        'is_condo': is_condo[prop_idx],
        'neighborhood': neighborhood[prop_idx],
        'lnvalue': lnvalue,
    })

    return df


def _estimate_did(df):
    """DiD: (RC_post - RC_pre) - (nonRC_post - nonRC_pre)."""
    means = df.groupby(['rc', 'post'])['lnvalue'].mean()
    did = (means.loc[(1, 1)] - means.loc[(1, 0)]) - (means.loc[(0, 1)] - means.loc[(0, 0)])
    return did


def run_monte_carlo(n_properties=5000, n_simulations=1000,
                    true_direct_effect=0.22, true_indirect_effect=0.40,
                    selection_strength=1.5, seed=42):
    """
    Run Monte Carlo simulation of the DiD estimator.

    Generates synthetic housing market datasets with a known true treatment
    effect and non-random RC assignment, then estimates the DiD coefficient
    in each replication to verify unbiasedness.

    Parameters
    ----------
    n_properties : int
        Number of properties per simulated dataset.
    n_simulations : int
        Number of Monte Carlo replications.
    true_direct_effect : float
        Known true RC x Post effect (log points). Default 0.22 mirrors Table 3.
    true_indirect_effect : float
        Known true RCI x Post effect. Default 0.40 mirrors Table 4.
    selection_strength : float
        Strength of selection into RC treatment.
    seed : int
        Random seed for reproducibility.

    Returns
    -------
    dict
        'did': np.ndarray of DiD estimates
        'true_effect': float
        'n_simulations': int
        'summary': pd.DataFrame with bias/RMSE statistics
    """
    rng = np.random.default_rng(seed)

    did_ests = np.empty(n_simulations)

    for i in range(n_simulations):
        df = _simulate_one_dataset(n_properties, true_direct_effect,
                                   true_indirect_effect, selection_strength, rng)
        did_ests[i] = _estimate_did(df)

    # Summary statistics
    tau = true_direct_effect
    summary = pd.DataFrame({
        'Estimator': ['Difference-in-Differences'],
        'True Effect': [tau],
        'Mean Estimate': [did_ests.mean()],
        'Bias': [did_ests.mean() - tau],
        'Std Dev': [did_ests.std()],
        'RMSE': [np.sqrt(np.mean((did_ests - tau) ** 2))],
    })

    print("=" * 85)
    print(f"MONTE CARLO SIMULATION — {n_simulations} replications, "
          f"{n_properties} properties each")
    print("=" * 85)
    print(f"True direct effect (RC x Post): {tau:.2f}\n")
    print(summary.to_string(index=False))
    print("-" * 85)

    return {
        'did': did_ests,
        'true_effect': tau,
        'n_simulations': n_simulations,
        'summary': summary,
    }
