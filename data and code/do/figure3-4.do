* THIS PROGRAM CREATES FIG 2 IN AUTOR, PALMER, PATHAK (JPE, 2013)
* This program creates event study plots for the effect of rent control on resident tenure.

clear
set mem 100m
set matsize 2000
set more 1
pause off

local 1 "quad"
local main_rad 20
local fe "bg90"

* create relevant sample
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
}

local exis = "totrooms bathrooms bedrooms sqft nolot lotsize lotsize2 agedk lnage lnage2"
local struct_type = "condo twofam threefam lsc qsc ls2 qs2 ls3 qs3" // structure type trends
local interacted_exis = "`exis' condo_* twofam_* threefam_*" 

** ##################################################### **
** Part II: RC Intensity Specs
** ##################################################### **
local mainrci= "rci"
		
capture drop rci rc_rci p_rci* prc_rci*
gen rci=min(rci_u`main_rad',1)
sum rci
gen p_rci = post*rci

summ rci p_rci

* Event study specifications

foreach v of varlist rc rci  {
   forvalues y = 1988/2005 {
      if `y'!=1994 gen `v'yr_`y' = `v'*(year_sale==`y')
   }
}   

local rc_control "rc rcyr*"
local rcivars "rci rciyr_*"


** #############################
** 1diff
** #############################

local app = "replace"

drop year1988

local 1diff = ""
local 2diff = "`rcivars'"

gen nrc = !rc

gen both = 1

sum `struct_type'
sum `interacted_exis'


graph drop _all

* 1diff

local struct pooled
local rent both
local diff 1diff
local rc_control "rc rcyr*"
areg lprice `rc_control' ``diff''  `struct_type' `interacted_exis'  year19* year20* if ``struct'' & `rent'==1, cluster(clusvar) a(bg90)
preserve
parmest, fast
gen year=regexs(1) if regexm(parm, "^rcyr_([0-9]+)$")
destring year, replace
drop if mi(year)
local Nplus1=_N+1
set obs `Nplus1'
replace year=1994 in l
replace estimate=0 in l
* extend CI lines
set obs 20
replace year = 1993.5 in 19
replace year = 1994.5 in 20
sort year
replace min=min[6]-(.5*(est[6])) if year==1993.5
replace max=max[6]-(.5*(est[6])) if year==1993.5
replace min=min[10]-(.5*(est[10])) if year==1994.5
replace max=max[10]-(.5*(est[10])) if year==1994.5

twoway  (connected estimate year, msize(small)) (rline min max year, cmissing(n) lp(dash)) , ///
				scheme(s2color) legend(r(1) label(2 "95% Confidence Interval") label(1 "Point Estimate")) name(pooled_1diff) ///
				xlab(1989(3)2004) ylab(-.4(.1).4, labs(medsmall)) ytick(-.4(.1).4, grid gmin gmax)  xline(1994) title(I. Rent Control Main Effect) xtitle("")
restore

* 2diff
local diff 2diff
foreach rent in nrc rc {
	areg lprice `rc_control' ``diff'' `struct_type' `interacted_exis'  year19* year20* if ``struct'' & `rent'==1, cluster(clusvar) a(bg90)
	preserve
	parmest, fast
	gen year=regexs(1) if regexm(parm, "^rciyr_([0-9]+)$")
	destring year, replace
	drop if mi(year)
	local Nplus1=_N+1
	set obs `Nplus1'
	replace year=1994 in l
	replace estimate=0 in l
	* extend CI lines
	set obs 20
	replace year = 1993.5 in 19
	replace year = 1994.5 in 20
	sort year
	replace min=min[6]-(.5*(est[6])) if year==1993.5
	replace max=max[6]-(.5*(est[6])) if year==1993.5
	replace min=min[10]-(.5*(est[10])) if year==1994.5
	replace max=max[10]-(.5*(est[10])) if year==1994.5

	twoway  (connected estimate year, msize(small)) (rline min max year, cmissing(n) lp(dash)) , ///
		scheme(s2color) legend(r(1) label(2 "95% Confidence Interval") label(1 "Point Estimate")) name(`struct'_`rent'_`diff') ///
		xlab(1989(3)2004) ylab(-.6(.3)1.5, labs(medsmall) grid gmin gmax) ytick(-.6(.3)1.5)  xline(1994) title(II. Indirect Effect: `rent' Properties) xtitle("")
	restore
	}


* end of do file