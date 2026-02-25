* THIS PROGRAM CREATES FIG 5 IN AUTOR, PALMER, PATHAK (JPE, 2013)

clear*
set matsize 2000
set more 1
pause on

local depvar "cost2008" 

use ../dta/building-permits-data, clear

quietly bysort year: gen z1=_N
egen z2=sd(z1)
assert z2==0
drop z1 z2

drop if year<1991 | year>2005



** ####################### **
** Select sample        ## **
** ####################### **

gen byte useflag=1
tab year

* Structure types
drop if state_use_cd>=121 & state_use_cd<=123 | state_use_cd==908
gen byte s_mix = (state_use_cd>=13 & state_use_cd<=41)
gen byte s_con = state_use_cd==199
gen byte s_h1 = state_use_cd==101
gen byte s_h2 = state_use_cd==104
gen byte s_h3 = state_use_cd==105 //| state_use_cd==109
gen byte hs123 = (s_h1 | s_h2 | s_h3 )
gen byte s_apt = state_use_cd==111 | state_use_cd==112
tab s_apt rc
summ s_* if year==1994

keep if s_con | hs123 //| s_apt

tab state, sum(cost)

gen nu = numunits
gen nusq = (numunits^2)/100
summ nu nusq

** ########################## **
** Add'l outcome measures  ## **
** ########################## **


** Set cost to be missing if it is in the permits database but has a permitted expenditure of 0. best thing is to ignore this, or impute?
drop if cost==0 & invest == 1


* Consumer Price Index - All Urban Consumers
* Series Id:    CUUR0000SA0L2,CUUS0000SA0L2
* Not Seasonally Adjusted
* Area:         U.S. city average
* Item:         All items less shelter
* Base Period:  1982-84=100
* Value for 2008 is 205.453
* Accessed 7/20/2009
capture drop cpi
gen double cpi=.
replace cpi = 115.9   if year==1988 
replace cpi = 121.6   if year==1989
replace cpi = 128.2   if year==1990
replace cpi = 133.5   if year==1991
replace cpi = 137.3   if year==1992
replace cpi = 141.4   if year==1993
replace cpi = 144.8   if year==1994
replace cpi = 148.6   if year==1995
replace cpi = 152.8   if year==1996
replace cpi = 155.9   if year==1997
replace cpi = 157.2   if year==1998
replace cpi = 160.2   if year==1999
replace cpi = 165.7   if year==2000
replace cpi = 169.7   if year==2001
replace cpi = 170.8   if year==2002
replace cpi = 174.6   if year==2003
replace cpi = 179.3   if year==2004
replace cpi = 186.1   if year==2005
replace cpi = 191.9   if year==2006
replace cpi = 196.639   if year==2007
replace cpi = 205.453   if year==2008
replace cpi = 203.301 if year == 2009
tab year, summ(cpi)
assert cpi!=.
gen cost2008 = (cost*(205.453/cpi))/1000

replace cost2008 = 0 if invest==0

ge perunit=cost2008/nu

* Winsorize 

forvalues w = 995/995 {
	local percentile=`w'/10
	bys s_con year: egen winsor`w' = pctile(cost2008) /*if cost2008>0 & cost2008!=.*/, p(`percentile')
	tab year, summ(winsor`w')
	gen cost`w'=min(winsor`w', cost2008) if cost2008!=.
	gen winsorizedobs`w'=cost`w'==winsor`w'
	tab winsorizedobs
}

table year, c(mean cost2008 p50 cost2008 max cost2008 mean cost2008 max cost2008)
assert cost2008 == . if invest==1 & cost==.

* Additional controls
local exis = "nu nusq"

** ########################## **
** Flags for RC, post, etc ## **
** ########################## **

gen byte post = year>= 1995
tab year, summ(post)
gen post_hs = hs123*post
gen post_h1 = s_h1*post
gen post_h2 = s_h2*post
gen post_h3 = s_h3*post
gen post_con = s_con*post
gen post_mix = s_mix*post
gen post_apt = s_apt*post
gen rc_hs = hs123*rc
gen rc_con = s_con*rc
gen rc_mix = s_mix*rc
gen rc_apt = s_apt*rc
gen rcpost = rc*post
gen rcpost_apt = s_apt*post*rc
gen rcpost_hs = hs123*rc*post
gen rcpost_con = s_con*rc*post
gen rcpost_mix = s_mix*rc*post

* Make residential houses the baseline structure by renaming their main effect
rename s_h1 hs1
foreach v of varlist s_* {
	gen `v'_p = `v'*post
	gen rc_`v' = `v'*rc
	gen rc_`v'_p = `v'*rc*post
	
}
summ rc_s_*
local struct_type = "s_con s_h2 s_h3"


if "`depvar'"=="perunit" {
	local exis ""
	}
	
cap gen perunit=cost2008/nu

	

** ####################### **
** Cluster variable     ## **
** ####################### **
egen clusvar = group(bg90)
xi i.year

** ##################################################### **
** RC and RC x Post only
** ##################################################### **

summ nu
local replace replace
local counter = 0

local dspec = 1 // only do single diff-in-diff

gen unit_house = nu*inlist(state_use_cd,101,104,105)
gen unit_condo = nu*inlist(state_use_cd,199)
gen unit_2condo = nu*nu*inlist(state_use_cd,199)
local exis = "unit_condo unit_2condo"
local replace


local e event

		if "`e'"=="event" {
			if `counter'!=1 {	
				forval yr = 1988/2005 {
					if `yr'!=1994 gen rcyr_`yr' = rc*(year==`yr')
					local counter = 1
				}
			}
			* event study lines
			local rcpost "rc rcyr*"
		
			local etag = "event"
			local k = 2
		}
		else local etag = ""

		
	foreach depvar in invest cost995 {
		foreach i in -1 {
			codebook `depvar'
			* preserve
			
			if "`depvar'"=="invest" local 2tag = "lpm"
			if "`depvar'"=="cost995" local 2tag = "levels"

			local stype "pooled"

			areg `depvar' `rcpost' `exis' _Iyear_* `struct_type'  `weight', cluster(clusvar) a(bg90)
			if "`e'"=="event" {
				mat beta = e(b)'
				mat se = e(V)
				mat d1_`2tag'_`stype'`k' = J(17,2,0)
				
				forval p=1/17 {
					local p1 = `p' + 1
					mat d1_`2tag'_`stype'`k'[`p',1] = beta[`p1',1]
					mat d1_`2tag'_`stype'`k'[`p',2] = sqrt(se[`p1',`p1'])
				}
			}
}
}
drop _all

set obs 17
gen year = _n + 1987

foreach d in 1 {
	foreach 2tag in lpm levels  {
		foreach stype in pooled  {
			forval k = 2/2 {
				svmat d`d'_`2tag'_`stype'`k'
				ren d`d'_`2tag'_`stype'`k'1 d`d'_`2tag'_`stype'`k'_rc
				gen d`d'_`2tag'_`stype'`k'_rchi = d`d'_`2tag'_`stype'`k'_rc + d`d'_`2tag'_`stype'`k'2
				gen d`d'_`2tag'_`stype'`k'_rclo = d`d'_`2tag'_`stype'`k'_rc - d`d'_`2tag'_`stype'`k'2
				drop d`d'_`2tag'_`stype'`k'2

			}
		}
	}
}

list d1_lpm_pooled2_rc d1_levels_pooled2_rc


replace year = year + 1 if year>=1994
local temp = `=_N' + 1
set obs `temp'
replace year = 1994 if year==.

list d1_lpm_pooled2_rc d1_levels_pooled2_rc


foreach 2tag in lpm levels {
	foreach stype in pooled  {
		replace d1_`2tag'_`stype'2_rc = 0 if year==1994 & d1_`2tag'_`stype'2_rc ==.
	}
}

sort year

keep if year>1990

list d1_lpm_pooled2_rc d1_levels_pooled2_rc

* extend CI lines
assert _N==15
set obs 17
replace year = 1993.5 in 16
replace year = 1994.5 in 17

sort year

replace d1_lpm_pooled2_rclo=d1_lpm_pooled2_rclo[3]-(.5*(d1_lpm_pooled2_rc[3])) if year==1993.5
replace d1_lpm_pooled2_rchi=d1_lpm_pooled2_rchi[3]-(.5*(d1_lpm_pooled2_rc[3])) if year==1993.5

replace d1_lpm_pooled2_rclo=d1_lpm_pooled2_rclo[7]-(.5*(d1_lpm_pooled2_rc[7])) if year==1994.5
replace d1_lpm_pooled2_rchi=d1_lpm_pooled2_rchi[7]-(.5*(d1_lpm_pooled2_rc[7])) if year==1994.5

replace d1_levels_pooled2_rclo=d1_levels_pooled2_rclo[3]-(.5*(d1_levels_pooled2_rc[3])) if year==1993.5
replace d1_levels_pooled2_rchi=d1_levels_pooled2_rchi[3]-(.5*(d1_levels_pooled2_rc[3])) if year==1993.5

replace d1_levels_pooled2_rclo=d1_levels_pooled2_rclo[7]-(.5*(d1_levels_pooled2_rc[7])) if year==1994.5
replace d1_levels_pooled2_rchi=d1_levels_pooled2_rchi[7]-(.5*(d1_levels_pooled2_rc[7])) if year==1994.5

sort year

list year d1_lpm_pooled2_rc d1_levels_pooled2_rc

foreach 2tag in lpm levels {
	if "`2tag'"=="lpm" {
		local rclabel = "-.02(.01).03) ytick(-.02(.005).035, grid"
		local taglabel = "Probability of Permitted Investment"
	}
	if "`2tag'"=="levels" {
		local rclabel = "-2(.5)3"
		local taglabel = "Investment Expenditure ($1000s)"
	}
	foreach stype in pooled  {
		twoway  (rline d1_`2tag'_`stype'2_rchi d1_`2tag'_`stype'2_rclo year, lp(dash) cmissing(n)) ///
				(connected d1_`2tag'_`stype'2_rc year) , ///
				title( "`taglabel'") leg(label(1 "95% Confidence Interval") label(2 "Point Estimate") order(2 1))  ///	
				xlab(1992(3)2004) ylab(`rclabel') xtitle("") scheme(s2mono) xline(1994) ///
				saving(../invest-event-`2tag'.gph, replace)
		
		if `dspec'>1 {
		twoway  (connected `2tag'_`stype'2_rci year) ///
				(rline `2tag'_`stype'2_rcihi `2tag'_`stype'2_rcilo year,  lp(dash) cmissing(n)) ///
				title( "`taglabel'") leg(label(1 "95% Confidence Interval") label(2 "Point Estimate") order(2 1))  ///
				xlab(1992(3)2004) ylab(`rclabel',grid) xtitle("") scheme(s2mono) xline(1994) ///
				saving(../invest-event-`2tag'.gph) // , replace
		}

	}
	
}
	
* end