* THIS PROGRAM CREATES TABLE A-1 IN AUTOR, PALMER, PATHAK (JPE, 2013)

clear

set mem 1g

use ../dta/building-permits-data, clear

drop if year==2005

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
replace cpi = 196.639 if year==2007
replace cpi = 205.453 if year==2008
replace cpi = 203.301 if year==2009
tab year, summ(cpi)
assert cpi!=.
gen cost2008 = (cost*(205.453/cpi))/1000

mat output = J(12,8,0)

local i = 1
local j = 1

cap drop house condo

gen house = inlist(state_use_cd,101,104,105)
gen condo = inlist(state_use_cd,199)

keep if inlist(1,house,condo) & year!=1990

*drop 0 expenditure permits
drop if invest==1 & cost2008==0

gen nu = round(numunits,1)
gen investnu=invest*nu

/*a permit is considered good for 1 unit in a structure. */
/*So sum(invest) is the the total permitted units*/

gen post=year>=1995
gen pre=!post

bys house post year rc: egen yearly = sum(cost2008)
bys house post year rc: egen yearlyunits = sum(nu)
bys house post year rc: egen yearlyperm = sum(invest)

bys house post year rc: gen yearrep = 1 if _n==1

gen yearcost = yearly if yearrep==1
gen yearpctinvest = yearlyperm/yearlyunits if yearrep==1


bys house post rc: egen meanyearly = mean(yearcost)
bys house post rc: egen meanpctinvest = mean(yearpctinvest)


bys house post rc: egen totalcost = sum(cost2008)
bys house post rc: egen totunits = sum(nu)
bys house post rc: gen averagecost = totalcost/totunits




replace cost2008 = 0 if cost2008==.
gen costperunit = 0
replace costperunit=cost2008/nu if nu>0



foreach s in house condo {
	foreach r in 0 1 {
		foreach t in pre post {
			* # Permits
			qui summ invest if `s'==1 & rc==`r' & `t'==1
			mat output[1,`j'] = r(sum)
			
			* Annual Mean Fraction of units permitted
			qui summ meanpctinvest if `s'==1 & rc==`r' & `t'==1
			mat output[2,`j'] = r(mean)
			
			* Mean units in permitted structures
			qui summ nu if `s'==1 & rc==`r' & `t'==1 & invest==1
			mat output[3,`j'] = r(mean)
			
			* Annual mean agg exp
			qui summ meanyearly if `s'==1 & rc==`r' & `t'==1
			mat output[4,`j'] = r(mean)
			
			* Total agg exp
			qui summ totalcost if `s'==1 & rc==`r' & `t'==1
			mat output[5,`j'] = r(mean)
			
			* Exp per Unit
			qui summ costperunit [fw=nu] if `s'==1 & rc==`r' & `t'==1
			mat output[6,`j'] = r(mean)
			mat output[7,`j'] = r(sd)
			
			* Exp per permitted unit (no FW)
  			qui summ cost2008 if `s'==1 & rc==`r' & `t'==1 & invest==1, d
			mat output[8,`j'] = r(mean)
			mat output[9,`j'] = r(sd)
			mat output[10,`j'] = r(p50)
			mat output[11,`j'] = r(min)
			mat output[12,`j'] = r(max)
			
			* * N
			* count if `s'==1 & rc==`r' & `t'==1
			* mat output[13,`j'] = r(N)
			local j = `j' + 1
		}		
	}
}

mat li output
