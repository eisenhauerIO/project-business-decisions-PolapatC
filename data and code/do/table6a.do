* THIS PROGRAM CREATES top panel of TABLE 6 IN AUTOR, PALMER, PATHAK (JPE, 2013)

clear
set mem 1g
set more off


/*GET RCI*/

use ml rci_uBLK rci_u01 rci_u05 rci_u10 rci_u15 rci_uBG rci_u30 rci_u40 block90 using ../dta/structures-2001, clear
sort ml 
tempfile rcidata1
save `rcidata1'


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

egen mlid = group(ml)

local replace 

gen year2004 = (year==2004)

xi i.tract90*year2004, prefix(tr04)
drop tr04tract90*

local Tract = " tr0* "
local None

gen rc_post = rc*post

** ####################### **
** Cluster variable     ## **
** ####################### **

egen clusvar = group(bg90)

**#############################################################
**## 3diff by structure type, varying radius and FE together ##
**#############################################################

sort ml
merge ml using `rcidata1', uniqus nokeep
tab _merge
drop _merge

drop if mi(rci_u20) // want consistent N across estimation samples

local app = "replace"
foreach trend in "none" "Tract" {
	local fe "block90"
	foreach v in 10 20 "BG" 30 {
		if "`v'"=="20" {
			local app = "append"
			local fe "bg90"
			}
		else if "`v'"=="40" local fe "tract90"
		
		cap drop *rci
		gen rci=min(rci_u`v',1) if rci_u`v' !=.
		sum rci
		local rcimean=r(mean)
		local rcisd=r(sd)
		gen rc_rci = rci*rc
		gen p_rci = post*rci
		gen prc_rci = post*rci*rc
		gen nrc_rci = (1-rc)*rci
		gen p_nrc_rci = (1-rc)*rci*post
		summ *rci


		areg lvalue rc rc_post nrc_rci p_nrc_rci rc_rci prc_rci _yr* twofam threefam condo ``trend''  if house==1|condo==1, cluster(clusvar) a(ml)
		test p_nrc_rci = prc_rci
		local equal = r(p)
		test p_nrc_rci = prc_rci = 0
		local zero = r(p)
		outreg2 rc_post p_nrc_rci prc_rci   using ../tab/table6.xml, title(3diff by radius) excel `app' bdec(3) tdec(3) /// 
			addstat(Eq and Zero, `zero',Equal, `equal',RCImean,`rcimean',RCIsd,`rcisd') addtext(Group,All, Fixed Effects, `e(absvar)', Trend, `trend' ) nocons label nonotes ctitle(rci`v')
				
		}
	}
	
