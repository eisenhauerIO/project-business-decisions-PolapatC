* THIS PROGRAM CREATES TABLE 3 IN AUTOR, PALMER, PATHAK (JPE, 2013)

clear
set mem 1g
set more off

**#######################***
** Assessed value regs using repeated unit-level cross-section
**#######################***

use ../dta/assess-panel, clear


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

gen rc_post = rc*post
local replace replace
foreach struct in pooled {
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

	reg lvalue rc rc_post  _yr* ``trend'' ``struct'', cluster(bg90)
	outreg2  rc rc_post using ../tab/table3.xml, `replace' excel  bdec(3) tdec(3) nocons  ///
		addtext(FE, none, Struct, `struct', Trend, `trend', Spec, "Assessor")   label nonotes	
	local replace

	foreach trend in None Tract {
	
		areg lvalue rc rc_post  _yr* ``trend'' ``struct'', cluster(bg90) a(bg90)
		outreg2  rc rc_post using ../tab/table3.xml, `replace' excel  bdec(3) tdec(3) nocons  ///
			addtext(FE, `e(absvar)', Struct, `struct', Trend, `trend', Spec, "Assessor")   label nonotes	

		if "`trend'"=="Tract" {
			areg lvalue rc_post  _yr* ``trend'' ``struct'', cluster(bg90) a(mlid)
			outreg2  rc_post using ../tab/table3.xml, `replace' excel  bdec(3) tdec(3) nocons  ///
				addtext(FE, `e(absvar)', Struct, `struct', Trend, `trend', Spec, "Assessor")   label nonotes	
		}
	}

}

log close

