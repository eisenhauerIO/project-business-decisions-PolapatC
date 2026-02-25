* THIS PROGRAM CREATES TABLE B1 IN AUTOR, PALMER, PATHAK (JPE, 2013)

clear
set mem 3g
set matsize 11000
set more off

* file with distance from every ML to centroid of every block
use ../dta/distance90block.dta
foreach var of varlist block3* {
	gen within2_`var'=`var'<.2
	gen decay_`var'=exp(-`var')
	}
keep ml within* decay*
tempfile within
save `within'

**#######################***
** Assessed value regs using repeated unit-level cross-section
**#######################***

use ../dta/assess-panel, clear
merge m:1 ml using ../dta/structures-2001, keepusing(rci_u20) keep(master match)
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

local house = "twofam threefam if house==1"
local condo = "if condo==1"
local pooled = "twofam threefam condo if house==1|condo==1"

local ifhouse = "if house==1"
local ifcondo = "if condo==1"
local ifpooled = "if house==1|condo==1"

tabstat condo house, by(year) s(sum)

egen mlid = group(ml)

local replace 

gen year2004 = (year==2004)

xi i.tract90*year2004, prefix(tr04)
drop tr04tract90*
local Tract = " tr0* "
local None


merge m:1 ml using `within'

gen rc_post = rc*post
local replace replace
foreach struct in pooled house condo {
	cap drop *rci *rci_post
	gen rci = rci_u20
	drop if rci==.
	replace rci=min(rci,1)
	sum rci  `if`struct''
	replace rci=rci-r(mean)
	gen rci_post = rci*post
	gen nrc_rci = rci*(rc==0)
	gen rc_rci = rci*(rc==1)
	gen nrc_rci_post = nrc_rci*post
	gen rc_rci_post = rc_rci*post
	local fevar bg90


* add 3diff
	local fevar bg90
	foreach trend in None Tract{
		areg lvalue rc rc_post nrc_rci nrc_rci_post rc_rci rc_rci_post _yr* ``trend'' ``struct'' , cluster(`fevar') a(`fevar')
		test nrc_rci_post = rc_rci_post
		local equal = r(p)
		test nrc_rci_post = rc_rci_post = 0
		local zero = r(p)	
		outreg2 rc rc_post nrc_rci_post rc_rci_post using ../tab/table-b1.xml, excel bdec(3) tdec(3) nocons  ///
			addtext(FE, `e(absvar)', Struct, `struct', Trend, `trend')   label nonotes ///
			addstat(Adj R2,`e(r2_a)')

		reg lvalue rc rc_post nrc_rci nrc_rci_post rc_rci rc_rci_post _yr* within* ``trend'' ``struct'' , cluster(`fevar')
		test nrc_rci_post = rc_rci_post
		local equal = r(p)
		test nrc_rci_post = rc_rci_post = 0
		local zero = r(p)	
		outreg2 rc rc_post nrc_rci_post rc_rci_post using ../tab/table-b1.xml, excel bdec(3) tdec(3) nocons  ///
			addtext(FE, rolling, Struct, `struct', Trend, `trend')   label nonotes ///
			addstat(Adj R2,`e(r2_a)')
			
		reg lvalue rc rc_post nrc_rci nrc_rci_post rc_rci rc_rci_post _yr* decay* ``trend'' ``struct'' , cluster(`fevar')
		test nrc_rci_post = rc_rci_post
		local equal = r(p)
		test nrc_rci_post = rc_rci_post = 0
		local zero = r(p)	
		outreg2 rc rc_post nrc_rci_post rc_rci_post using ../tab/table-b1.xml, excel bdec(3) tdec(3) nocons  ///
			addtext(FE, decay, Struct, `struct', Trend, `trend')   label nonotes ///
			addstat(Adj R2,`e(r2_a)')
	
		}
}

log close

