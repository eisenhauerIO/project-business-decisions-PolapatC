* THIS PROGRAM CREATES TABLE A2 IN AUTOR, PALMER, PATHAK (JPE, 2013)

clear

set mem 2g
set more off

use ml rc rci_u20 bg90 tract90 apts_units using ../dta/structures-2001
sort ml
tempfile rc
save `rc'


use ../dta/assess-panel, clear

* count number of duplicate usage code x ML x year duplicates
preserve
gen temp = 1
collapse (count) temp, by(year ml usecode)
bys year ml: gen mlcount = _N
keep year ml mlcount
sort year ml
tempfile mlcount
save `mlcount'
restore

sort year ml
merge year ml using `mlcount'
assert _merge==3
drop _merge

gen useclass = .

replace useclass = 1 if inlist(usecode,101,104,105)
replace useclass = 2 if inlist(usecode,102,199)
replace useclass = 3 if inlist(usecode,111,112)
replace useclass = 4 if !inlist(usecode,102,199,101,104,105,111,112) & (usecode <=124 | inlist(usecode,907,908))
replace useclass = 5 if usecode>124 & !inlist(usecode,907,908,199) & usecode!=.
replace useclass = 6 if usecode==.

* drop 2 MLs that have multiple zoning types listed, drop the types that aren't houses or condos.
drop if mlcount>1 & !inlist(usecode,101,102,104,105,199)

gen temp = 1

expand 2 if usecode==104
expand 3 if usecode==105
gen apt111=usecode==111
gen apt112=usecode==112
gen twofam=usecode==104
gen threefam=usecode==105
collapse (count) units=temp (mean) apt111 apt112 useclass (max) twofam threefam (sd) sd=useclass, by(year ml)
assert sd==0 | sd==.
drop sd
assert apt111==0 | apt111==1
assert apt112==0 | apt112==1

* make it a balanced panel
fillin ml year

replace useclass = 6 if _fillin==1
replace units = 1 if _fillin==1

sort ml
merge ml using `rc', nokeep
assert _merge==3
drop _merge

* for apartment buildings, use units current as of 2001.
replace apts_units = max(1,round(apts_units,1))
assert apts_units!=0
replace units = apts_units if apts_units!=0 & useclass==3

* for apartments with units outside of the range for that usecode, replace with average
* for example, if apt building has only one unit, but is a 111, we know it has 4-8 units, so fix that.
tab units if apt111==1
sum units if apt111==1 & units>3 & units<9
replace units=r(mean) if apt111==1 & (units<4 | units>8)

tab units if apt112==1
sum units if apt112==1 & units>7
replace units=r(mean) if apt112==1 & units<8

* these are time-varying, so drop them before we do the reshape since we dont need them anymore
drop apt111 apt112

summ
drop _fillin

label def uses 1 "house" 2 "condo" 3 "apt" 4 "oth_res" 5 "nonres" 6 "missing"
label val useclass uses

tab useclass


reshape wide useclass units twofam threefam, i(ml) j(year)
sort ml

foreach year in 1994 2004 {
	summ units`year' if useclass`year'==2 & rc==0 
	global nrcCONDOS`year' = r(sum)
	summ units`year' if useclass`year'==1 & rc==0 
	global nrcHOUSES`year' = r(sum)
	summ units`year' if useclass`year'==2 & rc==1 
	global rcCONDOS`year' = r(sum)
	summ units`year' if useclass`year'==1 & rc==1 
	global rcHOUSES`year' = r(sum)
}


local temp = round($rcCONDOS2004/($rcCONDOS1994),.001)
global rcCONDOSr = `temp'
di $rcCONDOSr
local temp = round($rcHOUSES2004/($rcHOUSES1994), .001)
global rcHOUSESr = `temp'
di $rcHOUSESr
local temp = round($nrcCONDOS2004/($nrcCONDOS1994),.001)
global nrcCONDOSr = `temp'
di $nrcCONDOSr
local temp = round($nrcHOUSES2004/($nrcHOUSES1994), .001)
global nrcHOUSESr = `temp'
di $nrcHOUSESr



local row = "row"
local col col

local all
local rc = "if rc==1"
local nrc = "if rc==0"

table useclass1994, c(sum units1994)
table useclass2004, c(sum units2004)

replace useclass1994=5 if useclass1994==6 // count missing as non-res for Table 6

* the houses and condos columns of these three tables form Table 6.

preserve

keep if useclass2004==1 | useclass2004==2

foreach mat in col {
	foreach r in all rc nrc {
		di "Transitions by `mat', `r' units"
		tab useclass1994 useclass2004 ``r'' [fw=units2004], ``mat''
	}
}

restore

