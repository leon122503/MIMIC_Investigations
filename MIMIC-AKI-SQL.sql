-- Query 1: Count total cases of AKI (Acute Kidney Injury) diagnoses by ICD9 code and provide descriptions.
SELECT 
    COUNT(*) AS Total_Cases, 
    d.ICD9_CODE, 
    d.SHORT_TITLE, 
    d.LONG_TITLE
FROM `physionet-data.mimiciii_clinical.diagnoses_icd` aki
INNER JOIN `physionet-data.mimiciii_clinical.d_icd_diagnoses` d 
    ON aki.ICD9_CODE = d.ICD9_CODE
WHERE aki.ICD9_CODE LIKE '584%' AND aki.SEQ_NUM = 1
GROUP BY d.ICD9_CODE, d.SHORT_TITLE, d.LONG_TITLE
ORDER BY Total_Cases DESC;

-- Query 2: Identify common comorbidities associated with AKI cases where SEQ_NUM is 1.
SELECT 
    d_comorb.SHORT_TITLE, 
    COUNT(*) AS Comorbidity_Count
FROM `physionet-data.mimiciii_clinical.diagnoses_icd` aki
INNER JOIN `physionet-data.mimiciii_clinical.diagnoses_icd` comorbidity 
    ON aki.SUBJECT_ID = comorbidity.SUBJECT_ID 
    AND aki.HADM_ID = comorbidity.HADM_ID
INNER JOIN `physionet-data.mimiciii_clinical.d_icd_diagnoses` d 
    ON aki.ICD9_CODE = d.ICD9_CODE
INNER JOIN `physionet-data.mimiciii_clinical.d_icd_diagnoses` d_comorb 
    ON d_comorb.ICD9_CODE = comorbidity.ICD9_CODE
WHERE aki.ICD9_CODE LIKE '584%' 
    AND aki.SEQ_NUM = 1
    AND comorbidity.ICD9_CODE NOT LIKE '584%'
GROUP BY d_comorb.SHORT_TITLE, comorbidity.ICD9_CODE
HAVING Comorbidity_Count > 10
ORDER BY Comorbidity_Count DESC;

-- This query identifies common comorbidities associated with different types of Acute Kidney Injury (AKI) 
SELECT 
    d_aki.SHORT_TITLE AS AKI_Diagnosis, 
    d_comorb.SHORT_TITLE AS Comorbidity_Diagnosis, 
    COUNT(*) AS Comorbidity_Count
FROM `physionet-data.mimiciii_clinical.diagnoses_icd` aki
INNER JOIN `physionet-data.mimiciii_clinical.diagnoses_icd` comorbidity 
    ON aki.SUBJECT_ID = comorbidity.SUBJECT_ID 
    AND aki.HADM_ID = comorbidity.HADM_ID
INNER JOIN `physionet-data.mimiciii_clinical.d_icd_diagnoses` d_aki 
    ON aki.ICD9_CODE = d_aki.ICD9_CODE
INNER JOIN `physionet-data.mimiciii_clinical.d_icd_diagnoses` d_comorb 
    ON comorbidity.ICD9_CODE = d_comorb.ICD9_CODE
WHERE aki.ICD9_CODE LIKE '584%' 
    AND aki.SEQ_NUM = 1
    AND comorbidity.ICD9_CODE NOT LIKE '584%'
GROUP BY d_aki.SHORT_TITLE, d_comorb.SHORT_TITLE, comorbidity.ICD9_CODE
HAVING Comorbidity_Count > 10
ORDER BY d_aki.SHORT_TITLE, Comorbidity_Count DESC;



-- Query 3: Similar to Query 2 but filters for comorbidities where SEQ_NUM is 2.
SELECT 
    d_comorb.SHORT_TITLE, 
    COUNT(*) AS Comorbidity_Count
FROM `physionet-data.mimiciii_clinical.diagnoses_icd` aki
INNER JOIN `physionet-data.mimiciii_clinical.diagnoses_icd` comorbidity 
    ON aki.SUBJECT_ID = comorbidity.SUBJECT_ID 
    AND aki.HADM_ID = comorbidity.HADM_ID
INNER JOIN `physionet-data.mimiciii_clinical.d_icd_diagnoses` d 
    ON aki.ICD9_CODE = d.ICD9_CODE
INNER JOIN `physionet-data.mimiciii_clinical.d_icd_diagnoses` d_comorb 
    ON d_comorb.ICD9_CODE = comorbidity.ICD9_CODE
WHERE aki.ICD9_CODE LIKE '584%' 
    AND aki.SEQ_NUM = 1
    AND comorbidity.ICD9_CODE NOT LIKE '584%'
    AND comorbidity.SEQ_NUM = 2
GROUP BY d_comorb.SHORT_TITLE, comorbidity.ICD9_CODE
ORDER BY Comorbidity_Count DESC;

-- Query 3: Calculate the percentage of AKI cases among different ethnic groups with more than 500 admissions.
WITH TotalAdmissionsByEthnicity AS (
    SELECT 
    ETHNICITY,
    COUNT(*) AS TotalAdmissions
    FROM `physionet-data.mimiciii_clinical.admissions`
    GROUP BY ETHNICITY
)
SELECT 
    a.ETHNICITY, 
    COUNT(*) AS AKI_Cases,
    total_admsn.TotalAdmissions AS AllAdmissionsCount,
    CEIL((COUNT(*) / total_admsn.TotalAdmissions) * 100) AS Percentage_AKI
FROM `physionet-data.mimiciii_clinical.diagnoses_icd` aki
INNER JOIN `physionet-data.mimiciii_clinical.admissions` a 
    ON a.SUBJECT_ID = aki.SUBJECT_ID
INNER JOIN TotalAdmissionsByEthnicity total_admsn 
    ON total_admsn.ETHNICITY = a.ETHNICITY
WHERE aki.ICD9_CODE LIKE '584%' 
    AND aki.SEQ_NUM = 1
    AND total_admsn.TotalAdmissions > 500
GROUP BY a.ETHNICITY, total_admsn.TotalAdmissions
ORDER BY Percentage_AKI DESC;


-- Query 5: Determine readmission rates within specific time frames (7, 30, and 60 days) for patients with AKI.
WITH AKIAdmissions AS (
    SELECT 
    a.SUBJECT_ID, 
    a.HADM_ID, 
    a.ADMITTIME, 
    a.DISCHTIME
    FROM `physionet-data.mimiciii_clinical.admissions` a
    INNER JOIN `physionet-data.mimiciii_clinical.diagnoses_icd` d 
    ON a.HADM_ID = d.HADM_ID
    WHERE d.ICD9_CODE LIKE '584%'
    GROUP BY a.SUBJECT_ID, a.HADM_ID, a.ADMITTIME, a.DISCHTIME
),
RankedAKIAdmissions AS (
    SELECT *,
    LEAD(ADMITTIME) OVER(PARTITION BY SUBJECT_ID ORDER BY ADMITTIME) AS Next_AKI_ADMITTIME
    FROM AKIAdmissions
)
SELECT 
    SUBJECT_ID, 
    HADM_ID, 
    ADMITTIME, 
    DISCHTIME, 
    Next_AKI_ADMITTIME,
    DATE_DIFF(Next_AKI_ADMITTIME, DISCHTIME, DAY) AS Days_Until_Next_AKI_Admission,
    IF(DATE_DIFF(Next_AKI_ADMITTIME, DISCHTIME, DAY) <= 60, 'YES', 'NO') AS AKI_Readmission_Within_60_Days,
    IF(DATE_DIFF(Next_AKI_ADMITTIME, DISCHTIME, DAY) <= 30, 'YES', 'NO') AS AKI_Readmission_Within_30_Days,
    IF(DATE_DIFF(Next_AKI_ADMITTIME, DISCHTIME, DAY) <= 7, 'YES', 'NO') AS AKI_Readmission_Within_7_Days
FROM RankedAKIAdmissions
ORDER BY SUBJECT_ID, ADMITTIME;

-- Query 4: Save the results from Query 5 into a table in the AKIreadmissions database.
CREATE OR REPLACE TABLE `tidal-velocity-449200-q7.AKIreadmissions.readmissions` AS
WITH AKIAdmissions AS (
    SELECT 
    a.SUBJECT_ID, 
    a.HADM_ID, 
    a.ADMITTIME, 
    a.DISCHTIME
    FROM `physionet-data.mimiciii_clinical.admissions` a
    INNER JOIN `physionet-data.mimiciii_clinical.diagnoses_icd` d 
    ON a.HADM_ID = d.HADM_ID
    WHERE d.ICD9_CODE LIKE '584%'
    GROUP BY a.SUBJECT_ID, a.HADM_ID, a.ADMITTIME, a.DISCHTIME
),
RankedAKIAdmissions AS (
    SELECT *,
    LEAD(ADMITTIME) OVER(PARTITION BY SUBJECT_ID ORDER BY ADMITTIME) AS Next_AKI_ADMITTIME
    FROM AKIAdmissions
)
SELECT 
    SUBJECT_ID, 
    HADM_ID, 
    ADMITTIME, 
    DISCHTIME, 
    Next_AKI_ADMITTIME,
    DATE_DIFF(Next_AKI_ADMITTIME, DISCHTIME, DAY) AS Days_Until_Next_AKI_Admission,
    IF(DATE_DIFF(Next_AKI_ADMITTIME, DISCHTIME, DAY) <= 60, 'YES', 'NO') AS AKI_Readmission_Within_60_Days,
    IF(DATE_DIFF(Next_AKI_ADMITTIME, DISCHTIME, DAY) <= 30, 'YES', 'NO') AS AKI_Readmission_Within_30_Days,
    IF(DATE_DIFF(Next_AKI_ADMITTIME, DISCHTIME, DAY) <= 7, 'YES', 'NO') AS AKI_Readmission_Within_7_Days
FROM RankedAKIAdmissions
ORDER BY SUBJECT_ID, ADMITTIME;

-- Query 4: Calculate the readmission rate within 7 days for AKI patients.
SELECT 
    COUNT(*) AS Total_AKI_Admissions,
    SUM(CASE WHEN AKI_Readmission_Within_7_Days = 'YES' THEN 1 ELSE 0 END) AS AKI_Readmission_Within_7_Days,
    CEIL(SAFE_DIVIDE(SUM(CASE WHEN AKI_Readmission_Within_7_Days = 'YES' THEN 1 ELSE 0 END), COUNT(*)) * 100) AS Readmission_Rate_Percent
FROM `tidal-velocity-449200-q7.AKIreadmissions.readmissions`;

-- Query 4: Calculate the readmission rate within 30 days for AKI patients.
SELECT 
    COUNT(*) AS Total_AKI_Admissions,
    SUM(CASE WHEN AKI_Readmission_Within_30_Days = 'YES' THEN 1 ELSE 0 END) AS Total_AKI_Readmissions_Within_30_Days,
    CEIL(SAFE_DIVIDE(SUM(CASE WHEN AKI_Readmission_Within_30_Days = 'YES' THEN 1 ELSE 0 END), COUNT(*)) * 100) AS Readmission_Rate_Percent
FROM `tidal-velocity-449200-q7.AKIreadmissions.readmissions`;

-- Query 4: Calculate the readmission rate within 60 days for AKI patients.
SELECT 
    COUNT(*) AS Total_AKI_Admissions,
    SUM(CASE WHEN AKI_Readmission_Within_60_Days = 'YES' THEN 1 ELSE 0 END) AS AKI_Readmission_Within_60_Days,
    CEIL(SAFE_DIVIDE(SUM(CASE WHEN AKI_Readmission_Within_60_Days = 'YES' THEN 1 ELSE 0 END), COUNT(*)) * 100) AS Readmission_Rate_Percent
FROM `tidal-velocity-449200-q7.AKIreadmissions.readmissions`;


-- Query 10: Analyze readmission rates based on length of stay for AKI patients.
WITH LOS_Readmissions AS (
    SELECT 
    SUBJECT_ID, 
    HADM_ID, 
    ADMITTIME, 
    DISCHTIME,
    DATE_DIFF(DISCHTIME, ADMITTIME, DAY) AS Length_of_Stay,
    AKI_Readmission_Within_30_Days
    FROM `tidal-velocity-449200-q7.AKIreadmissions.readmissions`
)
SELECT 
    Length_of_Stay,
    COUNT(*) AS Total_Admissions,
    SUM(CASE WHEN AKI_Readmission_Within_30_Days = 'YES' THEN 1 ELSE 0 END) AS Readmissions_Within_30_Days,
    CEIL(SAFE_DIVIDE(SUM(CASE WHEN AKI_Readmission_Within_30_Days = 'YES' THEN 1 ELSE 0 END), COUNT(*)) * 100) AS Readmission_Rate_Percent
FROM LOS_Readmissions
GROUP BY Length_of_Stay
ORDER BY Length_of_Stay DESC;

-- Query 11: Identify the most commonly prescribed drugs for AKI patients.
SELECT 
    p.DRUG, 
    COUNT(DISTINCT p.HADM_ID) AS Prescriptions_Count
FROM `physionet-data.mimiciii_clinical.prescriptions` p
INNER JOIN `physionet-data.mimiciii_clinical.diagnoses_icd` d 
    ON p.HADM_ID = d.HADM_ID
WHERE d.ICD9_CODE LIKE '584%'
GROUP BY p.DRUG
ORDER BY Prescriptions_Count DESC;

-- Query 12: Analyze AKI admissions by gender and age group.
SELECT 
    p.GENDER, 
    CASE
    WHEN FLOOR(DATE_DIFF(a.ADMITTIME, p.DOB, YEAR) / 10) * 10 = 300 THEN 90
    WHEN FLOOR(DATE_DIFF(a.ADMITTIME, p.DOB, YEAR) / 10) * 10 > 300 THEN 95
    ELSE FLOOR(DATE_DIFF(a.ADMITTIME, p.DOB, YEAR) / 10) * 10
    END AS Age_Group,
    COUNT(a.HADM_ID) AS AKI_Admissions
FROM `physionet-data.mimiciii_clinical.patients` p
INNER JOIN `physionet-data.mimiciii_clinical.admissions` a 
    ON p.SUBJECT_ID = a.SUBJECT_ID
INNER JOIN `physionet-data.mimiciii_clinical.diagnoses_icd` d 
    ON a.HADM_ID = d.HADM_ID
WHERE d.ICD9_CODE LIKE '584%' 
    AND d.SEQ_NUM = 1
GROUP BY p.GENDER, Age_Group
ORDER BY p.GENDER, Age_Group;

-- Query 13: Analyze mortality rates based on length of stay for AKI patients.
WITH LOS_Mort AS (
    SELECT 
    d.HADM_ID, 
    DATE_DIFF(a.DISCHTIME, a.ADMITTIME, DAY) AS Length_of_Stay,
    a.HOSPITAL_EXPIRE_FLAG AS Mortality_Flag
    FROM `physionet-data.mimiciii_clinical.admissions` a
    INNER JOIN `physionet-data.mimiciii_clinical.diagnoses_icd` d 
    ON a.HADM_ID = d.HADM_ID  
    WHERE d.ICD9_CODE LIKE '584%'
)
SELECT 
    Length_of_Stay,
    COUNT(*) AS Total_AKI_Admissions,
    SUM(Mortality_Flag) AS Mortality_Count,
    CEIL(SAFE_DIVIDE(SUM(Mortality_Flag), COUNT(*)) * 100) AS Mortality_Rate_Percent
FROM LOS_Mort
GROUP BY Length_of_Stay
ORDER BY Length_of_Stay;

-- Query 7: Identify the top abnormal lab items for AKI patients.
WITH AKI_PATIENTS AS (
    SELECT DISTINCT A.SUBJECT_ID
    FROM `physionet-data.mimiciii_clinical.diagnoses_icd` D
    JOIN `physionet-data.mimiciii_clinical.admissions` A
    ON D.HADM_ID = A.HADM_ID
    WHERE D.ICD9_CODE LIKE '584%'
)
SELECT 
    L.ITEMID,
    DL.LABEL,
    COUNT(*) AS ABNORMAL_COUNT
FROM AKI_PATIENTS AP
JOIN `physionet-data.mimiciii_clinical.labevents` L
    ON AP.SUBJECT_ID = L.SUBJECT_ID
JOIN `physionet-data.mimiciii_clinical.d_labitems` DL
    ON L.ITEMID = DL.ITEMID
WHERE L.FLAG = 'abnormal'
GROUP BY L.ITEMID, DL.LABEL
ORDER BY ABNORMAL_COUNT DESC
LIMIT 10;

-- Query 15: Determine the distribution of AKI patients across different ICU care units.
WITH AKI_PATIENTS AS (
    SELECT DISTINCT A.SUBJECT_ID
    FROM `physionet-data.mimiciii_clinical.diagnoses_icd` D
    JOIN `physionet-data.mimiciii_clinical.admissions` A
    ON D.HADM_ID = A.HADM_ID
    WHERE D.ICD9_CODE LIKE '584%'
)
SELECT 
    I.FIRST_CAREUNIT,
    COUNT(DISTINCT AP.SUBJECT_ID) AS PATIENT_COUNT
FROM AKI_PATIENTS AP
JOIN `physionet-data.mimiciii_clinical.icustays` I
    ON AP.SUBJECT_ID = I.SUBJECT_ID
GROUP BY I.FIRST_CAREUNIT
ORDER BY PATIENT_COUNT DESC;

-- Query 16: Identify the average dosage and count of prescriptions for AKI patients.
WITH AKI_PATIENTS AS (
    SELECT DISTINCT A.SUBJECT_ID
    FROM `physionet-data.mimiciii_clinical.diagnoses_icd` D
    JOIN `physionet-data.mimiciii_clinical.admissions` A
    ON D.HADM_ID = A.HADM_ID
    WHERE D.ICD9_CODE LIKE '584%'
)
SELECT 
    P.DRUG,
    AVG(CAST(REGEXP_EXTRACT(P.DOSE_VAL_RX, r'[0-9]+') AS FLOAT64)) AS AVG_DOSE,
    COUNT(*) AS PRESCRIPTION_COUNT
FROM AKI_PATIENTS AP
JOIN `physionet-data.mimiciii_clinical.prescriptions` P
    ON AP.SUBJECT_ID = P.SUBJECT_ID
WHERE P.DOSE_VAL_RX IS NOT NULL
GROUP BY P.DRUG
ORDER BY PRESCRIPTION_COUNT DESC
LIMIT 10;

-- Query 17: Analyze the trend of AKI admissions over the years.
WITH AKI_ADMISSIONS AS (
    SELECT 
    EXTRACT(YEAR FROM A.ADMITTIME) AS Admission_Year,
    COUNT(*) AS Admission_Count
    FROM `physionet-data.mimiciii_clinical.diagnoses_icd` D
    JOIN `physionet-data.mimiciii_clinical.admissions` A
    ON D.HADM_ID = A.HADM_ID
    WHERE D.ICD9_CODE LIKE '584%'
    GROUP BY EXTRACT(YEAR FROM A.ADMITTIME)
)
SELECT 
    Admission_Year,
    Admission_Count
FROM AKI_ADMISSIONS
ORDER BY Admission_Year;

-- Query 9: Analyze mortality rates across different ICU care units for AKI patients.
WITH AKI_PATIENTS AS (
    SELECT DISTINCT A.SUBJECT_ID
    FROM `physionet-data.mimiciii_clinical.diagnoses_icd` D
    JOIN `physionet-data.mimiciii_clinical.admissions` A
    ON D.HADM_ID = A.HADM_ID
    WHERE D.ICD9_CODE LIKE '584%'
)
SELECT 
    I.FIRST_CAREUNIT,
    COUNT(DISTINCT AP.SUBJECT_ID) AS TOTAL_PATIENTS,
    SUM(CASE WHEN A.HOSPITAL_EXPIRE_FLAG = 1 THEN 1 ELSE 0 END) AS DECEASED_COUNT,
    ROUND(SUM(CASE WHEN A.HOSPITAL_EXPIRE_FLAG = 1 THEN 1 ELSE 0 END) / COUNT(DISTINCT AP.SUBJECT_ID) * 100, 2) AS MORTALITY_RATE
FROM AKI_PATIENTS AP
JOIN `physionet-data.mimiciii_clinical.admissions` A
    ON AP.SUBJECT_ID = A.SUBJECT_ID
JOIN `physionet-data.mimiciii_clinical.icustays` I
    ON A.HADM_ID = I.HADM_ID
GROUP BY I.FIRST_CAREUNIT
ORDER BY MORTALITY_RATE DESC;


 -- Query 8: Analyze LOS across different gender and age ranges
WITH AKI_PATIENTS AS (
    SELECT DISTINCT A.SUBJECT_ID
    FROM `physionet-data.mimiciii_clinical.diagnoses_icd` D
    JOIN `physionet-data.mimiciii_clinical.admissions` A
        ON D.HADM_ID = A.HADM_ID
    WHERE D.ICD9_CODE LIKE '584%'
),
GROUPED_DATA AS (
    SELECT 
        P.GENDER,
        CASE
            WHEN FLOOR(DATE_DIFF(I.INTIME, P.DOB, YEAR) / 10) * 10 = 300 THEN '90+'
            WHEN FLOOR(DATE_DIFF(I.INTIME, P.DOB, YEAR) / 10) * 10 > 300 THEN '95+'
            ELSE CAST(FLOOR(DATE_DIFF(I.INTIME, P.DOB, YEAR) / 10) * 10 AS STRING) || 's'
        END AS AGE_GROUP,
        COUNT(*) AS PATIENT_COUNT,
        ROUND(AVG(I.LOS), 2) AS AVG_ICU_LOS_DAYS
    FROM AKI_PATIENTS AP
    JOIN `physionet-data.mimiciii_clinical.patients` P
        ON AP.SUBJECT_ID = P.SUBJECT_ID
    JOIN `physionet-data.mimiciii_clinical.icustays` I
        ON AP.SUBJECT_ID = I.SUBJECT_ID
    GROUP BY P.GENDER, AGE_GROUP
)
SELECT 
    GENDER,
    AGE_GROUP,
    PATIENT_COUNT,
    AVG_ICU_LOS_DAYS,
    ROUND((PATIENT_COUNT / SUM(PATIENT_COUNT) OVER ()) * 100, 2) AS PROPORTION_PERCENT
FROM GROUPED_DATA
ORDER BY GENDER, AGE_GROUP;

-- Query 7: Identify the most common procedures performed on AKI patients.
WITH AKI_PATIENTS AS (
    SELECT DISTINCT A.SUBJECT_ID
    FROM `physionet-data.mimiciii_clinical.diagnoses_icd` D
    JOIN `physionet-data.mimiciii_clinical.admissions` A
    ON D.HADM_ID = A.HADM_ID
    WHERE D.ICD9_CODE LIKE '584%'
)
SELECT 
    PR.ICD9_CODE,
    DP.SHORT_TITLE,
    COUNT(*) AS PROCEDURE_COUNT
FROM AKI_PATIENTS AP
JOIN `physionet-data.mimiciii_clinical.procedures_icd` PR
    ON AP.SUBJECT_ID = PR.SUBJECT_ID
JOIN `physionet-data.mimiciii_clinical.d_icd_procedures` DP
    ON PR.ICD9_CODE = DP.ICD9_CODE
GROUP BY PR.ICD9_CODE, DP.SHORT_TITLE
ORDER BY PROCEDURE_COUNT DESC
LIMIT 10;

-- Query 21: Analyze discharge locations for AKI patients.
WITH AKI_PATIENTS AS (
    SELECT DISTINCT A.SUBJECT_ID
    FROM `physionet-data.mimiciii_clinical.diagnoses_icd` D
    JOIN `physionet-data.mimiciii_clinical.admissions` A
    ON D.HADM_ID = A.HADM_ID
    WHERE D.ICD9_CODE LIKE '584%'
)
SELECT 
    A.DISCHARGE_LOCATION,
    COUNT(*) AS DISCHARGE_COUNT
FROM AKI_PATIENTS AP
JOIN `physionet-data.mimiciii_clinical.admissions` A
    ON AP.SUBJECT_ID = A.SUBJECT_ID
GROUP BY A.DISCHARGE_LOCATION
ORDER BY DISCHARGE_COUNT DESC;

-- Query 10: Analyze mortality rates based on creatinine levels for AKI patients.
WITH AKI_CREATININE AS (
    SELECT 
    L.SUBJECT_ID,
    MAX(CAST(L.VALUENUM AS FLOAT64)) AS MAX_CREATININE
    FROM `physionet-data.mimiciii_clinical.labevents` L
    JOIN `physionet-data.mimiciii_clinical.d_labitems` DL
    ON L.ITEMID = DL.ITEMID
    WHERE DL.LABEL = 'Creatinine'
    GROUP BY L.SUBJECT_ID
),
AKI_MORTALITY AS (
    SELECT 
    A.SUBJECT_ID,
    A.HOSPITAL_EXPIRE_FLAG
    FROM `physionet-data.mimiciii_clinical.diagnoses_icd` D
    JOIN `physionet-data.mimiciii_clinical.admissions` A
    ON D.HADM_ID = A.HADM_ID
    WHERE D.ICD9_CODE LIKE '584%'
)
SELECT 
    CASE 
    WHEN AC.MAX_CREATININE < 1.2 THEN 'Normal'
    WHEN AC.MAX_CREATININE BETWEEN 1.2 AND 2.0 THEN 'Mildly Elevated'
    ELSE 'Severely Elevated'
    END AS Creatinine_Level,
    COUNT(*) AS PATIENT_COUNT,
    SUM(AM.HOSPITAL_EXPIRE_FLAG) AS DECEASED_COUNT,
    ROUND(SUM(AM.HOSPITAL_EXPIRE_FLAG) / COUNT(*) * 100, 2) AS MORTALITY_RATE
FROM AKI_CREATININE AC
JOIN AKI_MORTALITY AM
    ON AC.SUBJECT_ID = AM.SUBJECT_ID
GROUP BY Creatinine_Level
ORDER BY MORTALITY_RATE DESC;


