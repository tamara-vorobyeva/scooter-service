# 📊 Analysis of the the seasonal trends in the real estate market of St. Petersburg and the Leningrad region for the purpose of Marketing Optimization

## 📌 Business Case Overview
The client, a real-estate agency was considering entering St. Petersburg's market and needed reliable data to assess its prospects and plan market launch activities. 

## 🎯 Project Objectives 
- Identify the market dynamics and deliver insights regarding periods with increased activity of sellers and buyers to leadership.📌 
- Create interactive dashboard.📌 

## 🔗 Quick Links
* ▶ **[View Interactive Dashboard in Yandex DataLens](https://datalens.ru/gvj9ho0yb4tc0)** (No registration required)
* 🛠 **[View SQL Data Cleaning & Analysis Script](src/data-cleansing-analysis)** 

---

## 🛠 Tech Stack
* **Database:** PostgreSQL (temporary tables, advanced Window Functions, CTEs, complex aggregations, segmentation, pivot).
* **Data Processing:** PostgreSQL (DBeaver) — utilized for data deduplication and data anomalies filtration.
* **BI Platform:** Yandex DataLens — leveraged for building the interactive dashboard and performing cohort analysis.

---

## 🔍 Research Approach 
* **Data Cleaning & Scope**: The study analyzed a cleaned 2015–2018 real estate dataset for St. Petersburg and Leningrad Oblast towns, filtering out extreme anomalies in area, price, and zero-duration listings to ensure consistency.
* **Methodological Segmentation**: The analysis separated the data into specific temporary subsets to distinctly track listing publications (supply) and listing removals (completed sales) over time.
* **Time Lag Integration**: The methodology explicitly incorporated a natural 1–2 month transaction lag, noting that listing removals heavily reflect purchasing decisions made in preceding months.  

---

## 💡 Key Findings
*	**St. Petersburg Domination**: St. Petersburg heavily drives the regional market, exhibiting 1.7x higher square-meter prices and a financial volume in November that is 8 times larger than the entire Leningrad Oblast. 
*	**Autumn Market Peak**: Autumn (September to November) serves as the ultimate peak season where buyer and seller activities align, contrasted by a sharp supply-demand mismatch in February and absolute market stagnation in May. 
*	**Liquidity and Format Correlations**: Most listings close within 1–3 months or stretch beyond half a year, with transaction speeds heavily dictated by lower prices, smaller 1-room formats, and the presence of a balcony. 

---

## 🚀 Strategic Recommendations
*	**Core Focus & Timing**: Concentrate primary business operations within St. Petersburg and launch major marketing campaigns between late September and October to capture the peak annual demand. 
*	**Target High-Liquidity Segment**: Build the core portfolio around 1–2 room apartments ranging between 45 and 65 sq.m. in St. Petersburg and highly accessible inner-city towns like Gatchina, Pushkin, and Pavlovsk. 
*	**Cautious Premium Execution**: Enter the high-commission premium tier selectively, factoring in aggressive market competition and a 1.5x longer sales cycle (averaging 228 days compared to 155 days for budget properties). 

---

## 📁 Repository Structure
* 'README.md' — Project overview and executive summary (this file).
* '/data' — Anonymized raw dataset limited to 500 data entries.
* '/src' — Source code folder containing SQL script (PostGreSQL).
