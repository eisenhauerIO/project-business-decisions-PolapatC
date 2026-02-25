* THIS PROGRAM CREATES TABLE 2 IN AUTOR, PALMER, PATHAK (JPE, 2013)

clear
set more off

use ../dta/assess-panel, clear

keep if inlist(1,house,condo)
keep if inlist(year,1994,2004)
keep if rci_u20!=.
keep if value!=.
gen post = year>=1995

tab year


* deflate

cap gen cpi=.
replace cpi = 144.8   if year==1994
replace cpi = 179.3   if year==2004
gen value2008 = (value*(205.453/cpi))
*use real log value
gen lvalue = ln(value2008)

* Houses
bys rc : eststo: estpost tabstat lvalue rci_u20 if !condo, by(year) statistics(n mean sd) c(statistics) listwise nototal
esttab using "../tab/table-2.csv", main(mean) aux(sd) nostar unstack ///
	nonote nonumber nolines nogaps replace label b(2) 


* Condos

bys rc : eststo: estpost tabstat lvalue rci_u20 if condo, by(year) statistics(n mean sd) c(statistics) listwise nototal
esttab using "../tab/table-2.csv", main(mean) aux(sd) nostar unstack ///
	nonote nonumber nolines nogaps append label b(2) 

foreach r in 0 1 {
	foreach s in 0 1 {
		foreach t in 0 1 {
			di "Condo:`s' RC: `r' Post: `t' "
			count if rc==`r' & post==`t' & condo==`s'
		}
	}
}

log close

