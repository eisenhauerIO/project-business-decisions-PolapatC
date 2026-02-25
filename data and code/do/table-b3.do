* THIS PROGRAM CREATES TABLE B3 IN AUTOR, PALMER, PATHAK (JPE, 2013)


clear
set more off

use ../dta/census-bg-data

reg   rci_uBG   DENSITY   FAM_MED_INC  PUBLICTRANS_P  TENURE_OWN   TENURE_RENT   OLDBUILD_OWN OLDBUILD_RENT  CONDO_PER RENTER_PER ROOMMATES_P  AVG_AGE  MEDIAN_RENT  AVGVAL_UNIT  WHITE_PERSON   ASIAN_PERSON   VACANT_HOME  UNITS_20PLUS  UNITS_5_19
predict rci_uBG_hat
keep bg90 rci_uBG_hat
sort bg90
tempfile predicted
save `predicted'

**********************
** Begin price regs **
**********************


local 1 "quad"
local main_rad 20
local fe "bg90"

local date=c(current_date)

local day = "1"


use ../dta/placebo-data-cleaned, clear
keep if inlist(city,"Somerville","Medford","Malden")

* a few cleaning things I noticed and fixed.
drop if totrooms==99
replace price=349000 if price==3490000 // an outlier that I verified on Zillow had a zero added
drop if regexm(address,"Innerbelt") // Somerville industrial complex. not residential!
drop if price>=3e6 // drop two other outliers that I hand checked and have definitely not been ever sold for more than $3 mil
* perhaps accurate replacements, but seem too selective
* http://data.visionappraisal.com/MedfordMA/findpid.asp?iTable=pid&pid=8166
replace price=169000 if price==15739


merge address city using ../dta/placebo-data-geocoded
tab _merge
tab city _merge
keep if _merge==3
drop _merge

gen tract90 = substr(tract,1,4)
gen bg90 = tract90 + bg

egen temp = ends(match_add), p(",") t
egen match_city = ends(temp), p(",") h
replace match_city = trim(proper(match_city))

tab match_city city

keep if city==match_city | (match_city=="Boston" & city=="Charlestown")

tab city

sort bg90
merge bg90 using `predicted'
keep if _merge==3 & city!="Charlestown"

drop if inlist(city,"Everett","Chelsea","Arlington","Belmont")

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
foreach struct in "condo" "twofam" "threefam" {
	foreach x in `exis' {
		ge `struct'_`x'=`struct'*`x'
	}
}

local interacted_exis = "`exis' condo_* twofam_* threefam_*" 
local struct_type = "condo twofam threefam"

** ####################### **
** Cluster variable     ## **
** ####################### **

egen clusvar = group(bg90)

	
** ####################### **
** Data summary         ## **
** ####################### **

tab city
tab year_sale

summ rci_uBG_hat, d

tabstat rci_uBG_hat, by(year_sale) s(mean sd min max count)
tabstat rci_uBG_hat, by(city) s(mean sd min max count)


foreach city in Somerville  Malden Medford {
	gen `city' = city=="`city'"
}
local cities = " Somerville Malden Medford"


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


local cities_y = ""
foreach city in  Somerville Malden Medford {
	forval i = 1988/2005 {
		gen `city'_q`i' = `city'*year_sale==`i'
	}
}


** ################### **
** By structure, trend **
** ################### **

drop _merge
sort ml
merge ml using ../dta/structures-2001, nokeep keep(rc)
drop _merge

local pooled = "condo twofam threefam if inlist(1,sing_fam,twofam,threefam,condo)"
local house = "twofam threefam if inlist(1,sing_fam,twofam,threefam)"
local condo = "if condo==1"
local Quad = "`trendvars'"
local None
di "`cities'"
di "`cities_y'"

local fe = "tract90"

foreach r in 1  {
	preserve		
	if `r'==1 {
		drop if rc==1
		local lasttag = "noRC"
		local rcvars = ""
	}
	
	local replace replace
	foreach struct in  house condo  {
		foreach trend in None  {

			areg lprice `rcvars' rci rci_post *_q* `interacted_exis' ``trend'' ``struct'', cluster(clusvar) a(`fe')
			outreg2 `rcvars' rci rci_post using "../tab/table-b3.xml", `replace' title(RCI Main Effect) excel bdec(3) tdec(3) ///
				addtext(Other X's,Full, Fixed Effects, `fe', Structure, `struct', Trend, `trend') nocons label nonotes ctitle(All)
		
			local replace append
		}
	}
	foreach trend in None {
		if `r'==1 local use = "Somerville Malden Medford"
		if `r'==0 local use = "Cambridge"
		foreach city in `use' {
			foreach struct in house condo  {
				areg lprice `rcvars' rci rci_post `interacted_exis' _yr* ``trend'' ``struct'' & city=="`city'", cluster(clusvar) a(`fe')
				outreg2 `rcvars' rci rci_post using "../tab/table-b3.xml", title(RCI Main Effect) excel bdec(3) tdec(3) ///
					addtext(Other X's,Full, Fixed Effects, `fe', Structure, `struct', Trend, `trend') nocons label nonotes ctitle(`city')
			}
		}
	}
	restore
}


