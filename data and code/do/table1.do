* THIS PROGRAM CREATES TABLE 1 IN AUTOR, PALMER, PATHAK (JPE, 2013)

clear
set mem 2g
set more off

use ../dta/fromEquifax-v7-19oct11


gen bg90 = real(substr(string(block90),1,5))


duplicates drop cidnew year, force
egen id_c = group(cidnew)
xtset id_c year

* Movement variables
egen mlnum = group(ml)
gen newthisyr = mlnum!=l.mlnum

sort ml
merge ml using ../dta/structures-2001, keep(rci_u20 state_use_cd) nokeep
tab _merge
keep if _merge==3
drop _merge


forval i=1992/2000 {
	gen rent_`i' = rent*year==`i'
	gen rci_y`i' = rci_u20*(year==`i')
	gen rc_rci_y`i' = (rc==1)*rci_y`i'
	gen nrc_rci_y`i' = (rc==0)*rci_y`i'
}
summ rci_y*

drop if year==1991

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
replace inother=1 if (state_use_cd != 101) & (state_use_cd != 104) & (state_use_cd != 105) & (state_use_cd! = 109) & (state_use_cd != 111) & (state_use_cd != 112) & (state_use_cd != 199)

tab inother

*keep ALL ZIPS, good structures

keep if inother==0

xi i.year

gen post = year>=1995
replace rc = rent
gen rc_post = rc*post


local pooled = "twofam threefam multihouse incondo inapt if inhouse==1 | incondo==1 | inapt==1"
local house = "twofam threefam multihouse if inhouse==1"
local condo = "if incondo==1"
local apt = "if inapt==1"

local replace replace
foreach trend in none {
	foreach type in pooled house condo apt  {
		di "***** `type' regressions, Event ******"
		
		reg newthisyr rc rc_post _I* _bg* ``trend'' ``type'', cluster(bg90)

		sum newthisyr if e(sample), meanonly
		local ymean=r(mean)
		outreg2 rc rc_post using "../tab/table1.xml", ///
			`replace' excel bdec(3) tdec(3) addtext(FE, "bg90", Trend, "`trend'", Struct, `type') nocons addstat(Dep Var Mean, `ymean')
		

	local replace
	}
}

* end of do file