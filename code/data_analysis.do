* ============================================================
* HCAMP Concussion Study — Main Analysis
* ============================================================
* Reads:   Data/Processed Data/regdata_new.dta (from data_cleaning.do)
* Outputs: tables/  (LaTeX), figures/ (PNG)
*
* SETUP: Change the path below to your local HCAMP project root.
*        All file paths in this script are relative to that folder.
* ============================================================

cd "YOUR_HCAMP_PATH_HERE"


local sumstats_all = 1
local figure1 = 1
local figure2 = 1
local figure3 = 1
local sumstats_by_conc = 1
local cs_did_single = 1
local cs_did_multiple = 1
local idfe = 1
local heterogeneity = 1


* -----------------------------------------------------------------------
* TABLE 1: Overall summary statistics
* -----------------------------------------------------------------------
if `sumstats_all' == 1 {

	use "Data/Processed Data/regdata_new.dta", clear

	* --- Grade level indicators ---
	gen grade9  = (GradeLevel == 9)
	gen grade10 = (GradeLevel == 10)
	gen grade11 = (GradeLevel == 11)
	gen grade12 = (GradeLevel == 12)
	label var grade9  "9th Grade"
	label var grade10 "10th Grade"
	label var grade11 "11th Grade"
	label var grade12 "12th Grade"

	* --- Labels ---
	label var asian           "Asian"
	label var filipino        "Filipino"
	label var nativehawaiian  "Native Hawaiian"
	label var other           "Other"
	label var pacificislander "Pacific Islander"
	label var white           "White"
	label var school_days     "School days (year)"
	label var days_absent     "Days absent (year)"
	label var offense         "Total behavioral offenses (Class A + Class B)"
	label var cumulative_gpa  "Cumulative GPA"

	* --- Count unique students ---
	bysort research_id: gen byte tag_t1 = (_n == 1)
	count if tag_t1
	local n_unique_t1 = r(N)
	drop tag_t1

	local varlist_t1 sy_concussions cum_concussions ///
		age male econ_disadvantaged SPEDStatus ELLStatus ///
		asian filipino nativehawaiian other pacificislander white ///
		Wrestling Volleyball track_field martial_arts Tennis Swimming ///
		Softball Soccer Paddling Football Cheerleading Basketball Baseball ///
		grade9 grade10 grade11 grade12 ///
		annual_gpa math_gpa eng_gpa sci_gpa cumulative_gpa ///
		days_absent school_days offense ADHD AUT Dyslexia

	eststo clear
	eststo t1: quietly estpost summarize `varlist_t1', detail
	estadd scalar students = `n_unique_t1': t1

	esttab t1 using "tables/sumstats_all.tex", replace ///
		title("Summary Statistics") ///
		cells("mean(fmt(3)) sd(fmt(3)) min(fmt(0)) max(fmt(0))") ///
		collabels("Mean" "SD" "Min" "Max") ///
		label nonumber nomtitle ///
		stats(N students, labels("Observations" "Unique students (N)") fmt(%9.0f)) ///
		booktabs ///
		refcat( ///
			sy_concussions   "\addlinespace \textbf{Concussion variables}" ///
			age              "\addlinespace \textbf{Student Demographics}" ///
			Wrestling        "\addlinespace \textbf{Sports participation}" ///
			grade9           "\addlinespace \textbf{Academic variables}" ///
			days_absent      "\addlinespace \textbf{Behavioral variables}" ///
			, nolabel )

}


* -----------------------------------------------------------------------
* FIGURE 1: Distribution of cumulative concussions
* -----------------------------------------------------------------------
if `figure1' == 1 {

	use "Data/Processed Data/regdata_new.dta", clear

	* Collapse to student level using maximum (final) cumulative concussions
	bysort research_id: egen max_cum = max(cum_concussions)
	bysort research_id: keep if _n == 1

	* Bin: 0, 1, 2, 3+
	gen cumconc_bin = .
	replace cumconc_bin = 1 if max_cum == 0
	replace cumconc_bin = 2 if max_cum == 1
	replace cumconc_bin = 3 if max_cum == 2
	replace cumconc_bin = 4 if max_cum >= 3 & !missing(max_cum)

	label define cumconc_lbl 1 "0" 2 "1" 3 "2" 4 "3+"
	label values cumconc_bin cumconc_lbl

	* Top panel: full sample
	histogram cumconc_bin, discrete percent ///
		barwidth(0.7) ///
		fcolor(navy%35) lcolor(navy) lwidth(vthin) ///
		xlabel(1 "0" 2 "1" 3 "2" 4 "3+", labsize(medlarge)) ///
		xtitle("Cumulative concussions (Full Sample)") ///
		ytitle("Percent") ///
		graphregion(color(white)) plotregion(color(white)) bgcolor(white) ///
		name(hist_all, replace)

	* Bottom panel: concussed students only
	histogram cumconc_bin if max_cum > 0, discrete percent ///
		barwidth(0.7) ///
		fcolor(navy%35) lcolor(navy) lwidth(vthin) ///
		xlabel(2 "1" 3 "2" 4 "3+", labsize(medlarge)) ///
		xtitle("Cumulative concussions (Concussed Students)") ///
		ytitle("Percent") ///
		graphregion(color(white)) plotregion(color(white)) bgcolor(white) ///
		name(hist_concussed, replace)

	* Combine vertically
	graph combine hist_all hist_concussed, cols(1) ///
		graphregion(color(white)) ///
		xsize(5) ysize(7) ///
		name(hist_combined, replace)

	cap mkdir "figures"
	graph export "figures/fig1_cum_conc_dist.png", as(png) replace

}


* -----------------------------------------------------------------------
* FIGURE 2: 9th-grade GPA histograms by concussion status
* -----------------------------------------------------------------------
if `figure2' == 1 {

	use "Data/Processed Data/regdata_new.dta", clear

	local w = 0.25

	* Panel (a): 9th-grade annual GPA
	preserve
	keep if GradeLevel == 9 & !missing(annual_gpa)
	replace annual_gpa = 4 if annual_gpa > 4 & !missing(annual_gpa)

	twoway ///
		(histogram annual_gpa if ever_treated == 0, percent width(`w') start(0) ///
			fcolor(navy%35) lcolor(navy) lwidth(vthin)) ///
		(histogram annual_gpa if ever_treated == 1, percent width(`w') start(0) ///
			fcolor(maroon%35) lcolor(maroon) lwidth(vthin)), ///
		legend(order(1 "Never concussed" 2 "Eventually concussed") ///
			   ring(1) pos(12) cols(2) region(lcolor(none) fcolor(none))) ///
		xtitle("9th-grade annual GPA") ///
		ytitle("Percent") ///
		graphregion(color(white)) plotregion(color(white)) bgcolor(white) ///
		name(fig2a, replace)
	restore

	* Panel (b): 9th-grade math GPA
	preserve
	keep if GradeLevel == 9 & !missing(math_gpa)

	twoway ///
		(histogram math_gpa if ever_treated == 0, percent width(`w') start(0) ///
			fcolor(navy%35) lcolor(navy) lwidth(vthin)) ///
		(histogram math_gpa if ever_treated == 1, percent width(`w') start(0) ///
			fcolor(maroon%35) lcolor(maroon) lwidth(vthin)), ///
		legend(order(1 "Never concussed" 2 "Eventually concussed") ///
			   ring(1) pos(12) cols(2) region(lcolor(none) fcolor(none))) ///
		xtitle("9th-grade math GPA") ///
		ytitle("Percent") ///
		graphregion(color(white)) plotregion(color(white)) bgcolor(white) ///
		name(fig2b, replace)
	restore

	* Combine panels side by side
	graph combine fig2a fig2b, cols(2) ///
		graphregion(color(white)) ///
		xsize(10) ysize(5) ///
		name(fig2_combined, replace)

	cap mkdir "figures"
	graph export "figures/fig2_gpa_hist.png", as(png) replace

}


* -----------------------------------------------------------------------
* FIGURE 3: Annual GPA by grade level, concussion status, and sex
*           (never concussed vs. first concussion in 10th grade)
* -----------------------------------------------------------------------
if `figure3' == 1 {

	use "Data/Processed Data/regdata_new.dta", clear

	* Grade-specific concussion totals (broadcast to student level)
	gen conc_grade9  = sy_concussions if GradeLevel == 9
	gen conc_grade10 = sy_concussions if GradeLevel == 10

	bysort research_id: egen total_conc   = total(sy_concussions)
	bysort research_id: egen total_conc9  = total(conc_grade9)
	bysort research_id: egen total_conc10 = total(conc_grade10)

	* Group 1: Never concussed
	* Group 2: First concussion in 10th grade (none in 9th, at least 1 in 10th)
	gen group = .
	replace group = 1 if total_conc == 0
	replace group = 2 if total_conc9 == 0 & total_conc10 >= 1

	keep if inrange(GradeLevel, 9, 12) & !missing(annual_gpa) & !missing(group)

	* Count unique students per group for legend labels
	preserve
		bysort research_id: keep if _n == 1
		count if group == 1 & male == 1
		local n_m_nc = r(N)
		count if group == 2 & male == 1
		local n_m_c  = r(N)
		count if group == 1 & male == 0
		local n_f_nc = r(N)
		count if group == 2 & male == 0
		local n_f_c  = r(N)
	restore

	* Collapse to mean and SE by grade, group, and sex
	collapse (mean) mean_gpa = annual_gpa ///
	         (semean) se_gpa = annual_gpa, ///
	    by(GradeLevel group male)

	* 95% CI
	gen ci_lo = mean_gpa - 1.96 * se_gpa
	gen ci_hi = mean_gpa + 1.96 * se_gpa

	* Offset x positions for side-by-side bars
	gen x_pos = GradeLevel - 0.2 if group == 1
	replace x_pos = GradeLevel + 0.2 if group == 2

	* --- Panel A: Males ---
	twoway ///
	    (bar mean_gpa x_pos if male == 1 & group == 1, ///
	        barwidth(0.35) fcolor(navy%70) lcolor(navy%70)) ///
	    (bar mean_gpa x_pos if male == 1 & group == 2, ///
	        barwidth(0.35) fcolor(maroon%70) lcolor(maroon%70)) ///
	    (rcap ci_lo ci_hi x_pos if male == 1 & group == 1, ///
	        lcolor(navy) lwidth(medium)) ///
	    (rcap ci_lo ci_hi x_pos if male == 1 & group == 2, ///
	        lcolor(maroon) lwidth(medium)), ///
	    xlabel(9 "9th" 10 "10th" 11 "11th" 12 "12th") ///
	    xtitle("Grade Level") ///
	    ytitle("Annual GPA") ///
	    legend(order(1 "Never concussed" 2 "First concussion in 10th grade") ///
	           pos(6) cols(2) region(lcolor(none) fcolor(none))) ///
	    title("Males") ///
	    ytitle("Annual GPA", margin(medium)) ///
	    yscale(range(2.4 3.2)) ylabel(2.4(0.2)3.2) ///
	    graphregion(color(white)) plotregion(color(white)) bgcolor(white) ///
	    name(fig3_male, replace)

	* --- Panel B: Females ---
	twoway ///
	    (bar mean_gpa x_pos if male == 0 & group == 1, ///
	        barwidth(0.35) fcolor(navy%70) lcolor(navy%70)) ///
	    (bar mean_gpa x_pos if male == 0 & group == 2, ///
	        barwidth(0.35) fcolor(maroon%70) lcolor(maroon%70)) ///
	    (rcap ci_lo ci_hi x_pos if male == 0 & group == 1, ///
	        lcolor(navy) lwidth(medium)) ///
	    (rcap ci_lo ci_hi x_pos if male == 0 & group == 2, ///
	        lcolor(maroon) lwidth(medium)), ///
	    xlabel(9 "9th" 10 "10th" 11 "11th" 12 "12th") ///
	    xtitle("Grade Level") ///
	    legend(order(1 "Never concussed" 2 "First concussion in 10th grade") ///
	           pos(6) cols(2) region(lcolor(none) fcolor(none))) ///
	    title("Females") ///
	    ytitle("Annual GPA", margin(medium)) ///
	    yscale(range(2.4 3.2)) ylabel(2.4(0.2)3.2) ///
	    graphregion(color(white)) plotregion(color(white)) bgcolor(white) ///
	    name(fig3_female, replace)

	* Combine panels side by side
	graph combine fig3_male fig3_female, cols(2) ///
	    graphregion(color(white)) ///
	    xsize(14) ysize(6) ///
	    name(fig3_combined, replace)

	cap mkdir "figures"
	graph export "figures/fig3_gpa_grade_concussion.png", as(png) replace

}


* -----------------------------------------------------------------------
* TABLE 2: Summary statistics by concussion group
* -----------------------------------------------------------------------
if `sumstats_by_conc' == 1 {

	use "Data/Processed Data/regdata_new.dta", clear

	* create a never treated group
	gen never_treated = 0
	replace never_treated = 1 if ever_treated == 0

	* create a single concussion group
	bysort research_id: egen max_cum = max(cum_concussions)
	gen single_concussed = (max_cum == 1)

	* create a group variable where 0 = never treated, 1 = 1 concussion, 2 = 2+ concussions
	gen conc_group = .
	replace conc_group = 0 if never_treated == 1
	replace conc_group = 1 if single_concussed == 1
	replace conc_group = 2 if ever_treated2 == 1

	label define conc_group 0 "0 Concussions" 1 "1+ Concussion" 2 "2+ Concussions"
	label values conc_group conc_group

	* variable labels to match Table 2
	label var age                "Age"
	label var male               "Male"
	label var econ_disadvantaged "Economically Disadvantaged"
	label var ELLStatus          "ELL Status"
	label var SPEDStatus         "SPED Status"
	label var ADHD               "ADHD"
	label var AUT                "Autism"
	label var Dyslexia           "Dyslexia"
	label var Wrestling          "Wrestling"
	label var Volleyball         "Volleyball"
	label var track_field        "Track and Field"
	label var martial_arts       "Martial Arts"
	label var Tennis             "Tennis"
	label var Swimming           "Swimming"
	label var Softball           "Softball"
	label var Soccer             "Soccer"
	label var Paddling           "Paddling"
	label var Football           "Football"
	label var Cheerleading       "Cheerleading"
	label var Basketball         "Basketball"
	label var Baseball           "Baseball"
	label var annual_gpa         "Annual GPA"
	label var math_gpa           "Math GPA"
	label var eng_gpa            "English GPA"
	label var sci_gpa            "Science GPA"
	label var AP                 "AP Courseload"
	label var offense            "Behavioral Offense"
	label var days_absent        "Days Absent"

	* list of covariates to display in summary stats table
	local covars age male econ_disadvantaged ELLStatus SPEDStatus ADHD AUT Dyslexia Wrestling Volleyball track_field martial_arts Tennis Swimming Softball Soccer Paddling Football Cheerleading Basketball Baseball annual_gpa math_gpa eng_gpa sci_gpa offense days_absent

	eststo clear
	local stored_ests ""
	forvalues g = 0/2 {

	    * skip groups with no observations (e.g. never-treated may be absent from analysis sample)
	    quietly count if conc_group == `g'
	    if r(N) == 0 continue

	    * tag one observation per student
	    egen tag_student = tag(research_id) if conc_group==`g'

	    * count distinct students
	    quietly count if tag_student==1
	    local n_students = r(N)

	    * summary stats
	    estpost summarize `covars' if conc_group==`g'

	    * add distinct student count
	    estadd scalar students = `n_students'

	    eststo g`g'
	    local stored_ests "`stored_ests' g`g'"

	    drop tag_student
	}

	* LaTeX export: mean and sd for each covariate, columns for non-empty groups
	esttab `stored_ests' using "tables/sumstats_concussions.tex", replace ///
		title("Summary Statistics by Total Concussions") ///
		cells("mean(fmt(3)) sd(fmt(3))") ///
		collabels("Mean" "SD") ///
		mgroups("Never Concussed" "One Concussion" "2+ Concussions", ///
			pattern(1 1 1) span ///
			prefix(\multicolumn{@span}{c}{) suffix(}) ///
			erepeat(\cmidrule(lr){@span})) ///
		label nonumber nomtitle ///
		stats(N students, labels("Student-Years" "Unique Students") fmt(%9.0f)) ///
		booktabs ///
		refcat( ///
			age        "\addlinespace \textbf{Student Demographics}" ///
			Wrestling  "\addlinespace \textbf{Sports Participation}" ///
			annual_gpa "\addlinespace \textbf{Academic variables}" ///
			offense    "\addlinespace \textbf{Behavioral variables}" ///
			, nolabel )

}


* -----------------------------------------------------------------------
* TABLE 4: CS DiD — effects of a first concussion
* -----------------------------------------------------------------------
if `cs_did_single' == 1 {

	use "Data/Processed Data/regdata_new.dta", clear

	preserve
	keep if ever_treated==1 /*this is so the regression runs faster*/

	foreach y in annual_gpa math_gpa eng_gpa sci_gpa offense days_absent {

		*cs-did regression of cumulative concussions on cumulative gpa
		csdid `y'  male i.ethnicity  ELLStatus SPEDStatus econ_disadvantaged Wrestling Volleyball track_field martial_arts Tennis Swimming Softball Soccer Paddling Football Cheerleading Basketball Baseball ADHD AUT Dyslexia BirthYear if ever_treated==1, ivar(research_id) time(sy) gvar(g) method(dripw) vce(cluster research_id)

		* Count student-year observations (capture from csdid before estat overwrites e(N))
		scalar N1 = e(N)

		estat event, estore(reg_`y')

		estadd scalar N = N1 : reg_`y'

		* Count UNIQUE individuals actually used in estimation
	    egen tag_id = tag(research_id) if e(sample)
	    count if tag_id
	    scalar N_unique = r(N)

	    * Add scalar to stored estimation
	    estadd scalar N_unique = N_unique : reg_`y'

	    * Clean up temporary variable
	    drop tag_id

	}

	restore

	esttab reg_annual_gpa reg_math_gpa reg_eng_gpa reg_sci_gpa reg_offense reg_days_absent using "tables/csdid_eventstudy.tex", replace ///
	    booktabs se label ///
	    b(%9.3f) se(%9.3f) ///
	    mtitles("GPA" "Math GPA" "Eng GPA" "Sci GPA" "Behavior Offense" "Days Absent" ) ///
		title("Effects of a First Concussion on Academic and Behavioral Outcomes") ///
		coeflabel( ///
			Pre_avg		"Pre-Treatment Avg" ///
	        Post_avg    "Post-Treatment Avg" ///
			Tm2			"t-2" ///
	        Tm1         "t–1" ///
	        Tp0         "t" ///
	        Tp1         "t+1" ///
			Tp2			"t+2" ///
	    ) ///
		stats(N N_unique, labels("Student-Years" "Unique Students") fmt(%9.0f)) ///
	    star(* 0.10 ** 0.05 *** 0.01)

}


* -----------------------------------------------------------------------
* TABLE 5: CS DiD — effects of a second concussion
* -----------------------------------------------------------------------
if `cs_did_multiple' == 1 {

	use "Data/Processed Data/regdata_new.dta", clear

	preserve
	keep if ever_treated2 == 1

	foreach y in annual_gpa math_gpa eng_gpa sci_gpa offense days_absent {

		*cs-did regression of cumulative concussions on cumulative gpa
		csdid `y' male i.ethnicity  ELLStatus SPEDStatus econ_disadvantaged Wrestling Volleyball track_field martial_arts Tennis Swimming Softball Soccer Paddling Football Cheerleading Basketball Baseball ADHD AUT Dyslexia BirthYear if ever_treated2==1, ivar(research_id) time(sy) gvar(g2) method(dripw) vce(cluster research_id)

		* Count student-year observations (capture from csdid before estat overwrites e(N))
		scalar N1 = e(N)

		estat event, estore(reg_`y')

		estadd scalar N = N1 : reg_`y'

		* Count UNIQUE individuals actually used in estimation
	    egen tag_id = tag(research_id) if e(sample)
	    count if tag_id
	    scalar N_unique = r(N)

	    * Add scalar to stored estimation
	    estadd scalar N_unique = N_unique : reg_`y'

	    * Clean up temporary variable
	    drop tag_id
	}

	restore

	esttab reg_annual_gpa reg_math_gpa reg_eng_gpa reg_sci_gpa reg_offense reg_days_absent using "tables/csdid_eventstudy2.tex", replace ///
	    booktabs se label ///
	    b(%9.3f) se(%9.3f) ///
	    mtitles("GPA" "Math GPA" "Eng GPA" "Sci GPA" "Behavior Offense" "Days Absent" ) ///
		title("Effects of Multiple Concussions on Academic and Behavioral Outcomes") ///
		coeflabel( ///
			Pre_avg		"Pre-Treatment Avg" ///
	        Post_avg    "Post-Treatment Avg" ///
			Tm2			"t-2" ///
	        Tm1         "t–1" ///
	        Tp0         "t" ///
	        Tp1         "t+1" ///
			Tp2			"t+2" ///
	    ) ///
		stats(N N_unique, labels("Student-Years" "Unique Students") fmt(%9.0f)) ///
	    star(* 0.10 ** 0.05 *** 0.01)

}


* -----------------------------------------------------------------------
* TABLE 3: Individual fixed effects (IDFE) model
* -----------------------------------------------------------------------
if `idfe' == 1 {

	use "Data/Processed Data/regdata_new.dta", clear

	* run regressions
	eststo clear

	foreach var in annual_gpa math_gpa eng_gpa sci_gpa offense days_absent {

	eststo: reghdfe `var' sy_conc_lag  i.GradeLevel  ELLStatus SPEDStatus econ_disadvantaged Wrestling Volleyball track_field martial_arts Tennis Swimming Softball Soccer Paddling Football Cheerleading Basketball Baseball, absorb(SCHOOL_CODE sy research_id) vce(cluster research_id)

	}

	esttab using "tables/idfe.tex", replace ///
    booktabs se label ///
    b(%9.3f) se(%9.3f) ///
	mtitle("GPA" "Math GPA" "Eng GPA" "Sci GPA" "Behavior Offense" "Days Absent") ///
	keep(sy_conc_lag econ_disadvantaged ELLStatus SPEDStatus) ///
	title("Effect of Lagged School Year Concussions on Academic and Behavioral Outcomes: Individual Fixed Effects Model") ///
	coeflabel( ///
		sy_conc_lag			"School Year Concussions (t-1)" ///
		econ_disadvantaged		"Economic Disadvantage" ///
		ELLStatus				"English Language Learner" ///
		SPEDStatus 					"Special Education" ///
		) ///
	stats(N, labels("Student-Years") fmt(%9.0f)) ///
    star(* 0.10 ** 0.05 *** 0.01)

}


* -----------------------------------------------------------------------
* TABLE A1: Heterogeneous effects of concussions
* -----------------------------------------------------------------------
if `heterogeneity' == 1 {

	use "Data/Processed Data/regdata_new.dta", clear

	*run regressions
	eststo clear

	* Col 1: Male x Concussions (t-1)
	eststo m1: reghdfe annual_gpa c.sy_conc_lag##i.male ///
	    i.ethnicity ELLStatus SPEDStatus econ_disadvantaged ///
	    Wrestling Volleyball track_field martial_arts Tennis Swimming Softball Soccer ///
	    Paddling Football Cheerleading Basketball Baseball ADHD AUT Dyslexia BirthYear, ///
	    absorb(SCHOOL_CODE##sy) vce(cluster research_id)

	* Col 2: Econ. Disadv. x Concussions (t-1)
	eststo m2: reghdfe annual_gpa c.sy_conc_lag##i.econ_disadvantaged ///
	    male i.ethnicity ELLStatus SPEDStatus ///
	    Wrestling Volleyball track_field martial_arts Tennis Swimming Softball Soccer ///
	    Paddling Football Cheerleading Basketball Baseball ADHD AUT Dyslexia BirthYear, ///
	    absorb(SCHOOL_CODE##sy) vce(cluster research_id)

	* Col 3: ELL x Concussions (t-1)
	eststo m3: reghdfe annual_gpa c.sy_conc_lag##i.ELLStatus ///
	    male i.ethnicity SPEDStatus econ_disadvantaged ///
	    Wrestling Volleyball track_field martial_arts Tennis Swimming Softball Soccer ///
	    Paddling Football Cheerleading Basketball Baseball ADHD AUT Dyslexia BirthYear, ///
	    absorb(SCHOOL_CODE##sy) vce(cluster research_id)

	* Col 4: SPED x Concussions (t-1)
	eststo m4: reghdfe annual_gpa c.sy_conc_lag##i.SPEDStatus ///
	    male i.ethnicity ELLStatus econ_disadvantaged ///
	    Wrestling Volleyball track_field martial_arts Tennis Swimming Softball Soccer ///
	    Paddling Football Cheerleading Basketball Baseball ADHD AUT Dyslexia BirthYear, ///
	    absorb(SCHOOL_CODE##sy) vce(cluster research_id)

	* Col 5: ADHD x Concussions (t-1)
	eststo m5: reghdfe annual_gpa c.sy_conc_lag##i.ADHD ///
	    SPEDStatus male i.ethnicity ELLStatus econ_disadvantaged ///
	    Wrestling Volleyball track_field martial_arts Tennis Swimming Softball Soccer ///
	    Paddling Football Cheerleading Basketball Baseball AUT Dyslexia BirthYear, ///
	    absorb(SCHOOL_CODE##sy) vce(cluster research_id)

	* Col 6: Autism x Concussions (t-1)
	eststo m6: reghdfe annual_gpa c.sy_conc_lag##i.AUT ///
	    SPEDStatus male i.ethnicity ELLStatus econ_disadvantaged ///
	    Wrestling Volleyball track_field martial_arts Tennis Swimming Softball Soccer ///
	    Paddling Football Cheerleading Basketball Baseball ADHD Dyslexia BirthYear, ///
	    absorb(SCHOOL_CODE##sy) vce(cluster research_id)

	* Col 7: Dyslexia x Concussions (t-1)
	eststo m7: reghdfe annual_gpa c.sy_conc_lag##i.Dyslexia ///
	    SPEDStatus male i.ethnicity ELLStatus econ_disadvantaged ///
	    Wrestling Volleyball track_field martial_arts Tennis Swimming Softball Soccer ///
	    Paddling Football Cheerleading Basketball Baseball AUT ADHD BirthYear, ///
	    absorb(SCHOOL_CODE##sy) vce(cluster research_id)

	*------------------------------------------------------------
	* Export LaTeX: interactions + "core dummies" in every column
	*------------------------------------------------------------
	esttab m1 m2 m3 m4 m5 m6 m7 using "tables/heterogeneity.tex", replace ///
	    b(%9.3f) se(%9.3f) ///
	    star(* 0.10 ** 0.05 *** 0.01) ///
	    compress nonotes ///
	    mtitle("Male" "Econ. Disadv." "ELL" "SPED" "ADHD" "Autism" "Dyslexia") ///
	    keep( ///
	        sy_conc_lag ///
	        1.male 1.econ_disadvantaged 1.ELLStatus 1.SPEDStatus 1.ADHD 1.AUT 1.Dyslexia ///
	        1.male#c.sy_conc_lag ///
	        1.econ_disadvantaged#c.sy_conc_lag ///
	        1.ELLStatus#c.sy_conc_lag ///
	        1.SPEDStatus#c.sy_conc_lag ///
	        1.ADHD#c.sy_conc_lag ///
	        1.AUT#c.sy_conc_lag ///
	        1.Dyslexia#c.sy_conc_lag ///
	    ) ///
	    varlabels( ///
	        sy_conc_lag "Concussions (t-1)" ///
	        1.male "Male" ///
	        1.econ_disadvantaged "Economically Disadvantaged" ///
	        1.ELLStatus "English Language Learner" ///
	        1.SPEDStatus "Special Education" ///
	        1.ADHD "ADHD" ///
	        1.AUT "Autism" ///
	        1.Dyslexia "Dyslexia" ///
	        1.male#c.sy_conc_lag "Male $\times$ Concussions (t-1)" ///
	        1.econ_disadvantaged#c.sy_conc_lag "Economically Disadvantaged $\times$ Concussions (t-1)" ///
	        1.ELLStatus#c.sy_conc_lag "English Language Learner $\times$ Concussions (t-1)" ///
	        1.SPEDStatus#c.sy_conc_lag "Special Education $\times$ Concussions (t-1)" ///
	        1.ADHD#c.sy_conc_lag "ADHD $\times$ Concussions (t-1)" ///
	        1.AUT#c.sy_conc_lag "Autism $\times$ Concussions (t-1)" ///
	        1.Dyslexia#c.sy_conc_lag "Dyslexia $\times$ Concussions (t-1)" ///
	    ) ///
	    stats(N, fmt(%9.0f) label("Student-Years"))

}
