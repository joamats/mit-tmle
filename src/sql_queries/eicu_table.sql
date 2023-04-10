
WITH tt3 AS (
    WITH tt2 AS (
      WITH tt AS (

SELECT yug.patientunitstayid, yug.patienthealthsystemstayid,
yug.gender,yug.age,
yug.hospitalid,yug.wardid,
yug.apacheadmissiondx,yug.admissionheight,
yug.hospitaladmittime24,yug.hospitaladmitoffset,
yug.hospitaladmitsource,yug.hospitaldischargeyear,
yug.hospitaldischargetime24,yug.hospitaldischargeoffset,
yug.hospitaldischargelocation,yug.hospitaldischargestatus,
yug.unittype,yug.unitadmittime24,yug.unitadmitsource,
yug.unitvisitnumber,yug.unitstaytype,yug.admissionweight,
yug.dischargeweight,yug.unitdischargetime24,yug.unitdischargeoffset,
yug.unitdischargelocation,yug.unitdischargestatus,
yug.uniquepid,yug.SOFA,yug.respiration,yug.coagulation,
yug.liver,yug.cardiovascular,yug.cns,yug.renal,
yug.patientunitstayid as pid, 
-- to match MIMIC's names
yug.Charlson as charlson_comorbidity_index,
yug.ethnicity as race,

CASE 
WHEN yug.age = "> 89" THEN 91
ELSE CAST(yug.age AS INT64) 
END AS anchor_age,

yug.hospitaldischargeyear as anchor_year_group,

tr_aux.mech_vent,
tr_aux.rrt,
tr_aux.pressor,

apachepatientresultO.apachescore, apachepatientresultO.acutephysiologyscore, apachepatientresultO.apache_pred_hosp_mort,
hospitaladmitoffset_OASIS,
gcs_OASIS,
heartrate_OASIS,
ibp_mean_OASIS,
respiratoryrate_OASIS,
temperature_OASIS,
urineoutput_OASIS,
adm_elective,
electivesurgery_OASIS,
major_surgery,
surgical_icu,
transfusion_yes,
insulin_yes,
glucose_max,
inr_max,
lactate_max,
potassium_max,
sodium_min,
fibrinogen_min,
fio2_avg,
pco2_max,
po2_min,
ph_min,
hemoglobin_min,
cortisol_min,
heart_rate_mean,
resp_rate_mean,
spo2_mean,
temperature_mean,
mbp_mean,
pneumonia,
uti,
biliary,
skin,
clabsi,
cauti,
ssi,
vap,
hypertension_present,
heart_failure_present,
copd_present,
asthma_present,
cad_present,
ckd_stages,
diabetes_types,
connective_disease

, CASE
  WHEN codes.first_code IS NULL
  OR codes.first_code = "No blood draws" 
  OR codes.first_code = "No blood products"
  OR codes.first_code = "Full therapy"
  THEN 1
  ELSE 0
  END AS is_full_code_admission
  
, CASE
  WHEN codes.last_code IS NULL
  OR codes.last_code = "No blood draws" 
  OR codes.last_code = "No blood products"
  OR codes.last_code = "Full therapy"
  THEN 1
  ELSE 0
  END AS is_full_code_discharge

FROM `db_name.my_eICU.yugang` as yug 

-- Pre-ICU stay LOS -> Mapping according to OASIS -> convert from hours to minutes
LEFT JOIN(
  SELECT patientunitstayid
  
  ,CASE
      WHEN hospitaladmitoffset > (-0.17*60) THEN 5
      WHEN hospitaladmitoffset BETWEEN (-4.94*60) AND (-0.17*60) THEN 3
      WHEN hospitaladmitoffset BETWEEN (-24*60) AND (-4.94*60) THEN 0
      WHEN hospitaladmitoffset BETWEEN (-311.80*60) AND (-24.0*60) THEN 2
      WHEN hospitaladmitoffset < (-311.80*60) THEN 1
      ELSE NULL
      END AS hospitaladmitoffset_OASIS

  , CASE
    WHEN unittype LIKE "%SICU%" 
    OR unittype LIKE "%CTICU%" THEN 1
    ELSE 0
    END AS surgical_icu

  FROM `physionet-data.eicu_crd.patient`
)
AS hospitaladmitoffsetO
ON hospitaladmitoffsetO.patientunitstayid = yug.patientunitstayid

-- Age -> Mapping according to OASIS below
-- <24 = 0, 24-53 = 3, 54-77 = 6, 78-89 =9 ,>90 =7

-- GCS -> Mapping according to OASIS
LEFT JOIN(
  SELECT patientunitstayid, CASE
    WHEN COUNT(gcs) < 8 THEN 10
    WHEN (COUNT(gcs) >=8 OR COUNT(gcs) <=13) THEN 4
    WHEN COUNT(gcs) =14 THEN 3
    WHEN COUNT(gcs) =15 THEN 0
    ELSE NULL
    END AS gcs_OASIS

  FROM `db_name.my_eICU.OASIS_GCS`
  GROUP BY patientunitstayid
)
AS gcsO
ON gcsO.patientunitstayid = yug.patientunitstayid

-- Heart rate -> Mapping according to OASIS
LEFT JOIN(
  SELECT patientunitstayid, CASE
    WHEN COUNT(heartrate) < 33 THEN 4
    WHEN (COUNT(heartrate) >=33 OR COUNT(heartrate) <=88) THEN 0
    WHEN (COUNT(heartrate) >=89 OR COUNT(heartrate) <=106) THEN 1
    WHEN (COUNT(heartrate) >=107 OR COUNT(heartrate) <=125) THEN 3
    WHEN COUNT(heartrate) >125 THEN 6
    ELSE NULL
    END AS heartrate_OASIS

  FROM `physionet-data.eicu_crd_derived.pivoted_vital`
  WHERE (chartoffset > 0 AND chartoffset <= 1440 ) -- convert hours to minutes -> 60*24=1440
  GROUP BY patientunitstayid
)
AS heartrateO
ON heartrateO.patientunitstayid = yug.patientunitstayid

-- Mean arterial pressure -> Mapping according to OASIS
LEFT JOIN(
  SELECT patientunitstayid, CASE
    WHEN COUNT(ibp_mean) < 20.65 THEN 4
    WHEN (COUNT(ibp_mean) >=20.65 OR COUNT(ibp_mean) <=50.99) THEN 3
    WHEN (COUNT(ibp_mean) >=51 OR COUNT(ibp_mean) <=61.32) THEN 2
    WHEN (COUNT(ibp_mean) >=61.33 OR COUNT(ibp_mean) <=143.44) THEN 0
    WHEN COUNT(ibp_mean) >143.44 THEN 3
    ELSE NULL
    END AS ibp_mean_OASIS

  FROM `physionet-data.eicu_crd_derived.pivoted_vital`
  WHERE (chartoffset > 0 AND chartoffset <= 1440 ) -- convert hours to minutes -> 60*24=1440
  GROUP BY patientunitstayid
)
AS ibp_meanO
ON ibp_meanO.patientunitstayid = yug.patientunitstayid


-- Respiratory rate -> Mapping according to OASIS
LEFT JOIN(
  SELECT patientunitstayid, CASE
    WHEN COUNT(respiratoryrate) < 6 THEN 10
    WHEN (COUNT(respiratoryrate) >=6 OR COUNT(respiratoryrate) <=12) THEN 1
    WHEN (COUNT(respiratoryrate) >=13 OR COUNT(respiratoryrate) <=22) THEN 0
    WHEN (COUNT(respiratoryrate) >=23 OR COUNT(respiratoryrate) <=30) THEN 1
    WHEN (COUNT(respiratoryrate) >=31 OR COUNT(respiratoryrate) <=44) THEN 6
    WHEN COUNT(respiratoryrate) >44 THEN 9
    ELSE NULL
    END AS respiratoryrate_OASIS

  FROM `physionet-data.eicu_crd_derived.pivoted_vital`
  WHERE (chartoffset > 0 AND chartoffset <= 1440 ) -- convert hours to minutes -> 60*24=1440
  GROUP BY patientunitstayid
)
AS respiratoryrateO
ON respiratoryrateO.patientunitstayid = yug.patientunitstayid

-- Temperature first 24h -> Mapping according to OASIS
LEFT JOIN(
  SELECT patientunitstayid, CASE
    WHEN COUNT(temperature) < 33.22 THEN 3
    WHEN (COUNT(temperature) >=33.22 OR COUNT(temperature) <=35.93) THEN 4
    WHEN (COUNT(temperature) >=35.94 OR COUNT(temperature) <=36.39) THEN 2
    WHEN (COUNT(temperature) >=36.40 OR COUNT(temperature) <=36.88) THEN 0
    WHEN (COUNT(temperature) >=36.89 OR COUNT(temperature) <=39.88) THEN 2
    WHEN COUNT(temperature) >39.88 THEN 6
    ELSE NULL
    END AS temperature_OASIS

  FROM `physionet-data.eicu_crd_derived.pivoted_vital`
  WHERE (chartoffset > 0 AND chartoffset <= 1440 ) -- convert hours to minutes -> 60*24=1440
  GROUP BY patientunitstayid
)
AS temperatureO
ON temperatureO.patientunitstayid = yug.patientunitstayid

-- Urine output first 24h -> Mapping according to OASIS
LEFT JOIN(
  SELECT patientunitstayid, CASE
    WHEN COUNT(urineoutput) <671 THEN 10
    WHEN (COUNT(urineoutput) >=671 OR COUNT(urineoutput) <=1426.99) THEN 5
    WHEN (COUNT(urineoutput) >=1427 OR COUNT(urineoutput) <=2543.99) THEN 1
    WHEN (COUNT(urineoutput) >=2544 OR COUNT(urineoutput) <=6896) THEN 0
    WHEN COUNT(urineoutput) >6896 THEN 8
    ELSE NULL
    END AS urineoutput_OASIS

  FROM `db_name.icu_elos.pivoted_uo_24h`
  GROUP BY patientunitstayid
)
AS urineoutputO
ON urineoutputO.patientunitstayid = yug.patientunitstayid

-- Ventilation -> Mapping according to OASIS, see below -> No 0, Yes 9

-- Elective surgery and admissions -> Mapping according to OASIS
LEFT JOIN(
  SELECT patientunitstayid, adm_elective
  , CASE
    WHEN new_elective_surgery = 1 THEN 0
    WHEN new_elective_surgery = 0 THEN 6
    ELSE 0
    -- Analysed admission table -> In most cases -> if elective surgery is NULL -> there was no surgery or emergency surgery
    END AS electivesurgery_OASIS
  
  , CASE
    WHEN new_elective_surgery = 1 THEN 1
    WHEN new_elective_surgery = 0 THEN 0
    WHEN adm_elective = 1 THEN 1
    ELSE 0
    END AS major_surgery

  FROM `db_name.my_eICU.pivoted_elective`
)
AS electivesurgeryO
ON electivesurgeryO.patientunitstayid = yug.patientunitstayid


-- APACHE IV
LEFT JOIN(
  SELECT patientunitstayid, 
  apachescore,
  acutephysiologyscore,
  predictedhospitalmortality as apache_pred_hosp_mort
  FROM `physionet-data.eicu_crd.apachepatientresult`
  WHERE apacheversion = "IVa"
)
AS apachepatientresultO
ON apachepatientresultO.patientunitstayid = yug.patientunitstayid

-- treatment aux table
LEFT JOIN `db_name.my_eICU.pivoted_treatments` 
AS tr_aux
ON tr_aux.patientunitstayid = yug.patientunitstayid

-- hospital table for hospital variables
LEFT JOIN(
  SELECT * 
  FROM `physionet-data.eicu_crd.hospital`
)
AS hospital
ON hospital.hospitalid = yug.hospitalid

-- pivoted lab for usual blood tests
LEFT JOIN(
  SELECT patientunitstayid,
  
  MAX(CASE WHEN 
  chartoffset < 1440 THEN glucose
  END) AS glucose_max,

  MAX(CASE WHEN 
  chartoffset < 1440 THEN INR
  END) AS inr_max,

  MAX(CASE WHEN 
  chartoffset < 1440 THEN lactate
  END) AS lactate_max,

  MAX(CASE WHEN 
  chartoffset < 1440 THEN potassium
  END) AS potassium_max,

  CASE WHEN 
  MAX(chartoffset < 1440) THEN MIN(sodium)
  END AS sodium_min,

  CASE WHEN 
  MAX(chartoffset) < 1440 THEN MIN(fibrinogen)
  END AS fibrinogen_min,

  CASE WHEN 
  MAX(chartoffset) < 1440 THEN AVG(fio2)
  END AS fio2_avg,

  CASE WHEN 
  MAX(chartoffset) < 1440 THEN MAX(pco2)
  END AS pco2_max,

  CASE WHEN 
  MAX(chartoffset) < 1440 THEN MIN(pao2)
  END AS po2_min,

  CASE WHEN 
  MAX(chartoffset) < 1440 THEN MIN(pH)
  END AS ph_min,

  MIN(hemoglobin) AS hemoglobin_min,
  MIN(cortisol) AS cortisol_min,

  FROM `db_name.my_eICU.pivoted_lab`

  GROUP BY patientunitstayid
  ORDER BY patientunitstayid
)
AS lab
ON lab.patientunitstayid = yug.patientunitstayid

-- grouped vital signs
LEFT JOIN (

SELECT patientunitstayid,

AVG(heartrate) AS heart_rate_mean,
AVG(respiratoryrate) AS resp_rate_mean,
AVG(spo2) AS spo2_mean,
AVG(temperature) AS temperature_mean,

CASE WHEN MIN(ibp_mean) IS NOT NULL THEN AVG(ibp_mean)
WHEN MIN(ibp_mean) IS NULL THEN AVG(nibp_mean) 
END AS mbp_mean

FROM `physionet-data.eicu_crd_derived.pivoted_vital` 

WHERE chartoffset < 1440
AND heartrate IS NOT NULL
OR respiratoryrate IS NOT NULL
OR spo2 IS NOT NULL
OR temperature IS NOT NULL

GROUP BY patientunitstayid
)
AS vitals
ON vitals.patientunitstayid = yug.patientunitstayid

-- Negative control outcomes - blood transfusion and insulin
LEFT JOIN  `db_name.my_eICU.pivoted_control_outcomes`
AS controls
ON controls.patientunitstayid = yug.patientunitstayid

-- add table for code status
LEFT JOIN(
  SELECT *
  FROM `db_name.my_eICU.pivoted_codes`
)
AS codes
ON codes.patientunitstayid = yug.patientunitstayid 

-- add pivoted table for comorbidities
LEFT JOIN `db_name.my_eICU.pivoted_comorbidities`
AS comorbidities
ON comorbidities.patientunitstayid = yug.patientunitstayid

/*
-- exclude non-first stays
LEFT JOIN(
  SELECT patientunitstayid, unitvisitnumber
  FROM `physionet-data.eicu_crd_derived.icustay_detail`
) 
AS icustay_detail
ON icustay_detail.patientunitstayid = yug.patientunitstayid

WHERE icustay_detail.unitvisitnumber = 1
AND yug.ethnicity != "Other/Unknown"
AND yug.age != "16" AND yug.age != "17"
)
*/

-- Remove non-first stays another way



-- exclude non-first stays
RIGHT JOIN(
  SELECT uniquepid,
  COUNT(uniquepid),
  MIN(patientunitstayid) AS patientunitstayid
  FROM `physionet-data.eicu_crd_derived.icustay_detail`

  GROUP BY uniquepid

  HAVING COUNT(uniquepid) = 1
) 
AS icustay_detail
ON icustay_detail.patientunitstayid = yug.patientunitstayid

WHERE yug.ethnicity != "Other/Unknown"
AND yug.age != "16" AND yug.age != "17"
)



SELECT *

    , CASE
    WHEN anchor_age < 24 THEN 0
    WHEN (anchor_age >= 24 OR anchor_age <= 53) THEN 3
    WHEN (anchor_age >= 54 OR anchor_age <= 77) THEN 6
    WHEN (anchor_age >= 78 OR anchor_age <= 89) THEN 9
    WHEN anchor_age > 90 THEN 7
    ELSE NULL
    END AS age_OASIS

    , CASE
    WHEN mech_vent = 1 THEN 9
    ELSE 0
    END AS vent_OASIS,

  IFNULL(gcs_OASIS, 10) AS gcs_OASIS_W, 
  IFNULL(urineoutput_OASIS, 10) AS urineoutput_OASIS_W, 
  IFNULL(electivesurgery_OASIS, 6) AS electivesurgery_OASIS_W, 
  IFNULL(temperature_OASIS, 6) AS temperature_OASIS_W, 
  IFNULL(respiratoryrate_OASIS, 10) AS respiratoryrate_OASIS_W,
  IFNULL(heartrate_OASIS, 6) AS heartrate_OASIS_W,
  IFNULL(ibp_mean_oasis, 4) AS ibp_mean_oasis_W,

  IFNULL(gcs_OASIS, 0) AS gcs_OASIS_B, 
  IFNULL(urineoutput_OASIS, 0) AS urineoutput_OASIS_B, 
  IFNULL(electivesurgery_OASIS, 0) AS electivesurgery_OASIS_B, 
  IFNULL(temperature_OASIS, 0) AS temperature_OASIS_B, 
  IFNULL(respiratoryrate_OASIS, 0) AS respiratoryrate_OASIS_B,
  IFNULL(heartrate_OASIS, 0) AS heartrate_OASIS_B,
  IFNULL(ibp_mean_oasis, 0) AS ibp_mean_oasis_B

FROM tt)

--Compute overall scores -> Fist Worst, then Best Case Scenario
 SELECT *,

    (hospitaladmitoffset_OASIS + gcs_OASIS + heartrate_OASIS +
    ibp_mean_OASIS + respiratoryrate_OASIS + temperature_OASIS +
    urineoutput_OASIS + electivesurgery_OASIS + age_OASIS + vent_OASIS) AS score_OASIS_Nulls,

    (hospitaladmitoffset_OASIS + gcs_OASIS_W + heartrate_OASIS_W +
    ibp_mean_OASIS_W + respiratoryrate_OASIS_W + temperature_OASIS_W +
    urineoutput_OASIS_W + electivesurgery_OASIS_W + age_OASIS + vent_OASIS) AS score_OASIS_W

FROM tt2)

 SELECT *,
 
    (hospitaladmitoffset_OASIS + gcs_OASIS_B + heartrate_OASIS_B +
    ibp_mean_OASIS_B + respiratoryrate_OASIS_B + temperature_OASIS_B +
    urineoutput_OASIS_B + electivesurgery_OASIS_B + age_OASIS + vent_OASIS) AS score_OASIS_B

FROM tt3

