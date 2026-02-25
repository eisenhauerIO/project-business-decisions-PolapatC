* this file cleans the raw sales data as described in the data appendix
* Autor, Palmer, Pathak (JPE, 2013)

insheet using transact.csv, comma clear
keep if city=="Cambridge"

ren intersf sqft
replace sqft=sqft*100

egen add_group = group(address)
label var add_group "running id variable for unique addresses"

*********************************************
* Generate ML codes, identify RC transactions
*********************************************

* mapid is a Warren Group code which has a M: and a L: component.
* the following code splits those components and removes leading zeroes.

ge map = regexs(1) if regexm(mapid,"^M:0?0?0?0?([1-9][0-9]?[0-9]?\.?[0-9]?[0-9]?[A-Z]?)")
ge lot = regexs(1) if regexm(mapid,"L:0([0-9][0-9][0-9][0-9]?)")

*These commands remove the leading zeros and cast the lot as a string for concatenation
destring lot, replace
tostring lot, replace

ge ml = map+"-"+lot if mapid!=""

********************************************************
* Replace ml codes that don't match up with structures data, looked up by hand on Cambridge online property database
* checked how changes RC match, increases # RC found
********************************************************

replace ml = "108-32" if ml=="108-323"
replace ml = "122-176" if ml=="122-1761"
replace ml = "126-140" if ml=="126-1402"
replace ml = "126-140" if ml=="126-1402"
replace ml = "135-25" if ml=="135-251"
replace ml = "141-76" if ml=="141-761"
replace ml = "174-49" if ml=="174-492"
replace ml = "201.5-11" if ml=="2015-11"
replace ml = "201.5-24" if ml=="2015-24"
replace ml = "201.5-39" if ml=="2015-39"
replace ml = "201.5-49" if ml=="2015-49"
replace ml = "201.5-73" if ml=="2015-73"
replace ml = "224-4" if ml=="224-43"
replace ml = "225-5" if ml=="225-51"
replace ml = "225-5" if ml=="225-51"
replace ml = "271-16" if ml=="271-17"
replace ml = "37-38" if ml=="37-383"
replace ml = "37-38" if ml=="37-383"
replace ml = "77-81" if ml=="77-811"
replace ml = "77-81" if ml=="77-811"
replace ml = "77-81" if ml=="77-811"
replace ml = "8-61" if ml=="8-611"
replace ml = "8-61" if ml=="8-612"
replace ml = "8-61" if ml=="8-614"
replace ml = "8-61" if ml=="8-617"
replace ml = "82-107" if ml=="82-103"
replace ml = "82-62" if ml=="82-623"
replace ml = "88-67" if ml=="88-672"

sort ml

*********************************************
* Flag non-arms length transactions
*********************************************

ge flag_norooms = totr==0
label var flag_norooms "Total rooms = 0"
ge flag_nosqft = sqft==0
label var flag_nosqft "Property has zero interior sq ft"

***Parses date components.  Use regular expressions instead!
ge month=substr(date,1,2)
ge day = substr(date, 4,2)
ge year = substr(date, 7,2)

destring month, replace
destring day, replace
destring year, replace

*Converts two digit year to 4 digit
replace year =100+year if year<10
replace year=1900+year
ge post = year>1994
label var post "Sale took place after rent control repealed"

gen mydate = mdy(month,day, year)
label var mydate "Stata date fmt"

* elapsed will be missing if a sale has no previous sale in the dataset
* (if it was not sold twice in our data, or if it is the first sale of a property that was sold twice)
bys add_group (mydate): ge elapsed = mydate-mydate[_n-1]


* ********************************Fixing some obvious typos I found
replace buyer1 = "Michaelson, Miriam" if buyer1=="Michaelson, Mariam"
replace seller1 = "Cambridge Hldgs T" if seller1=="Cambridge Hlds T"
replace buyer1="Zylex LLC" if buyer1=="Zylex LLP"
replace buyer1="Epstein, David" if buyer1=="Epstein, Davip"
replace buyer1="New Eng Fedl Svgs Bk" if buyer1=="New Eng Fedl Svg Bk"
	
	ge abnormaldeed = deedtype=="FD" | deedtype=="LC"
	label var abnormaldeed "Foreclosure or Land Court Deed"
	bys mydate add_group: egen tot_abnormaldeed=total(abnormaldeed)
	ge flag_deed = tot_abnormaldeed>0									// if any deed at this address on this day is abnormal, flag all sales today


	* ****Code for picking one of each duplicate transaction group to keep, flagging the rest
	* Which observation we keep when all observables are the same is in principle irrelevant.
	* "duplicate transactions" are those with same price, date, address, and all observables constant

	* duplicates tag price group mydate totroom bath bedrooms lotsize intersf yearbuilt usecode deedt, gen(identical) //ml

	* This variable groups duplicate transactions, defined as same address, sale date, price
	egen dup_group = group(add_group mydate price)
	sort dup_group, stable
	label var dup_group "running id variable for unique duplicate transactions"

	* This creates a variable representing the total mortgage expenditure on a group of duplicate transactions
	by dup_group: egen dup_group_mort = total(mortgage)

	* drop those obs that are missing mortgage info that exist in otherwise identical obs
	drop if mortgage==0 & dup_group_mort>0 & dup_group!=.
	
	egen dup_tag=tag(dup_group)
	by dup_group: egen count_dup_group = count(dup_group)
	tab count_dup_group dup_tag		// checks that one obs is tagged in each dup group.
	* this reverses the tag.  We want all but one transaction tagged to drop, not none but one transaction tagged
	ge flag_duplicate=1-dup_tag
	label var flag_duplicate "flags all duplicate transactions but one in each duplicate group"




* ************Switched transaction codes
* this code identifies transactions that are between the same parties on the same day (but not necessarily same prices) of the same property and flags them

	egen sameday_group = group(add_group mydate) //if count_dup_group==1
	bys sameday_group: egen sameday_group_count = count(sameday_group)
	
	ge switcher=0

	forvalues b = 1/2 {
		forvalues s = 1/2 {
			bys sameday_group: replace switcher=1 if ///
				seller`s'==buyer`b'[_n-1] & seller`s'!="" & ///
				(((buyer1==seller1[_n-1] | buyer1==seller2[_n-1]) & buyer1!="") | ///
				((buyer2==seller1[_n-1] | buyer2==seller2[_n-1]) & buyer2!=""))
			}
		}

	bys sameday_group: egen tot_switch=total(switcher)
	ge flag_switch=tot_switch>0
*	}



* *******This code identifies partial transactions, which are defined as
* transactions on the same day of the same property, different price (o.w. they are duplicates), one entity appears on the same side of both
* I refer to them as partial transactions because sometimes a mortgage is taken out for the sum of the two prices
	ge repeat = sameday_group_count>1 & count_dup_group==1
	egen partial_group = group(add_group mydate) if repeat

	ge flag_partial=0
	forvalues first = 1/2 {
		forvalues second = 1/2 {
			bys partial_group: replace flag_partial=1 ///
				if ((seller`first'==seller`second'[_n+1] & seller`first'!="" & seller`second'[_n+1]!="") | ///
					(buyer`first'==buyer`second'[_n+1] & buyer`first'!="" & buyer`second'[_n+1]!="")) ///
					& partial_group!=.
		}
	}

bys partial_group: egen tot_partials=total(flag_partial)
replace flag_partial=tot_partials>0 if partial_group!=.


	egen repeat_group = group(add_group mydate repeat) if repeat
	bys repeat_group: egen repeat_group_count = count(repeat_group)
	label var repeat_group_count "=0 if no repeat trans found, o.w. = tot # repeats"
	cap drop not_last_trans
	ge flag_repeat = 0
	label var flag_repeat "transactions followed by subsequent transactions the same day"

	forvalues b = 1/2 {
		forvalues s = 1/2 {
			bys repeat_group: replace flag_repeat = 1 ///
				if ((buyer`b'==seller`s'[_n+1] & buyer`b'!="" & seller`s'[_n+1]!="") | ///
					(buyer`b'==seller`s'[_n-1] & buyer`b'!="" & seller`s'[_n-1]!="")) ///
					& repeat_group_count!=0
		}
	}

	tab flag_repeat, miss
	
	bys repeat_group: egen not_last_total = total(flag_repeat)
	ge leftover = repeat_group_count - not_last_total

	
label var flag_repeat "transactions followed by subsequent transactions the same day"



*****************************************************
* Share sales
* defined as the same person on both sides of a single transaction
*****************************************************

ge flag_share=0
forvalues i = 1/2 {
	forvalues j = 1/2 {
		replace flag_share=1 if buyer`i'==seller`j' & buyer`i'!="" & seller`j'!=""
	}
}

******************************************
* Within family sales
******************************************

ge flag_family=0

forvalues i = 1/2 {
	ge buyer`i'lastname=regexs(1) if regexm(buyer`i',"(^.+),")		// saves all characters before a comma as last name
	ge seller`i'lastname=regexs(1) if regexm(seller`i',"(^.+),")
}

forvalues i = 1/2 {
	forvalues j = 1/2 {
		replace flag_family=1 if buyer`i'last==seller`j'last & buyer`i'last!="" & seller`j'last!=""
	}
}


*****************************************
* Combine all data flags into one flag
*****************************************

sum flag*
egen flag = anymatch(flag_deed flag_norooms flag_nosqft flag_duplicate flag_switch flag_repeat flag_partial flag_share flag_family), values(1)
	
count if ml==""
drop if flag
count
count if ml==""
if r(N)>0 stop

ren year year_sale

* This code creates a dummy for whether the yearbuilt variable is missing and replaces missing values
* with the mean of the variable yearbuilt for taken over all non-flagged observations

ge yearbuilt_missing = yearbuilt==.
tab yearbuilt_missing

	bys add_group: egen maxyearbuilt=max(yearbuilt)
	bys add_group: egen hasmissing=total(yearbuilt_missing)
	replace yearbuilt=maxyearbuilt if yearbuilt_missing & year_sale>=maxyearbuilt
	replace yearbuilt_missing=yearbuilt==.
	tab yearbuilt_missing

	preserve // these properties had missing year build in warren data, but we were able to find them by looking up by hand in Cambridge online database
	insheet using ../data/yearbuilt-hand-lookup.csv, comma double clear
	ren year_built yearbuilt_new
	sort ml
	tempfile yearbuilt_new
	save `yearbuilt_new'
	restore

	sort ml
	merge ml using `yearbuilt_new', keep(yearbuilt_new) _merge(_merge_yearbuilt) uniqusing nokeep
	tab _merge_yearbuilt
	replace yearbuilt=yearbuilt_new if yearbuilt_new!=. & yearbuilt_new <= year_sale & yearbuilt==.
	replace yearbuilt_missing=yearbuilt==.
	tab yearbuilt_missing


* The usecode of 100 appears only twice and is listed under usage as a duplex.  Recode it
replace usecode=104 if usecode==100

* replace missing values with mean of non-zero missing stratified mean by type:
bys usecode: egen use_yearbuilt_mean=mean(yearbuilt)
replace yearbuilt=use_yearbuilt_mean if yearbuilt_missing

tab usecode, gen(usecode)
* rename the resulting dummy variables according to actual usage
ren usecode1 sing_fam
ren usecode2 condo
ren usecode3 twofam
ren usecode4 threefam

ge lprice = ln(price)
ge lotsize_nonapt=lotsize*(usecode!=102)

* end of do-file