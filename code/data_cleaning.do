* ============================================================
* HCAMP Concussion Study — Unified Data Cleaning
* ============================================================
* Inputs:  Data/raw_data/ (HCAMP CSV + P-20 Excel files)
* Outputs: Data/Processed Data/hcamp_cleaned.dta  (intermediate)
*          Data/Processed Data/regdata_new.dta     (analysis-ready)
*
* SETUP: Change the path below to your local HCAMP project root.
*        All file paths in this script are relative to that folder.
* ============================================================

cd "YOUR_HCAMP_PATH_HERE"


* ============================================================
* PART A: HCAMP DATA CLEANING
* ============================================================

import delimited "Data/raw_data/DXP1027_HCAMP_Table0-Matched Participant Data_2010-2024.csv", clear

destring sy research_id usereducationlevel useryearsplaying ///
    usernumberofconcussions userconcussiontype1 userconcussiontype2 ///
    userconcussiontype3 userconcussiontype4 usertotalgamesmissed ///
    userhoursofsleeplastnight, replace ignore("Skipped") force

drop if research_id == . | sy == .
format research_id %15.0f
sort research_id sy

* --- Sport dummies ---
gen Wrestling    = (usercurrentsport == "Wrestling")
gen Volleyball   = (usercurrentsport == "Volleyball")
gen track_field  = (usercurrentsport == "Track & Field")
gen Tennis       = (usercurrentsport == "Tennis")
gen Swimming     = (usercurrentsport == "Swimming")
gen Softball     = (usercurrentsport == "Softball")
gen Soccer       = (usercurrentsport == "Soccer")
gen martial_arts = (usercurrentsport == "Martial Arts")
gen Paddling     = (usercurrentsport == "Paddling")
gen Football     = inlist(usercurrentsport, "Football Varsity", "Football Middle School", ///
                    "Football Junior Varsity", "Football Freshman", "Football")
gen Cheerleading = (usercurrentsport == "Cheerleading")
gen Basketball   = (usercurrentsport == "Basketball")
gen Baseball     = (usercurrentsport == "Baseball")

label variable track_field  "Track and Field"
label variable martial_arts "Martial Arts"

* --- Health dummies ---
gen ADHD     = (addadhd  == "Yes")
gen AUT      = (autism   == "Yes")
gen Dyslexia = (dyslexia == "Yes")
label variable AUT "Autism"

* --- Parse test date ---
gen strL td_clean = strtrim(testdate)
gen byte mm = .
gen byte dd = .
gen int  yy = .
quietly replace mm = real(ustrregexs(1)) if ustrregexm(td_clean, "^([0-9]{1,2})/([0-9]{1,2})/([0-9]{2,4})$")
quietly replace dd = real(ustrregexs(2)) if ustrregexm(td_clean, "^([0-9]{1,2})/([0-9]{1,2})/([0-9]{2,4})$")
quietly replace yy = real(ustrregexs(3)) if ustrregexm(td_clean, "^([0-9]{1,2})/([0-9]{1,2})/([0-9]{2,4})$")
replace yy = yy + 2000 if yy < 60
replace yy = yy + 1900 if inrange(yy, 60, 99)
gen int    test_date  = mdy(mm, dd, yy)
gen double testdate_d = date(testdate, "MDY")
format %td test_date testdate_d

* One test per student per day
bysort research_id test_date: keep if _n == 1

* Annual concussion count: each Post-Injury 1 test = one new concussion
gen post_injury_1 = (testtype == "Post-Injury 1")

preserve
    collapse (sum) sy_concussions = post_injury_1, by(research_id sy)
    tempfile sy_totals
    save `sy_totals'
restore
merge m:1 research_id sy using `sy_totals', nogen

* Keep earliest test per student-year
bysort research_id sy (testdate_d): keep if _n == 1

* Self-reported concussions from earliest test in year
rename usernumberofconcussions total_concussions

* Keep only analysis-relevant variables
keep research_id sy sy_concussions total_concussions ///
     Wrestling Volleyball track_field martial_arts Tennis Swimming ///
     Softball Soccer Paddling Football Cheerleading Basketball Baseball ///
     ADHD AUT Dyslexia

sort research_id sy
save "Data/Processed Data/hcamp_cleaned.dta", replace


* ============================================================
* PART B: P-20 DATA CLEANING
* ============================================================

* --- Demographics ---
import excel "Data/raw_data/DXP1027_HCAMP_Table1-Demographics.xlsx", ///
    sheet("Table1_Demographics") firstrow clear
rename (RESEARCH_ID SY GradeLevel) (research_id sy GradeLevel_demo)
format research_id %15.0f
tempfile temp_Demographics
save `temp_Demographics'

* --- Academic data ---
import excel "Data/raw_data/DXP1027_HCAMP_Table2-Academics.xlsx", ///
    sheet("Table2_Academics") firstrow clear
rename (RESEARCH_ID SY) (research_id sy)
format research_id %15.0f
sort research_id sy
merge 1:1 research_id sy using `temp_Demographics'
keep if _merge == 3
drop _merge
tempfile temp_Academics
save `temp_Academics'

* --- Behavioral data ---
import excel "Data/raw_data/DXP1027_HCAMP_Table3-Behavioral.xlsx", ///
    sheet("Table3-Behavioral") firstrow clear
rename (RESEARCH_ID SY) (research_id sy)
format research_id %15.0f
sort research_id sy
merge 1:1 research_id sy using `temp_Academics'
keep if _merge == 3
drop _merge
sort research_id sy
tempfile temp_Behavioral
save `temp_Behavioral'

* --- Science GPA ---
import excel "Data/raw_data/DXP1027_HCAMP_Table2c-Academics (Science Courses).xlsx", ///
    sheet("Table2c_Science_Courses") firstrow clear
format RESEARCH_ID %15.0f
gen byte number_sci = .
replace number_sci = 4 if Grade == "A"
replace number_sci = 3 if Grade == "B"
replace number_sci = 2 if Grade == "C"
replace number_sci = 1 if Grade == "D"
replace number_sci = 0 if Grade == "F"
replace number_sci = . if inlist(upper(trim(Grade)), "I", "S", "U")
destring CreditsEarned, replace force
bysort RESEARCH_ID SY: gen gradepoint_sci = number_sci * CreditsEarned
format RESEARCH_ID %15.0f
bysort RESEARCH_ID SY: egen double total_gradepts_sci  = total(gradepoint_sci)
bysort RESEARCH_ID SY: egen double total_creditpts_sci = total(CreditsEarned)
gen double sci_gpa = total_gradepts_sci / total_creditpts_sci
rename (RESEARCH_ID SY CreditsEarned) (research_id sy CreditsEarned_sci)
* AP indicator — flag any AP course, then collapse to student-year max
gen strL title_u = upper(TitleStnd)
gen byte AP_sci = 0
replace AP_sci = 1 if strpos(title_u, "ADVANCED PLACEMENT")
replace AP_sci = 1 if substr(title_u,1,3) == "AP "  | substr(title_u,1,3) == "AP-"  ///
                    | strpos(title_u, " AP ")         | strpos(title_u, " AP-")       ///
                    | strpos(title_u, "(AP)")         | strpos(title_u, " AP)")
replace AP_sci = 1 if strpos(title_u, "PRE-AP") | strpos(title_u, "PRE AP")
bysort research_id sy: egen AP_sci_any = max(AP_sci)
keep research_id sy sci_gpa gradepoint_sci CreditsEarned_sci AP_sci_any
format research_id %15.0f
bysort research_id sy: keep if _n == 1
sort research_id sy
merge 1:1 research_id sy using `temp_Behavioral'
drop _merge
sort research_id sy
tempfile temp_Science
save `temp_Science'

* --- Math GPA ---
import excel "Data/raw_data/DXP1027_HCAMP_Table2b-Academics (Math Courses).xlsx", ///
    sheet("Table2b_Math_Courses") firstrow clear
gen byte number_math = .
replace number_math = 4 if Grade == "A"
replace number_math = 3 if Grade == "B"
replace number_math = 2 if Grade == "C"
replace number_math = 1 if Grade == "D"
replace number_math = 0 if Grade == "F"
replace number_math = . if inlist(upper(trim(Grade)), "I", "S", "U")
destring CreditsEarned, replace force
bysort RESEARCH_ID SY: gen gradepoint_math = number_math * CreditsEarned
format RESEARCH_ID %15.0f
bysort RESEARCH_ID SY: egen double total_gradepts_math  = total(gradepoint_math)
bysort RESEARCH_ID SY: egen double total_creditpts_math = total(CreditsEarned)
gen double math_gpa = total_gradepts_math / total_creditpts_math
rename (RESEARCH_ID SY CreditsEarned) (research_id sy CreditsEarned_math)
* AP indicator — flag any AP course, then collapse to student-year max
gen strL title_u = upper(TitleStnd)
gen byte AP_math = 0
replace AP_math = 1 if strpos(title_u, "ADVANCED PLACEMENT")
replace AP_math = 1 if substr(title_u,1,3) == "AP "  | substr(title_u,1,3) == "AP-"  ///
                     | strpos(title_u, " AP ")         | strpos(title_u, " AP-")       ///
                     | strpos(title_u, "(AP)")         | strpos(title_u, " AP)")
replace AP_math = 1 if strpos(title_u, "PRE-AP") | strpos(title_u, "PRE AP")
bysort research_id sy: egen AP_math_any = max(AP_math)
keep research_id sy math_gpa gradepoint_math CreditsEarned_math AP_math_any
format research_id %15.0f
bysort research_id sy: keep if _n == 1
sort research_id sy
merge 1:1 research_id sy using `temp_Science'
drop _merge
sort research_id sy
tempfile temp_Maths
save `temp_Maths'

* --- English GPA ---
import excel "Data/raw_data/DXP1027_HCAMP_Table2a-Academics (English Courses).xlsx", ///
    sheet("Table2a_English_Courses") firstrow clear
format RESEARCH_ID %15.0f
gen byte number_eng = .
replace number_eng = 4 if Grade == "A"
replace number_eng = 3 if Grade == "B"
replace number_eng = 2 if Grade == "C"
replace number_eng = 1 if Grade == "D"
replace number_eng = 0 if Grade == "F"
replace number_eng = . if inlist(upper(trim(Grade)), "I", "S", "U")
destring CreditsEarned, replace force
bysort RESEARCH_ID SY: gen gradepoint_eng = number_eng * CreditsEarned
format RESEARCH_ID %15.0f
bysort RESEARCH_ID SY: egen double total_gradepts_eng  = total(gradepoint_eng)
bysort RESEARCH_ID SY: egen double total_creditpts_eng = total(CreditsEarned)
gen double eng_gpa = total_gradepts_eng / total_creditpts_eng
rename (RESEARCH_ID SY CreditsEarned) (research_id sy CreditsEarned_eng)
* AP indicator — flag any AP course, then collapse to student-year max
gen strL title_u = upper(TitleStnd)
gen byte AP_eng = 0
replace AP_eng = 1 if strpos(title_u, "ADVANCED PLACEMENT")
replace AP_eng = 1 if substr(title_u,1,3) == "AP "  | substr(title_u,1,3) == "AP-"  ///
                    | strpos(title_u, " AP ")         | strpos(title_u, " AP-")       ///
                    | strpos(title_u, "(AP)")         | strpos(title_u, " AP)")
replace AP_eng = 1 if strpos(title_u, "PRE-AP") | strpos(title_u, "PRE AP")
bysort research_id sy: egen AP_eng_any = max(AP_eng)
keep research_id sy eng_gpa gradepoint_eng CreditsEarned_eng AP_eng_any
format research_id %15.0f
bysort research_id sy: keep if _n == 1
sort research_id sy
merge 1:1 research_id sy using `temp_Maths'
keep if _merge == 3
drop _merge
tempfile temp_English
save `temp_English'


* ============================================================
* PART C: COMBINE SUBJECT FILES AND CLEAN DEMOGRAPHICS
* ============================================================

* --- Combined annual GPA ---
bysort research_id sy: egen double total_gradepts  = ///
    total(gradepoint_sci + gradepoint_math + gradepoint_eng)
bysort research_id sy: egen double total_creditpts = ///
    total(CreditsEarned_sci + CreditsEarned_math + CreditsEarned_eng)
gen double annual_gpa = total_gradepts / total_creditpts

* --- AP: 1 if student took any AP course in any subject that year ---
gen byte AP = max(AP_sci_any, AP_math_any, AP_eng_any)
replace AP = 0 if missing(AP)

* --- Collapse to one row per student-year ---
bysort research_id sy: gen byte tag = (_n == 1)
keep if tag
drop tag

sort research_id sy

* --- Cumulative GPA (running across school years) ---
bysort research_id: gen double cum_gradepts  = sum(total_gradepts)
bysort research_id: gen double cum_creditpts = sum(total_creditpts)
gen double cumulative_gpa = cum_gradepts / cum_creditpts
replace cumulative_gpa = . if cum_creditpts == 0

* --- Demographics ---
tab Ethnicity, gen(eth_)
rename eth_1 asian
rename eth_2 filipino
rename eth_3 nativehawaiian
rename eth_4 other
rename eth_5 pacificislander
rename eth_6 white

tab Gender, gen(gender_)
rename gender_1 female
rename gender_2 male

gen age = sy - BirthYear

gen Repeated = 0
replace Repeated = 1 if RepeatedaGradeLevel == "Y"

destring GradeLevel, replace force
destring SCHOOL_CODE DOE_MATH_PL DOE_MATH_SS DOE_READING_PL DOE_READING_SS ///
    DOE_ACT_COMPOSITE DOE_ACT_ENGLISH DOE_ACT_MATH DOE_ACT_SCIENCE, replace force

tab GraduationStatus, gen(status_)
rename status_1 cert_of_compl
rename status_2 Continuing
rename status_3 Dropout
rename status_4 Graduated
rename status_5 Transfer

* --- Behavioral variables ---
rename (DOE_DAYS_ABSENT DOE_INSTRUCTIONAL_SCHOOL_DAYS ///
        DOE_CLASSA_OFFENSE_CNT DOE_CLASSB_OFFENSE_CNT) ///
       (days_absent school_days classA_offense classB_offense)
replace classA_offense = 0 if classA_offense == .
replace classB_offense = 0 if classB_offense == .

sort research_id sy


* ============================================================
* PART D: MERGE IN HCAMP DATA
* ============================================================

merge 1:1 research_id sy using "Data/Processed Data/hcamp_cleaned.dta"
drop if _merge == 2   // drop HCAMP-only rows (pre-HS years with no P-20 record)
drop _merge

rename (EconomicallyDisadvantagedStatu DOE_MATH_SS DOE_READING_SS) ///
       (econ_disadvantaged math_score_ss reading_score_ss)

encode Ethnicity, gen(ethnicity)

* Zero out missing HCAMP variables for students with no HCAMP record
replace sy_concussions = 0 if missing(sy_concussions)

foreach v in Wrestling Volleyball Tennis Swimming Softball Soccer Paddling ///
             Football Cheerleading Basketball Baseball martial_arts track_field ///
             ADHD AUT Dyslexia ELLStatus SPEDStatus econ_disadvantaged {
    replace `v' = 0 if missing(`v')
}

sort research_id sy


* ============================================================
* PART E: ADDITIONAL CLEANING (Rachel's edits)
* ============================================================

* Drop students observed for more than 6 school years
bysort research_id: gen years_in_data = _N
keep if years_in_data <= 6
drop years_in_data

* Cumulative concussions: running sum of HS concussions only
bysort research_id (sy): gen cum_concussions = sum(sy_concussions)

* Behavioral offense: count of Class A + Class B offenses
gen offense = classA_offense + classB_offense

* Drop intermediate computation variables
drop gradepoint_sci gradepoint_math gradepoint_eng          ///
     CreditsEarned_sci CreditsEarned_math CreditsEarned_eng  ///
     total_gradepts total_creditpts cum_gradepts cum_creditpts ///
     AP_sci_any AP_math_any AP_eng_any


* ============================================================
* VARIABLE LABELS
* ============================================================

label var sy               "School year (start year)"
label var annual_gpa       "Annual GPA"
label var math_gpa         "Math GPA"
label var eng_gpa          "English GPA"
label var sci_gpa          "Science GPA"
label var cumulative_gpa   "Cumulative GPA (running)"
label var AP               "Any AP course (any subject)"
label var days_absent      "Days absent"
label var offense          "Total behavioral offenses (Class A + B)"
label var classA_offense   "Class A offenses (count)"
label var classB_offense   "Class B offenses (count)"
label var sy_concussions   "Concussions in school year"
label var cum_concussions  "Cumulative concussions to date"
label var total_concussions "Self-reported total concussions (HCAMP assessment)"
label var male             "Male"
label var econ_disadvantaged "Economically disadvantaged"
label var ELLStatus        "English Language Learner"
label var SPEDStatus       "Special Education"
label var ADHD             "ADHD"
label var AUT              "Autism"
label var Dyslexia         "Dyslexia"
label var age              "Age (school year - birth year)"
label var SCHOOL_CODE      "School code"
label var track_field      "Track and Field"
label var martial_arts     "Martial Arts"

sort research_id sy


* ============================================================
* PART F: TREATMENT VARIABLE CONSTRUCTION
* ============================================================

* ---- 1+ Concussions ----

* Set panel structure
xtset research_id sy

* Indicator: student has any cumulative concussion
gen treated = cum_concussions > 0

* Group variable: first school year student was treated (0 = never treated)
bysort research_id (sy): egen g = min(cond(treated == 1, sy, .))

* Never-treated units get 0
replace g = 0 if missing(g)

label var g "First concussion school year (0 = never treated)"
tab g

* Ever-treated indicator: 1 if student had 1–10 cumulative concussions at any point
bysort research_id: egen ever_treated = max(cum_concussions > 0 & cum_concussions <= 10)


* ---- 2+ Concussions ----

* Indicator: student has 2+ cumulative concussions
gen treated2 = cum_concussions > 1 & cum_concussions != .

* Group variable: first school year student reached 2+ concussions (0 = never treated)
bysort research_id (sy): egen g2 = min(cond(treated2 == 1, sy, .))

* Never-treated units get 0
replace g2 = 0 if missing(g2)

label var g2 "Second concussion school year (0 = never treated)"
tab g2

* Ever-treated indicator: 1 if student had 2–10 cumulative concussions at any point
bysort research_id: egen ever_treated2 = max(cum_concussions > 1 & cum_concussions <= 10)


* ---- Drop Problematic Observations ----
/* Students whose treatment timing (g - sy) falls outside a plausible window are
   likely the result of P-20 incorrectly merging students with the same name
   across different enrollment periods. */

gen t = g - sy
drop if t < -9 & g > 0
drop if t > 6

* Drop cohort with insufficient overlap that distorts regression estimates
drop if g == 2013 & sy == 2012


* ---- Create Lagged Concussion Variable ----
xtset research_id sy

gen sy_conc_lag = L1.sy_concussions

save "Data/Processed Data/regdata_new.dta", replace
