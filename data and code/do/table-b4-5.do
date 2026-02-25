* THIS PROGRAM CREATES TABLES B4-5 IN AUTOR, PALMER, PATHAK (JPE, 2013)

clear
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



** #############################
** 2diff - pooled
** #############################

local mainrci= "rci"
		
replace sqft=sqft/1000
replace lotsize = lotsize/100

local app = "replace"

xi i.bg90

gen rc_post = rc*(year_sale>=1995)

local replace replace
foreach condostatus of numlist 0 1 {

	capture drop rci rc_rci* p_rci* prc_rci* nrc_rci* rci_post
	gen rci=min(rci_u`main_rad',1)
	sum rci if condo==`condostatus'
	gen rc_rci = rci*rc
	gen p_rci = post*rci
	gen prc_rci = post*rci*rc
	summ rci p_rci* prc_rci*

	gen rci_post = rci*(year_sale>=1995)
	gen nrc_rci = rci*(rc==0)
	gen nrc_rci_post = nrc_rci*(year_sale>=1995)
	gen rc_rci_post = rc_rci*(year_sale>=1995)



	if `condostatus'==1 {
		local iscondo="condo"
		local rhs_exis "totrooms bathrooms bedrooms sqft nolot lnage"
		local struct_type
	}
	else {
		local iscondo="houses"
		local rhs_exis "totrooms bathrooms bedrooms sqft lotsize lnage"
		local struct_type = "twofam threefam"
	}

		sureg (`rhs_exis'=agedk `struct_type' rc rc_post rci rci_post year1* year2* _I*) ///
			if condo==`condostatus'

		* tests across equations			
		foreach var in rc rci {
			test `var'_post 
			local `var'_chi2=r(chi2)
			local `var'_chi2p=r(p)
		}
	
		outreg2 rc_post rci_post using ../tab/tables4-5.xml, excel bdec(2) tdec(2) `replace' ///
			addtext(RC Wald, `rc_chi2', RC p, `rc_chi2p', RCI Wald, `rci_chi2', RCI p, `rci_chi2p')

		sureg (`rhs_exis'=agedk `struct_type' rc rc_post nrc_rci nrc_rci_post rc_rci rc_rci_post year1* year2* _I*) ///
			if condo==`condostatus'
		
		* test across equations				
		foreach var in rc rc_rci nrc_rci {
			test `var'_post
			local `var'_chi2=r(chi2)
			local `var'_chi2p=r(p)
		}
		
		* test within equations
		mat stats = J(2,6,0)
		local j = 1
		foreach eq in `rhs_exis' {
			test [`eq']rc_rci_post = [`eq']nrc_rci_post
			mat stats[2,`j'] = r(p)
			test [`eq']rc_rci_post = [`eq']nrc_rci_post = 0
			mat stats[1,`j'] = r(p)
			local j = `j' + 1
		}	
		di "Condo is `iscondo'"
		mat li stats
		
		outreg2 rc_post nrc_rci_post rc_rci_post using ../tab/tables4-5.xml, excel bdec(2) tdec(2)  ///
			addtext(RC Wald, `rc_chi2', RC p, `rc_chi2p', RC_RCI Wald, `rc_rci_chi2', RC_RCI p, `rc_rci_chi2p', NRC_RCI Wald, `nrc_rci_chi2', NRC_RCI p, `nrc_rci_chi2p')
	

}

* end of do file