* THIS PROGRAM CREATES FIG 2 IN AUTOR, PALMER, PATHAK (JPE, 2013)
* This program creates event study plots for the effect of rent control on resident tenure.

clear
set mem 2g
set more off

* Equifax data with unique identifiers for people at each address
use ../dta/fromEquifax-v7-19oct11

* generate census geography variable
gen bg90 = real(substr(string(block90),1,5))

* keep unique people, define dependent variable
duplicates drop cidnew year, force
egen id_c = group(cidnew)
xtset id_c year

egen mlnum = group(ml)
gen newthisyr = mlnum!=l.mlnum

* get structure type information on each person in a structure that has a valid ML code
sort ml
merge ml using ../dta/structures-2001, keep(state_use_cd) nokeep
tab _merge
keep if _merge==3
drop _merge

foreach i of numlist 1992 1993 1995/2000 {
	gen rent_`i' = rent*year==`i'
}

* can't see if 1991 people were there in 1990, but used this data for whether 1991 people are there in 1992
drop if year==1991

* generate structure type controls
gen inhouse=0
replace inhouse=1 if (state_use_cd==101) | (state_use_cd==104) | (state_use_cd==105) | (state_use_cd==109)

gen twofam=state_use_cd==104
gen threefam=state_use_cd==105
gen multihouse=state_use_cd==109

gen inapt=0
replace inapt=1 if (state_use_cd==111) | (state_use_cd==112) 

gen incondo=0
replace incondo=1 if (state_use_cd==199)

gen inother=0 
replace inother=1 if (state_use_cd != 101) & (state_use_cd != 104) & (state_use_cd != 105) & (state_use_cd != 109) & (state_use_cd != 111) & (state_use_cd != 112) & (state_use_cd != 199)
tab inother
* keep ALL ZIPS, common structures
keep if inother==0

xi i.year

** ############# **
** Event study   **
** ############# **

* New This year plots
local pooled = "twofam threefam multihouse incondo inapt if inhouse==1 | incondo==1 | inapt==1"
areg newthisyr rent rent_* _I* `pooled', cluster(bg90) a(bg90)
mat beta = e(b)'
mat var = e(V)
mat newthisyr_rc1= [beta[2..9,1], J(8,1,0), J(8,1,0)]
forval i=1/8 {
	local i1 = `i' + 1
	mat newthisyr_rc1[`i',2] = newthisyr_rc1[`i',1] - 1.96*sqrt(var[`i1',`i1'])
	mat newthisyr_rc1[`i',3] = newthisyr_rc1[`i',1] + 1.96*sqrt(var[`i1',`i1'])
	}
}

preserve
drop _all
local outcome newthisyr
local var rc1
svmat `outcome'_`var'
rename `outcome'_`var'1 `var'
rename `outcome'_`var'2 `var'_cilo
rename `outcome'_`var'3 `var'_cihi			

gen year = _n + 1991
replace year = year + 1 if year>=1994
local newobs = `=_N' + 1
set obs `newobs'
replace year = 1994 if year==.
replace rc1 = 0 if year==1994

* extend CI lines
set obs 11
replace year = 1993.5 in 10
replace year = 1994.5 in 11
sort year
replace rc1_cilo=rc1_cilo[2]-(.5*(rc1[2])) if year==1993.5
replace rc1_cihi=rc1_cihi[2]-(.5*(rc1[2])) if year==1993.5
replace rc1_cilo=rc1_cilo[6]-(.5*(rc1[6])) if year==1994.5
replace rc1_cihi=rc1_cihi[6]-(.5*(rc1[6])) if year==1994.5
sort year

twoway (rline rc1_cilo rc1_cihi year, cmissing(n) lp(dash)) (connected rc1 year), ///
		title( "RC effect on new residency, 1992-2000") /// 
		leg(label(1 "95% Confidence Interval") label(2 "Point Estimate") order(2 1)) ///
		scheme(s2mono) ylab(-.02(.02).14) xtitle("") xline(1994)
graph save "../gph/fig2-movers-event-study.gph", replace
graph export "../gph/fig2-movers-event-study.png", replace

* end of do file