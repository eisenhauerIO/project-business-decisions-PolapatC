* THIS PROGRAM CREATES TABLE A4 IN AUTOR, PALMER, PATHAK (JPE, 2013)

* create relevant sample
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
summ lotsize* nolot
summ lotsize if nolot
summ lnage lnage2 lotsize* nolot

**#############
* Covariate all descriptive statistics, disjoint
**#############

replace sqft=sqft/100
ge haslot=lotsize>0
replace haslot=0 if lotsize==.

local covariates "lprice totrooms bedrooms bathrooms sqft haslot lotsize yearbuilt"

label var lprice "log price"
label var lotsize "lot size"
label var yearbuilt "year built"
label var bedrooms "bedrooms"
label var bathrooms "bathrooms"
label var totrooms "total rooms"
* label var numunits "# of units"

**############
* Pooled sumstats
**############

eststo clear

* All by RC status

* Houses
bys rc : eststo: estpost tabstat `covariates' if !condo, by(post) statistics(n mean sd) c(statistics) listwise nototal
esttab using "tab/sumstats`date'.csv", main(mean) aux(sd) nostar unstack ///
	nonote nonumber nolines nogaps replace /*mtitles("pre" "post")*/ label b(2) // aux(2)

* Condos

bys rc : eststo: estpost tabstat `covariates' if condo, by(post) statistics(n mean sd) c(statistics) listwise nototal
esttab using "tab/sumstats`date'.csv", main(mean) aux(sd) nostar unstack ///
	nonote nonumber nolines nogaps append /*mtitles("pre" "post")*/ label b(2) // aux(2)


foreach s in 0 1 {
	foreach r in 0 1 {
		foreach t in 0 1 {
			di "Condo:`s' RC: `r' Post: `t' "
			count if condo==`s' & rc==`r' & post==`t'
		}
	}
}
