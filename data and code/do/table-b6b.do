* THIS PROGRAM CREATES TABLES B6 bottom panel IN AUTOR, PALMER, PATHAK (JPE, 2013)

clear
cap set mem 100m
set matsize 2000
set more 1
pause on

local 1 "quad"
local main_rad 20
local fe "bg90"


** ####################### **
** Select sample        ## **
** ####################### **


use dta/sales-data, clear
drop if rci_u20==.

tab sing_fam rc
tab twofam rc
tab threefam rc

* Drop firesale condos (11/89, 12/89)
* the ruling was Nov 21, 1989 (corresponds to Stata date 10916).  Sell-off seems limited to 11/21/89 - 12/31/89
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


foreach control of varlist rc  {
	gen p_`control' = post*`control'
	
	if "`control'"=="rc" local rc_control "`control' p_`control'"
}

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
	
local interacted_exis "`interacted_struct_type' `interacted_exis'"
sum `struct_type'
sum `interacted_exis'

** ####################### **
** Data summary         ## **
** ####################### **
* pause
tab year_sale, summ(rc)
tab year_sale rc, summ(lprice)



** #############################
** by struct type
** #############################

* generate subprime flag from MA lenders on HUD subprime lender list. Used from Campbell, Giglio, Pathak (AER 2008)
gen subprime=0
replace subprime=1 if lender=="Accredited Home Lend"
replace subprime=1 if lender=="Alliance Mtg Co" 
replace subprime=1 if lender=="American Res Mtg Corp" 
replace subprime=1 if lender=="Amresco Res Mtg Corp" 
replace subprime=1 if lender=="Aurora Loan Svcs"  
replace subprime=1 if lender=="Chase Manhattan Bk" 
replace subprime=1 if lender=="Citizens Mortgage Cor" 
replace subprime=1 if lender=="Citizens Mtg Co Inc" 
replace subprime=1 if lender=="Diversified Mortgage" 
replace subprime=1 if lender=="Equi Credit Corp" 
replace subprime=1 if lender=="Equity One Fncl Inc" 
replace subprime=1 if lender=="Equity One Inc" 
replace subprime=1 if lender=="Equity One Mtg Corp" 
replace subprime=1 if lender=="FHB Funding Corp" 
replace subprime=1 if lender=="Fieldstone Mtg Co" 
replace subprime=1 if lender=="Finance America LLC" 
replace subprime=1 if lender=="First Franklin Fncl" 
replace subprime=1 if lender=="Ford Consumer Fin Co" 
replace subprime=1 if lender=="Freemont Inv & Loan" 
replace subprime=1 if lender=="Full Spectrum Lending" 
replace subprime=1 if lender=="Headland Mtg Co" 
replace subprime=1 if lender=="Household Bank FSB" 
replace subprime=1 if lender=="Ivy Mortgage Co" 
replace subprime=1 if lender=="Key Bank NA" 
replace subprime=1 if lender=="Long Beach Mtg Co" 
replace subprime=1 if lender=="Metro Mortgage Co" 
replace subprime=1 if lender=="Metropolitan Mtg Co" 
replace subprime=1 if lender=="Mortgage Funding Corp" 
replace subprime=1 if lender=="Mortgage Lender Net" 
replace subprime=1 if lender=="Mortgagecom" 
replace subprime=1 if lender=="Mortgagecom Inc" 
replace subprime=1 if lender=="Nation One Mortgage" 
replace subprime=1 if lender=="New Century Mtg Corp" 
replace subprime=1 if lender=="Pan American FSB" 
replace subprime=1 if lender=="Southern Pacific Fund" 
replace subprime=1 if lender=="Summit Mortgage" 
replace subprime=1 if lender=="TransAmerica Mtg Corp" 
replace subprime=1 if lender=="United Co LendingCorp" 
replace subprime=1 if lender=="WMC Mtg Corp" 
replace subprime=1 if lender=="Union Federal Svgs Bk" 
replace subprime=1 if lender=="Pinnacle Fncl Corp" 
replace subprime=1 if lender=="Peoples Choice Hm Ln" 
replace subprime=1 if lender=="HSBC Mtg Co" 
replace subprime=1 if lender=="Graystone Mtg Corp" 
replace subprime=1 if lender=="Beneficial Mtg MA"

drop if subprime==1

local app = "replace"
local rc_rcivars "nrc_rci p_nrc_rci rc_rci prc_rci"

foreach Group in 1 "!condo" "condo" {
	capture drop *rci
	gen rci=min(rci_u`main_rad',1) if rci_u`main_rad'!=.
	gen rc_rci = rci*rc
	gen p_rci = post*rci
	gen prc_rci = post*rci*rc
	gen nrc_rci=rci*(1-rc)
	gen p_nrc_rci=rci*(1-rc)*post
	summ *rci

	
	areg lprice `rc_control' rci p_rci `struct_type' `interacted_exis' year19* year20* if `Group'==1, cluster(clusvar) a(`fe')
	outreg2 p_rc p_rci ///
		using "tab/price-3diff-struct-`date'-nosubprime", excel `app' bdec(3) tdec(3) /// 
		addtext(Group,`Group',Other X's,x, Fixed Effects, y, Trend,-) nocons label nonotes ctitle(rci`main_rad')
	local app "append"
	

	areg lprice `rc_control' `rc_rcivars' `struct_type' `interacted_exis' year19* year20* if `Group'==1, cluster(clusvar) a(`fe')
	test p_nrc_rci = prc_rci
	local equal = r(p)
	test p_nrc_rci = prc_rci = 0
	local zero = r(p)
	outreg2  p_rc p_nrc_rci prc_rci ///
		using "tab/price-3diff-struct-`date'-nosubprime", title(3diff by struct type) excel append bdec(3) tdec(3) /// 
		addstat(Equal, `equal', Eq and Zero, `zero' ) addtext(Group,`Group',Other X's,x, Fixed Effects, `e(absvar)', Trend,-) nocons label nonotes ctitle(rci`main_rad')

	areg lprice `rc_control' `rc_rcivars' `struct_type' `interacted_exis' `trendvars' year19* year20* if `Group'==1, cluster(clusvar) a(`fe')
	test p_nrc_rci = prc_rci
	local equal = r(p)
	test p_nrc_rci = prc_rci = 0
	local zero = r(p)
	outreg2 p_rc p_nrc_rci prc_rci  ///
		using "tab/price-3diff-struct-`date'-nosubprime", excel append bdec(3) tdec(3) /// 
		addstat(Equal, `equal', Eq and Zero, `zero' ) addtext(Group,`Group',Other X's,x, Fixed Effects, `e(absvar)', Trend,`1') nocons label nonotes ctitle(rci`main_rad')
}


log close

