* THIS PROGRAM CREATES TABLE A6 IN AUTOR, PALMER, PATHAK (JPE, 2013)

clear
set more off
cap set mem 2g


**********************
** Begin price regs **
**********************

local main_rad 20
local fe "bg90"

use ../dta/placebo-data-cleaned, clear
keep if inlist(city,"Somerville")

* a few cleaning things I noticed and fixed.
drop if totrooms==99
replace price=349000 if price==3490000 // an outlier that I verified on Zillow had a zero added
drop if regexm(address,"Innerbelt") // Somerville industrial complex. not residential
drop if price>=3e6 // drop two other outliers that I hand checked and have definitely not been ever sold for more than $3 mil

tab city
tab year_sale
keep if inrange(year_sale,1988,2005)

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
bys condo city: egen winsor = pctile(price2008), p(1)
tab condo city, sum(winsor)
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
summ age if condo | sing_fam

* find 2 transactions with age<1 (yearbuilt>year_sale) recode as average for that structure type
replace yearbuilt = use_yearbuilt_mean if age<1
replace yearbuilt_missing=1 if age<1
replace age = 1+ year_sale-yearbuilt if age<1

cap replace bathroom = bathfull + bathhalf if bathroom==.

summ age
gen lnage = ln(age)
gen lnage2 = lnage^2
gen lotsize2=lotsize^2
gen nolot = lotsize==0
summ lotsize* nolot
summ lotsize if nolot
summ lnage lnage2 lotsize* nolot
local exis = "totr bathr bed sqft nolot lotsize lotsize2 agedk lnage lnage2"
local altexis = "totr bathr bed "
foreach struct in "condo" "twofam" "threefam" {
	foreach x in `exis' {
		ge `struct'_`x'=`struct'*`x'
	}

	ge post_`struct'=post*`struct'
}

local interacted_exis = "`exis' condo_* twofam_* threefam_*" 

local struct_type = "condo twofam threefam"


* pause
** ####################### **
** Cluster variable     ## **
** ####################### **

egen clusvar = group(bg90)

local interacted_exis "`interacted_struct_type' `interacted_exis'"
sum `struct_type'
sum `interacted_exis'



** ######################### **
** 123 diff all struct types **
** ######################### **

qui summ year_sale
local fyr = r(min)
local lyr = r(max)




xi i.year_sale, prefix(_yr)

local replace replace

cap drop rci_y*
cap drop rci 
cap drop post
cap drop *_rci
cap drop *_post	
gen rci = rci_uBG_hat
gen post = year_sale>=1995
gen rci_post = rci*post



** ################### **
** By structure, trend **
** ################### **

drop _merge
merge m:1 tract90 using ../dta/Somerville-Border-Tracts, gen(_mergeTR)
keep if _mergeTR==3
merge m:1 bg90 using ../dta/Somerville-Border-BGs, gen(_mergeBL)
assert _mergeBL==3
* restrict to border tracts
keep if Cambridge_Border_Tract + Medford_Border_Tract == 1

gen Cambridge_Tract_Post = Cambridge_Border_Tract*post
gen Cambridge_BG_Post = Cambridge_Border_BG*post

local pooled = "condo twofam threefam if inlist(1,sing_fam,twofam,threefam,condo)"
local house = "twofam threefam if inlist(1,sing_fam,twofam,threefam)"
local condo = "if condo==1"
local Quad = "`trendvars'"
local None
di "`cities'"
di "`cities_y'"

di "`interacted_altexis'"

local fe = "tract90"

local replace replace
foreach struct in pooled house condo  {
	foreach trend in None Quad {
		areg lprice  Cambridge_Tract_Post `interacted_exis' _yr* ``trend'' ``struct'' & city=="Somerville", cluster(clusvar) a(`fe')
		outreg2 Cambridge_Tract_Post using "../tab/table-a6.xml", title(Border Analysis) excel bdec(3) tdec(3) ///
			addtext(Other X's,Full, Fixed Effects, `fe', Structure, `struct', Trend, `trend') nocons label nonotes ctitle(Somerville) `replace'
		local replace append
	}
}

* restrict to border BGs
keep if Cambridge_Border_BG + Medford_Border_BG == 1

foreach struct in pooled house condo  {
	foreach trend in None Quad {
		areg lprice  Cambridge_BG_Post `interacted_exis' _yr* ``trend'' ``struct'' & city=="Somerville", cluster(clusvar) a(`fe')
		outreg2 Cambridge_BG_Post using "../tab/table-a6.xml", title(Border Analysis) excel bdec(3) tdec(3) ///
			addtext(Other X's,Full, Fixed Effects, `fe', Structure, `struct', Trend, `trend') nocons label nonotes ctitle(Somerville) `replace'
	}
}

log close

