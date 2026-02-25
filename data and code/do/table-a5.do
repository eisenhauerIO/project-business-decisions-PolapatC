* THIS PROGRAM CREATES TABLE A5 IN AUTOR, PALMER, PATHAK (JPE, 2013)

clear
set mem 4g
set more off

** ########################## **
** Restrict to overlap sample **
** ########################## **

use ../dta/assess-panel, clear
keep if inlist(1,house,condo)
keep ml year
duplicates drop
ren year year_sale
sort ml year_sale
tempfile assess_dummy
save `assess_dummy'

use ../dta/sales-data, clear

** ####################### **
** Select sample        ## **
** ####################### **

drop if rci_u20==.

tab sing_fam rc
tab twofam rc
tab threefam rc

* Drop firesale condos (11/89, 12/89). Relevant court ruling was Nov 21, 1989 (corresponds to Stata date 10916).  Sell-off limited to 11/21/89 - 12/31/89
ge selloff=rc*condo*(mydate<=10957 & mydate>10916)
tab selloff
drop if selloff

** ########################## **
** Winsorize real prices   ## **
** ########################## **

* deflate

cap gen cpi=.
replace cpi = 115.9   if year_sale==1988 
replace cpi = 121.6   if year_sale==1989
replace cpi = 128.2   if year_sale==1990
replace cpi = 133.5   if year_sale==1991
replace cpi = 137.3   if year_sale==1992
replace cpi = 141.4   if year_sale==1993
replace cpi = 144.8   if year_sale==1994
replace cpi = 148.6   if year_sale==1995
replace cpi = 152.8   if year_sale==1996
replace cpi = 155.9   if year_sale==1997
replace cpi = 157.2   if year_sale==1998
replace cpi = 160.2   if year_sale==1999
replace cpi = 165.7   if year_sale==2000
replace cpi = 169.7   if year_sale==2001
replace cpi = 170.8   if year_sale==2002
replace cpi = 174.6   if year_sale==2003
replace cpi = 179.3   if year_sale==2004
replace cpi = 186.1   if year_sale==2005
replace cpi = 191.9   if year_sale==2006
replace cpi = 196.639   if year_sale==2007
replace cpi = 205.453   if year_sale==2008
replace cpi = 203.301 if year_sale == 2009
cap gen price2008 = (price*(205.453/cpi))

replace lprice=log(price2008)

* winsorize

* from below
bys condo: egen winsor = pctile(price2008), p(1)
tab condo, sum(winsor)
gen price1=max(winsor, price2008) if price2008!=.
gen winsorizedobs=price1!=price2008
tab winsorizedobs
tab year_sale winsorizedobs
drop lprice
gen lprice=log(price1)


** ########################## **
** Flags for RC, post, etc ## **
** ########################## **
drop post
gen byte post = year_sale>= 1995
tab year_sale, summ(post)

** ########################## **
** Calculate other X's     ## **
** ########################## **
tab yearbuilt_missing
summ yearbuilt if yearbuilt_missing
gen agedk = yearbuilt_missing
gen age = 1+ year_sale-yearbuilt
summ age if sing_fam & rc
summ age if sing_fam & !rc
summ age if condo & rc
summ age if condo & !rc
summ age if condo | sing_fam

* find 2 transactions with age<1 (yearbuilt>year_sale) recode as average for that structure type
replace yearbuilt = use_yearbuilt_mean if age<1
replace yearbuilt_missing=1 if age<1
replace age = 1+ year_sale-yearbuilt if age<1

summ age
gen lnage = ln(age)
gen lnage2 = lnage^2
gen lotsize2=lotsize^2
gen nolot = lotsize==0
*****************
keep if inlist(year_sale,1994,2004)
sort ml year_sale 

compress

merge ml year_sale using `assess_dummy'
tab _merge
bys year_sale: tab _merge
bys _merge: tab state_use_cd
keep if _merge==3
drop _merge

keep if inlist(year_sale,1994,2004)

gen house = inlist(1,sing_fam,twofam,threefam)

xi i.year_sale, prefix(_yr)

local house = "twofam threefam if house==1"
local condo = "if condo==1"
local pooled = "twofam threefam condo if house==1|condo==1"

tabstat condo house, by(year_sale) s(sum)

	** ######################## **
	** Stripped down price regs **
	** ######################## **


xi i.tract90*post, prefix(trp)
local Tract = " trp* "
local None
	
local replace replace
foreach struct in house condo  {
	foreach trend in None  {

		cap drop rci rc_* rci_post nrc_*
		gen rci = rci_u20
		drop if rci==.
		replace rci=min(rci,1)
		gen rc_post = rc*post
		gen rci_post = rci*post
		gen nrc_rci = rci*(rc==0)
		gen rc_rci = rci*(rc==1)
		gen nrc_rci_post = nrc_rci*post
		gen rc_rci_post = rc_rci*post
	
		areg lprice rc rc_post  _yr* ``trend'' ``struct'', cluster(bg90) a(bg90)
		outreg2  rc rc_post using ../tab/table-a5.xml, `replace' excel  bdec(3) tdec(3) nocons  ///
			addtext(FE, `e(absvar)', Struct, `struct', Trend, `trend', Spec, "Simple Price Reg")   label nonotes	
		local replace
		areg lprice rc rc_post rci rci_post _yr* ``trend'' ``struct'' , cluster(bg90) a(bg90)
		outreg2  rc rc_post  rci_post using ../tab/table-a5.xml, excel  bdec(3) tdec(3) nocons  ///
			addtext(FE, `e(absvar)', Struct, `struct', Trend, `trend', Spec, "Simple Price Reg")   label nonotes	
						
		areg lprice rc rc_post nrc_rci nrc_rci_post rc_rci rc_rci_post _yr* ``trend'' ``struct'' , cluster(bg90) a(bg90)
		test nrc_rci_post = rc_rci_post
		local equal = r(p)
		test nrc_rci_post = rc_rci_post = 0
		local zero = r(p)		
		outreg2  rc rc_post  nrc_rci_post  rc_rci_post using ../tab/table-a5.xml, excel append bdec(3) tdec(3) nocons  ///
			addtext(FE, `e(absvar)', Struct, `struct', Trend, `trend', Spec, "Simple Price Reg")   label nonotes ///
			addstat(Equal, `equal', Equal & 0, `zero')
		
		
		local replace 
	}
}

duplicates drop ml year_sale, force
gen sale = 1
ren year_sale year
tempfile saleflag
sort ml year
save `saleflag'



**#######################***
** Assessed value regs using repeated unit-level cross-section
**#######################***

use ../dta/assesspanel-022712, clear
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

tabstat condo house, by(year) s(sum)

egen mlid = group(ml)

local replace 

xi i.tract90*post, prefix(trp)
local Tract = " trp* "
local None

gen rc_post = rc*post


**#############################**
** Maplots that are transacted **
**#############################**

sort ml year
merge ml year using `saleflag',
tab _merge
drop if _merge==2
replace sale=0 if sale==. & _merge==1
tab sale _merge
drop _merge

cap drop *year_sa*

drop if sale!=1

local house = "twofam threefam if house==1"
local condo = "if condo==1"
local pooled = "twofam threefam condo if house==1|condo==1"

foreach struct in house condo  {
	
	drop *rci *rci_post
	gen rci = rci_u20
	drop if rci==.
	replace rci=min(rci,1)
	sum rci ``struct''
	cap gen rc_post = rc*post
	gen rci_post = rci*post
	gen nrc_rci = rci*(rc==0)
	gen rc_rci = rci*(rc==1)
	gen nrc_rci_post = nrc_rci*post
	gen rc_rci_post = rc_rci*post
	
	
	foreach trend in None  {
		foreach fe in bg90  {


		areg lvalue rc rc_post  _yr* ``trend'' ``struct'', cluster(bg90) a(`fe')
		outreg2 rc rc_post using ../tab/table-a5.xml, excel  bdec(3) tdec(3) nocons ///
			addtext(FE, `e(absvar)', Struct, `struct', Trend, `trend', Spec, "Assess-sold this year")   label nonotes	
	
		areg lvalue rc rc_post rci rci_post _yr* ``trend'' ``struct'' , cluster(bg90) a(`fe')
		outreg2 rc  rc_post  rci_post using ../tab/table-a5.xml, excel  bdec(3) tdec(3) nocons ///
			addtext(FE, `e(absvar)', Struct, `struct', Trend, `trend', Spec, "Assess-sold this year")   label nonotes	
						
		areg lvalue rc rc_post nrc_rci nrc_rci_post rc_rci rc_rci_post _yr* ``trend'' ``struct'' , cluster(bg90) a(`fe')
		test nrc_rci_post = rc_rci_post
		local equal = r(p)
		test nrc_rci_post = rc_rci_post = 0
		local zero = r(p)	
		outreg2 rc rc_post  nrc_rci_post  rc_rci_post using ../tab/table-a5.xml, excel bdec(3) tdec(3) nocons ///
			addtext(FE, `e(absvar)', Struct, `struct', Trend, `trend', Spec, "Assess-sold this year")   label nonotes ///
			addstat(Equal, `equal', Equal & 0, `zero')
		}
	}
}


