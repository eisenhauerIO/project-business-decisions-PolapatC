* THIS PROGRAM CREATES TABLE 8 IN AUTOR, PALMER, PATHAK (JPE, 2013)

clear
set mem 1g
set more off

use ../dta/assess-panel, clear

capture drop cpi
gen double cpi=.
replace cpi = 115.9   if year==1988 
replace cpi = 121.6   if year==1989
replace cpi = 128.2   if year==1990
replace cpi = 133.5   if year==1991
replace cpi = 137.3   if year==1992
replace cpi = 141.4   if year==1993
replace cpi = 144.8   if year==1994
replace cpi = 148.6   if year==1995
replace cpi = 152.8   if year==1996
replace cpi = 155.9   if year==1997
replace cpi = 157.2   if year==1998
replace cpi = 160.2   if year==1999
replace cpi = 165.7   if year==2000
replace cpi = 169.7   if year==2001
replace cpi = 170.8   if year==2002
replace cpi = 174.6   if year==2003
replace cpi = 179.3   if year==2004
replace cpi = 186.1   if year==2005
replace cpi = 191.9   if year==2006
replace cpi = 196.639   if year==2007
replace cpi = 205.453   if year==2008
replace cpi = 203.301 	if year == 2009
tab year, summ(cpi)
assert cpi!=.
gen nom_value = value
replace value = (value*(205.453/cpi))/ 1000000

keep if inlist(1,house,condo)
gen twofam=usecode==104
gen threefam=usecode==105
tab usecode

gen lvalue = ln(value)

gen post = year>=1995
gen rc_post = rc*post


keep if inlist(year,1994,2004)

xi i.year, prefix(_yr)

local house = "twofam threefam if house==1"
local condo = "if condo==1"
local pooled = "twofam threefam condo if house==1|condo==1"

egen mlid = group(ml)

local replace 

xi i.tract90*post, prefix(trp)
local Tract = " trp* "

foreach trend in Tract {

	local j = 1 // this index the row of the matrix we're working on. j=1 is houses, j=2 is condos, j=3 is the total and is filled directly
	mat rc_`trend' = J(3,7,0)
	mat nrc_`trend' = J(3,7,0)
	mat total_`trend'=J(3,7,0)

	foreach struct in house condo {
		
		cap drop *rci *rci_post
		gen rci = rci_u20
		drop if rci==.
		gen rci_post = rci*post
		gen nrc_rci = rci*(rc==0)
		gen rc_rci = rci*(rc==1)
		gen nrc_rci_post = nrc_rci*post
		gen rc_rci_post = rc_rci*post

		
		preserve
		
		areg lvalue rc rc_post nrc_rci nrc_rci_post rc_rci rc_rci_post _yr* ``trend'' ``struct'', a(mlid) // `pooled' instead of ``struct'' if pooling this.
			    
	    ** predict pvalue 
	
		foreach var in rc nrc_rci rc_rci {
			gen `var'_post_orig = `var'_post
		}
	
		* Pre and Post actual values
		local i = 1
		foreach t in 0 1 {
			summ value if post==`t' & e(sample) & `struct'==1 & rc==1, d
			mat rc_`trend'[`j',`i'] = `r(sum)'
			summ value if post==`t' & e(sample) & `struct'==1 & rc==0, d
			mat nrc_`trend'[`j',`i'] = `r(sum)'
			local i = `i' + 1
		}
		
		* Change in property values
		foreach i of numlist 1 2 {
			mat nrc_`trend'[`i',3]=nrc_`trend'[`i',2]-nrc_`trend'[`i',1]
			mat rc_`trend'[`i',3]=rc_`trend'[`i',2]-rc_`trend'[`i',1]
			}
			
		* calculate counterfactuals
		predict double lyhat_fullreg_`struct' if e(sample) & `struct'==1, xbd
		predict double lyhat_`struct'_resid if e(sample) & `struct'==1, resid
		
		* first do non-RC properties
		gen double lyhat_nrc_indirect_`struct' = lyhat_fullreg_`struct' - nrc_rci_post*_b[nrc_rci_post] if e(sample) & `struct'==1

		* now do RC properties
		* this is the direct effect
		gen double lyhat_rc_direct_`struct' = lyhat_fullreg_`struct' - rc_post*_b[rc_post] if e(sample) & `struct'==1
		* this is the indirect effect
		gen double lyhat_rc_indirect_`struct'=lyhat_fullreg_`struct'-rc_rci_post*_b[rc_rci_post] if e(sample) & `struct'==1

		assert abs(lyhat_fullreg_`struct'+lyhat_`struct'_resid-lvalue)<=c(epsfloat) if e(sample) & `struct'==1 // within error tolerance epsdouble
				
		foreach var in fullreg nrc_indirect rc_direct rc_indirect {
			gen yhat_`var'_`struct' = exp(lyhat_`var'_`struct'+lyhat_`struct'_resid) // don't need to exponentiate with poisson
		}

		
		* Post Counterfactual (i.e. counterfactual aggregate property value)
		* direct effect (%)
		summ yhat_rc_direct_`struct' if e(sample) & rc==1 & post==1  & `struct'==1
		mat rc_`trend'[`j',4] = rc_`trend'[`j',2]-`r(sum)'
		
		* indirect effect (%)
		summ yhat_rc_indirect_`struct' if e(sample) & rc==1 & post==1 & `struct'==1
		mat rc_`trend'[`j',5] = rc_`trend'[`j',2]-`r(sum)'
		summ yhat_nrc_indirect_`struct' if e(sample) & rc==0 & post==1 & `struct'==1
		mat nrc_`trend'[`j',5] = nrc_`trend'[`j',2]-`r(sum)'
	
		* effects in %
		* direct effect
		mat rc_`trend'[`j',6] = round(rc_`trend'[`j',4]/(rc_`trend'[`j',2]-rc_`trend'[`j',4]-rc_`trend'[`j',5]),.01)
		* indirect effects
		mat rc_`trend'[`j',7] = round(rc_`trend'[`j',5]/(rc_`trend'[`j',2]-rc_`trend'[`j',4]-rc_`trend'[`j',5]),.01)
		mat nrc_`trend'[`j',7] = round(nrc_`trend'[`j',5]/(nrc_`trend'[`j',2]-nrc_`trend'[`j',5]),.01)
		
		* increment row counter to work on condominiums row
		local j = `j' + 1
		restore
	}	
	forvalues i=1/5 { // sum columns
		* fill in total row for both RC and non-RC
		mat rc_`trend'[3,`i']=rc_`trend'[1,`i']+rc_`trend'[2,`i']
		mat nrc_`trend'[3,`i']=nrc_`trend'[1,`i']+nrc_`trend'[2,`i']
		* fill in total panel for each property type row
		forvalues j=1/3 { // sum rows
			mat total_`trend'[`j',`i']=rc_`trend'[`j',`i']+nrc_`trend'[`j',`i']
			}
		}

	* fill in total percentages
	* direct effect
	mat rc_`trend'[3,6]=round(rc_`trend'[3,4]/(rc_`trend'[3,2]-rc_`trend'[3,4]-rc_`trend'[3,5]),.01)
	mat nrc_`trend'[3,6]=round(nrc_`trend'[3,4]/(nrc_`trend'[3,2]-nrc_`trend'[3,4]-nrc_`trend'[3,5]),.01)
	mat total_`trend'[1,6]=round(total_`trend'[1,4]/(total_`trend'[1,2]-total_`trend'[1,4]-total_`trend'[1,5]),.01)
	mat total_`trend'[2,6]=round(total_`trend'[2,4]/(total_`trend'[2,2]-total_`trend'[2,4]-total_`trend'[2,5]),.01)
	mat total_`trend'[3,6]=round(total_`trend'[3,4]/(total_`trend'[3,2]-total_`trend'[3,4]-total_`trend'[3,5]),.01)
	
	* indirect effect
	mat rc_`trend'[3,7]=round(rc_`trend'[3,5]/(rc_`trend'[3,2]-rc_`trend'[3,4]-rc_`trend'[3,5]),.01)
	mat nrc_`trend'[3,7]=round(nrc_`trend'[3,5]/(nrc_`trend'[3,2]-nrc_`trend'[3,4]-nrc_`trend'[3,5]),.01)
	mat total_`trend'[1,7]=round(total_`trend'[1,5]/(total_`trend'[1,2]-total_`trend'[1,4]-total_`trend'[1,5]),.01)
	mat total_`trend'[2,7]=round(total_`trend'[2,5]/(total_`trend'[2,2]-total_`trend'[2,4]-total_`trend'[2,5]),.01)
	mat total_`trend'[3,7]=round(total_`trend'[3,5]/(total_`trend'[3,2]-total_`trend'[3,4]-total_`trend'[3,5]),.01)

	}


	
	
foreach trend in Tract {
	* RC panel
	di "rc `trend' "
	mat li rc_`trend', format(%10.2f)
	
	* non-RC panel
	di "nrc `trend' "
	mat li nrc_`trend', format(%10.2f)

	* this is what would have happened if RC units hadn't had their direct effect
	di "totals `trend'"
	mat li total_`trend', format(%10.2f)

	* this is what would have happened if RC units hadn't had either RC x Post or RCI x Post effects
	* di "rc no RCI `trend' -- note that because of exponentiating, this isn't the sum of the other two"
	* mat list rc_norci_`trend', format(%10.0f)

	
}
