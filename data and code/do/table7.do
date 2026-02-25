* THIS PROGRAM CREATES TABLE 7 IN AUTOR, PALMER, PATHAK (JPE, 2013)

clear
cap set mem 100m
set matsize 2000
set more 1
pause on

local 1 "quad"
local main_rad 20
local fe "bg90"

use ../dta/sales-data, clear

** ####################### **
** Select sample        ## **
** ####################### **

drop if rci_u20==.

tab sing_fam rc
tab twofam rc
tab threefam rc

* Drop firesale condos (11/89, 12/89)
* Court ruling was Nov 21, 1989 (corresponds to Stata date 10916).  Sell-off limited to 11/21/89 - 12/31/89
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
summ lotsize* nolot
summ lotsize if nolot
summ lnage lnage2 lotsize* nolot
local exis = "totr bath bed sqft nolot lotsize lotsize2 agedk lnage lnage2"
foreach struct in "condo" "twofam" "threefam" {
	foreach x in `exis' {
		ge `struct'_`x'=`struct'*`x'
	}

	ge post_`struct'=post*`struct'
}

local interacted_exis = "`exis' condo_* twofam_* threefam_*" 
local struct_type = "condo twofam threefam"

** ####################### **
** Cluster variable     ## **
** ####################### **

egen clusvar = group(bg90)

** ####################### **
** Time trends          ## **
** ####################### **
	
if "`1'"=="quad" {
	* linear trends
	gen t = int((year_sale-1987))
	xi i.tract90*t, prefix(lin)
	drop lintract90*
	local linear = "lin*"

	* quadratic trends
	gen t2 = t^2
	xi i.tract90*t2, prefix(quad)
	drop quadtract90*
	local trendvars = "lin* quad*"
	
	}

** ####################### **
** Data summary         ## **
** ####################### **

tab year_sale, summ(rc)
tab year_sale rc, summ(lprice)


** #############################
** 1diff
** #############################

local app = "replace"

* no geo no trends
reg lprice `rc_control' `struct_type' year19* year20*, cluster(clusvar)
gen sample = e(sample)
outreg2 `rc_control' using "../tab/table7", excel replace bdec(3) tdec(3) title(1diff) ///
	addtext(Fixed Effects, -,Other X's,-, Quadratic tract trends,-) nocons label nonotes ctitle(rci`main_rad')

areg lprice `rc_control' `struct_type' `interacted_exis' year19* year20*, cluster(clusvar) a(`fe')
outreg2 `rc_control' using "../tab/table7", excel append bdec(3) tdec(3) ///
	addtext(Other X's,x,Fixed Effects, x, Quadratic tract trends,-) nocons label nonotes ctitle(rci`main_rad')

areg lprice `rc_control' `struct_type' `interacted_exis' `trendvars' year19* year20*, cluster(clusvar) a(`fe')
outreg2 `rc_control' using "../tab/table7", excel append bdec(3) tdec(3) ///
	addtext(Other X's,x,Fixed Effects, x, Quadratic tract trends,x) nocons label nonotes ctitle(rci`main_rad')


** #############################
** 2diff - pooled
** #############################

local mainrci= "rci"
		
capture drop rci rc_rci p_rci* prc_rci*
gen rci=min(rci_u`main_rad',1) if rci_u`main_rad'!=.
sum rci
gen rc_rci = rci*rc
gen p_rci = post*rci
gen prc_rci = post*rci*rc
gen nrc_rci=rci*(1-rc)
gen p_nrc_rci=rci*(1-rc)*post

gen cond_rci = rci*condo
gen cond_rc_rci = rc_rci*condo
gen cond_p_rci = p_rci*condo
gen cond_prc_rci = prc_rci*condo
gen cond_nrc_rci = nrc_rci*condo
gen cond_p_nrc_rci = p_nrc_rci*condo


summ rci p_rci* prc_rci*



local rcivars "rci p_rci"
local condo_rcivars "cond_rci cond_p_rci"


local rc_rcivars "nrc_rci p_nrc_rci rc_rci prc_rci"
local condo_rc_rcivars "cond_nrc_rci cond_p_nrc_rci cond_rc_rci cond_prc_rci"

areg lprice `rc_control' `rcivars' `struct_type' `interacted_exis' year19* year20*, cluster(clusvar) a(`fe')
outreg2 `rc_control' `rcivars' using "../tab/table7", excel append bdec(3) tdec(3) ///
	addtext(Other X's,x,Fixed Effects, x, Quadratic tract trends,-) nocons label nonotes ctitle(rci`main_rad')

areg lprice `rc_control' `rcivars' `struct_type' `interacted_exis' `trendvars' year19* year20*, cluster(clusvar) a(`fe')
outreg2 `rc_control' `rcivars' using "../tab/table7", excel append bdec(3) tdec(3) ///
	addtext(Other X's,x,Fixed Effects, x, Quadratic tract trends,x) nocons label nonotes ctitle(rci`main_rad')




** #############################
** 3diff - pooled
** #############################


areg lprice `rc_control' `rc_rcivars' `struct_type' `interacted_exis' year19* year20*, cluster(clusvar) a(`fe')
test p_nrc_rci = prc_rci
local equal = r(p)
test p_nrc_rci = prc_rci = 0
local zero = r(p)
outreg2 `rc_control' `rc_rcivars' using "../tab/table7", excel append bdec(3) tdec(3) ///
	addstat(No spillovers, `zero',Equal,`equal') addtext(Other X's,x, Fixed Effects, x, Quadratic tract trends,-) nocons label nonotes ctitle(rci`main_rad')
	
areg lprice `rc_control' `rc_rcivars' `struct_type' `interacted_exis' `trendvars' year19* year20*, cluster(clusvar) a(`fe')
test p_nrc_rci = prc_rci
local equal = r(p)
test p_nrc_rci = prc_rci = 0
local zero = r(p)
outreg2 `rc_control' `rc_rcivars' using "../tab/table7", excel append bdec(3) tdec(3) ///
	addstat(No spillovers, `zero',Equal,`equal') addtext(Other X's,x, Fixed Effects, x, Quadratic tract trends,x) nocons label nonotes ctitle(rci`main_rad')

