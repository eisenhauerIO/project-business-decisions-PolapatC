* THIS PROGRAM CREATES bottom panel of TABLE 6 IN AUTOR, PALMER, PATHAK (JPE, 2013)

clear
set mem 1g
set matsize 11000
set more off


**#######################***
** Calculate exponential decay RCI as described in text
**#######################***


set more off
clear
set maxvar 30000

use ../dta/structures-2001, clear
keep if residential==1 | ml=="136-30" | ml=="156-52"
//encode ml, generate crosswalk
sort ml, stable
encode ml, generate(mlcode)
keep rc numunits ml map lot x y mlcode
preserve
keep ml mlcode
tempfile mlcrosswalk
save `mlcrosswalk'
restore

qui levelsof mlcode, local(mllist)
gen double reflat=.
gen double reflong=.
gen refrc=.
foreach m of local mllist {
	qui replace reflat=y[`m']
	qui replace reflong=x[`m']
	qui replace refrc=rc[`m']
	sphdist, lat1(y) lon1(x) lat2(reflat) lon2(reflong) gen(ml`m') units(mi) 
}
drop reflat reflong refrc

//assertation test & replace diagonal
generate refrc=.
forvalues j=1/10950 {
	local refml=mlcode[`j']
	qui replace refrc=rc[`j']
	assert ml`refml'==0 if _n==`j'
	qui replace ml`refml'=. if _n==`j'
}
drop refrc

preserve

forvalues lambda=1/13 {
	//numerator
	restore, preserve
	drop x y ml mlcode
	foreach var of varlist ml* {
		qui replace `var'=rc*numunits*exp(-`lambda'*`var')
	}
	collapse (sum) ml*,fast
	xpose, clear format varname
	rename _varname mlcode
	rename v1 numerator

	**regenerate mlcode**
	replace mlcode=substr(mlcode,3,.)
	destring mlcode, replace

	tempfile RCnum
	save `RCnum'

	//denominator
	restore, preserve
	drop x y ml mlcode //numunits rc
	foreach var of varlist ml* {
		qui replace `var'=numunits*exp(-`lambda'*`var')
	}
	collapse (sum) ml*,fast
	xpose, clear format varname
	rename _varname mlcode
	rename v1 denominator

	**regenerate mlcode**
	replace mlcode=substr(mlcode,3,.)
	destring mlcode, replace

	//merge and divide and clear
	**merge**
	merge 1:1 mlcode using `RCnum'
	assert _merge==3
	drop _merge
	**new RCI generated**
	generate rci_exp=numerator/denominator
	drop numerator denominator

	//merge with original structure file to get all other indicators
	merge 1:1 mlcode using `mlcrosswalk'
	assert _merge==3
	drop _merge
	order ml mlcode rci_exp

	save ../dta/RCIexp-decay-`lambda', replace
}


**#######################***
** Assessed value regs using repeated unit-level cross-section
**#######################***

use ../dta/assess-panel, clear
merge m:1 ml using ../dta/structures-2001, keepusing(rci_u* cdd_neigh) keep(master match)
assert _merge!=1
drop _merge

keep if inlist(1,house,condo)
keep if inlist(year,1994,2004)
gen post = year>=1995


tab year

tabstat value, by(year) s(mean min max)

gen lvalue = ln(value)


xi i.year, prefix(_yr)
gen twofam=usecode==104
gen threefam=usecode==105

local pooled = "twofam threefam condo if house==1|condo==1"

local ifpooled = "if house==1|condo==1"

tabstat condo house, by(year) s(sum)

egen mlid = group(ml)

local replace 

gen year2004 = (year==2004)

xi i.tract90*year2004, prefix(tr04)
drop tr04tract90*


local Tract = " tr0* "
local None

xi i.bg90*year2004, prefix(bg04)
drop bg04bg90*
local Bg = " bg0*"

gen rc_post = rc*post
forvalues lambda=1/13 {
	merge m:1 ml using ../dta/RCIexp-decay-`lambda'.dta, keep(master match)
	ren rci_exp rci_exp`lambda'
	drop _merge
	local replace replace
	foreach struct in pooled house condo {
		cap drop *rci *rci_post *rci_decay*
		gen rci = rci_u20
		drop if rci==.
		replace rci=min(rci,1)
		gen rci_decay=rci_exp`lambda'
		gen rci_post = rci*post
		gen rci_decay_post = rci_decay*post
		gen nrc_rci = rci*(rc==0)
		gen nrc_rci_decay = rci_decay*(rc==0)
		gen rc_rci = rci*(rc==1)
		gen rc_rci_decay = rci_decay*(rc==1)
		gen nrc_rci_post = nrc_rci*post
		gen nrc_rci_decay_post = nrc_rci_decay*post
		gen rc_rci_post = rc_rci*post
		gen rc_rci_decay_post = rc_rci_decay*post
		sum rci_decay
		local rcimean=r(mean)
		local rcisd=r(sd)
		local fevar mlid
		foreach trend in Tract {

			* add 3diff
			areg lvalue rc rc_post nrc_rci nrc_rci_post rc_rci rc_rci_post _yr* ``trend'' ``struct'' , cluster(bg90) a(`fevar')
			test nrc_rci_post = rc_rci_post
			local equal = r(p)
			test nrc_rci_post = rc_rci_post = 0
			local zero = r(p)	
			outreg2 rc rc_post nrc_rci nrc_rci_post rc_rci rc_rci_post using ../tab/table6b-`lambda', excel bdec(3) tdec(3) nocons  ///
				addstat(RCImean,`rcimean',RCIsd,`rcisd') addtext(FE, `e(absvar)', Struct, `struct', Trend, `trend',Spillovers Equal, `equal')   label nonotes

			areg lvalue rc rc_post nrc_rci_decay nrc_rci_decay_post rc_rci_decay rc_rci_decay_post _yr* ``trend'' ``struct'' , cluster(bg90) a(`fevar')
			test nrc_rci_decay_post = rc_rci_decay_post
			local equal = r(p)
			test nrc_rci_decay_post = rc_rci_decay_post = 0
			local zero = r(p)	
			outreg2 rc rc_post nrc_rci_decay nrc_rci_decay_post rc_rci_decay rc_rci_decay_post using ../tab/table6b-`lambda', excel bdec(3) tdec(3) nocons  ///
				addstat(RCImean,`rcimean',RCIsd,`rcisd') addtext(FE, `e(absvar)', Struct, `struct', Trend, `trend',Lambda,`lambda',Spillovers Equal, `equal')   label nonotes
		
			}
	}
}
log close

