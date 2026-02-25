* THIS PROGRAM CREATES TABLE 5 IN AUTOR, PALMER, PATHAK (JPE, 2013)

clear
set mem 1g
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
merge m:1 ml using ../dta/structures-2001, keepusing(rci_u* cdd_neigh) keep(master match)
assert _merge!=1
drop _merge

keep if inlist(1,house,condo)
keep if inlist(year,1994,2004)
gen post = year>=1995

* This allows throwing out all MLs that did not have identical usecodes in 1994 and 2004
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

* drop if cdd_neigh==0
xi i.cdd_neigh*year2004, prefix(ne04)
drop ne04cdd_ne*

local Tract = " tr0* "
local None
local Neigh = " ne0* "

xi i.bg90*year2004, prefix(bg04)
drop bg04bg90*
local Bg = " bg0*"


gen rc_post = rc*post
local replace replace
foreach struct in /*pooled*/ house condo {
	cap drop *rci *rci_post
	gen rci = rci_u20
	drop if rci==.
	replace rci=min(rci,1)
	sum rci  `if`struct''
	gen rci_post = rci*post
	gen nrc_rci = rci*(rc==0)
	gen rc_rci = rci*(rc==1)
	gen nrc_rci_post = nrc_rci*post
	gen rc_rci_post = rc_rci*post
	foreach fevar of varlist /*tract90*/ bg90 /*mlid*/ {
		foreach trend in None Tract /*Bg*/ {
			qui areg rci_post ``trend'' ``struct'', a(`fevar')
			cap drop rci_residual
			predict rci_residual, resid
			qui sum rci_residual
			local residvar=r(Var)
			areg lvalue rc rc_post rci rci_post _yr* ``trend'' ``struct'' , cluster(bg90) a(`fevar')
			outreg2 rc rc_post rci_post using ../tab/table5.xml, excel `replace' bdec(3) tdec(3) ///
				nocons addtext(FE, `e(absvar)', Struct, `struct', Trend, `trend',  RCIxPost Residual Var,`residvar')   label nonotes	
			local replace
			}
	}

	areg rci_post `Tract' ``struct'', a(mlid)
	cap drop rci_residual
	predict rci_residual, r
	sum rci_residual
	local residvar=r(Var)
	areg lvalue rc_post rci_post _yr* `Tract' ``struct'' , cluster(bg90) a(mlid)
	outreg2 rc rc_post rci_post using ../tab/table5.xml, excel  bdec(3) tdec(3) nocons  ///
		addtext(FE, `e(absvar)', Struct, `struct', Trend, Tract,  RCIxPost Residual Var,`residvar')   label nonotes	

* add 3diff
	foreach fevar of varlist /*tract90*/ bg90 {
		foreach trend in None Tract /*Bg*/ {
			qui areg nrc_rci_post ``trend'' ``struct'', a(`fevar')
			cap drop rci_residual
			predict rci_residual, r
			sum rci_residual
			local residvar=r(Var)
			areg lvalue rc rc_post nrc_rci nrc_rci_post rc_rci rc_rci_post _yr* ``trend'' ``struct'' , cluster(`fevar') a(`fevar')
			test nrc_rci_post = rc_rci_post
			local equal = r(p)
			test nrc_rci_post = rc_rci_post = 0
			local zero = r(p)	
			outreg2 rc rc_post nrc_rci_post rc_rci_post using ../tab/table5.xml, excel bdec(3) tdec(3) nocons  ///
				addtext(FE, `e(absvar)', Struct, `struct', Trend, `trend',  RCIxPost Residual Var,`residvar')   label nonotes ///
				addstat(Equal, `equal', Equal & 0, `zero')

			}
		}


	qui areg nrc_rci_post `Tract' ``struct'', a(mlid)
	cap drop rci_residual
	predict rci_residual, r
	sum rci_residual
	local residvar=r(Var)
	di `residvar'
	areg lvalue rc rc_post nrc_rci nrc_rci_post rc_rci rc_rci_post _yr* `Tract' ``struct'' , cluster(bg90) a(mlid)
	test nrc_rci_post = rc_rci_post
	local equal = r(p)
	test nrc_rci_post = rc_rci_post = 0
	local zero = r(p)	
	outreg2 rc rc_post nrc_rci_post rc_rci_post using ../tab/table5.xml, excel bdec(3) tdec(3) nocons  ///
		addtext(FE, `e(absvar)', Struct, `struct', Trend, Tract,  RCIxPost Residual Var,`residvar',Equal,`equal')   label nonotes

	* No converts 23diff
	cap drop *rci *rci_post
	gen rci = rci_u20
	drop if rci==.
	replace rci=min(rci,1)
	sum rci  `if`struct'' & convflag!=1
	gen rci_post = rci*post
	gen nrc_rci = rci*(rc==0)
	gen rc_rci = rci*(rc==1)
	gen nrc_rci_post = nrc_rci*post
	gen rc_rci_post = rc_rci*post
	
	foreach trend in None Tract /*Bg*/ {
	
		areg lvalue rc rc_post rci rci_post _yr* ``trend'' ``struct'' & convflag!=1, cluster(bg90) a(bg90)
		outreg2 rc rc_post rci_post using ../tab/table5.xml, excel `replace' bdec(3) tdec(3) nocons  ///
			addtext(FE, `e(absvar)', Struct, `struct', Exclude Converts, y,Trend,`trend')   label nonotes	
		
		areg lvalue rc rc_post nrc_rci nrc_rci_post rc_rci rc_rci_post _yr* ``trend''  ``struct'' & convflag!=1, cluster(bg90) a(bg90)
		test nrc_rci_post = rc_rci_post
		local equal = r(p)
		test nrc_rci_post = rc_rci_post = 0
		local zero = r(p)	
		outreg2 rc rc_post nrc_rci_post rc_rci_post using ../tab/table5.xml, excel bdec(3) tdec(3) nocons  ///
			addtext(FE, `e(absvar)', Struct, `struct', Exclude Converts, y,Trend,`trend')   label nonotes ///
			addstat(Equal, `equal', Equal & 0, `zero')
		if "`trend'"=="Tract" { // run with ML FE
			areg lvalue rc rc_post rci rci_post _yr* ``trend'' ``struct'' & convflag!=1, cluster(bg90) a(mlid)
			outreg2 rc rc_post rci_post using ../tab/table5.xml, excel `replace' bdec(3) tdec(3) nocons  ///
			addtext(FE, `e(absvar)', Struct, `struct', Exclude Converts, y,Trend,`trend')   label nonotes	
		
		
		
			areg lvalue rc rc_post nrc_rci nrc_rci_post rc_rci rc_rci_post _yr* ``trend''  ``struct'' & convflag!=1, cluster(bg90) a(mlid)
			test nrc_rci_post = rc_rci_post
			local equal = r(p)
			test nrc_rci_post = rc_rci_post = 0
			local zero = r(p)	
			outreg2 rc rc_post nrc_rci_post rc_rci_post using ../tab/table5.xml, excel bdec(3) tdec(3) nocons  ///
				addtext(FE, `e(absvar)', Struct, `struct', Exclude Converts, y,Trend,`trend')   label nonotes ///
				addstat(Equal, `equal', Equal & 0, `zero')
			}
		}

}
