* THIS PROGRAM CREATES TABLE A3 IN AUTOR, PALMER, PATHAK (JPE, 2013)

clear
set mem 50m
set more 1

use ml house condo year if inlist(1,house,condo) & inlist(year,1994,2004) using ../dta/assess-panel
keep ml
duplicates drop
merge 1:1 ml using ../dta/structures-2001, keepusing(block90) keep(match)
keep block90
duplicates drop
tempfile blocks_in_assess_sample
save `blocks_in_assess_sample'

use bg90 house condo year if inlist(1,house,condo) & inlist(year,1994,2004) using ../dta/assess-panel
keep bg90
duplicates drop
tempfile bgs_in_assess_sample
save `bgs_in_assess_sample'

use tract90 using ../dta/assess-panel
duplicates drop
tempfile tracts_in_assess_sample
save `tracts_in_assess_sample'




use  if block90!=. using ../dta/structures-2001

replace area=area/(5280^2)				// convert square feet to square miles


** #############
* Descriptive Statistics
** #############


preserve
sort block90
merge block90 using `blocks_in_assess_sample', uniqusing sort
tab _merge
keep if _merge==3

collapse tract90 bg90 area pop100 (sum) units_geo=numunits rc_units_geo=cunits struct_geo=residential rc_struct_geo=rc, by(block90)
sum area
label var area "Area (sq miles)"
label var pop100 "1990 Census Population"
label var rc_units_geo "Rent Control Units"
label var units_geo "Residential Units"
label var struct_geo "Residential Structures"
label var rc_struct_geo "Rent Control Structures"
	

estpost tabstat area pop100 units_geo rc_units_geo struct_geo rc_struct_geo, c(s) stat(n mean sd min max median)
esttab using ../tab/geo_sumstats_assessfixed.csv, cells("mean sd min max p50") replace nolines nonumber nogaps label  plain ///
	title(Descriptive Statistics - Census Geographies) wide nostar nonote b(%9.3g)
eststo clear


restore
preserve
sort bg90
merge bg90 using `bgs_in_assess_sample', uniqusing sort
tab _merge
keep if _merge==3

collapse tract90 bg90 area pop100 (sum) units_geo=numunits rc_units_geo=cunits struct_geo=residential rc_struct_geo=rc, by(block90)
collapse tract90 (sum) area pop100 units_geo rc_units_geo struct_geo rc_struct_geo, by(bg90)

* drop if inlist(0,pop100,units_geo,struct_geo)
label var area "Area (sq miles)"
label var pop100 "1990 Census Population"
label var rc_units_geo "Rent Control Units"
label var units_geo "Residential Units"
label var struct_geo "Residential Structures"
label var rc_struct_geo "Rent Control Structures"

estpost tabstat area pop100 units_geo rc_units_geo struct_geo rc_struct_geo, c(s) stat(n mean sd min max median) 
esttab using ../tab/geo_sumstats_assessfixed.csv, cells("mean sd min max p50") append nolines nonumber nogaps label  plain ///
	title(Block Groups) wide nostar nonote b(%9.3g)
eststo clear


restore
preserve

sort tract90
merge tract90 using `tracts_in_assess_sample', uniqusing sort
tab _merge
keep if _merge==3

collapse tract90 bg90 area pop100 (sum) units_geo=numunits rc_units_geo=cunits struct_geo=residential rc_struct_geo=rc, by(block90)
collapse tract90 (sum) area pop100 units_geo rc_units_geo struct_geo rc_struct_geo, by(bg90)
collapse (sum) area pop100 units_geo rc_units_geo struct_geo rc_struct_geo, by(tract90)

label var area "Area (sq miles)"
label var pop100 "1990 Census Population"
label var rc_units_geo "Rent Control Units"
label var units_geo "Residential Units"
label var struct_geo "Residential Structures"
label var rc_struct_geo "Rent Control Structures"

estpost tabstat area pop100 units_geo rc_units_geo struct_geo rc_struct_geo, c(s) stat(n mean sd min max median) 
esttab using ../tab/geo_sumstats_assessfixed.csv, cells("mean sd min max p50") append nolines nonumber nogaps label plain ///
	title(Tracts) wide nostar nonote b(%9.3g)
eststo clear	

restore

* impute population in each .2 mile radius as if having the same population density as the census block (later compare calculation if use BG)

drop if units20==0 | struct20==0 | units20==. | struct20==.

gen pop20=pop100*(.2^2*_pi)/area
estpost tabstat pop20 units20 rc_units20 struct20 rc_struct20, c(s) stat(n mean sd min max median)
esttab using ../tab/geo_sumstats_assessfixed.csv, cells("mean sd min max p50") append nolines nonumber nogaps label  plain ///
	title(0.2 mile radius) wide nostar nonote b(%9.3g)
eststo clear
	
* end of do file