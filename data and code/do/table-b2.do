* THIS PROGRAM CREATES TABLE B2 IN AUTOR, PALMER, PATHAK (JPE, 2013)

clear
set mem 3g
set more off

/*CREATE CONVERT FLAGS*/

use ../dta/assess-panel
collapse usecode, by (ml year)
drop if year==2002
reshape wide usecode, i(ml) j(year)
gen convflag=0
replace convflag=1 if usecode1994!=usecode2004
keep ml convflag
sort ml
tempfile converts
save `converts'



**#######################***
** Assessed value regs using repeated unit-level cross-section
**#######################***

use ../dta/assess-panel, clear

keep if inlist(1,house,condo)
keep if inlist(year,1994,2004)
gen post = year>=1995


*DROP BORDER BG
drop if bg90==35212
drop if bg90==35221
drop if bg90==35271
drop if bg90==35272
drop if bg90==35273
drop if bg90==25292
drop if bg90==35371
drop if bg90==35365
drop if bg90==35363
drop if bg90==35362
drop if bg90==36361
drop if bg90==35451
drop if bg90==45471
drop if bg90==35472
drop if bg90==35504
drop if bg90==35503
drop if bg90==35502
drop if bg90==35501
drop if bg90==35494
drop if bg90==35464
drop if bg90==35431
drop if bg90==35434
drop if bg90==35433

/*35423 and 35211 border large empty areas/cemetaries, so are not dropped
river borders are not dropped*/

* This sections allows throwing out all MLs that did not have identical usecodes in 1994 and 2004
sort ml
merge ml using `converts', uniqus nokeep
tab _merge
drop _merge

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

gen rc_post = rc*post
local replace replace
foreach struct in /*pooled*/ house condo {
	cap drop *rci *rci_post
	gen rci = rci_u20
	drop if rci==.
	replace rci=min(rci,1)
	gen rci_post = rci*post
	gen nrc_rci = rci*(rc==0)
	gen rc_rci = rci*(rc==1)
	gen nrc_rci_post = nrc_rci*post
	gen rc_rci_post = rc_rci*post

	foreach trend in None Tract {
		
		areg lvalue rc rc_post rci rci_post _yr* ``trend'' ``struct'' , cluster(bg90) a(bg90)
		outreg2  rc_post rci_post using ../tab/table-b2.xml, excel `replace' bdec(3) tdec(3) nocons  ///
			addtext(FE, `e(absvar)', Struct, `struct', Trend, `trend', Spec, "Assessor")   label nonotes	
		local replace
		}

* add 3diff

	foreach trend in None Tract {
		areg lvalue rc rc_post nrc_rci nrc_rci_post rc_rci rc_rci_post _yr* ``trend'' ``struct'' , cluster(bg90) a(bg90)
		test nrc_rci_post = rc_rci_post
		local equal = r(p)
		test nrc_rci_post = rc_rci_post = 0
		local zero = r(p)	
		outreg2  rc_post nrc_rci_post rc_rci_post using ../tab/table-b2.xml, excel bdec(3) tdec(3) nocons  ///
			addtext(FE, `e(absvar)', Struct, `struct', Trend, `trend', Spec, "Assessor")   label nonotes ///
			addstat(Equal, `equal', Equal & 0, `zero')
	}
		
	* No converts 23diff
	cap drop *rci *rci_post
	gen rci = rci_u20
	drop if rci==.
	replace rci=min(rci,1)
	gen rci_post = rci*post
	gen nrc_rci = rci*(rc==0)
	gen rc_rci = rci*(rc==1)
	gen nrc_rci_post = nrc_rci*post
	gen rc_rci_post = rc_rci*post
	
	areg lvalue rc rc_post rci rci_post _yr* ``struct'' & convflag!=1, cluster(bg90) a(bg90)
	outreg2  rc_post rci_post using ../tab/table-b2.xml, excel `replace' bdec(3) tdec(3) nocons  ///
		addtext(FE, `e(absvar)', Struct, `struct', Exclude Converts, y, Spec, "Assessor")   label nonotes	
	
	areg lvalue rc rc_post nrc_rci nrc_rci_post rc_rci rc_rci_post _yr* ``struct'' & convflag!=1, cluster(bg90) a(bg90)
	test nrc_rci_post = rc_rci_post
	local equal = r(p)
	test nrc_rci_post = rc_rci_post = 0
	local zero = r(p)	
	outreg2  rc_post nrc_rci_post rc_rci_post using ../tab/table-b2.xml, excel bdec(3) tdec(3) nocons  ///
		addtext(FE, `e(absvar)', Struct, `struct', Exclude Converts, y, Spec, "Assessor")   label nonotes ///
		addstat(Equal, `equal', Equal & 0, `zero')
}

